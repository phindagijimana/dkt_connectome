#!/usr/bin/env python3
"""Export pipeline outputs into a BIDS Derivatives-style tree under RESULTS_ROOT.

The live pipeline keeps the historical layout (qsiprep_single_run_output/,
connectomes/, …) for HPC resume compatibility. This script builds a shareable
BIDS Derivatives mirror using symlinks (default) or copies.

Usage:
  python3 export_bids_derivatives.py --results-root /path/to/RESULTS_ROOT
  python3 export_bids_derivatives.py --results-root OUT --copy
"""

from __future__ import annotations

import argparse
import json
import shutil
import sys
from datetime import datetime, timezone
from pathlib import Path

PIPELINE_NAME = "TrackTBI Connectome Pipeline"
PIPELINE_VERSION = "0.2.0"
CODE_URL = "https://github.com/phindagijimana/dkt_connectome"

DERIVATIVE_PIPELINES = (
    "qsiprep",
    "qsirecon",
    "tracktbi-inpaint",
    "tracktbi-connectome",
    "tracktbi-qc",
    "tracktbi-nodestrength",
)


def _dataset_description(name: str, description: str, *, extra: dict | None = None) -> dict:
    payload = {
        "Name": name,
        "BIDSVersion": "1.9.0",
        "DatasetType": "derivative",
        "GeneratedBy": [
            {
                "Name": PIPELINE_NAME,
                "Version": PIPELINE_VERSION,
                "CodeURL": CODE_URL,
                "Description": description,
            }
        ],
    }
    if extra:
        payload.update(extra)
    return payload


def _safe_unlink(path: Path) -> None:
    if path.is_symlink() or path.is_file():
        path.unlink()
    elif path.is_dir():
        shutil.rmtree(path)


def _link_or_copy(src: Path, dst: Path, *, copy: bool) -> None:
    if not src.exists():
        raise FileNotFoundError(src)
    dst.parent.mkdir(parents=True, exist_ok=True)
    if dst.exists() or dst.is_symlink():
        _safe_unlink(dst)
    if copy:
        if src.is_dir():
            shutil.copytree(src, dst, symlinks=True)
        else:
            shutil.copy2(src, dst)
    else:
        dst.symlink_to(src.resolve())


def _discover_subjects(results_root: Path) -> list[str]:
    subjects: set[str] = set()
    for pattern in (
        "qsiprep_single_run_output/sub-*",
        "connectomes/sub-*",
        "freesurfer/sub-*",
    ):
        for path in results_root.glob(pattern):
            if path.is_dir():
                subjects.add(path.name)
    return sorted(subjects)


def _discover_sessions(results_root: Path, subject_id: str) -> list[str]:
    sessions: set[str] = set()
    for base in (
        results_root / "qsiprep_single_run_output" / subject_id,
        results_root / "inpainted" / subject_id,
        results_root / "qsirecon_single_run_output" / subject_id,
    ):
        if base.is_dir():
            for ses in base.glob("ses-*"):
                if ses.is_dir():
                    sessions.add(ses.name)
    return sorted(sessions)


def export_qsiprep(results_root: Path, out_root: Path, subjects: list[str], *, copy: bool, manifest: list) -> None:
    pipeline_root = out_root / "qsiprep"
    pipeline_root.mkdir(parents=True, exist_ok=True)
    src_base = results_root / "qsiprep_single_run_output"
    for subject_id in subjects:
        src_sub = src_base / subject_id
        if not src_sub.is_dir():
            continue
        dst_sub = pipeline_root / subject_id
        _link_or_copy(src_sub, dst_sub, copy=copy)
        manifest.append({"pipeline": "qsiprep", "src": str(src_sub), "dst": str(dst_sub), "type": "dir"})
        html = src_base / f"{subject_id}.html"
        if html.is_file():
            dst_html = pipeline_root / f"{subject_id}.html"
            _link_or_copy(html, dst_html, copy=copy)
            manifest.append({"pipeline": "qsiprep", "src": str(html), "dst": str(dst_html), "type": "file"})


