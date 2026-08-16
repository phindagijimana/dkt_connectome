#!/usr/bin/env python3
"""Standalone Step 4.5 — lesion-aware disconnectome (Options A, B, C).

Runs outside subject.sh so you can test on a completed results tree before
wiring it into the pipeline. Requires Step 1.5 (lesion_mask_prepared), Step 3
(tractogram + SIFT2 weights), and Step 4 (nodes.mif + dkt_connectome.csv).

Outputs under ``connectomes/sub-<ID>/disconnectome/``:

  lesion_in_dwi.mif          — lesion on the DWI / nodes grid
  lesion_roi_metrics.csv     — per-DKT-node overlap stats
  nodes_A_parcexcised.mif    — Option A parcellation
  streamlines_B_nolesion.tck — Option B spared tractogram
  sift2_B_nolesion.csv       — filtered SIFT2 weights
  dkt_connectome_A_parcexcised.csv
  dkt_connectome_B_streamexcluded.csv
  dkt_connectome_C_both.csv
  disconnection_matrix.csv        — D_ij = 1 - spared_ij / P_ij (default spared = Option C)
  disconnection_matrix_A.csv      — D using Option A (if --option-a)
  disconnection_matrix_B.csv      — D using Option B (if --option-b)
  disconnection_matrix_C.csv      — D using Option C (if --option-c)
  disconnectome.json              — provenance

Connectome weighting defaults to **streamline counts** (same as Step 4). Use
``--connectome-weighting sift2`` for SIFT2-weighted matrices. (The pipeline
does not use SIFT1 streamline culling.)

Usage:
  python3 run_disconnectome.py \\
    --results-root dwi_pipeline/dwi_test_TBI/sub-TBI011011_fastsurfer_inpaint \\
    --subject TBI011011
"""

from __future__ import annotations

import argparse
import csv
import json
import shlex
import subprocess
import sys
from dataclasses import dataclass
from pathlib import Path

try:
    from scipy.ndimage import binary_erosion, generate_binary_structure
except ImportError:  # pragma: no cover
    binary_erosion = None
    generate_binary_structure = None

import nibabel as nib
import numpy as np

SCRIPT_DIR = Path(__file__).resolve().parent
DEFAULT_LUT = SCRIPT_DIR.parent / "containers" / "connectome" / "mrtrix_lut" / "fs_dkt.txt"
DEFAULT_CONTAINER = Path(
    __import__("os").environ.get("CONTAINER_CONNECTOME", "/path/to/dkt_connectome.sif")
)


def log(msg: str) -> None:
    print(f"[disconnectome] {msg}", file=sys.stderr)


@dataclass
class ExcisionConfig:
    """Which excision connectomes to build and how to weight them."""

    run_a: bool = True
    run_b: bool = True
    run_c: bool = True
    weighting: str = "count"  # count | sift2
    lesion_erode_voxels: int = 0
    disconnection_spared: str = "C"  # A | B | C — primary disconnection_matrix.csv


def normalize_weighting(value: str) -> str:
    value = value.lower().strip()
    if value in ("count", "none", "no-sift2", "streamline", "streamlines"):
        return "count"
    if value in ("sift2", "sift"):
        return "sift2"
    raise SystemExit(f"Unknown connectome weighting: {value!r} (use count or sift2)")


def erode_binary_lesion(binary_path: Path, erode_voxels: int) -> Path:
    """Erode binary lesion mask before warp (sensitivity: less over-exclusion)."""
    if erode_voxels <= 0:
        return binary_path
    if binary_erosion is None:
        raise SystemExit("scipy is required for --lesion-erode-voxels (pip install scipy)")
    img = nib.load(str(binary_path))
    data = (np.asarray(img.get_fdata()) > 0)
    struct = generate_binary_structure(3, 1)
    eroded = binary_erosion(data, structure=struct, iterations=erode_voxels)
    out = binary_path.with_name(f"{binary_path.stem}_eroded{erode_voxels}.nii.gz")
    nib.save(nib.Nifti1Image(eroded.astype(np.uint8), img.affine, img.header), str(out))
    log(f"Eroded lesion by {erode_voxels} voxels -> {out.name}")
    return out


