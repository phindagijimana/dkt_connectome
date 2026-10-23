"""dlsurfer command-line interface."""

from __future__ import annotations

import argparse
import sys
from pathlib import Path

import yaml

from dlsurfer import __claim__, __version__
from dlsurfer.adapters.plan import build_plan
from dlsurfer.doctor import run_doctor
from dlsurfer.registry import engines as load_engines
from dlsurfer.registry import profiles as load_profiles
from dlsurfer.runner import execute_plan

_PKG = Path(__file__).resolve().parent
_ISOLATION = (
    "Isolated under methods/others_methods/preprocessing/DL/dlsurfer/ — "
    "does not import or modify the DKT connectome pipeline."
)


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(
        prog="dlsurfer",
        description=(
            "DLSurfer: curated deep-learning morphometry orchestrator. "
            + __claim__
            + " "
            + _ISOLATION
        ),
    )
    parser.add_argument("--version", action="version", version=f"dlsurfer {__version__}")
    sub = parser.add_subparsers(dest="cmd", required=True)

    sub.add_parser("doctor", help="Check environment, pins, isolation, claim boundary")
    sub.add_parser("profiles", help="List profiles")
    sub.add_parser("atlases", help="List cortical/subcortical atlas options (DKT default, not exclusive)")
    sub.add_parser("compare", help="Summarize DLSurfer vs FreeSurfer vs FastSurfer gaps")
    sub.add_parser(
        "gaps-remaining",
        help="Gaps with no credible alternative (or out-of-scope / by design)",
    )
    p_eng = sub.add_parser("engines", help="List engines with why, citations, and alternatives")
    p_eng.add_argument("--id", help="Show one engine")
    p_eng.add_argument(
        "--alternatives",
        action="store_true",
        help="Print alternatives table for all chosen engines",
    )

    p_cite = sub.add_parser("cite", help="Print citation boilerplate for a profile or all engines")
    p_cite.add_argument("--profile", help="Profile name")

    p_run = sub.add_parser("run", help="Build/execute a profile plan")
    p_run.add_argument("--t1", type=Path, required=True)
    p_run.add_argument("--sd", type=Path, required=True, help="SUBJECTS_DIR (DLSurfer-owned tree)")
    p_run.add_argument("--sid", required=True)
    p_run.add_argument("--profile", required=True)
    p_run.add_argument(
        "--atlas",
        default=None,
        help="Cortical atlas (default dkt, or profile atlas). Wired: dkt|dk|destrieux|schaefer|aseg.",
    )
    p_run.add_argument("--lesion-mask", type=Path, default=None)
    p_run.add_argument("--fs-license", type=Path, default=None)
    p_run.add_argument("--device", default="auto", choices=["auto", "cpu", "cuda"])
    p_run.add_argument("--threads", type=int, default=4)
    p_run.add_argument("--vox-size", type=float, default=None, help="FastSurfer --vox_size (hires VINN)")
    p_run.add_argument("--no-cc", action="store_true", help="FastSurfer --no_cc")
    p_run.add_argument("--no-cereb", action="store_true", help="FastSurfer --no_cereb")
    p_run.add_argument("--no-hypothal", action="store_true", help="FastSurfer --no_hypothal")
    p_run.add_argument(
        "--hpc",
        default="none",
        choices=["none", "srun", "brun"],
        help="Use FastSurfer srun_fastsurfer.sh or brun_fastsurfer.sh launcher",
    )
    p_run.add_argument("--post-lit", action=argparse.BooleanOptionalAction, default=True)
    p_run.add_argument(
        "--execute",
        action="store_true",
        help="Actually run commands (default is dry-run)",
    )

    p_handoff = sub.add_parser(
        "handoff",
        help="Optional one-way notes for consumers (DKT or other) — does not run connectome",
    )
    p_handoff.add_argument("--sd", type=Path, required=True)
    p_handoff.add_argument("--sid", required=True)
    p_handoff.add_argument(
        "--consumer",
        default="generic",
        choices=["generic", "dkt"],
        help="Consumer hint only (default generic). DLSurfer never calls DKT.",
    )
    # Back-compat alias
    p_handoff_dkt = sub.add_parser("handoff-dkt", help="Alias for: handoff --consumer dkt")
    p_handoff_dkt.add_argument("--sd", type=Path, required=True)
    p_handoff_dkt.add_argument("--sid", required=True)

    args = parser.parse_args(argv)

    if args.cmd == "doctor":
        print(f"dlsurfer {__version__}")
        print(__claim__)
        print(_ISOLATION)
        print()
        for c in run_doctor():
            mark = "OK " if c.ok else "MISS"
            print(f"[{mark}] {c.name}: {c.detail}")
        print("[OK ] isolation: package path under others_methods/preprocessing/DL/dlsurfer/")
        print("[OK ] dkt_decouple: no import of DKT workflow; handoff is print-only")
        return 0

    if args.cmd == "profiles":
        for name, meta in sorted(load_profiles().items()):
            exp = " [experimental]" if meta.get("experimental") else ""
            print(f"{name:22} phase={meta.get('phase')}{exp}")
            print(f"  {str(meta.get('description', '')).strip()[:120]}...")
        return 0

    if args.cmd == "atlases":
        data = yaml.safe_load((_PKG / "atlases.yaml").read_text())
        print(f"Default atlas: {data.get('default')}")
        print("DKT is one labeling scheme — not the DKT connectome pipeline.\n")
        for aid, a in data.get("atlases", {}).items():
            print(f"## {aid} — {a.get('name')}  [{a.get('status')}]")
            print(f"  FS={a.get('freesurfer')}  FastSurfer={a.get('fastsurfer')}  wired={a.get('wired')}")
            if a.get("how"):
                print(f"  How: {a.get('how')}")
            print(f"  {a.get('note')}")
            print()
        return 0

    if args.cmd == "compare":
        path = _PKG.parent / "docs" / "COMPARE_FS_FASTSURFER.md"
        print(path.read_text() if path.is_file() else "Missing docs/COMPARE_FS_FASTSURFER.md")
        return 0

    if args.cmd == "gaps-remaining":
        path = _PKG.parent / "docs" / "GAPS_WITHOUT_ALTERNATIVES.md"
        print(path.read_text() if path.is_file() else "Missing docs/GAPS_WITHOUT_ALTERNATIVES.md")
        return 0

    if args.cmd == "engines":
        engs, pins, deferred = load_engines()
        print("Pins:", pins)
        print()
        if args.alternatives:
            print("# Chosen → alternatives (future reference)\n")
            for eid, e in engs.items():
                if not e.get("chosen"):
                    continue
                alts = e.get("alternatives") or []
                print(f"{eid}  CHOSEN={e['name']}")
                if not alts:
                    print("  (no alternatives listed)")
                for a in alts:
                    print(f"  - {a.get('id')} [{a.get('readiness')}]: {a.get('note')}")
                print()
            print("Deferred:")
            for d in deferred:
                print(f"  - {d['id']}: {d['why']}")
            return 0
        if args.id:
            e = engs[args.id]
            _print_engine(args.id, e)
            return 0
        for eid, e in engs.items():
            if not e.get("chosen"):
                continue
            _print_engine(eid, e)
            print()
        print("Deferred (not default):")
        for d in deferred:
            print(f"  - {d['id']}: {d['why']}")
        print("\nTip: dlsurfer engines --alternatives")
        return 0

    if args.cmd == "cite":
        engs, _, _ = load_engines()
        seen: set[str] = set()
        if args.profile:
            from dlsurfer.registry import profile as get_profile

            prof = get_profile(args.profile)
            print(f"# Citations for profile {args.profile}")
            print(prof.get("citations_note", ""))
            for step in prof.get("steps", []):
                eid = step["engine"]
                for c in engs[eid].get("cite", []):
                    if c not in seen:
                        print(f"- {c}")
                        seen.add(c)
        else:
            print("# All chosen engine citations")
            for eid, e in engs.items():
                if not e.get("chosen"):
                    continue
                print(f"\n## {e['name']} ({eid})")
                print(e["why"].strip())
                for c in e.get("cite", []):
                    print(f"- {c}")
        print(
            "\n# DLSurfer itself\n"
            "- DLSurfer is an orchestrator only; cite the engines you actually ran.\n"
            f"- Claim: {__claim__}\n"
            f"- Isolation: {_ISOLATION}"
        )
        return 0

    if args.cmd == "run":
        try:
            plan = build_plan(
                args.profile,
                t1=args.t1,
                sd=args.sd,
                sid=args.sid,
                lesion_mask=args.lesion_mask,
                fs_license=args.fs_license,
                device=args.device,
                post_lit=args.post_lit,
                threads=args.threads,
                atlas=args.atlas,
                no_cc=args.no_cc,
                no_cereb=args.no_cereb,
                no_hypothal=args.no_hypothal,
                vox_size=args.vox_size,
                hpc=args.hpc,
            )
        except (KeyError, ValueError) as exc:
            print(f"error: {exc}", file=sys.stderr)
            return 2
        print(
            f"[dlsurfer] atlas={plan.atlas} hpc={plan.extras.get('hpc')} "
            f"fs_flags={plan.extras.get('fs_flags')}  (isolated; not DKT-connectome)"
        )
        return execute_plan(
            plan,
            dry_run=not args.execute,
            sd=args.sd,
            sid=args.sid,
        )

    if args.cmd in {"handoff", "handoff-dkt"}:
        consumer = "dkt" if args.cmd == "handoff-dkt" else args.consumer
        sd, sid = args.sd, args.sid
        print(_handoff_text(sd, sid, consumer))
        return 0

    return 1


