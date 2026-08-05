#!/usr/bin/env python3
"""
build_morphometry_panels.py -- ENIGMA-style DK-68 morphometry panels

Reads FreeSurfer's classic Desikan-Killiany (DK, 68-region) surface stats and
`aseg.stats` subcortical volumes -- the exact extraction protocol ENIGMA's
cortical/subcortical working groups use -- and renders:

  E_thickness.png       cortical thickness (mm) on the native DK-68 surface
  E_surface_area.png    surface area (mm^2) on the native DK-68 surface
  F_subcortical_summary.png   subcortical volumes (raw + ICV-normalised),
                        left vs right, per structure

This requires a `recon-all` tree (or FastSurfer run with --fast-fs/--fsaparc,
see pipeline_science.md Sec2.6/Sec15.8): plain FastSurfer has no
lh/rh.aparc.stats. There is deliberately no comparison group or z-score here
-- see ENIGMA.md Sec2 for why a single-subject report cannot claim a
normative "abnormal for age/sex" statement without one; this only shows the
subject's own values, described, not judged.
"""

from common import FS_DIR, REPORTS_DIR, parse_aparc_stats, parse_aseg_stats

import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
import numpy as np

OUT = REPORTS_DIR / "morphometry"
OUT.mkdir(parents=True, exist_ok=True)


def parse_aparc_stats(path):
    """StructName -> dict(NumVert, SurfArea, GrayVol, ThickAvg, ThickStd, ...)."""
    cols = None
    rows = {}
    for line in Path(path).read_text().splitlines():
        if line.startswith("# ColHeaders"):
            cols = line.split()[2:]
            continue
        if line.startswith("#") or not line.strip():
            continue
        parts = line.split()
        name = parts[0]
        values = [float(v) for v in parts[1:]]
        rows[name] = dict(zip(cols[1:], values))
    return rows


def parse_aseg_stats(path):
    """Returns (eTIV_mm3, {StructName: volume_mm3})."""
    etiv = None
    vols = {}
    for line in Path(path).read_text().splitlines():
        if line.startswith("# Measure EstimatedTotalIntraCranialVol"):
            etiv = float(line.split(",")[3])
            continue
        if line.startswith("#") or not line.strip():
            continue
        parts = line.split()
        # Index SegId NVoxels Volume_mm3 StructName normMean ...
        vols[parts[4]] = float(parts[3])
    return etiv, vols


def panel_surface_metric(lh_stats, rh_stats, key, title, fname, cmap="viridis"):
    from nilearn import plotting as nlp
    from nibabel.freesurfer.io import read_annot, read_geometry

    fig = plt.figure(figsize=(12, 6))
    for col, (hemi, stats) in enumerate([("lh", lh_stats), ("rh", rh_stats)]):
        coords, faces = read_geometry(str(FS_DIR / "surf" / f"{hemi}.inflated"))
        labels, _ctab, names = read_annot(str(FS_DIR / "label" / f"{hemi}.aparc.annot"))
        names = [n.decode() if isinstance(n, bytes) else n for n in names]

        vertex_vals = np.zeros(labels.shape[0], dtype=float)
        for local_idx, region_name in enumerate(names):
            val = stats.get(region_name, {}).get(key, 0.0)
            vertex_vals[labels == local_idx] = val

        ax = fig.add_subplot(1, 2, col + 1, projection="3d")
        nlp.plot_surf_stat_map(
            (coords, faces), vertex_vals,
            hemi="left" if hemi == "lh" else "right",
            view="lateral", colorbar=True, cmap=cmap,
            title=f"{hemi} {key}", axes=ax,
        )
    fig.suptitle(f"{SUBJECT} -- {title} (native DK-68 surface)")
    fig.savefig(OUT / fname, dpi=150)
    plt.close(fig)


SUBCORT_STRUCTS = [
    "Thalamus", "Caudate", "Putamen", "Pallidum",
    "Hippocampus", "Amygdala", "Accumbens-area",
]


def panel_subcortical(etiv, vols):
    fig, axes = plt.subplots(1, 2, figsize=(12, 5.5))

    left = [vols.get(f"Left-{s}", np.nan) for s in SUBCORT_STRUCTS]
    right = [vols.get(f"Right-{s}", np.nan) for s in SUBCORT_STRUCTS]
    x = np.arange(len(SUBCORT_STRUCTS))

    ax = axes[0]
    ax.bar(x - 0.2, left, width=0.4, label="Left", color="darkorange")
    ax.bar(x + 0.2, right, width=0.4, label="Right", color="seagreen")
    ax.set_xticks(x)
    ax.set_xticklabels(SUBCORT_STRUCTS, rotation=45, ha="right", fontsize=8)
    ax.set_ylabel("Volume (mm^3)")
    ax.set_title("Raw subcortical volumes")
    ax.legend()

    # Per-mille of eTIV: divide by ICV and express per 1000, so the head-size
    # correction reads in a comparable range to the raw plot rather than as a
    # tiny fraction.
    left_icv = [1000 * v / etiv for v in left]
    right_icv = [1000 * v / etiv for v in right]
    ax = axes[1]
    ax.bar(x - 0.2, left_icv, width=0.4, label="Left", color="darkorange")
    ax.bar(x + 0.2, right_icv, width=0.4, label="Right", color="seagreen")
    ax.set_xticks(x)
    ax.set_xticklabels(SUBCORT_STRUCTS, rotation=45, ha="right", fontsize=8)
    ax.set_ylabel("Volume / eTIV (per-mille)")
    ax.set_title(f"ICV-normalised (eTIV = {etiv:,.0f} mm^3)")
    ax.legend()

    fig.suptitle(f"{SUBJECT} -- subcortical volumes, described not judged (no reference group)")
    fig.tight_layout()
    fig.savefig(OUT / "F_subcortical_summary.png", dpi=150)
    plt.close(fig)


def main():
    lh_aparc = parse_aparc_stats(FS_DIR / "stats" / "lh.aparc.stats")
    rh_aparc = parse_aparc_stats(FS_DIR / "stats" / "rh.aparc.stats")
    etiv, vols = parse_aseg_stats(FS_DIR / "stats" / "aseg.stats")

    panel_surface_metric(lh_aparc, rh_aparc, "ThickAvg", "cortical thickness (mm)",
                          "E_thickness.png", cmap="magma")
    panel_surface_metric(lh_aparc, rh_aparc, "SurfArea", "surface area (mm^2)",
                          "E_surface_area.png", cmap="cividis")
    panel_subcortical(etiv, vols)
    print(f"eTIV = {etiv:,.0f} mm^3")
    print(f"Wrote panels to {OUT}")


if __name__ == "__main__":
    main()