def export_qsirecon(results_root: Path, out_root: Path, subjects: list[str], *, copy: bool, manifest: list) -> None:
    pipeline_root = out_root / "qsirecon"
    pipeline_root.mkdir(parents=True, exist_ok=True)
    src_base = results_root / "qsirecon_single_run_output"
    if not src_base.is_dir():
        return
    for subject_id in subjects:
        src_sub = src_base / subject_id
        if src_sub.is_dir():
            dst_sub = pipeline_root / subject_id
            _link_or_copy(src_sub, dst_sub, copy=copy)
            manifest.append({"pipeline": "qsirecon", "src": str(src_sub), "dst": str(dst_sub), "type": "dir"})
    deriv = src_base / "derivatives"
    if deriv.is_dir():
        dst_deriv = pipeline_root / "derivatives"
        _link_or_copy(deriv, dst_deriv, copy=copy)
        manifest.append({"pipeline": "qsirecon", "src": str(deriv), "dst": str(dst_deriv), "type": "dir"})


def export_inpaint(results_root: Path, out_root: Path, subjects: list[str], *, copy: bool, manifest: list) -> None:
    pipeline_root = out_root / "tracktbi-inpaint"
    src_base = results_root / "inpainted"
    if not src_base.is_dir():
        return
    for subject_id in subjects:
        src_sub = src_base / subject_id
        if not src_sub.is_dir():
            continue
        dst_sub = pipeline_root / subject_id
        _link_or_copy(src_sub, dst_sub, copy=copy)
        manifest.append({"pipeline": "tracktbi-inpaint", "src": str(src_sub), "dst": str(dst_sub), "type": "dir"})


def export_connectome(results_root: Path, out_root: Path, subjects: list[str], *, copy: bool, manifest: list) -> None:
    pipeline_root = out_root / "tracktbi-connectome"
    src_base = results_root / "connectomes"
    if not src_base.is_dir():
        return
    for subject_id in subjects:
        src_sub = src_base / subject_id
        if not src_sub.is_dir():
            continue
        dst_sub = pipeline_root / subject_id
        _link_or_copy(src_sub, dst_sub, copy=copy)
        manifest.append({"pipeline": "tracktbi-connectome", "src": str(src_sub), "dst": str(dst_sub), "type": "dir"})


def export_qc(results_root: Path, out_root: Path, subjects: list[str], *, copy: bool, manifest: list) -> None:
    pipeline_root = out_root / "tracktbi-qc"
    src_base = results_root / "qc"
    if not src_base.is_dir():
        return
    for subject_id in subjects:
        src_sub = src_base / subject_id
        if not src_sub.is_dir():
            continue
        dst_sub = pipeline_root / subject_id
        _link_or_copy(src_sub, dst_sub, copy=copy)
        manifest.append({"pipeline": "tracktbi-qc", "src": str(src_sub), "dst": str(dst_sub), "type": "dir"})
    for cohort_file in ("cohort_qc.html", "cohort_qc.json", "disconnectome_cohort_qc.html", "disconnectome_cohort_qc.json"):
        src = results_root / cohort_file
        if src.is_file():
            dst = pipeline_root / cohort_file
            _link_or_copy(src, dst, copy=copy)
            manifest.append({"pipeline": "tracktbi-qc", "src": str(src), "dst": str(dst), "type": "file"})


def export_nodestrength(results_root: Path, out_root: Path, subjects: list[str], *, copy: bool, manifest: list) -> None:
    pipeline_root = out_root / "tracktbi-nodestrength"
    src_base = results_root / "node_strength"
    if not src_base.is_dir():
        return
    for name in ("manifest.json", "strength", "volume", "compare"):
        src = src_base / name
        if src.exists():
            dst = pipeline_root / name
            _link_or_copy(src, dst, copy=copy)
            manifest.append({"pipeline": "tracktbi-nodestrength", "src": str(src), "dst": str(dst), "type": "dir" if src.is_dir() else "file"})
    reports = src_base / "reports"
    if reports.is_dir():
        for subject_id in subjects:
            src_sub = reports / subject_id
            if src_sub.is_dir():
                dst_sub = pipeline_root / "reports" / subject_id
                _link_or_copy(src_sub, dst_sub, copy=copy)
                manifest.append(
                    {"pipeline": "tracktbi-nodestrength", "src": str(src_sub), "dst": str(dst_sub), "type": "dir"}
                )


