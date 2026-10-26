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
    argv_list = list(sys.argv[1:] if argv is None else argv)
    # BIDS App–style stub uses its own argparse (positional bids_dir output_dir level).
    if argv_list and argv_list[0] == "bids-app":
        from dlsurfer.bids_app import run_bids_app

        return run_bids_app(argv_list[1:])

    parser = argparse.ArgumentParser(
        prog="dlsurfer",
        description=(
            "DLSurfer: deep-learning FreeSurfer-suite methods "
            "(morphometry + TractSeg/PET-DL/DeepPrep/QC; specialty allowed). "
            + __claim__
            + " "
            + _ISOLATION
        ),
        epilog=(
            "First run: source env/cluster_containers.sh && dlsurfer doctor && "
            "dlsurfer smoke --quiet.\n"
            "FS-shaped: dlsurfer recon-all -i T1 -sd SD -s SID\n"
            "Specialty:  dlsurfer tools | dlsurfer tool hippunfold …\n"
            "Policy:     dlsurfer credibility\n"
            "Docs: https://dlsurfer.readthedocs.io/"
        ),
        formatter_class=argparse.RawDescriptionHelpFormatter,
    )
    parser.add_argument("--version", action="version", version=f"dlsurfer {__version__}")
    sub = parser.add_subparsers(dest="cmd", required=True)

    # Primary workflow first (help order = discovery order)
    p_doc = sub.add_parser("doctor", help="Check environment, pins, isolation, claim boundary")
    p_doc.add_argument("--profile", help="Also report gates blocking this profile")
    p_doc.add_argument(
        "--brief",
        "-q",
        action="store_true",
        help="Core checks + READY only (hide long OK wall)",
    )
    p_smoke = sub.add_parser(
        "smoke",
        help="Doctor + dry-run plan for a profile (default core-lesion) — no execute",
    )
    p_smoke.add_argument("--profile", default="core-lesion")
    p_smoke.add_argument("--t1", type=Path, default=Path("/tmp/dlsurfer_smoke_t1.nii.gz"))
    p_smoke.add_argument("--sd", type=Path, default=Path("/tmp/dlsurfer_smoke_sd"))
    p_smoke.add_argument("--sid", default="sub-SMOKE")
    p_smoke.add_argument("--lesion-mask", type=Path, default=None)
    p_smoke.add_argument(
        "--quiet",
        "-q",
        action="store_true",
        help="Compact plan (steps + commands only; skip why/cite)",
    )

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
        "--t2",
        type=Path,
        default=None,
        help="Co-registered T2w for HypVINN (--t2); also set via HYPVINN_T2 / DLSURFER_T2",
    )
    p_run.add_argument(
        "--hpc",
        default="none",
        choices=["none", "srun", "brun"],
        help="Use FastSurfer srun_fastsurfer.sh or brun_fastsurfer.sh launcher",
    )
    p_run.add_argument(
        "--schaefer-annot-lh",
        type=Path,
        default=None,
        help="fsaverage lh Schaefer annot (or set SCHAEFER_ANNOT_LH)",
    )
    p_run.add_argument(
        "--schaefer-annot-rh",
        type=Path,
        default=None,
        help="fsaverage rh Schaefer annot (or set SCHAEFER_ANNOT_RH)",
    )
    p_run.add_argument("--post-lit", action=argparse.BooleanOptionalAction, default=True)
    p_run.add_argument(
        "--stage",
        choices=["all", "gpu", "cpu", "fill", "seg", "surf", "post"],
        default="all",
        help="HPC slice for DL separable LIT: gpu=fill+seg_only, cpu=surf_only+lit-post",
    )
    p_run.add_argument(
        "--execute",
        action="store_true",
        help="Actually run commands (default is dry-run)",
    )
    p_run.add_argument(
        "--allow-experimental",
        action="store_true",
        help="Allow --execute on experimental profiles / open gates (lab override)",
    )
    p_run.add_argument(
        "--allow-classical",
        action="store_true",
        help="Allow classical / non-DL profiles (fs8, Bayesian HA/BS, fs-long, …)",
    )
    p_run.add_argument(
        "--batch-size",
        type=int,
        default=None,
        help="FastSurfer --batch (use 1 on small GPUs)",
    )
    p_run.add_argument(
        "--viewagg-device",
        default=None,
        choices=["cpu", "cuda"],
        help="FastSurfer --viewagg_device (cpu saves GPU RAM)",
    )
    p_run.add_argument(
        "--quiet",
        "-q",
        action="store_true",
        help="Compact plan (steps + commands only; skip why/cite)",
    )

    p_fv = sub.add_parser(
        "freeview",
        help="Open a subject tree in upstream FreeView (GUI launcher — not a reimplementation)",
    )
    p_fv.add_argument("--sd", type=Path, required=True, help="SUBJECTS_DIR")
    p_fv.add_argument("--sid", required=True)
    p_fv.add_argument(
        "--volume",
        default="orig.mgz",
        help="Volume under mri/ (default orig.mgz; falls back to T1/brain/norm)",
    )
    p_fv.add_argument("--aseg", action="store_true", help="Overlay aseg / aparc+aseg if present")
    p_fv.add_argument("--no-surfaces", action="store_true", help="Skip white/pial overlays")
    p_fv.add_argument("--pial", action="store_true", help="Also load lh/rh.pial (red)")
    p_fv.add_argument("--inflated", action="store_true", help="Also load lh/rh.inflated")
    p_fv.add_argument(
        "--hemi",
        default="both",
        choices=["both", "lh", "rh"],
        help="Which hemisphere surfaces to load",
    )
    p_fv.add_argument(
        "--dry-run",
        action="store_true",
        help="Print the FreeView command without launching",
    )
    p_fv.add_argument(
        "--check",
        action="store_true",
        help="Headless readiness: resolve freeview binary/SIF + subject (no GUI)",
    )
    p_fv.add_argument(
        "extra",
        nargs=argparse.REMAINDER,
        help="Extra FreeView args after -- (e.g. dlsurfer freeview … -- -viewport 3d)",
    )

    p_prof = sub.add_parser("profiles", help="List deep-learning profiles (default)")
    p_prof.add_argument(
        "--all",
        action="store_true",
        help="Include classical / non-DL profiles (require --allow-classical to run)",
    )
    sub.add_parser("gates", help="List production/experimental gates (Phase 3, SynthSeg-PC, EG smoke)")
    p_contract = sub.add_parser(
        "contract",
        help="FreeSurfer-shaped SUBJECTS_DIR layout / check (all DLSurfer outputs)",
    )
    p_contract.add_argument(
        "--list",
        action="store_true",
        help="Print full FS-looking layout + profile→path registry",
    )
    p_contract.add_argument("--sd", type=Path, default=None, help="SUBJECTS_DIR to check")
    p_contract.add_argument("--sid", default=None, help="Subject id to check")
    p_contract.add_argument("--profile", default="core", help="Profile contract to validate")
    p_contract.add_argument(
        "--ensure-tree",
        action="store_true",
        help="Create mri/surf/label/stats/scripts/tmp/touch under --sd/--sid",
    )
    p_eng = sub.add_parser("engines", help="List engines with why, citations, and alternatives")
    p_eng.add_argument("--id", help="Show one engine")
    p_eng.add_argument(
        "--alternatives",
        action="store_true",
        help="Print alternatives table for all chosen engines",
    )
    p_eng.add_argument(
        "--all",
        action="store_true",
        help="Include engines marked is_deep_learning: false / classical",
    )
    p_cred = sub.add_parser(
        "credibility",
        help="Print A/B/C/D credibility policy (T1-agnostic; specialty allowed)",
    )
    p_tools = sub.add_parser(
        "tools",
        help="List FS-style DL tool aliases with credibility tier (A/B/C)",
    )
    p_tools.add_argument(
        "--tier",
        choices=["A", "B", "C"],
        default=None,
        help="Show only this tier and higher (A ⊂ B ⊂ C listing filter: max tier)",
    )
    p_tool = sub.add_parser(
        "tool",
        help="Run one DL module by FS-style name (e.g. hippunfold, synthseg, sclimbic)",
    )
    p_tool.add_argument("name", help="Tool alias or profile id (see: dlsurfer tools)")
    p_tool.add_argument("--t1", type=Path, required=True)
    p_tool.add_argument("--sd", type=Path, required=True, help="SUBJECTS_DIR")
    p_tool.add_argument("--sid", required=True)
    p_tool.add_argument("--execute", action="store_true")
    p_tool.add_argument("--allow-experimental", action="store_true")
    p_tool.add_argument("--quiet", "-q", action="store_true")
    p_tool.add_argument("--device", default="auto", choices=["auto", "cpu", "cuda"])
    p_tool.add_argument("--threads", type=int, default=4)
    p_tool.add_argument("--fs-license", type=Path, default=None)
    p_tool.add_argument("--lesion-mask", type=Path, default=None)
    p_tool.add_argument(
        "--t2",
        type=Path,
        default=None,
        help="Co-registered T2w for HypVINN (also HYPVINN_T2)",
    )

    p_ra = sub.add_parser(
        "recon-all",
        help="DL morphometry orchestrator (FastSurferVINN core) — not classical recon-all",
    )
    p_ra.add_argument("-i", "--t1", type=Path, required=True, help="Input T1 (FS-style -i)")
    p_ra.add_argument("-sd", "--sd", type=Path, required=True, help="SUBJECTS_DIR")
    p_ra.add_argument("-s", "--sid", required=True, help="Subject id (FS-style -s)")
    p_ra.add_argument(
        "--lesion-mask",
        type=Path,
        default=None,
        help="If set, use core-lesion (neuroLIT → FastSurfer) instead of core",
    )
    p_ra.add_argument(
        "--stage",
        choices=["all", "gpu", "cpu", "fill", "seg", "surf", "post"],
        default="all",
        help="HPC slice: gpu=fill+seg, cpu=surf+post (DL separable LIT)",
    )
    p_ra.add_argument("--fs-license", type=Path, default=None)
    p_ra.add_argument("--device", default="auto", choices=["auto", "cpu", "cuda"])
    p_ra.add_argument("--threads", type=int, default=4)
    p_ra.add_argument("--atlas", default=None)
    p_ra.add_argument("--execute", action="store_true")
    p_ra.add_argument("--allow-experimental", action="store_true")
    p_ra.add_argument("--quiet", "-q", action="store_true")
    p_ra.add_argument("--no-cc", action="store_true")
    p_ra.add_argument("--no-cereb", action="store_true")
    p_ra.add_argument("--no-hypothal", action="store_true")
    p_ra.add_argument(
        "--t2",
        type=Path,
        default=None,
        help="Co-registered T2w for HypVINN (also HYPVINN_T2)",
    )
    p_ra.add_argument("--hpc", default="none", choices=["none", "srun", "brun"])
    p_ra.add_argument("--batch-size", type=int, default=None)
    p_ra.add_argument("--viewagg-device", default=None, choices=["cpu", "cuda"])
    sub.add_parser("atlases", help="List cortical/subcortical atlas options (DKT default, not exclusive)")
    p_cite = sub.add_parser("cite", help="Print citation boilerplate for a profile or all engines")
    p_cite.add_argument("--profile", help="Profile name")
    p_cmp = sub.add_parser(
        "compare",
        help="Summarize DLSurfer vs FreeSurfer vs FastSurfer gaps (use --full for matrix)",
    )
    p_cmp.add_argument(
        "--full",
        action="store_true",
        help="Print full COMPARE markdown (default is a short summary)",
    )
    p_gaps = sub.add_parser(
        "gaps-remaining",
        help="Gaps with no credible alternative (use --full for markdown)",
    )
    p_gaps.add_argument(
        "--full",
        action="store_true",
        help="Print full GAPS markdown (default is a short bullet list)",
    )
    sub.add_parser(
        "bids-app",
        help="BIDS App–style stub (short of full standard): bids_dir output_dir {participant|group}",
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

    args = parser.parse_args(argv_list)
    if args.cmd == "bids-app":
        from dlsurfer.bids_app import run_bids_app

        return run_bids_app([])  # -h path via empty → usage; prefer `dlsurfer bids-app -h`

    if args.cmd == "doctor":
        from dlsurfer.doctor import doctor_summary_ok
        from dlsurfer.reports import format_doctor_report

        checks = run_doctor(profile=getattr(args, "profile", None))
        print(
            format_doctor_report(
                checks,
                brief=bool(args.brief),
                version=__version__,
                claim=__claim__,
                isolation=_ISOLATION,
            ),
            end="",
        )
        return 0 if doctor_summary_ok(checks) else 1

    if args.cmd == "gates":
        from dlsurfer.gates import format_gates

        print(format_gates())
        return 0

    if args.cmd == "contract":
        from dlsurfer.contract import (
            check_profile_contract,
            ensure_fs_tree,
            format_layout_tree,
            registry_profile_names,
        )

        if args.list or (args.sd is None and not args.ensure_tree):
            print(format_layout_tree(), end="")
            print(f"Registry profiles: {len(registry_profile_names())}")
            print("Check: dlsurfer contract --sd SD --sid SID --profile core")
            return 0
        if args.sd is None or args.sid is None:
            print("error: --sd and --sid required to check or --ensure-tree", file=sys.stderr)
            return 2
        if args.ensure_tree:
            root = ensure_fs_tree(args.sd, args.sid)
            print(f"[dlsurfer] ensured FS tree under {root}")
        problems = check_profile_contract(args.sd, args.sid, args.profile)
        if problems:
            print(f"FAIL ({args.profile}):")
            for p in problems:
                print(f"  - {p}")
            return 1
        print(f"OK: FreeSurfer-shaped contract for profile '{args.profile}' under {args.sd / args.sid}")
        return 0

    if args.cmd == "smoke":
        from dlsurfer.reports import format_doctor_report

        print("=== doctor ===")
        checks = run_doctor(profile=args.profile)
        print(
            format_doctor_report(
                checks,
                brief=bool(args.quiet),
                version=__version__,
                claim=__claim__,
                isolation=_ISOLATION,
            ),
            end="",
        )
        print("=== dry-run plan ===")
        lesion = args.lesion_mask
        from dlsurfer.registry import profile as get_profile

        if get_profile(args.profile).get("requires_lesion_mask") and lesion is None:
            lesion = Path("/tmp/dlsurfer_smoke_lesion.nii.gz")
            print(f"(using placeholder lesion mask {lesion} for dry-run)")
        try:
            plan = build_plan(
                args.profile,
                t1=args.t1,
                sd=args.sd,
                sid=args.sid,
                lesion_mask=lesion,
                device="cpu",
            )
        except (KeyError, ValueError) as exc:
            print(f"error: {exc}", file=sys.stderr)
            return 2
        return execute_plan(
            plan, dry_run=True, sd=args.sd, sid=args.sid, quiet=bool(getattr(args, "quiet", False))
        )

    if args.cmd == "credibility":
        from dlsurfer.credibility import PROFILE_TIER, TIER_HELP, format_tier_banner

        print(format_tier_banner())
        for tier in ("A", "B", "C", "D"):
            names = sorted(n for n, t in PROFILE_TIER.items() if t == tier)
            print(f"## {tier} — {TIER_HELP[tier]}")
            print("  " + ", ".join(names))
            print()
        print("Docs: docs/reference/CREDIBILITY.md")
        print("Specialty methods are allowed at A/B/C; D is classical-only.")
        return 0

    if args.cmd == "profiles":
        from dlsurfer.credibility import tier_for_profile
        from dlsurfer.tools import profile_is_deep_learning

        for name, meta in sorted(load_profiles().items()):
            if not args.all and not profile_is_deep_learning(name, meta):
                continue
            tier = tier_for_profile(name, meta)
            exp = " [experimental]" if meta.get("experimental") else ""
            classical = "" if profile_is_deep_learning(name, meta) else " [classical]"
            print(f"{name:22} {tier} phase={meta.get('phase')}{exp}{classical}")
            desc = str(meta.get("description", "")).strip().replace("\n", " ")
            print(f"  {desc}")
        if not args.all:
            print(
                "\n(classical D hidden — --all to list; --allow-classical to run)\n"
                "Specialty A/B/C are first-class. See: dlsurfer credibility"
            )
        return 0

    if args.cmd == "tools":
        from dlsurfer.credibility import format_tier_banner
        from dlsurfer.tools import tools_table

        print(format_tier_banner())
        print(f"{'alias':22} tier  profile")
        print("-" * 56)
        for alias, prof, tier in tools_table(min_tier=args.tier):
            print(f"{alias:22} {tier}     {prof}")
        print(
            "\nRun one:  dlsurfer tool hippunfold --t1 T1.nii.gz --sd SD --sid SID [--execute]\n"
            "Full tree: dlsurfer recon-all -i T1.nii.gz -sd SD -s SID [--execute]\n"
            "C = experimental specialty (allowed). D classical not listed."
        )
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
        from dlsurfer.reports import format_compare

        print(format_compare(full=bool(args.full)), end="")
        return 0

    if args.cmd == "gaps-remaining":
        from dlsurfer.reports import format_gaps_remaining

        print(format_gaps_remaining(full=bool(args.full)), end="")
        return 0

    if args.cmd == "engines":
        engs, pins, deferred = load_engines()
        print("Pins:", pins)
        print()

        def _show(eid: str, e: dict) -> bool:
            if not e.get("chosen"):
                return False
            if args.all:
                return True
            # Default: DL engines only (unknown flag → treat as DL for legacy entries)
            if e.get("is_deep_learning") is False:
                return False
            if e.get("readiness") == "classical" and e.get("is_deep_learning") is not True:
                return False
            return True

        if args.alternatives:
            print("# Chosen DL → alternatives (future reference)\n")
            for eid, e in engs.items():
                if not _show(eid, e):
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
            if not _show(eid, e):
                continue
            _print_engine(eid, e)
            print()
        print("Deferred (not default):")
        for d in deferred:
            print(f"  - {d['id']}: {d['why']}")
        if not args.all:
            print("\n(classical engines hidden — pass --all)")
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

    if args.cmd in {"run", "recon-all", "tool"}:
        from dlsurfer.registry import ensure_dl_profile
        from dlsurfer.tools import resolve_tool

        if args.cmd == "recon-all":
            profile_name = "core-lesion" if args.lesion_mask else "core"
            allow_classical = False
            post_lit = True
            atlas = args.atlas
            no_cc = args.no_cc
            no_cereb = args.no_cereb
            no_hypothal = args.no_hypothal
            hpc = args.hpc
            batch_size = args.batch_size
            viewagg_device = args.viewagg_device
            vox_size = None
            sch_lh = sch_rh = None
        elif args.cmd == "tool":
            profile_name = resolve_tool(args.name)
            allow_classical = False
            post_lit = True
            atlas = None
            no_cc = no_cereb = no_hypothal = False
            hpc = "none"
            batch_size = viewagg_device = vox_size = None
            sch_lh = sch_rh = None
        else:
            profile_name = args.profile
            allow_classical = bool(args.allow_classical)
            post_lit = args.post_lit
            atlas = args.atlas
            no_cc = args.no_cc
            no_cereb = args.no_cereb
            no_hypothal = args.no_hypothal
            hpc = args.hpc
            batch_size = args.batch_size
            viewagg_device = args.viewagg_device
            vox_size = args.vox_size
            sch_lh = args.schaefer_annot_lh
            sch_rh = args.schaefer_annot_rh

        try:
            ensure_dl_profile(profile_name, allow_classical=allow_classical)
            t2 = getattr(args, "t2", None)
            if t2 is not None:
                import os

                os.environ.setdefault("HYPVINN_T2", str(Path(t2).resolve()))
            from dlsurfer.adapters.plan import filter_steps_for_partition

            plan = build_plan(
                profile_name,
                t1=args.t1,
                sd=args.sd,
                sid=args.sid,
                lesion_mask=getattr(args, "lesion_mask", None),
                fs_license=getattr(args, "fs_license", None),
                device=args.device,
                post_lit=post_lit,
                threads=args.threads,
                atlas=atlas,
                no_cc=bool(no_cc),
                no_cereb=bool(no_cereb),
                no_hypothal=bool(no_hypothal),
                vox_size=vox_size,
                hpc=hpc,
                schaefer_annot_lh=sch_lh,
                schaefer_annot_rh=sch_rh,
                batch_size=batch_size,
                viewagg_device=viewagg_device,
                t2=t2,
            )
            stage = getattr(args, "stage", "all") or "all"
            if stage != "all":
                plan = filter_steps_for_partition(plan, stage)
        except (KeyError, ValueError) as exc:
            print(f"error: {exc}", file=sys.stderr)
            return 2
        if args.cmd == "recon-all":
            print(
                f"[dlsurfer recon-all] profile={profile_name} "
                f"(DL FastSurferVINN — not classical FreeSurfer recon-all)"
            )
        elif args.cmd == "tool":
            print(f"[dlsurfer tool] {args.name} → profile={profile_name}")
        print(
            f"[dlsurfer] atlas={plan.atlas} hpc={plan.extras.get('hpc')} "
            f"fs_flags={plan.extras.get('fs_flags')}  (isolated; not DKT-connectome)"
        )
        return execute_plan(
            plan,
            dry_run=not args.execute,
            sd=args.sd,
            sid=args.sid,
            allow_experimental=bool(getattr(args, "allow_experimental", False)),
            quiet=bool(getattr(args, "quiet", False)),
        )

    if args.cmd == "freeview":
        from dlsurfer.freeview import launch_freeview

        extra = list(args.extra or [])
        if extra and extra[0] == "--":
            extra = extra[1:]
        return launch_freeview(
            args.sd,
            args.sid,
            volume=args.volume,
            aseg=args.aseg,
            surfaces=not args.no_surfaces,
            white=True,
            pial=args.pial,
            inflated=args.inflated,
            hemi=args.hemi,
            extra=extra or None,
            dry_run=args.dry_run,
            check_only=bool(args.check),
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