def tck2connectome_weight_args(weighting: str, weights_host: Path | None, root: Path) -> str:
    if weighting == "sift2":
        if weights_host is None:
            raise SystemExit("SIFT2 weighting requested but no weights file provided")
        return f"-tck_weights_in {cpath(weights_host, root)} "
    return ""


def normalize_subject(subject: str) -> str:
    return subject.removeprefix("sub-")


def find_one(label: str, paths: list[Path]) -> Path:
    if not paths:
        raise SystemExit(f"Missing {label}: no matching files")
    if len(paths) > 1:
        raise SystemExit(f"Ambiguous {label} ({len(paths)} matches):\n  " + "\n  ".join(str(p) for p in paths))
    return paths[0]


def session_from_path(path: Path) -> str | None:
    for part in path.parts:
        if part.startswith("ses-"):
            return part.removeprefix("ses-")
    return None


@dataclass
class DisconnectomePaths:
    results_root: Path
    subject: str
    session: str
    lesion_mask: Path
    lesion_json: Path
    connectome_dir: Path
    nodes_mif: Path
    primary_connectome: Path
    parcellation_json: Path
    tractogram: Path
    sift2_weights: Path
    dwiref: Path
    preproc_t1w: Path
    affine_mat: Path | None
    outdir: Path
    lut: Path


def discover_paths(
    results_root: Path,
    subject: str,
    session: str | None,
    lut: Path,
) -> DisconnectomePaths:
    results_root = results_root.resolve()
    sub = normalize_subject(subject)

    qsirecon = results_root / "qsirecon_single_run_output"
    qsiprep = results_root / "qsiprep_single_run_output"
    inpaint_root = results_root / "inpainted"
    connectome_dir = results_root / "connectomes" / f"sub-{sub}"

    tract_candidates = sorted(
        p
        for p in qsirecon.rglob("*model-ifod2_streamlines.tck.gz")
        if f"sub-{sub}" in p.as_posix()
    )
    tractogram = find_one("tractogram", tract_candidates)

    ses = session or session_from_path(tractogram)
    if not ses:
        raise SystemExit(f"Could not infer session from tractogram: {tractogram}")

    lesion_mask = inpaint_root / f"sub-{sub}" / f"ses-{ses}" / "lesion_mask_prepared.nii.gz"
    lesion_json = lesion_mask.with_suffix("").with_suffix(".json")
    if not lesion_mask.is_file():
        raise SystemExit(f"No prepared lesion mask (Step 1.5): {lesion_mask}")

    nodes_mif = connectome_dir / "nodes.mif"
    primary_connectome = connectome_dir / "dkt_connectome.csv"
    parcellation_json = connectome_dir / "parcellation.json"
    for req, label in (
        (nodes_mif, "nodes.mif"),
        (primary_connectome, "dkt_connectome.csv"),
    ):
        if not req.is_file():
            raise SystemExit(f"Missing Step 4 output {label}: {req}")

    weight_candidates = sorted(
        p
        for p in qsirecon.rglob("*model-sift2_streamlineweights.csv")
        if f"sub-{sub}" in p.as_posix()
    )
    sift2_weights = find_one("SIFT2 weights", weight_candidates)

    dwiref_candidates = sorted(qsiprep.rglob(f"sub-{sub}/ses-{ses}/dwi/*space-T1w_dwiref.nii.gz"))
    dwiref = find_one("dwiref", dwiref_candidates)

    preproc_candidates = sorted(
        qsiprep.rglob(f"sub-{sub}/ses-{ses}/anat/*desc-preproc_T1w.nii.gz")
    )
    if not preproc_candidates:
        preproc_candidates = sorted(qsiprep.rglob(f"sub-{sub}/anat/*desc-preproc_T1w.nii.gz"))
    preproc_t1w = find_one("desc-preproc T1w", preproc_candidates)

    mat = connectome_dir / "native_to_preproc_T1w_0GenericAffine.mat"
    affine_mat = mat if mat.is_file() else None

    return DisconnectomePaths(
        results_root=results_root,
        subject=sub,
        session=ses,
        lesion_mask=lesion_mask,
        lesion_json=lesion_json,
        connectome_dir=connectome_dir,
        nodes_mif=nodes_mif,
        primary_connectome=primary_connectome,
        parcellation_json=parcellation_json if parcellation_json.is_file() else None,
        tractogram=tractogram,
        sift2_weights=sift2_weights,
        dwiref=dwiref,
        preproc_t1w=preproc_t1w,
        affine_mat=affine_mat,
        outdir=connectome_dir / "disconnectome",
        lut=lut,
    )


