#!/usr/bin/env python3
"""Collect QC summaries from all pipeline steps for one subject."""

from __future__ import annotations

import json
import sys
from datetime import datetime, timezone
from pathlib import Path
from typing import Any

SCRIPT_DIR = Path(__file__).resolve().parent
if str(SCRIPT_DIR) not in sys.path:
    sys.path.insert(0, str(SCRIPT_DIR))

from evaluate_disconnectome_integrity import collect_integrity_report  # noqa: E402


def _sub_ids(subject: str) -> tuple[str, str]:
    subject = subject.removeprefix("sub-")
    return f"sub-{subject}", subject


def _load_json(path: Path) -> dict | None:
    if not path.is_file():
        return None
    try:
        return json.loads(path.read_text())
    except json.JSONDecodeError:
        return None


def _rel_link(from_dir: Path, target: Path | None) -> str | None:
    if target is None or not target.is_file():
        return None
    import os

    return Path(os.path.relpath(target, from_dir)).as_posix()


def _step(
    step_id: str,
    name: str,
    status: str,
    *,
    summary: dict[str, Any] | None = None,
    links: list[dict[str, str]] | None = None,
    figures: list[dict[str, str]] | None = None,
    notes: str | None = None,
) -> dict:
    return {
        "id": step_id,
        "name": name,
        "status": status,
        "summary": summary or {},
        "links": links or [],
        "figures": figures or [],
        "notes": notes,
    }


def _worst_status(statuses: list[str]) -> str:
    order = {"FAIL": 3, "WARN": 2, "PASS": 1, "SKIP": 0, "NA": 0}
    active = [s for s in statuses if s not in ("SKIP", "NA")]
    if not active:
        return "NA"
    return max(active, key=lambda s: order.get(s, 0))


def collect_qsiprep(results_root: Path, subject_id: str, qc_dir: Path) -> dict:
    html = results_root / "qsiprep_single_run_output" / f"{subject_id}.html"
    figures_dir = results_root / "qsiprep_single_run_output" / subject_id / "figures"
    marker = results_root / ".snakemake_markers" / subject_id / "qsiprep.done"
    sub_short = subject_id.removeprefix("sub-")
    log_path = results_root / "logs" / f"sub-{sub_short}_qsiprep.log"

    if not html.is_file() and not marker.is_file():
        return _step("qsiprep", "Step 1 — QSIPrep", "NA", notes="No QSIPrep outputs found")

    status = "PASS" if html.is_file() else "WARN"
    links = []
    if html.is_file():
        links.append({"label": "QSIPrep subject report", "href": _rel_link(qc_dir, html) or ""})

    figures: list[dict[str, str]] = []
    if figures_dir.is_dir():
        preferred = ("summary.html", "coreg.svg", "carpetplot.svg", "seg_mask.svg")
        seen: set[str] = set()
        for fig in sorted(figures_dir.iterdir()):
            if fig.suffix.lower() not in {".html", ".svg", ".png"}:
                continue
            key = next((p for p in preferred if p in fig.name), fig.name)
            if key in seen:
                continue
            seen.add(key)
            rel = _rel_link(qc_dir, fig)
            if rel:
                figures.append({"label": fig.name, "href": rel, "kind": fig.suffix.lower().lstrip(".")})
            if len(figures) >= 6:
                break

    slice_qc = sorted((results_root / "qsiprep_single_run_output" / subject_id).glob("**/desc-SliceQC_dwi.json"))
    summary: dict[str, Any] = {"report_present": html.is_file(), "figure_count": len(figures)}
    if slice_qc:
        summary["slice_qc_json"] = str(slice_qc[0].relative_to(results_root))

    return _step("qsiprep", "Step 1 — QSIPrep", status, summary=summary, links=links, figures=figures)


