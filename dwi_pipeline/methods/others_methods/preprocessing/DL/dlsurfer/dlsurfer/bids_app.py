"""BIDS App–style entrypoint with derivatives layout + Boutiques descriptor."""

from __future__ import annotations

import argparse
import json
import os
import sys
from datetime import datetime, timezone
from pathlib import Path

from dlsurfer import __version__
from dlsurfer.adapters.plan import build_plan
from dlsurfer.runner import execute_plan

_PKG = Path(__file__).resolve().parent
_BOUTIQUES = _PKG.parent / "boutiques" / "dlsurfer_bids_app.json"


def _find_t1(bids_dir: Path, label: str) -> Path | None:
    anat = bids_dir / f"sub-{label}" / "anat"
    if not anat.is_dir():
        sub = bids_dir / f"sub-{label}"
        if sub.is_dir():
            hits = sorted(sub.glob("ses-*/anat/*T1w.nii*"))
            if hits:
                return hits[0]
        return None
    hits = sorted(anat.glob("*T1w.nii*"))
    return hits[0] if hits else None


def _find_lesion(bids_dir: Path, label: str) -> Path | None:
    sub = bids_dir / f"sub-{label}"
    patterns = (
        "anat/*lesion*.nii*",
        "anat/*Lesion*.nii*",
        "ses-*/anat/*lesion*.nii*",
    )
    for pat in patterns:
        hits = sorted(sub.glob(pat))
        if hits:
            return hits[0]
    return None


def _labels(bids_dir: Path, requested: list[str] | None) -> list[str]:
    if requested:
        return [x.removeprefix("sub-") for x in requested]
    return sorted(
        p.name.removeprefix("sub-")
        for p in bids_dir.glob("sub-*")
        if p.is_dir()
    )


def _write_dataset_description(deriv: Path, profile: str) -> None:
    deriv.mkdir(parents=True, exist_ok=True)
    desc = {
        "Name": "DLSurfer",
        "BIDSVersion": "1.8.0",
        "DatasetType": "derivative",
        "GeneratedBy": [
            {
                "Name": "DLSurfer",
                "Version": __version__,
                "Description": (
                    f"FreeSurfer-shaped SUBJECTS_DIR under freesurfer/ "
                    f"(profile={profile}). Cite upstream engines, not DLSurfer."
                ),
                "CodeURL": "https://github.com/phindagijimana/dlsurfer",
            }
        ],
        "HowToAcknowledge": (
            "Cite FastSurfer / FreeSurfer / neuroLIT papers used by the profile "
            "(dlsurfer cite --profile …)."
        ),
    }
    (deriv / "dataset_description.json").write_text(json.dumps(desc, indent=2) + "\n")


def _write_participant_sidecar(
    deriv: Path,
    *,
    sid: str,
    t1: Path,
    lesion: Path | None,
    profile: str,
    subjects_dir: Path,
) -> None:
    out = deriv / sid
    out.mkdir(parents=True, exist_ok=True)
    meta = {
        "ParticipantId": sid,
        "Profile": profile,
        "Sources": {"T1w": str(t1), "LesionMask": str(lesion) if lesion else None},
        "SubjectsDir": str(subjects_dir),
        "FreeSurferSubject": str(subjects_dir / sid),
        "GeneratedAt": datetime.now(timezone.utc).isoformat(),
        "DLSurferVersion": __version__,
    }
    (out / f"{sid}_dlsurfer.json").write_text(json.dumps(meta, indent=2) + "\n")