def write_dataset_descriptions(out_root: Path, bids_dir: Path | None) -> None:
    root_extra = {
        "HowToAcknowledge": "See dwi_pipeline/docs/citation.md",
        "PipelineLayout": "BIDS Derivatives export (symlink mirror of internal RESULTS_ROOT layout)",
    }
    if bids_dir is not None:
        root_extra["SourceDatasets"] = [{"URL": f"file://{bids_dir.resolve()}", "Version": "unspecified"}]

    (out_root / "dataset_description.json").write_text(
        json.dumps(
            _dataset_description(
                "TrackTBI Connectome Pipeline derivatives export",
                "Aggregated BIDS Derivatives export from TrackTBI Connectome Pipeline",
                extra=root_extra,
            ),
            indent=2,
        )
        + "\n"
    )

    descriptions = {
        "qsiprep": "QSIPrep preprocessed anatomical and diffusion MRI",
        "qsirecon": "QSIRecon diffusion reconstruction and tractography",
        "tracktbi-inpaint": "Lesion inpainting (neuroLIT) outputs and QC sidecars",
        "tracktbi-connectome": "DKT structural connectome and disconnectome matrices",
        "tracktbi-qc": "Unified HTML QC dashboards and cohort indexes",
        "tracktbi-nodestrength": "Node strength tables and ENIGMA-style reports",
    }
    for pipeline, desc in descriptions.items():
        pdir = out_root / pipeline
        if pdir.exists():
            (pdir / "dataset_description.json").write_text(
                json.dumps(_dataset_description(f"TrackTBI — {pipeline}", desc), indent=2) + "\n"
            )


def export_bids_derivatives(
    results_root: Path,
    *,
    out_dir: Path | None = None,
    bids_dir: Path | None = None,
    copy: bool = False,
) -> dict:
    results_root = results_root.resolve()
    out_root = (out_dir or (results_root / "derivatives")).resolve()
    out_root.mkdir(parents=True, exist_ok=True)

    subjects = _discover_subjects(results_root)
    manifest: list[dict] = []

    export_qsiprep(results_root, out_root, subjects, copy=copy, manifest=manifest)
    export_qsirecon(results_root, out_root, subjects, copy=copy, manifest=manifest)
    export_inpaint(results_root, out_root, subjects, copy=copy, manifest=manifest)
    export_connectome(results_root, out_root, subjects, copy=copy, manifest=manifest)
    export_qc(results_root, out_root, subjects, copy=copy, manifest=manifest)
    export_nodestrength(results_root, out_root, subjects, copy=copy, manifest=manifest)
    write_dataset_descriptions(out_root, bids_dir)

    payload = {
        "results_root": str(results_root),
        "export_root": str(out_root),
        "mode": "copy" if copy else "symlink",
        "subjects": subjects,
        "sessions_by_subject": {sid: _discover_sessions(results_root, sid) for sid in subjects},
        "pipelines": list(DERIVATIVE_PIPELINES),
        "links": manifest,
        "exported_at": datetime.now(timezone.utc).replace(microsecond=0).isoformat(),
    }
    (out_root / "export_manifest.json").write_text(json.dumps(payload, indent=2) + "\n")
    return payload


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--results-root", type=Path, required=True)
    ap.add_argument("--out-dir", type=Path, help="Default: RESULTS_ROOT/derivatives")
    ap.add_argument("--bids-dir", type=Path, default=None)
    ap.add_argument("--copy", action="store_true", help="Copy files instead of symlinking")
    ap.add_argument("--dry-run", action="store_true")
    args = ap.parse_args()

    if args.dry_run:
        subjects = _discover_subjects(args.results_root)
        print(json.dumps({"subjects": subjects, "out_dir": str(args.out_dir or args.results_root / "derivatives")}, indent=2))
        return 0

    payload = export_bids_derivatives(
        args.results_root,
        out_dir=args.out_dir,
        bids_dir=args.bids_dir,
        copy=args.copy,
    )
    print(f"Exported BIDS Derivatives mirror: {payload['export_root']} ({len(payload['links'])} links, {len(payload['subjects'])} subjects)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