def load_lut(path: Path) -> dict[int, str]:
    names: dict[int, str] = {}
    for line in path.read_text().splitlines():
        line = line.split("#", 1)[0].strip()
        if not line:
            continue
        parts = line.split()
        if not parts[0].isdigit():
            continue
        node_id = int(parts[0])
        if node_id == 0:
            continue
        names[node_id] = parts[1] if len(parts) > 1 else f"node_{node_id}"
    return names


def load_lesion_selection(lesion_json: Path, core_only: bool) -> list[int]:
    if not lesion_json.is_file():
        log(f"WARNING: no {lesion_json.name}; using all nonzero labels")
        return []
    meta = json.loads(lesion_json.read_text())
    selected = meta.get("labels_selected") or meta.get("labels_present") or []
    selected = [int(x) for x in selected]
    if core_only:
        selected = [x for x in selected if x == 1]
        if not selected:
            raise SystemExit("--core-only requested but label 1 (core) not in labels_selected")
    return selected


def build_binary_lesion(
    lesion_mask: Path,
    lesion_json: Path,
    out_path: Path,
    core_only: bool,
) -> dict:
    img = nib.load(str(lesion_mask))
    data = np.asarray(img.get_fdata())
    selected = load_lesion_selection(lesion_json, core_only)
    if selected:
        binary = np.isin(data.astype(np.int32), selected).astype(np.uint8)
    else:
        binary = (data > 0).astype(np.uint8)
    out = nib.Nifti1Image(binary, img.affine, img.header)
    out_path.parent.mkdir(parents=True, exist_ok=True)
    nib.save(out, str(out_path))
    meta = json.loads(lesion_json.read_text()) if lesion_json.is_file() else {}
    meta = dict(meta)
    meta["binary_labels_used"] = selected if selected else "nonzero"
    meta["core_only"] = core_only
    return meta


def cpath(host: Path, root: Path) -> str:
    return f"/data/{host.resolve().relative_to(root.resolve()).as_posix()}"


def run_container(container: Path, data_root: Path, shell_cmd: str, dry_run: bool = False) -> None:
    cmd = [
        "apptainer",
        "exec",
        "--cleanenv",
        "--containall",
        "-B",
        f"{data_root.resolve()}:/data",
        str(container),
        "bash",
        "-lc",
        f"export PATH=/opt/mrtrix3-latest/bin:/opt/ants/bin:$PATH; {shell_cmd}",
    ]
    log(f"run: {shell_cmd[:120]}{'...' if len(shell_cmd) > 120 else ''}")
    if dry_run:
        return
    subprocess.run(cmd, check=True)


def warp_lesion(
    paths: DisconnectomePaths,
    binary_lesion: Path,
    container: Path,
    dry_run: bool,
) -> Path:
    """Warp binary lesion onto the nodes / DWI grid."""
    out_nii = paths.outdir / "lesion_in_dwi.nii.gz"
    out_mif = paths.outdir / "lesion_in_dwi.mif"
    paths.outdir.mkdir(parents=True, exist_ok=True)
    root = paths.results_root

    if paths.affine_mat is not None:
        lesion_preproc = paths.outdir / "lesion_in_preproc_t1w.nii.gz"
        cmd = " && ".join(
            [
                "set -euo pipefail",
                f"antsApplyTransforms -d 3 -i {cpath(binary_lesion, root)} "
                f"-r {cpath(paths.preproc_t1w, root)} "
                f"-t {cpath(paths.affine_mat, root)} "
                f"-n NearestNeighbor -o {cpath(lesion_preproc, root)}",
                f"antsApplyTransforms -d 3 -i {cpath(lesion_preproc, root)} "
                f"-r {cpath(paths.dwiref, root)} "
                f"-n NearestNeighbor -o {cpath(out_nii, root)}",
                f"mrconvert -force {cpath(out_nii, root)} {cpath(out_mif, root)}",
            ]
        )
        log("Warping lesion: native/inpainted T1w -> preproc T1w -> dwiref (Step 4 affine)")
    else:
        cmd = " && ".join(
            [
                "set -euo pipefail",
                f"mrtransform -force {cpath(binary_lesion, root)} "
                f"-template {cpath(paths.nodes_mif, root)} -interp nearest "
                f"{cpath(out_mif, root)}",
                f"mrconvert -force {cpath(out_mif, root)} {cpath(out_nii, root)}",
            ]
        )
        log("Warping lesion: mrtransform -template nodes.mif (no Step 4 affine found)")

    run_container(container, root, cmd, dry_run=dry_run)
    return out_mif