def _handoff_text(sd: Path, sid: str, consumer: str) -> str:
    base = f"""Optional handoff notes (print-only — DLSurfer does not run connectome)
=======================================================================
Isolation: {_ISOLATION}

FreeSurfer-shaped tree:
  {sd}/{sid}/

Atlas default in DLSurfer is DKT labeling (FastSurferVINN), but other atlases
are in-scope for the morphometry tree (see `dlsurfer atlases`). Connectome
node definitions are NOT owned by DLSurfer.

Do not mix FastSurfer 'core' and 'fs8' outputs for the same sid.
Cite:  dlsurfer cite --profile <used_profile>
"""
    if consumer == "dkt":
        base += f"""
Consumer hint: DKT connectome pipeline (optional)
-------------------------------------------------
If you choose to use these surfaces/labels downstream, point DKT config at:
  fs_subjects_dir / FS_SUBJECTS_DIR = {sd}
Typical DKT steps (outside this package): QSIPrep/QSIRecon, connectome rules.
DLSurfer never imports or submits DKT jobs.
"""
    else:
        base += """
Consumer hint: generic
----------------------
Any tool that reads FreeSurfer SUBJECTS_DIR can consume these outputs.
DKT connectome is one possible consumer among others — not required.
"""
    return base


def _print_engine(eid: str, e: dict) -> None:
    print(f"## {e['name']}  [{eid}]  readiness={e.get('readiness')}  phase={e.get('phase')}")
    print(f"Replaces classical: {e.get('classical_replaces')}")
    print(f"CLI: {e.get('cli')}")
    print("Why:")
    print(f"  {e.get('why', '').strip()}")
    print("Cite:")
    for c in e.get("cite", []):
        print(f"  - {c}")
    alts = e.get("alternatives") or []
    if alts:
        print("Other best alternatives (not default):")
        for a in alts:
            print(f"  - {a.get('id')} [{a.get('readiness')}]: {a.get('note')}")


if __name__ == "__main__":
    raise SystemExit(main())