def collect_inpaint(results_root: Path, subject_id: str, qc_dir: Path) -> dict:
    qc_files = sorted((results_root / "inpainted" / subject_id).glob("ses-*/inpainting_qc.json"))
    if not qc_files:
        return _step("inpaint", "Step 1.1 — Inpaint", "SKIP", notes="No lesion inpainting QC (mask absent or skipped)")

    qc_path = qc_files[0]
    data = _load_json(qc_path) or {}
    status = "PASS" if data.get("ok") else "FAIL"
    session = qc_path.parent.name
    img_dir = qc_path.parent / "inpainting_images"
    figures: list[dict[str, str]] = []
    for name in ("inpainting_original.png", "inpainting_mask.png", "inpainting_result.png"):
        fig = img_dir / name
        rel = _rel_link(qc_dir, fig)
        if rel:
            figures.append({"label": name.replace("inpainting_", "").replace(".png", ""), "href": rel, "kind": "png"})

    summary = {
        k: data.get(k)
        for k in (
            "ok",
            "outside_lesion_correlation",
            "correlation_drop_vs_control",
            "resampling_control_correlation",
            "lesion_voxels",
            "geometry_matches_original",
        )
        if k in data
    }
    summary["session"] = session
    links = [{"label": "inpainting_qc.json", "href": _rel_link(qc_dir, qc_path) or ""}]
    prov = qc_path.parent / "inpainting.json"
    if prov.is_file():
        links.append({"label": "inpainting.json", "href": _rel_link(qc_dir, prov) or ""})

    return _step("inpaint", "Step 1.1 — Inpaint", status, summary=summary, links=links, figures=figures)


def collect_recon(results_root: Path, subject_id: str, qc_dir: Path) -> dict:
    fs_dir = results_root / "freesurfer" / subject_id
    aparc = fs_dir / "mri" / "aparc+aseg.mgz"
    if not aparc.is_file():
        return _step("recon", "Step 2 — Recon", "NA", notes="No recon outputs found")

    tool = "fastsurfer" if (fs_dir / "scripts" / "recon-surf.log").is_file() else "freesurfer"
    stats_files = sorted((fs_dir / "stats").glob("*.stats")) if (fs_dir / "stats").is_dir() else []
    summary: dict[str, Any] = {"tool": tool, "aparc_aseg_present": True, "stats_files": len(stats_files)}
    sub_short = subject_id.removeprefix("sub-")
    links = [{"label": "recon log", "href": _rel_link(qc_dir, results_root / "logs" / f"sub-{sub_short}_recon.log") or ""}]
    return _step("recon", "Step 2 — Recon", "PASS", summary=summary, links=[l for l in links if l["href"]])


def collect_qsirecon(results_root: Path, subject_id: str, qc_dir: Path) -> dict:
    html_files = sorted((results_root / "qsirecon_single_run_output").glob(f"**/derivatives/**/{subject_id}*.html"))
    html_files = [p for p in html_files if p.parent.name == "derivatives" or "derivatives" in p.parts]
    # Prefer session-level report at derivatives root
    top_reports = [
        p
        for p in html_files
        if p.parent.name.startswith("qsirecon-") and p.name.startswith(subject_id)
    ]
    report = top_reports[0] if top_reports else (html_files[0] if html_files else None)
    marker = results_root / ".snakemake_markers" / subject_id / "qsirecon.done"

    if report is None and not marker.is_file():
        return _step("qsirecon", "Step 3 — QSIRecon", "NA", notes="No QSIRecon outputs found")

    status = "PASS" if report is not None else "WARN"
    links = []
    if report is not None:
        links.append({"label": "QSIRecon report", "href": _rel_link(qc_dir, report) or ""})

    figures: list[dict[str, str]] = []
    fig_dir = results_root / "qsirecon_single_run_output"
    for fig in sorted(fig_dir.glob(f"**/{subject_id}/**/figures/*"))[:4]:
        rel = _rel_link(qc_dir, fig)
        if rel:
            figures.append({"label": fig.name, "href": rel, "kind": fig.suffix.lower().lstrip(".")})

    return _step("qsirecon", "Step 3 — QSIRecon", status, summary={"report_present": report is not None}, links=links, figures=figures)


def collect_connectome(results_root: Path, subject_id: str, qc_dir: Path) -> dict:
    conn_dir = results_root / "connectomes" / subject_id
    prov = conn_dir / "parcellation.json"
    matrix = conn_dir / "dkt_connectome.csv"
    if not prov.is_file() and not matrix.is_file():
        return _step("connectome", "Step 4 — Connectome", "NA", notes="No connectome outputs found")

    data = _load_json(prov) or {}
    empty_nodes = int(data.get("empty_nodes", 0) or 0)
    status = "PASS" if empty_nodes == 0 else "WARN"
    summary = {
        "parcellation": data.get("parcellation"),
        "nodes": data.get("nodes"),
        "empty_nodes": empty_nodes,
        "deterministic": data.get("deterministic"),
    }
    links = []
    if prov.is_file():
        links.append({"label": "parcellation.json", "href": _rel_link(qc_dir, prov) or ""})
    if matrix.is_file():
        links.append({"label": "dkt_connectome.csv", "href": _rel_link(qc_dir, matrix) or ""})
    return _step("connectome", "Step 4 — Connectome", status, summary=summary, links=links)


