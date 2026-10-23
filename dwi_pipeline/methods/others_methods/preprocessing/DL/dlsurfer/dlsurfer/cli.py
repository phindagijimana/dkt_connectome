"""dlsurfer command-line interface."""

from __future__ import annotations

import argparse
import sys
from pathlib import Path

from dlsurfer import __claim__, __version__
from dlsurfer.adapters.plan import build_plan
from dlsurfer.doctor import run_doctor
from dlsurfer.registry import engines as load_engines
from dlsurfer.registry import profiles as load_profiles
from dlsurfer.runner import execute_plan


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(
        prog="dlsurfer",
        description=(
            "DLSurfer: curated deep-learning morphometry orchestrator. "
            + __claim__
        ),
    )
    parser.add_argument("--version", action="version", version=f"dlsurfer {__version__}")
    sub = parser.add_subparsers(dest="cmd", required=True)

    sub.add_parser("doctor", help="Check environment, pins, and claim boundary")
    sub.add_parser("profiles", help="List profiles")
    p_eng = sub.add_parser("engines", help="List engines with why + citations")
    p_eng.add_argument("--id", help="Show one engine")

    p_cite = sub.add_parser("cite", help="Print citation boilerplate for a profile or all engines")
    p_cite.add_argument("--profile", help="Profile name")

    p_run = sub.add_parser("run", help="Build/execute a profile plan")
    p_run.add_argument("--t1", type=Path, required=True)
    p_run.add_argument("--sd", type=Path, required=True, help="SUBJECTS_DIR")
    p_run.add_argument("--sid", required=True)
    p_run.add_argument("--profile", required=True)
    p_run.add_argument("--lesion-mask", type=Path, default=None)
    p_run.add_argument("--fs-license", type=Path, default=None)
    p_run.add_argument("--device", default="auto", choices=["auto", "cpu", "cuda"])
    p_run.add_argument("--threads", type=int, default=4)
    p_run.add_argument("--post-lit", action=argparse.BooleanOptionalAction, default=True)
    p_run.add_argument(
        "--execute",
        action="store_true",
        help="Actually run commands (default is dry-run)",
    )

    p_handoff = sub.add_parser("handoff-dkt", help="Print DKT / QSIRecon handoff notes")
    p_handoff.add_argument("--sd", type=Path, required=True)
    p_handoff.add_argument("--sid", required=True)

    args = parser.parse_args(argv)

    if args.cmd == "doctor":
        print(f"dlsurfer {__version__}")
        print(__claim__)
        print()
        for c in run_doctor():
            mark = "OK " if c.ok else "MISS"
            print(f"[{mark}] {c.name}: {c.detail}")
        return 0

    if args.cmd == "profiles":
        for name, meta in sorted(load_profiles().items()):
            exp = " [experimental]" if meta.get("experimental") else ""
            print(f"{name:22} phase={meta.get('phase')}{exp}")
            print(f"  {str(meta.get('description', '')).strip()[:120]}...")
        return 0

    if args.cmd == "engines":
        engs, pins, deferred = load_engines()
        print("Pins:", pins)
        print()
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
            f"- Claim: {__claim__}"
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
            )
        except (KeyError, ValueError) as exc:
            print(f"error: {exc}", file=sys.stderr)
            return 2
        return execute_plan(
            plan,
            dry_run=not args.execute,
            sd=args.sd,
            sid=args.sid,
        )

    if args.cmd == "handoff-dkt":
        sd, sid = args.sd, args.sid
        print(
            f"""DKT / QSIRecon handoff
=====================
DLSurfer writes a FreeSurfer-shaped tree at:
  {sd}/{sid}/

Point your DKT / pipeline config at:
  fs_subjects_dir / FS_SUBJECTS_DIR = {sd}

Typical next steps (existing DKT stack — not reimplemented here):
  - QSIPrep / QSIRecon using the same SUBJECTS_DIR
  - connectome / disconnectome rules that expect aparc.DKTatlas+aseg

Do not mix FastSurfer 'core' and 'fs8' outputs for the same sid.
Cite engines via:  dlsurfer cite --profile <used_profile>
"""
        )
        return 0

    return 1


def _print_engine(eid: str, e: dict) -> None:
    print(f"## {e['name']}  [{eid}]  readiness={e.get('readiness')}  phase={e.get('phase')}")
    print(f"Replaces classical: {e.get('classical_replaces')}")
    print(f"CLI: {e.get('cli')}")
    print("Why:")
    print(f"  {e.get('why', '').strip()}")
    print("Cite:")
    for c in e.get("cite", []):
        print(f"  - {c}")


if __name__ == "__main__":
    raise SystemExit(main())