def export_nodes_nii(paths: DisconnectomePaths, container: Path, dry_run: bool) -> Path:
    nodes_nii = paths.outdir / "nodes.nii.gz"
    cmd = (
        f"mrconvert -force {cpath(paths.nodes_mif, paths.results_root)} "
        f"{cpath(nodes_nii, paths.results_root)}"
    )
    run_container(container, paths.results_root, cmd, dry_run=dry_run)
    return nodes_nii


def compute_roi_metrics(
    nodes_nii: Path,
    lesion_nii: Path,
    lut: dict[int, str],
    flag_threshold: float,
) -> list[dict]:
    nodes_img = nib.load(str(nodes_nii))
    lesion_img = nib.load(str(lesion_nii))
    nodes = np.rint(nodes_img.get_fdata()).astype(np.int32)
    lesion = (lesion_img.get_fdata() > 0)

    if nodes.shape != lesion.shape:
        raise SystemExit(f"Grid mismatch: nodes {nodes.shape} vs lesion {lesion.shape}")

    zooms = nodes_img.header.get_zooms()[:3]
    voxel_vol = float(np.prod(zooms))

    rows: list[dict] = []
    for node_id in sorted(lut):
        parcel = nodes == node_id
        parcel_voxels = int(parcel.sum())
        if parcel_voxels == 0:
            rows.append(
                {
                    "node_id": node_id,
                    "node_name": lut[node_id],
                    "parcel_voxels": 0,
                    "lesion_voxels": 0,
                    "lesion_load_frac": 0.0,
                    "excised_fraction": 0.0,
                    "lesion_vol_mm3": 0.0,
                    "flagged": 0,
                }
            )
            continue
        lesion_voxels = int((parcel & lesion).sum())
        load_frac = lesion_voxels / parcel_voxels
        rows.append(
            {
                "node_id": node_id,
                "node_name": lut[node_id],
                "parcel_voxels": parcel_voxels,
                "lesion_voxels": lesion_voxels,
                "lesion_load_frac": round(load_frac, 6),
                "excised_fraction": round(load_frac, 6),
                "lesion_vol_mm3": round(lesion_voxels * voxel_vol, 3),
                "flagged": int(load_frac >= flag_threshold),
            }
        )
    return rows


def write_roi_csv(rows: list[dict], path: Path) -> None:
    fields = [
        "node_id",
        "node_name",
        "parcel_voxels",
        "lesion_voxels",
        "lesion_load_frac",
        "excised_fraction",
        "lesion_vol_mm3",
        "flagged",
    ]
    with path.open("w", newline="") as fh:
        writer = csv.DictWriter(fh, fieldnames=fields)
        writer.writeheader()
        writer.writerows(rows)


