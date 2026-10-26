"""Execute or print a plan."""

from __future__ import annotations

import os
import subprocess
import time
from pathlib import Path

from dlsurfer.adapters.plan import Plan, runnable_steps
from dlsurfer.contract import check_profile_contract, ensure_fs_tree


def format_plan(plan: Plan, *, verbose: bool = True) -> str:
    lines: list[str] = []
    lines.append(f"Profile: {plan.profile}")
    lines.append(plan.description)
    for w in plan.warnings:
        lines.append(f"WARNING: {w}")
    if plan.citations_note:
        lines.append(f"Citations: {plan.citations_note}")
    lines.append("")
    for i, s in enumerate(plan.steps, 1):
        tag = "info" if s.informational or (s.argv and str(s.argv[0]).startswith("#")) else "run"
        # Quiet mode: skip pure info rows (bundled into FastSurfer argv) unless they have a command.
        if not verbose and tag == "info" and not s.argv:
            continue
        lines.append(f"--- step {i} [{tag}] {s.engine_name} ({s.engine_id}) device={s.device}")
        if verbose:
            lines.append(f"Why: {s.why}")
            for c in s.citations:
                lines.append(f"  cite: {c}")
            for n in s.notes:
                lines.append(f"  note: {n}")
        if s.argv:
            lines.append("  $ " + " ".join(s.argv))
        lines.append("")
    return "\n".join(lines)


def _expand_argv(argv: list[str]) -> list[str]:
    return [os.path.expandvars(a) for a in argv]


def execute_plan(
    plan: Plan,
    *,
    dry_run: bool = True,
    sd: Path | None = None,
    sid: str | None = None,
    allow_experimental: bool = False,
    quiet: bool = False,
) -> int:
    print(format_plan(plan, verbose=not quiet))

    if not dry_run and not allow_experimental:
        from dlsurfer.gates import gates_blocking_profile

        blockers = gates_blocking_profile(plan.profile)
        if blockers:
            print("[dlsurfer] execute blocked by open gates:")
            for b in blockers:
                print(f"  - {b['id']}: {b.get('title')} [{b.get('status')}]")
                if b.get("note"):
                    print(f"    {str(b['note']).strip()[:160]}")
            print("Re-run with --allow-experimental after reviewing gates, or mark status: passed in gates.yaml.")
            return 3

    if dry_run:
        print("[dlsurfer] dry-run only — no commands executed.")
        return 0

    metrics_path = None
    if sd and sid:
        ensure_fs_tree(Path(sd), sid)
        metrics_path = Path(sd) / sid / "scripts" / "dlsurfer_metrics.tsv"
        if not metrics_path.exists():
            metrics_path.write_text("step\tengine\tdevice\tseconds\texit\n")

    for s in runnable_steps(plan):
        argv = _expand_argv(s.argv)
        # Refuse unresolved ${VAR} placeholders on execute
        unresolved = [a for a in argv if a.startswith("${") and a.endswith("}")]
        if unresolved:
            print(f"[dlsurfer] unresolved env placeholders: {unresolved}")
            return 2
        print(f"[dlsurfer] running: {' '.join(argv)}")
        t0 = time.time()
        proc = subprocess.run(argv, check=False)
        dt = time.time() - t0
        if metrics_path:
            with metrics_path.open("a") as f:
                f.write(f"{s.stage}\t{s.engine_id}\t{s.device}\t{dt:.2f}\t{proc.returncode}\n")
        if proc.returncode != 0:
            print(f"[dlsurfer] step failed ({proc.returncode}): {s.engine_id}")
            return proc.returncode

    if sd and sid:
        if metrics_path and metrics_path.exists():
            _print_metrics_summary(metrics_path)
        problems = check_profile_contract(
            Path(sd),
            sid,
            plan.profile,
            atlas=plan.atlas,
        )
        if problems:
            print("[dlsurfer] FreeSurfer-shaped contract warnings:")
            for p in problems:
                print(f"  - {p}")
    return 0


def _print_metrics_summary(path: Path) -> None:
    rows = path.read_text().strip().splitlines()
    if len(rows) <= 1:
        return
    total = 0.0
    by_device: dict[str, float] = {}
    for line in rows[1:]:
        parts = line.split("\t")
        if len(parts) < 5:
            continue
        try:
            sec = float(parts[3])
        except ValueError:
            continue
        total += sec
        by_device[parts[2]] = by_device.get(parts[2], 0.0) + sec
    print(f"[dlsurfer] metrics: {path}")
    print(f"[dlsurfer] wall_compute_s={total:.1f} by_device={{{', '.join(f'{k}:{v:.1f}' for k,v in by_device.items())}}}")
    print("[dlsurfer] compare to legacy: add SLURM queue time from job .out; see docs/lab/LIVE_RUNS.md")