def collect_disconnectome(results_root: Path, subject_id: str, qc_dir: Path) -> dict:
    ddir = results_root / "connectomes" / subject_id / "disconnectome"
    if not (ddir / "disconnectome.json").is_file():
        return _step("disconnectome", "Step 4.1 — Disconnectome", "SKIP", notes="No disconnectome (non-lesion or skipped)")

    qc_json = ddir / "disconnectome_qc.json"
    if qc_json.is_file():
        report = _load_json(qc_json) or {}
        status = report.get("overall_status", "PASS")
        summary = {
            "weighting": report.get("weighting"),
            "disconnection_spared": report.get("disconnection_spared"),
            **(report.get("disconnection_summary") or {}),
        }
    else:
        try:
            report = collect_integrity_report(ddir)
            status = report["overall_status"]
            summary = {
                "weighting": report.get("weighting"),
                "disconnection_spared": report.get("disconnection_spared"),
                **(report.get("disconnection_summary") or {}),
            }
        except FileNotFoundError:
            return _step("disconnectome", "Step 4.1 — Disconnectome", "WARN", notes="disconnectome.json incomplete")

    links = [
        {"label": "disconnectome detail report", "href": _rel_link(qc_dir, ddir / "disconnectome_qc.html") or ""},
        {"label": "disconnectome.json", "href": _rel_link(qc_dir, ddir / "disconnectome.json") or ""},
    ]
    links = [l for l in links if l["href"]]
    return _step("disconnectome", "Step 4.1 — Disconnectome", status, summary=summary, links=links)


def collect_nodestrength(results_root: Path, subject_id: str, qc_dir: Path) -> dict:
    ns_root = results_root / "node_strength"
    sub_short = subject_id.removeprefix("sub-")
    csv_path = ns_root / "strength" / "per_subject" / f"sub-{sub_short}_strength.csv"
    report_pdf = ns_root / "reports" / subject_id / "report.pdf"
    fig_dir = ns_root / "reports" / subject_id / "figures"

    if not csv_path.is_file() and not report_pdf.is_file():
        return _step("nodestrength", "Step 5 — Node strength", "SKIP", notes="Node strength not run")

    status = "PASS"
    links = []
    if report_pdf.is_file():
        links.append({"label": "ENIGMA report (PDF)", "href": _rel_link(qc_dir, report_pdf) or ""})
    if csv_path.is_file():
        links.append({"label": "strength CSV", "href": _rel_link(qc_dir, csv_path) or ""})

    figures: list[dict[str, str]] = []
    if fig_dir.is_dir():
        for fig in sorted(fig_dir.glob("*.png"))[:6]:
            rel = _rel_link(qc_dir, fig)
            if rel:
                figures.append({"label": fig.stem, "href": rel, "kind": "png"})

    return _step("nodestrength", "Step 5 — Node strength", status, summary={"report_present": report_pdf.is_file()}, links=links, figures=figures)


def collect_subject_qc(results_root: Path, subject: str) -> dict:
    results_root = results_root.resolve()
    subject_id, _ = _sub_ids(subject)
    qc_dir = results_root / "qc" / subject_id

    steps = [
        collect_qsiprep(results_root, subject_id, qc_dir),
        collect_inpaint(results_root, subject_id, qc_dir),
        collect_recon(results_root, subject_id, qc_dir),
        collect_qsirecon(results_root, subject_id, qc_dir),
        collect_connectome(results_root, subject_id, qc_dir),
        collect_disconnectome(results_root, subject_id, qc_dir),
        collect_nodestrength(results_root, subject_id, qc_dir),
    ]
    overall = _worst_status([s["status"] for s in steps])

    return {
        "pipeline": "DKT Connectome",
        "subject": subject_id,
        "results_root": str(results_root),
        "generated_at": datetime.now(timezone.utc).isoformat(),
        "overall_status": overall,
        "steps": steps,
    }