def run_excision_mrtrix(
    paths: DisconnectomePaths,
    container: Path,
    lesion_mif: Path,
    cfg: ExcisionConfig,
    dry_run: bool,
) -> dict[str, Path | None]:
    if cfg.run_c and not (cfg.run_a and cfg.run_b):
        raise SystemExit("Option C requires both Option A and Option B (--option-c without --skip-option-a/b)")

    root = paths.results_root
    out = paths.outdir
    artifacts: dict[str, Path | None] = {
        "tck_staged": out / "streamlines_staged.tck",
        "nodes_A": out / "nodes_A_parcexcised.mif" if cfg.run_a else None,
        "tck_B": out / "streamlines_B_nolesion.tck" if cfg.run_b else None,
        "weights_B": out / "sift2_B_nolesion.csv" if cfg.run_b and cfg.weighting == "sift2" else None,
        "connectome_A": out / "dkt_connectome_A_parcexcised.csv" if cfg.run_a else None,
        "connectome_B": out / "dkt_connectome_B_streamexcluded.csv" if cfg.run_b else None,
        "connectome_C": out / "dkt_connectome_C_both.csv" if cfg.run_c else None,
    }

    c_lesion = cpath(lesion_mif, root)
    c_nodes = cpath(paths.nodes_mif, root)
    c_tck_in = cpath(paths.tractogram, root)
    c_tck = cpath(artifacts["tck_staged"], root)  # type: ignore[arg-type]
    c_w_in = cpath(paths.sift2_weights, root)
    w_full = tck2connectome_weight_args(cfg.weighting, paths.sift2_weights, root)

    steps = ["set -euo pipefail", f"gunzip -c {c_tck_in} > {c_tck}"]

    if cfg.run_a:
        steps.append(
            f"mrcalc -force {c_nodes} {c_lesion} -not -mult {cpath(artifacts['nodes_A'], root)}"  # type: ignore[arg-type]
        )
        steps.append(
            f"tck2connectome -force {w_full}{c_tck} "
            f"{cpath(artifacts['nodes_A'], root)} {cpath(artifacts['connectome_A'], root)} "  # type: ignore[arg-type]
            f"-symmetric -zero_diagonal"
        )

    if cfg.run_b:
        if cfg.weighting == "sift2":
            steps.append(
                f"tckedit -force {c_tck} -exclude {c_lesion} "
                f"-tck_weights_in {c_w_in} -tck_weights_out {cpath(artifacts['weights_B'], root)} "  # type: ignore[arg-type]
                f"{cpath(artifacts['tck_B'], root)}"  # type: ignore[arg-type]
            )
            w_b = tck2connectome_weight_args("sift2", artifacts["weights_B"], root)  # type: ignore[arg-type]
        else:
            steps.append(
                f"tckedit -force {c_tck} -exclude {c_lesion} {cpath(artifacts['tck_B'], root)}"  # type: ignore[arg-type]
            )
            w_b = ""
        steps.append(
            f"tck2connectome -force {w_b}{cpath(artifacts['tck_B'], root)} "  # type: ignore[arg-type]
            f"{c_nodes} {cpath(artifacts['connectome_B'], root)} "  # type: ignore[arg-type]
            f"-symmetric -zero_diagonal"
        )

    if cfg.run_c:
        w_b = tck2connectome_weight_args(cfg.weighting, artifacts["weights_B"], root)  # type: ignore[arg-type]
        steps.append(
            f"tck2connectome -force {w_b}{cpath(artifacts['tck_B'], root)} "  # type: ignore[arg-type]
            f"{cpath(artifacts['nodes_A'], root)} {cpath(artifacts['connectome_C'], root)} "  # type: ignore[arg-type]
            f"-symmetric -zero_diagonal"
        )

    run_container(container, root, " && ".join(steps), dry_run=dry_run)
    return artifacts


def load_connectome_csv(path: Path) -> np.ndarray:
    with path.open() as fh:
        rows = [[float(x) for x in line.split(",")] for line in fh if line.strip()]
    return np.asarray(rows, dtype=np.float64)


