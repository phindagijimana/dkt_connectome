"""Execute or print a plan."""

from __future__ import annotations

import subprocess
import time
from pathlib import Path

from dlsurfer.adapters.plan import Plan, runnable_steps
from dlsurfer.contract import check_contract


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


def execute_plan(plan: Plan, *, dry_run: bool = True, sd: Path | None = None, sid: str | None = None) -> int:
    print(format_plan(plan, verbose=True))
    if dry_run:
        print("[dlsurfer] dry-run only — no commands executed.")
        return 0

    metrics_path = None
    if sd and sid:
        metrics_path = Path(sd) / sid / "scripts" / "dlsurfer_metrics.tsv"
        metrics_path.parent.mkdir(parents=True, exist_ok=True)
        if not metrics_path.exists():
            metrics_path.write_text("step\tengine\tdevice\tseconds\texit\n")

    for s in runnable_steps(plan):
        print(f"[dlsurfer] running: {' '.join(s.argv)}")
        t0 = time.time()
        proc = subprocess.run(s.argv, check=False)
        dt = time.time() - t0
        if metrics_path:
            with metrics_path.open("a") as f:
                f.write(f"{s.stage}\t{s.engine_id}\t{s.device}\t{dt:.2f}\t{proc.returncode}\n")
        if proc.returncode != 0:
            print(f"[dlsurfer] step failed ({proc.returncode}): {s.engine_id}")
            return proc.returncode

    if sd and sid and plan.profile.startswith("core"):
        problems = check_contract(Path(sd), sid, seg_only="seg-quick" in plan.profile)
        if problems:
            print("[dlsurfer] contract warnings:")
            for p in problems:
                print(f"  - {p}")
    return 0