# ---------------------------------------------------------------------------
# Provenance manifest (per-subject, per-arm) — stitches pipeline version,
# container digests, BIDS input hashes, and existing step-level provenance
# JSONs into one file for reproducibility audits.
# ---------------------------------------------------------------------------

def _sha256_file(path: Path, block_size: int = 65536) -> str | None:
    import hashlib

    try:
        h = hashlib.sha256()
        with path.open("rb") as fh:
            while chunk := fh.read(block_size):
                h.update(chunk)
        return h.hexdigest()
    except OSError:
        return None


def _file_record(path_str: str | None, role: str) -> dict | None:
    if not path_str:
        return None
    p = Path(path_str)
    if not p.is_file():
        return {"role": role, "path": path_str, "exists": False, "sha256": None, "size_bytes": None}
    return {
        "role": role,
        "path": path_str,
        "exists": True,
        "sha256": _sha256_file(p),
        "size_bytes": p.stat().st_size,
    }


def _pipeline_meta() -> dict:
    import subprocess

    pipeline_root = SCRIPT_DIR.parent
    app = _load_json(pipeline_root / "app.json") or {}
    repo_root = pipeline_root.parent
    git_info: dict[str, Any] = {"commit": None, "dirty": None}
    try:
        git_info["commit"] = subprocess.check_output(
            ["git", "-C", str(repo_root), "rev-parse", "HEAD"],
            text=True,
            stderr=subprocess.DEVNULL,
        ).strip()
    except (subprocess.CalledProcessError, FileNotFoundError):
        pass
    try:
        status = subprocess.check_output(
            ["git", "-C", str(repo_root), "status", "--porcelain"],
            text=True,
            stderr=subprocess.DEVNULL,
        )
        git_info["dirty"] = bool(status.strip())
    except (subprocess.CalledProcessError, FileNotFoundError):
        pass
    return {
        "name": app.get("Name"),
        "pipeline_version": app.get("PipelineVersion"),
        "source": app.get("Source"),
        "git": git_info,
    }


def _container_manifest() -> dict:
    return _load_json(SCRIPT_DIR.parent / "release_manifest.json") or {}


def _bids_input_records(results_root: Path, subject_id: str) -> list[dict]:
    records: list[dict] = []
    seen: set[str] = set()

    def _add(path_str: str | None, role: str) -> None:
        if not path_str or path_str in seen:
            return
        seen.add(path_str)
        rec = _file_record(path_str, role)
        if rec:
            records.append(rec)

    for ip in sorted((results_root / "inpainted" / subject_id).glob("ses-*/inpainting.json")):
        d = _load_json(ip) or {}
        _add(d.get("input_t1w"), "t1w")
        _add(d.get("lesion_mask_source"), "lesion_mask")

    la = _load_json(results_root / "lesion_aware_act" / subject_id / "lesion_aware_act.json") or {}
    _add(la.get("act_lesion_mask_reference_t1w"), "t1w")
    _add(la.get("act_lesion_mask_source"), "lesion_mask")

    return records


def _step_provenance(results_root: Path, subject_id: str) -> list[dict]:
    slots: list[tuple[str, list[Path]]] = [
        ("inpaint", sorted((results_root / "inpainted" / subject_id).glob("ses-*/inpainting.json"))),
        ("lesion_aware_act", [results_root / "lesion_aware_act" / subject_id / "lesion_aware_act.json"]),
        ("connectome", [results_root / "connectomes" / subject_id / "parcellation.json"]),
        ("disconnectome", [results_root / "connectomes" / subject_id / "disconnectome" / "disconnectome.json"]),
    ]
    out: list[dict] = []
    for step, paths in slots:
        for p in paths:
            if p and p.is_file():
                out.append({"step": step, "path": str(p), "data": _load_json(p)})
    return out


def collect_subject_provenance(results_root: Path, subject: str) -> dict:
    results_root = results_root.resolve()
    subject_id, _ = _sub_ids(subject)
    return {
        "pipeline": _pipeline_meta(),
        "subject": subject_id,
        "results_root": str(results_root),
        "generated_at": datetime.now(timezone.utc).isoformat(),
        "containers": _container_manifest(),
        "bids_inputs": _bids_input_records(results_root, subject_id),
        "step_provenance": _step_provenance(results_root, subject_id),
    }