def write_disconnection_matrix(primary: Path, spared: Path, out_path: Path) -> dict:
    c = load_connectome_csv(primary)
    s = load_connectome_csv(spared)
    if c.shape != s.shape:
        raise SystemExit(f"Connectome shape mismatch: primary {c.shape} vs spared {s.shape}")

    d = np.zeros_like(c)
    mask = c > 0
    raw_ratio = np.zeros_like(c)
    raw_ratio[mask] = 1.0 - (s[mask] / c[mask])
    d[mask] = np.clip(raw_ratio[mask], 0.0, 1.0)

    np.savetxt(out_path, d, delimiter=",", fmt="%.6f")

    n_edges = int(mask.sum())
    spared_gt_primary = int(((s > c) & mask).sum())
    disrupted = int((d[mask] > 0).sum())
    mean_d = float(d[mask].mean()) if n_edges else 0.0
    return {
        "n_edges_primary_gt0": n_edges,
        "n_edges_disrupted_gt0": disrupted,
        "n_edges_spared_gt_primary": spared_gt_primary,
        "mean_disconnection_on_primary_edges": round(mean_d, 6),
        "mean_disconnection_unclipped": round(float(raw_ratio[mask].mean()) if n_edges else 0.0, 6),
        "total_primary": round(float(c.sum()), 6),
        "total_spared": round(float(s.sum()), 6),
        "total_spared_over_primary": round(float(s.sum() / c.sum()) if c.sum() else 0.0, 6),
    }