def build_parser() -> argparse.ArgumentParser:
    p = argparse.ArgumentParser(
        prog="dlsurfer bids-app",
        description=(
            "BIDS App–style entrypoint. Writes derivatives under "
            "output_dir/derivatives/dlsurfer/ plus FreeSurfer SUBJECTS_DIR at "
            "output_dir/freesurfer/."
        ),
    )
    p.add_argument("bids_dir", type=Path, help="BIDS dataset root")
    p.add_argument("output_dir", type=Path, help="Output root")
    p.add_argument(
        "analysis_level",
        choices=["participant", "group"],
        help="participant = per-subject morphometry; group = aggregate stub",
    )
    p.add_argument(
        "--participant_label",
        nargs="+",
        default=None,
        help="Participant id(s) without 'sub-' prefix",
    )
    p.add_argument("--profile", default="core", help="DLSurfer profile (default: core)")
    p.add_argument("--fs-license", type=Path, default=None)
    p.add_argument("--device", default="auto", choices=["auto", "cpu", "cuda"])
    p.add_argument("--threads", type=int, default=4)
    p.add_argument(
        "--lesion-mask",
        type=Path,
        default=None,
        help="Override lesion path (else search anat/*lesion*)",
    )
    p.add_argument("--execute", action="store_true", help="Run (default: dry-run plan)")
    p.add_argument(
        "--allow-experimental",
        action="store_true",
        help="Pass through to execute_plan for gated profiles",
    )
    p.add_argument(
        "--bids-exec-spec",
        action="store_true",
        help="Print Boutiques descriptor path/JSON and exit",
    )
    return p


def run_bids_app(argv: list[str] | None = None) -> int:
    args = build_parser().parse_args(argv)

    if args.bids_exec_spec:
        if _BOUTIQUES.is_file():
            print(_BOUTIQUES.read_text())
            return 0
        print(f"[dlsurfer bids-app] missing Boutiques file: {_BOUTIQUES}", file=sys.stderr)
        return 2

    bids = args.bids_dir.resolve()
    out = args.output_dir.resolve()
    if not bids.is_dir():
        print(f"[dlsurfer bids-app] missing bids_dir: {bids}", file=sys.stderr)
        return 2

    deriv = out / "derivatives" / "dlsurfer"
    sd = out / "freesurfer"
    _write_dataset_description(deriv, args.profile)

    if args.analysis_level == "group":
        # Aggregate: list subjects that have a FreeSurfer tree + metrics
        rows = []
        if sd.is_dir():
            for sub in sorted(sd.glob("sub-*")):
                metrics = sub / "scripts" / "dlsurfer_metrics.tsv"
                rows.append(
                    {
                        "participant_id": sub.name,
                        "metrics": str(metrics) if metrics.is_file() else None,
                    }
                )
        summary = deriv / "group" / "participants.json"
        summary.parent.mkdir(parents=True, exist_ok=True)
        summary.write_text(json.dumps({"subjects": rows}, indent=2) + "\n")
        print(f"[dlsurfer bids-app] group summary → {summary} (n={len(rows)})")
        return 0

    labels = _labels(bids, args.participant_label)
    if not labels:
        print("[dlsurfer bids-app] no participants found", file=sys.stderr)
        return 2

    lic = args.fs_license or (
        Path(os.environ["FS_LICENSE"]) if os.environ.get("FS_LICENSE") else None
    )
    sd.mkdir(parents=True, exist_ok=True)
    rc_all = 0
    for lab in labels:
        t1 = _find_t1(bids, lab)
        if t1 is None:
            print(f"[dlsurfer bids-app] no T1w for sub-{lab}", file=sys.stderr)
            rc_all = max(rc_all, 2)
            continue
        lesion = args.lesion_mask or _find_lesion(bids, lab)
        sid = f"sub-{lab}"
        print(f"[dlsurfer bids-app] {sid} t1={t1} lesion={lesion} -> sd={sd}")
        _write_participant_sidecar(
            deriv, sid=sid, t1=t1, lesion=lesion, profile=args.profile, subjects_dir=sd
        )
        plan = build_plan(
            args.profile,
            t1=t1,
            sd=sd,
            sid=sid,
            lesion_mask=lesion,
            fs_license=lic,
            device=args.device,
            threads=args.threads,
        )
        rc = execute_plan(
            plan,
            dry_run=not args.execute,
            sd=sd,
            sid=sid,
            allow_experimental=args.allow_experimental,
        )
        rc_all = max(rc_all, rc)
    return rc_all