def main() -> None:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--results-root", type=Path, required=True, help="Subject results tree (RESULTS_ROOT)")
    ap.add_argument("--subject", required=True, help="Subject ID, with or without sub- prefix")
    ap.add_argument("--session", default=None, help="BIDS session (default: infer from tractogram path)")
    ap.add_argument("--container", type=Path, default=Path(DEFAULT_CONTAINER), help="dkt_connectome.sif")
    ap.add_argument("--lut", type=Path, default=DEFAULT_LUT, help="DKT MRtrix LUT (node names)")
    ap.add_argument("--flag-threshold", type=float, default=0.5, help="lesion_load_frac for flagged=1")
    ap.add_argument("--core-only", action="store_true", help="Sensitivity: core label (1) only")
    ap.add_argument(
        "--connectome-weighting",
        default="count",
        choices=("count", "sift2"),
        help="Edge weights: streamline counts (default, matches Step 4) or SIFT2",
    )
    ap.add_argument(
        "--no-sift2",
        action="store_const",
        const="count",
        dest="connectome_weighting",
        help="Alias for --connectome-weighting count",
    )
    ap.add_argument(
        "--lesion-erode-voxels",
        type=int,
        default=0,
        metavar="N",
        help="Binary erosion iterations on lesion before warp (sensitivity)",
    )
    ap.add_argument(
        "--disconnection-spared",
        default="C",
        choices=("A", "B", "C"),
        help="Which spared connectome defines disconnection_matrix.csv (default: C)",
    )
    ap.add_argument("--option-a", dest="run_a", action="store_true", default=True, help="Build Option A (default: on)")
    ap.add_argument("--skip-option-a", dest="run_a", action="store_false")
    ap.add_argument("--option-b", dest="run_b", action="store_true", default=True, help="Build Option B (default: on)")
    ap.add_argument("--skip-option-b", dest="run_b", action="store_false")
    ap.add_argument("--option-c", dest="run_c", action="store_true", default=True, help="Build Option C (default: on)")
    ap.add_argument("--skip-option-c", dest="run_c", action="store_false")
    ap.add_argument("--dry-run", action="store_true", help="Print steps without running MRtrix/ANTs")
    args = ap.parse_args()

    if not args.container.is_file():
        raise SystemExit(f"Container not found: {args.container}")
    if not args.lut.is_file():
        raise SystemExit(f"LUT not found: {args.lut}")

    cfg = ExcisionConfig(
        run_a=args.run_a,
        run_b=args.run_b,
        run_c=args.run_c,
        weighting=normalize_weighting(args.connectome_weighting),
        lesion_erode_voxels=max(0, args.lesion_erode_voxels),
        disconnection_spared=args.disconnection_spared.upper(),
    )
    if cfg.disconnection_spared == "A" and not cfg.run_a:
        raise SystemExit("--disconnection-spared A requires --option-a")
    if cfg.disconnection_spared == "B" and not cfg.run_b:
        raise SystemExit("--disconnection-spared B requires --option-b")
    if cfg.disconnection_spared == "C" and not cfg.run_c:
        raise SystemExit("--disconnection-spared C requires --option-c")

    paths = discover_paths(args.results_root, args.subject, args.session, args.lut)
    log(f"subject=sub-{paths.subject} session=ses-{paths.session} weighting={cfg.weighting}")
    log(f"options A={cfg.run_a} B={cfg.run_b} C={cfg.run_c} D_spared={cfg.disconnection_spared}")
    log(f"output -> {paths.outdir}")

    lut = load_lut(paths.lut)
    binary_lesion = paths.outdir / "lesion_binary_t1w.nii.gz"
    lesion_meta = build_binary_lesion(paths.lesion_mask, paths.lesion_json, binary_lesion, args.core_only)
    binary_lesion = erode_binary_lesion(binary_lesion, cfg.lesion_erode_voxels)
    if cfg.lesion_erode_voxels > 0:
        lesion_meta["lesion_erode_voxels"] = cfg.lesion_erode_voxels

    lesion_mif = warp_lesion(paths, binary_lesion, args.container, args.dry_run)
    lesion_nii = paths.outdir / "lesion_in_dwi.nii.gz"

    nodes_nii = export_nodes_nii(paths, args.container, args.dry_run)
    if not args.dry_run:
        roi_rows = compute_roi_metrics(nodes_nii, lesion_nii, lut, args.flag_threshold)
        roi_csv = paths.outdir / "lesion_roi_metrics.csv"
        write_roi_csv(roi_rows, roi_csv)
        log(f"Wrote {roi_csv} ({sum(r['flagged'] for r in roi_rows)} flagged nodes)")

    artifacts = run_excision_mrtrix(paths, args.container, lesion_mif, cfg, args.dry_run)

    disconnection_stats: dict = {}
    disconnection_by_option: dict[str, dict] = {}
    disconnection_csv = paths.outdir / "disconnection_matrix.csv"
    spared_map = {
        "A": artifacts.get("connectome_A"),
        "B": artifacts.get("connectome_B"),
        "C": artifacts.get("connectome_C"),
    }
    if not args.dry_run:
        for label, spared_path in spared_map.items():
            if spared_path is None:
                continue
            stats = write_disconnection_matrix(
                paths.primary_connectome,
                spared_path,
                paths.outdir / f"disconnection_matrix_{label}.csv",
            )
            disconnection_by_option[label] = stats
            log(f"Wrote disconnection_matrix_{label}.csv (mean D={stats['mean_disconnection_on_primary_edges']})")
        primary_spared = spared_map[cfg.disconnection_spared]
        if primary_spared is not None:
            disconnection_stats = write_disconnection_matrix(
                paths.primary_connectome,
                primary_spared,
                disconnection_csv,
            )
            log(f"Wrote {disconnection_csv} (spared=Option {cfg.disconnection_spared})")

    provenance = {
        "step": "4.5_disconnectome",
        "subject": f"sub-{paths.subject}",
        "session": f"ses-{paths.session}",
        "results_root": str(paths.results_root),
        "connectome_weighting": cfg.weighting,
        "options": {"A": cfg.run_a, "B": cfg.run_b, "C": cfg.run_c},
        "disconnection_spared": cfg.disconnection_spared,
        "lesion_mask_prepared": str(paths.lesion_mask),
        "lesion_selection": lesion_meta,
        "warp": "ants_affine+dwiref" if paths.affine_mat else "mrtransform_template_nodes",
        "affine_mat": str(paths.affine_mat) if paths.affine_mat else None,
        "primary_connectome": str(paths.primary_connectome),
        "flag_threshold": args.flag_threshold,
        "outputs": {k: str(v) for k, v in artifacts.items() if v is not None},
        "lesion_roi_metrics": str(paths.outdir / "lesion_roi_metrics.csv"),
        "disconnection_matrix": str(disconnection_csv),
        "disconnection_by_option": disconnection_by_option,
        "disconnection_summary": disconnection_stats,
        "container": str(args.container),
    }
    prov_path = paths.outdir / "disconnectome.json"
    if not args.dry_run:
        prov_path.write_text(json.dumps(provenance, indent=2) + "\n")
        log(f"Done. Provenance: {prov_path}")
    else:
        print(json.dumps(provenance, indent=2))


if __name__ == "__main__":
    main()
