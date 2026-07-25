#!/usr/bin/env python3
"""Generate the figure set used by dwi_pipeline/brain.md and brain.docx.

Renders real subject data (FreeSurfer/FastSurfer volumes and surfaces, QSIPrep
grids, QSIRecon HSVS 5TT and connectome) plus schematic panels for radiological
contrast and lesion patterns, which are drawn rather than imaged because no
lesion-positive example is shipped with the repository.

Usage:
    python3 make_brain_figures.py [--subject-dir DIR] [--out-dir DIR]
"""
from __future__ import annotations

import argparse
import os
import re
from pathlib import Path

import matplotlib

matplotlib.use("Agg")
import matplotlib.patches as mpatches
import matplotlib.pyplot as plt
import nibabel as nib
import numpy as np
from matplotlib.colors import ListedColormap, LogNorm

DPI = 150
FS_LUT_CANDIDATES = [
    Path(__file__).resolve().parents[1]
    / "containers/connectome/build_ctx_lean/freesurfer/FreeSurferColorLUT.txt",
    Path("/opt/freesurfer/FreeSurferColorLUT.txt"),
]

# Cortical GM, subcortical GM, WM and CSF label groups in the FreeSurfer aseg
# convention (see FreeSurferColorLUT.txt).
CORTEX_LABELS = (3, 42)
WM_LABELS = (2, 41, 77, 251, 252, 253, 254, 255)
CSF_LABELS = (4, 5, 14, 15, 24, 43, 44, 72)
SUBCORTICAL = {
    10: "Thalamus (L)",
    49: "Thalamus (R)",
    11: "Caudate (L)",
    50: "Caudate (R)",
    12: "Putamen (L)",
    51: "Putamen (R)",
    13: "Pallidum (L)",
    52: "Pallidum (R)",
    17: "Hippocampus (L)",
    53: "Hippocampus (R)",
    18: "Amygdala (L)",
    54: "Amygdala (R)",
    26: "Accumbens (L)",
    58: "Accumbens (R)",
    28: "Ventral DC (L)",
    60: "Ventral DC (R)",
}


# --------------------------------------------------------------------------
# helpers
# --------------------------------------------------------------------------
def load_canonical(path):
    """Load a volume and reorient to closest canonical RAS."""
    return nib.as_closest_canonical(nib.load(str(path)))


def slice_ras(data, axis, index):
    """Take a 2D slice from RAS-ordered data and orient it for display."""
    sl = np.take(data, index, axis=axis)
    # RAS axes are (R, A, S). Rotating puts S (or A) on the vertical axis.
    return np.rot90(sl)


def robust_window(vol, lo=1.0, hi=99.5):
    finite = vol[np.isfinite(vol) & (vol > 0)]
    if finite.size == 0:
        return 0.0, 1.0
    return np.percentile(finite, lo), np.percentile(finite, hi)


def show_anat(ax, data, axis, index, cmap="gray", vmin=None, vmax=None):
    img = slice_ras(data, axis, index)
    ax.imshow(img, cmap=cmap, vmin=vmin, vmax=vmax, interpolation="nearest")
    ax.set_xticks([])
    ax.set_yticks([])
    return img


def overlay(ax, mask2d, color, alpha=0.55):
    rgba = np.zeros(mask2d.shape + (4,))
    rgba[..., 0], rgba[..., 1], rgba[..., 2] = color
    rgba[..., 3] = np.where(mask2d, alpha, 0.0)
    ax.imshow(rgba, interpolation="nearest")


def read_fs_lut():
    for cand in FS_LUT_CANDIDATES:
        if cand.exists():
            lut = {}
            for line in cand.read_text(errors="ignore").splitlines():
                line = line.strip()
                if not line or line.startswith("#"):
                    continue
                parts = line.split()
                if len(parts) >= 5 and parts[0].isdigit():
                    idx = int(parts[0])
                    lut[idx] = (
                        parts[1],
                        (int(parts[2]) / 255, int(parts[3]) / 255, int(parts[4]) / 255),
                    )
            return lut
    return {}


def center_of_mass_index(mask, axis):
    idx = np.where(mask.any(axis=tuple(a for a in range(3) if a != axis)))[0]
    return int(np.median(idx)) if idx.size else mask.shape[axis] // 2


def largest_area_index(mask, axis):
    """Slice index where the mask has the greatest cross-sectional area."""
    counts = mask.sum(axis=tuple(a for a in range(3) if a != axis))
    return int(np.argmax(counts)) if counts.max() > 0 else mask.shape[axis] // 2


def to_display(pts, axis, shape):
    """Map RAS voxel coordinates to pixel coordinates of slice_ras() output.

    slice_ras takes a slice then applies np.rot90, so the two in-plane axes are
    swapped and one is flipped. Returns (x_display, y_display).
    """
    pts = np.atleast_2d(np.asarray(pts, dtype=float))
    if axis == 2:  # axial: in-plane axes are (R, A); vertical axis is A
        return pts[:, 0], (shape[1] - 1) - pts[:, 1]
    if axis == 1:  # coronal: in-plane axes are (R, S); vertical axis is S
        return pts[:, 0], (shape[2] - 1) - pts[:, 2]
    return pts[:, 1], (shape[2] - 1) - pts[:, 2]  # sagittal: (A, S)


def label_centroid(seg, labels, axis, index, tol=6):
    """Centroid of the given labels restricted to a slab around `index`."""
    m = np.isin(seg, labels)
    if not m.any():
        return None
    sl = [slice(None)] * 3
    sl[axis] = slice(max(index - tol, 0), index + tol + 1)
    sub = np.zeros_like(m)
    sub[tuple(sl)] = m[tuple(sl)]
    if not sub.any():
        return None
    return np.array(np.nonzero(sub)).mean(axis=1)


def ring_annotate(ax, anns, shape, axis, margin=40, color="#c1121f"):
    """Place labels on a ring outside the head, with arrows to real centroids.

    `anns` is a list of (centroid_voxel, text). Text slots are distributed by
    angle so labels do not collide.
    """
    if not anns:
        return
    H_pts = [to_display(c, axis, shape) for c, _ in anns]
    xs = np.array([p[0][0] for p in H_pts])
    ys = np.array([p[1][0] for p in H_pts])
    cx, cy = xs.mean(), ys.mean()
    ang = np.arctan2(ys - cy, xs - cx)
    order = np.argsort(ang)
    radius = 0.50 * max(shape) + margin
    # Distribute the sorted labels evenly around the circle, preserving order.
    slots = np.linspace(-np.pi, np.pi, len(anns) + 1)[:-1] + np.pi / max(len(anns), 1)
    for slot_i, idx in enumerate(order):
        a = slots[slot_i]
        tx, ty = cx + radius * np.cos(a), cy + radius * np.sin(a)
        # Grow the text away from the head so it never sits on the dark image,
        # where black-on-black would make it unreadable.
        ca = np.cos(a)
        ha = "left" if ca > 0.2 else ("right" if ca < -0.2 else "center")
        ax.annotate(
            anns[idx][1],
            xy=(xs[idx], ys[idx]),
            xytext=(tx, ty),
            fontsize=7.5,
            color="#111111",
            ha=ha,
            va="center",
            annotation_clip=False,
            clip_on=False,
            bbox=dict(boxstyle="round,pad=0.15", fc="white", ec="none", alpha=0.85),
            arrowprops=dict(arrowstyle="->", color=color, lw=0.9, shrinkA=1, shrinkB=1),
        )
    lim = radius + 76
    ax.set_xlim(cx - lim, cx + lim)
    ax.set_ylim(cy + lim, cy - lim)
    ax.set_frame_on(False)


def panel_label(ax, text):
    ax.set_title(text, fontsize=9, pad=4)


def finish(fig, out_path, caption=None):
    if caption:
        fig.text(0.01, 0.005, caption, fontsize=7, color="#444444", va="bottom")
    fig.savefig(out_path, dpi=DPI, bbox_inches="tight", facecolor="white")
    plt.close(fig)
    print(f"  wrote {out_path.name}")


# --------------------------------------------------------------------------
# figures
# --------------------------------------------------------------------------
def fig_normal_anatomy(paths, out):
    """Three orthogonal planes, annotated from aseg centroids rather than by hand."""
    t1 = load_canonical(paths["t1"])
    aseg = load_canonical(paths["aseg"])
    data = t1.get_fdata()
    seg = aseg.get_fdata().astype(int)
    shape = data.shape
    vmin, vmax = robust_window(data)

    # Choose slices from anatomy: the axial slice where the lateral ventricles
    # are largest, a coronal slice through the thalamus, and mid-sagittal
    # through the corpus callosum.
    lat_vent = np.isin(seg, (4, 43))
    z_ax = largest_area_index(lat_vent, 2)
    y_cor = center_of_mass_index(np.isin(seg, (10, 49)), 1)
    x_sag = center_of_mass_index(np.isin(seg, (251, 252, 253, 254, 255)), 0)

    planes = [
        (
            2,
            z_ax,
            "Axial — level of the lateral ventricles",
            [
                ((4, 43), "lateral ventricle"),
                ((251, 252, 253, 254, 255), "corpus callosum"),
                ((2, 41), "cerebral WM"),
                ((3, 42), "cortical GM"),
                ((10, 49), "thalamus"),
                ((11, 50), "caudate"),
                ((12, 51), "putamen"),
            ],
        ),
        (
            1,
            y_cor,
            "Coronal — level of the thalamus",
            [
                ((10, 49), "thalamus"),
                ((2, 41), "cerebral WM"),
                ((3, 42), "cortical GM"),
                ((17, 53), "hippocampus"),
                ((16,), "brainstem"),
                ((8, 47), "cerebellar cortex"),
                ((4, 43), "lateral ventricle"),
            ],
        ),
        (
            0,
            x_sag,
            "Mid-sagittal — corpus callosum and posterior fossa",
            [
                ((251, 252, 253, 254, 255), "corpus callosum"),
                ((16,), "brainstem"),
                ((8, 47), "cerebellum"),
                ((10, 49), "thalamus"),
                ((14,), "3rd ventricle"),
                ((15,), "4th ventricle"),
            ],
        ),
    ]

    fig, axes = plt.subplots(1, 3, figsize=(16.5, 6.6))
    fig.subplots_adjust(wspace=0.02)
    for ax, (axis, index, name, wanted) in zip(axes, planes):
        show_anat(ax, data, axis, index, vmin=vmin, vmax=vmax)
        anns = []
        for labels, text in wanted:
            c = label_centroid(seg, labels, axis, index)
            if c is not None:
                anns.append((c, text))
        ring_annotate(ax, anns, shape, axis)
        panel_label(ax, name)

    fig.suptitle(
        "Figure 1 — Normal T1-weighted anatomy in three orthogonal planes (subject TBI011204)",
        fontsize=11,
    )
    finish(
        fig,
        out / "fig01_normal_anatomy.png",
        "Source: FreeSurfer/FastSurfer T1.mgz, conformed 1 mm isotropic, reoriented to RAS. Arrow "
        "targets are centroids of the corresponding aseg.mgz labels within the displayed slab, so "
        "labels track this subject's actual anatomy.",
    )


def fig_tissue_classes(paths, out):
    t1 = load_canonical(paths["t1"])
    aseg = load_canonical(paths["aseg"])
    data = t1.get_fdata()
    seg = aseg.get_fdata().astype(int)
    vmin, vmax = robust_window(data)

    gm = np.isin(seg, CORTEX_LABELS)
    wm = np.isin(seg, WM_LABELS)
    csf = np.isin(seg, CSF_LABELS)
    sub = np.isin(seg, list(SUBCORTICAL))

    z = center_of_mass_index(wm, 2) + 6
    fig = plt.figure(figsize=(12.5, 6.4))
    gs = fig.add_gridspec(2, 4, height_ratios=[1.25, 1.0], hspace=0.28, wspace=0.12)

    combos = [
        ("T1w (no overlay)", None, None),
        ("Cortical GM", gm, (0.16, 0.78, 0.42)),
        ("White matter", wm, (0.99, 0.85, 0.20)),
        ("CSF", csf, (0.25, 0.55, 0.98)),
    ]
    for col, (title, mask, color) in enumerate(combos):
        ax = fig.add_subplot(gs[0, col])
        show_anat(ax, data, 2, z, vmin=vmin, vmax=vmax)
        if mask is not None:
            overlay(ax, slice_ras(mask, 2, z), color)
        panel_label(ax, title)

    # Intensity histograms per tissue class.
    ax_h = fig.add_subplot(gs[1, :2])
    for mask, color, label in [
        (csf, "#3f8efc", "CSF"),
        (gm, "#2bc76b", "Cortical GM"),
        (wm, "#fcd913", "WM"),
    ]:
        vals = data[mask]
        vals = vals[(vals > 0) & (vals < 160)]
        if vals.size:
            ax_h.hist(
                vals,
                bins=80,
                density=True,
                histtype="stepfilled",
                alpha=0.55,
                color=color,
                label=f"{label} (n={vals.size/1000:.0f}k vox)",
            )
    ax_h.set_xlabel("T1 intensity (FreeSurfer normalised units)", fontsize=8)
    ax_h.set_ylabel("density", fontsize=8)
    ax_h.set_title(
        "Tissue intensity distributions — the basis of intensity-driven segmentation (e.g. FSL FAST)",
        fontsize=9,
    )
    ax_h.legend(fontsize=7)
    ax_h.tick_params(labelsize=7)

    # Volumes bar chart.
    ax_v = fig.add_subplot(gs[1, 2:])
    vox_mm3 = float(np.prod(t1.header.get_zooms()[:3]))
    vols = {
        "Cortical GM": gm.sum() * vox_mm3 / 1000,
        "WM": wm.sum() * vox_mm3 / 1000,
        "Subcortical GM": sub.sum() * vox_mm3 / 1000,
        "CSF/ventricles": csf.sum() * vox_mm3 / 1000,
    }
    colors = ["#2bc76b", "#fcd913", "#e76f51", "#3f8efc"]
    ax_v.bar(list(vols), list(vols.values()), color=colors)
    for i, v in enumerate(vols.values()):
        ax_v.text(i, v, f"{v:.0f}", ha="center", va="bottom", fontsize=7)
    ax_v.set_ylabel("volume (cm³)", fontsize=8)
    ax_v.set_title("Segmented tissue volumes for this subject", fontsize=9)
    ax_v.tick_params(labelsize=7)
    plt.setp(ax_v.get_xticklabels(), rotation=15, ha="right")

    fig.suptitle(
        "Figure 2 — The three primary tissue classes: appearance, intensity statistics, and volumes",
        fontsize=10,
    )
    finish(
        fig,
        out / "fig02_tissue_classes.png",
        "Masks derived from FreeSurfer aseg.mgz label groups. Volumes are voxel counts × voxel volume "
        "and differ slightly from surface-based aseg.stats values.",
    )


def fig_subcortical(paths, out):
    t1 = load_canonical(paths["t1"])
    aseg = load_canonical(paths["aseg"])
    data = t1.get_fdata()
    seg = aseg.get_fdata().astype(int)
    vmin, vmax = robust_window(data)
    lut = read_fs_lut()

    thal = np.isin(seg, (10, 49))
    z = center_of_mass_index(thal, 2)
    y = center_of_mass_index(thal, 1)

    fig, axes = plt.subplots(1, 2, figsize=(10.5, 5.0))
    for ax, (axis, index, name) in zip(
        axes, [(2, z, "Axial through thalamus"), (1, y, "Coronal through basal ganglia")]
    ):
        show_anat(ax, data, axis, index, vmin=vmin, vmax=vmax)
        for lab in SUBCORTICAL:
            m = slice_ras(seg == lab, axis, index)
            if m.any():
                color = lut.get(lab, (None, (1, 0, 0)))[1]
                overlay(ax, m, color, alpha=0.75)
        panel_label(ax, name)

    handles = []
    seen = set()
    for lab, name in SUBCORTICAL.items():
        base = name.split(" (")[0]
        if base in seen:
            continue
        seen.add(base)
        color = lut.get(lab, (None, (1, 0, 0)))[1]
        handles.append(mpatches.Patch(color=color, label=base))
    fig.legend(
        handles=handles,
        loc="lower center",
        ncol=4,
        fontsize=7.5,
        frameon=False,
        bbox_to_anchor=(0.5, -0.06),
    )
    fig.suptitle(
        "Figure 3 — Subcortical gray matter nuclei (FreeSurfer aseg), the deep GM class of the 5TT image",
        fontsize=10,
    )
    finish(
        fig,
        out / "fig03_subcortical_gm.png",
        "Colours follow FreeSurferColorLUT.txt. These structures form 5TT volume 1 and act as valid "
        "streamline termination targets under ACT.",
    )


def fig_parcellation(paths, out):
    t1 = load_canonical(paths["t1"])
    ap = load_canonical(paths["aparc"])
    data = t1.get_fdata()
    seg = ap.get_fdata().astype(int)
    vmin, vmax = robust_window(data)
    lut = read_fs_lut()

    labels = np.unique(seg)
    labels = labels[labels > 0]
    maxlab = int(labels.max())
    cmap_arr = np.zeros((maxlab + 1, 4))
    rng = np.random.default_rng(0)
    for lab in labels:
        rgb = lut.get(int(lab), (None, tuple(rng.random(3))))[1]
        cmap_arr[lab] = (*rgb, 1.0)
    cmap = ListedColormap(cmap_arr)

    cx, cy, cz = (s // 2 for s in data.shape)
    fig, axes = plt.subplots(1, 3, figsize=(11.5, 4.3))
    for ax, (axis, index, name) in zip(
        axes, [(2, cz + 8, "Axial"), (1, cy, "Coronal"), (0, cx - 25, "Sagittal (lateral)")]
    ):
        show_anat(ax, data, axis, index, vmin=vmin, vmax=vmax)
        s2 = slice_ras(seg, axis, index)
        masked = np.ma.masked_where(s2 == 0, s2)
        ax.imshow(masked, cmap=cmap, vmin=0, vmax=maxlab, alpha=0.7, interpolation="nearest")
        panel_label(ax, name)

    n_ctx = int(((labels >= 1000) & (labels < 3000)).sum())
    fig.suptitle(
        f"Figure 4 — Cortical + subcortical parcellation (aparc+aseg): {len(labels)} labels, "
        f"{n_ctx} cortical parcels. These are the connectome nodes.",
        fontsize=10,
    )
    finish(
        fig,
        out / "fig04_parcellation.png",
        "FastSurfer DKT parcellation mapped to aparc+aseg.mgz. Step 4 converts these to the 84-node "
        "Desikan-Killiany index set via MRtrix labelconvert and fs_default.txt.",
    )


def fig_surfaces(paths, out):
    """White and pial surface contours on T1 — the geometric basis of HSVS."""
    t1_img = nib.load(str(paths["t1"]))
    t1_can = nib.as_closest_canonical(t1_img)
    data = t1_can.get_fdata()
    shape = data.shape
    vmin, vmax = robust_window(data)

    aseg = load_canonical(paths["aseg"])
    seg = aseg.get_fdata().astype(int)
    cortex = np.isin(seg, CORTEX_LABELS)

    # tkrRAS -> world RAS -> canonical voxel coordinates.
    tkr2can = np.linalg.inv(t1_can.affine) @ t1_img.affine @ np.linalg.inv(
        t1_img.header.get_vox2ras_tkr()
    )
    surfs = {}
    for hemi in ("lh", "rh"):
        for kind in ("white", "pial"):
            p = paths["surf"] / f"{hemi}.{kind}"
            if p.exists():
                coords, _ = nib.freesurfer.read_geometry(str(p))
                surfs[f"{hemi}.{kind}"] = nib.affines.apply_affine(tkr2can, coords)

    # A supraventricular axial slice shows the most cortical ribbon.
    ctx_z = np.where(cortex.any(axis=(0, 1)))[0]
    z = int(np.percentile(ctx_z, 72)) if ctx_z.size else shape[2] // 2

    fig, axes = plt.subplots(1, 2, figsize=(12.5, 6.0))
    for ax, zoom in zip(axes, [False, True]):
        show_anat(ax, data, 2, z, vmin=vmin, vmax=vmax)
        for key, vox in surfs.items():
            sel = np.abs(vox[:, 2] - z) < 0.5
            if not sel.any():
                continue
            xs, ys = to_display(vox[sel], 2, shape)
            color = "#ff3b30" if "white" in key else "#39ff6a"
            ax.scatter(xs, ys, s=1.1, c=color, linewidths=0, alpha=0.9)

        if zoom:
            # Centre the zoom where cortex is densest in this slice, so the
            # window is guaranteed to contain ribbon rather than skull or air.
            from scipy.ndimage import uniform_filter

            half = 34
            dens = uniform_filter(cortex[:, :, z].astype(float), size=2 * half)
            iy, ix = np.unravel_index(np.argmax(dens), dens.shape)
            px, py = to_display(np.array([iy, ix, z]), 2, shape)
            ax.set_xlim(px[0] - half, px[0] + half)
            ax.set_ylim(py[0] + half, py[0] - half)
            panel_label(
                ax,
                "Zoom (~68 mm field of view): the GM ribbon lies between the surfaces,\n"
                "and sulcal CSF is excluded even where it is thinner than a voxel",
            )
        else:
            ax.legend(
                handles=[
                    mpatches.Patch(color="#ff3b30", label="white surface — WM/GM boundary"),
                    mpatches.Patch(color="#39ff6a", label="pial surface — GM/CSF boundary"),
                ],
                loc="lower left",
                fontsize=7,
                framealpha=0.8,
            )
            panel_label(ax, "Supraventricular axial slice with both surfaces overlaid")

    fig.suptitle(
        "Figure 5 — Cortical surfaces define the GM ribbon with sub-voxel precision (why HSVS needs surfaces)",
        fontsize=10.5,
    )
    finish(
        fig,
        out / "fig05_cortical_surfaces.png",
        "Vertices within 0.5 mm of the displayed plane, mapped tkrRAS -> world RAS -> canonical voxel "
        "coordinates. FastSurfer --seg_only does not write these files, so 5ttgen hsvs cannot run.",
    )


def fig_5tt(paths, out):
    img = nib.load(str(paths["hsvs"]))
    data = img.get_fdata()
    names = [
        "0 — Cortical GM",
        "1 — Subcortical GM",
        "2 — White matter",
        "3 — CSF",
        "4 — Pathological",
    ]
    wm_idx = int(np.argmax([np.nansum(data[..., k]) for k in (0, 1, 2, 3, 4)]))
    vol = np.nan_to_num(data[..., wm_idx])
    z = center_of_mass_index(vol > 0.5, 2)

    fig, axes = plt.subplots(1, 6, figsize=(16, 3.4))
    for k in range(5):
        ax = axes[k]
        sl = np.rot90(np.nan_to_num(data[:, :, z, k]))
        ax.imshow(sl, cmap="magma", vmin=0, vmax=1, interpolation="nearest")
        ax.set_xticks([])
        ax.set_yticks([])
        frac = np.nansum(data[..., k]) / max(np.nansum(data), 1)
        panel_label(ax, f"{names[k]}\n{frac*100:.1f}% of total PV")

    ax = axes[5]
    rgb = np.zeros(np.rot90(data[:, :, z, 0]).shape + (3,))
    rgb[..., 1] = np.rot90(np.nan_to_num(data[:, :, z, 0]))  # cortical GM -> green
    rgb[..., 0] = np.rot90(np.nan_to_num(data[:, :, z, 1]))  # subcortical -> red
    rgb[..., 2] = np.rot90(np.nan_to_num(data[:, :, z, 3]))  # CSF -> blue
    wmv = np.rot90(np.nan_to_num(data[:, :, z, 2]))
    rgb = np.clip(rgb + wmv[..., None] * 0.75, 0, 1)
    ax.imshow(rgb, interpolation="nearest")
    ax.set_xticks([])
    ax.set_yticks([])
    panel_label(ax, "Composite\n(GM=green, subGM=red,\nCSF=blue, WM=white)")

    fig.suptitle(
        "Figure 6 — The real HSVS 5TT image driving ACT for this subject (5 partial-volume tissue maps)",
        fontsize=10,
    )
    finish(
        fig,
        out / "fig06_5tt_hsvs.png",
        "Source: QSIRecon sub-TBI011204_space-ACPC_seg-hsvs_probseg.nii.gz "
        f"(shape {data.shape}). Values are partial volume fractions in [0, 1].",
    )


def fig_spaces(paths, out):
    fs = nib.load(str(paths["t1"]))
    pre = nib.load(str(paths["preproc_t1w"]))
    dwi = nib.load(str(paths["dwiref"]))

    fig, axes = plt.subplots(1, 3, figsize=(12, 4.6))
    for ax, (img, title) in zip(
        axes,
        [
            (fs, "FreeSurfer conformed\nT1.mgz"),
            (pre, "QSIPrep anatomical\ndesc-preproc_T1w"),
            (dwi, "Tractography grid\nspace-T1w_dwiref"),
        ],
    ):
        can = nib.as_closest_canonical(img)
        d = can.get_fdata()
        if d.ndim == 4:
            d = d[..., 0]
        vmin, vmax = robust_window(d)
        show_anat(ax, d, 2, d.shape[2] // 2, vmin=vmin, vmax=vmax)
        zooms = np.round(img.header.get_zooms()[:3], 2)
        panel_label(
            ax,
            f"{title}\nshape {tuple(int(s) for s in img.shape[:3])}   "
            f"{zooms[0]}×{zooms[1]}×{zooms[2]} mm\naxcodes {''.join(nib.aff2axcodes(img.affine))}",
        )

    fig.suptitle(
        "Figure 7 — Three coordinate grids the pipeline must reconcile before counting connections",
        fontsize=10,
    )
    finish(
        fig,
        out / "fig07_coordinate_spaces.png",
        "Labels are read directly from each NIfTI/MGZ header. Step 4 of the pipeline resamples "
        "parcellation labels from the left grid onto the right grid.",
    )


def fig_connectome(paths, out):
    import scipy.io as sio

    m = sio.loadmat(str(paths["conn"]))
    key_sift = next(
        (k for k in m if k.endswith("sift_invnodevol_radius2_count_connectivity")), None
    )
    key_count = next((k for k in m if k.endswith("radius2_count_connectivity")), None)
    key = key_sift or key_count
    C = np.array(m[key], dtype=float)
    C = np.nan_to_num(C)

    fig = plt.figure(figsize=(14.5, 5.2))
    gs = fig.add_gridspec(1, 3, width_ratios=[1.2, 1.1, 0.95], wspace=0.55)

    ax = fig.add_subplot(gs[0, 0])
    pos = C[C > 0]
    im = ax.imshow(
        np.where(C > 0, C, np.nan),
        cmap="inferno",
        norm=LogNorm(vmin=max(pos.min(), 1e-6), vmax=pos.max()),
        interpolation="nearest",
    )
    ax.set_title(f"Connectivity matrix ({C.shape[0]}×{C.shape[1]})\nlog colour scale", fontsize=9)
    ax.set_xlabel("node", fontsize=8)
    ax.set_ylabel("node", fontsize=8)
    ax.tick_params(labelsize=7)
    cb = fig.colorbar(im, ax=ax, fraction=0.046, pad=0.03)
    cb.set_label("edge weight", fontsize=8)
    cb.ax.tick_params(labelsize=6.5)

    ax2 = fig.add_subplot(gs[0, 1])
    strength = C.sum(axis=1)
    ax2.hist(strength[strength > 0], bins=30, color="#4361ee", alpha=0.85)
    ax2.set_xlabel("nodal strength (sum of edge weights)", fontsize=8)
    ax2.set_ylabel("number of nodes", fontsize=8)
    ax2.set_title("Nodal strength distribution\n(hubs are the right tail)", fontsize=9)
    ax2.tick_params(labelsize=7)

    ax3 = fig.add_subplot(gs[0, 2])
    n = C.shape[0]
    density = (C > 0).sum() / (n * (n - 1))
    stats = [
        ("Nodes", f"{n}"),
        ("Edges (non-zero)", f"{int((C > 0).sum() // 2):,}"),
        ("Density", f"{density:.3f}"),
        ("Max edge weight", f"{C.max():.3g}"),
        ("Mean nodal strength", f"{strength.mean():.3g}"),
        ("Matrix symmetric", f"{np.allclose(C, C.T)}"),
    ]
    ax3.axis("off")
    ax3.set_title("Graph summary", fontsize=9)
    for i, (k, v) in enumerate(stats):
        ax3.text(0.02, 0.88 - i * 0.14, k, fontsize=8.5, weight="bold")
        ax3.text(0.62, 0.88 - i * 0.14, v, fontsize=8.5, family="monospace")

    fig.suptitle(
        "Figure 8 — Real structural connectome for this subject (QSIRecon SS3T + ACT-HSVS, 4S156 atlas)",
        fontsize=10,
    )
    finish(
        fig,
        out / "fig08_connectome.png",
        f"Source: connectivity.mat, field '{key}'. SIFT2-weighted and inverse-node-volume scaled "
        "streamline counts.",
    )


def fig_contrast_schematic(out):
    """Schematic radiological contrast table — drawn, not imaged."""
    tissues = [
        "CSF",
        "Cortical GM",
        "White matter",
        "Fat",
        "Acute blood",
        "Chronic blood\n(haemosiderin)",
        "Vasogenic oedema",
        "Acute infarct\n(cytotoxic)",
        "Demyelination\n(MS plaque)",
    ]
    seqs = ["T1w", "T2w", "FLAIR", "DWI (b>0)", "ADC map", "SWI/GRE", "T1w + Gd"]
    # 0 = very dark ... 4 = very bright; np.nan = variable / not applicable
    M = np.array(
        [
            [0, 4, 0, 0, 4, 2, 0],       # CSF
            [2, 2, 2, 2, 2, 2, 2],       # cortical GM
            [3, 1, 1, 1, 2, 2, 3],       # WM
            [4, 3, 1, 1, 2, 2, 4],       # fat (with suppression on FLAIR)
            [2, 1, 1, 2, 1, 0, 2],       # acute blood
            [1, 0, 0, 1, 1, 0, 1],       # haemosiderin
            [1, 4, 4, 2, 4, 2, 1],       # vasogenic oedema
            [1, 3, 3, 4, 0, 2, 1],       # acute infarct
            [1, 4, 4, 2, 3, 2, np.nan],  # MS plaque (enhances if active)
        ],
        dtype=float,
    )
    fig, ax = plt.subplots(figsize=(11, 5.6))
    cmap = plt.get_cmap("gray")
    cmap = cmap.with_extremes(bad="#8d3b72")
    im = ax.imshow(M, cmap=cmap, vmin=-0.4, vmax=4.4, interpolation="nearest")
    ax.set_xticks(range(len(seqs)), seqs, fontsize=8.5)
    ax.set_yticks(range(len(tissues)), tissues, fontsize=8.5)
    words = {0: "very\nlow", 1: "low", 2: "iso", 3: "high", 4: "very\nhigh"}
    for i in range(M.shape[0]):
        for j in range(M.shape[1]):
            v = M[i, j]
            if np.isnan(v):
                ax.text(j, i, "variable", ha="center", va="center", fontsize=6.5, color="white")
            else:
                ax.text(
                    j,
                    i,
                    words[int(v)],
                    ha="center",
                    va="center",
                    fontsize=6.5,
                    color="black" if v >= 2.5 else "white",
                )
    ax.set_xticks(np.arange(-0.5, len(seqs), 1), minor=True)
    ax.set_yticks(np.arange(-0.5, len(tissues), 1), minor=True)
    ax.grid(which="minor", color="#5a5a5a", linewidth=0.6)
    ax.tick_params(which="minor", length=0)
    ax.set_title(
        "Figure 9 — Signal intensity of normal tissue and pathology across common MRI contrasts (schematic)",
        fontsize=10,
    )
    finish(
        fig,
        out / "fig09_mri_contrast_table.png",
        "Cell shading encodes expected relative signal, not measured values. Blood signal evolves with "
        "haemoglobin breakdown stage; see the text for the full time course.",
    )


def fig_lesion_schematic(out):
    fig, axes = plt.subplots(1, 3, figsize=(13, 4.6))

    def brain_outline(ax):
        ax.add_patch(mpatches.Ellipse((0, 0), 1.75, 2.15, fc="#d9d9d9", ec="#5a5a5a", lw=1.3))
        ax.add_patch(mpatches.Ellipse((0, 0), 1.45, 1.85, fc="#efefef", ec="#8a8a8a", lw=0.9))
        for sign in (-1, 1):
            ax.add_patch(
                mpatches.Ellipse((sign * 0.22, 0.18), 0.2, 0.55, fc="#3f8efc", ec="none", alpha=0.75)
            )
        ax.plot([0, 0], [-1.0, 1.0], color="#8a8a8a", lw=0.8, ls="--")
        ax.set_xlim(-1.15, 1.15)
        ax.set_ylim(-1.35, 1.35)
        ax.set_aspect("equal")
        ax.axis("off")

    # Panel A: TBI focal lesions.
    ax = axes[0]
    brain_outline(ax)
    items = [
        (0.0, 0.95, 0.18, 0.10, "#c1121f", "coup contusion\n(impact site)"),
        (0.0, -0.85, 0.20, 0.11, "#e5383b", "contrecoup\ncontusion"),
        (-0.62, 0.35, 0.16, 0.30, "#780000", "extra-axial\nhaemorrhage"),
        (0.45, -0.35, 0.14, 0.09, "#ff8fa3", "petechial\nhaemorrhage"),
    ]
    for x, y, w, h, c, label in items:
        ax.add_patch(mpatches.Ellipse((x, y), w, h, fc=c, ec="none", alpha=0.9))
    ax.annotate(
        "coup",
        xy=(0.0, 0.95),
        xytext=(0.55, 1.2),
        fontsize=7,
        arrowprops=dict(arrowstyle="->", lw=0.8),
    )
    ax.annotate(
        "contrecoup",
        xy=(0.0, -0.85),
        xytext=(0.5, -1.25),
        fontsize=7,
        arrowprops=dict(arrowstyle="->", lw=0.8),
    )
    ax.annotate(
        "extra-axial\nblood",
        xy=(-0.62, 0.35),
        xytext=(-1.1, 0.95),
        fontsize=7,
        arrowprops=dict(arrowstyle="->", lw=0.8),
    )
    ax.set_title("A. Focal traumatic lesions", fontsize=9.5)

    # Panel B: diffuse axonal injury distribution.
    ax = axes[1]
    brain_outline(ax)
    rng = np.random.default_rng(3)
    # Grade I: lobar GM/WM junction; II: corpus callosum; III: brainstem.
    for _ in range(40):
        th = rng.uniform(0, 2 * np.pi)
        r = rng.uniform(0.62, 0.76)
        ax.plot(r * np.cos(th) * 0.95, r * np.sin(th) * 1.15, "o", ms=3, color="#ffb703")
    for _ in range(14):
        ax.plot(rng.uniform(-0.3, 0.3), rng.uniform(0.05, 0.35), "o", ms=3.4, color="#fb8500")
    for _ in range(6):
        ax.plot(rng.uniform(-0.1, 0.1), rng.uniform(-0.85, -0.6), "o", ms=3.6, color="#d00000")
    ax.legend(
        handles=[
            mpatches.Patch(color="#ffb703", label="Grade I: GM/WM junction"),
            mpatches.Patch(color="#fb8500", label="Grade II: corpus callosum"),
            mpatches.Patch(color="#d00000", label="Grade III: brainstem"),
        ],
        fontsize=6.5,
        loc="lower center",
        frameon=False,
        bbox_to_anchor=(0.5, -0.16),
    )
    ax.set_title("B. Diffuse axonal injury (Adams grades)", fontsize=9.5)

    # Panel C: mass effect and herniation.
    ax = axes[2]
    ax.add_patch(mpatches.Ellipse((0, 0), 1.75, 2.15, fc="#d9d9d9", ec="#5a5a5a", lw=1.3))
    ax.add_patch(mpatches.Ellipse((-0.45, 0.25), 0.5, 0.62, fc="#e5383b", ec="none", alpha=0.55))
    ax.add_patch(mpatches.Ellipse((-0.45, 0.25), 0.28, 0.34, fc="#780000", ec="none", alpha=0.95))
    ax.add_patch(mpatches.Ellipse((0.30, 0.18), 0.16, 0.45, fc="#3f8efc", ec="none", alpha=0.8))
    ax.add_patch(mpatches.Ellipse((-0.12, 0.18), 0.08, 0.20, fc="#3f8efc", ec="none", alpha=0.35))
    ax.plot([0.12, 0.12], [-1.0, 1.0], color="#8a8a8a", lw=0.9, ls="--")
    ax.annotate(
        "midline shift",
        xy=(0.12, 0.85),
        xytext=(0.45, 1.2),
        fontsize=7,
        arrowprops=dict(arrowstyle="->", lw=0.8),
    )
    ax.annotate(
        "vasogenic\noedema",
        xy=(-0.62, 0.55),
        xytext=(-1.15, 1.0),
        fontsize=7,
        arrowprops=dict(arrowstyle="->", lw=0.8),
    )
    ax.annotate(
        "compressed\nventricle",
        xy=(-0.12, 0.18),
        xytext=(-1.15, -0.55),
        fontsize=7,
        arrowprops=dict(arrowstyle="->", lw=0.8),
    )
    ax.annotate(
        "dilated\ncontralateral\nventricle",
        xy=(0.30, 0.18),
        xytext=(0.55, -0.75),
        fontsize=7,
        arrowprops=dict(arrowstyle="->", lw=0.8),
    )
    ax.set_xlim(-1.15, 1.15)
    ax.set_ylim(-1.35, 1.35)
    ax.set_aspect("equal")
    ax.axis("off")
    ax.set_title("C. Mass effect, oedema, midline shift", fontsize=9.5)

    fig.suptitle(
        "Figure 10 — Lesion patterns that break automated pipelines (schematic, axial view)",
        fontsize=10,
    )
    finish(
        fig,
        out / "fig10_lesion_patterns.png",
        "Schematic drawings, not patient images. Each pattern maps to a specific pipeline failure mode "
        "described in the accompanying text.",
    )


def fig_volumetrics(paths, out):
    """Real volumetrics parsed from aseg.stats, plus ventricle rendering."""
    stats_path = paths["stats"] / "aseg.stats"
    measures = {}
    rows = []
    if stats_path.exists():
        for line in stats_path.read_text(errors="ignore").splitlines():
            if line.startswith("# Measure"):
                parts = [p.strip() for p in line.replace("# Measure", "").split(",")]
                if len(parts) >= 4:
                    try:
                        val = float(parts[3])
                    except ValueError:
                        continue
                    # aseg.stats gives both a short name and a *Vol alias; index both.
                    measures[parts[0]] = val
                    measures[parts[1]] = val
            elif not line.startswith("#") and line.strip():
                f = line.split()
                if len(f) >= 5:
                    try:
                        rows.append((f[4], float(f[3])))
                    except ValueError:
                        pass

    t1 = load_canonical(paths["t1"])
    aseg = load_canonical(paths["aseg"])
    data = t1.get_fdata()
    seg = aseg.get_fdata().astype(int)
    vmin, vmax = robust_window(data)
    vent = np.isin(seg, (4, 43, 5, 44, 14, 15))
    z = largest_area_index(np.isin(seg, (4, 43)), 2)

    fig = plt.figure(figsize=(13.5, 5.2))
    gs = fig.add_gridspec(1, 3, width_ratios=[0.9, 1.25, 1.15], wspace=0.42)

    ax = fig.add_subplot(gs[0, 0])
    show_anat(ax, data, 2, z, vmin=vmin, vmax=vmax)
    overlay(ax, slice_ras(vent, 2, z), (0.25, 0.55, 0.98), alpha=0.7)
    vent_cm3 = measures.get("VentricleChoroidVol", vent.sum()) / 1000.0
    panel_label(
        ax,
        f"Ventricular system (blue), {vent_cm3:.1f} cm³\nenlarges with atrophy / hydrocephalus",
    )

    ax2 = fig.add_subplot(gs[0, 1])
    keys = [
        ("CortexVol", "Cortical GM"),
        ("CerebralWhiteMatterVol", "Cerebral WM"),
        ("SubCortGrayVol", "Subcortical GM"),
        ("VentricleChoroidVol", "Ventricles"),
        ("BrainSegVol", "Total brain seg"),
        ("eTIV", "eTIV"),
    ]
    names, vals = [], []
    for k, label in keys:
        if k in measures:
            names.append(label)
            vals.append(measures[k] / 1000.0)
    ax2.barh(names[::-1], vals[::-1], color="#457b9d")
    for i, v in enumerate(vals[::-1]):
        ax2.text(v, i, f" {v:,.0f}", va="center", fontsize=7.5)
    ax2.set_xlabel("volume (cm³)", fontsize=8)
    ax2.set_title("Global measures from aseg.stats", fontsize=9)
    ax2.tick_params(labelsize=7.5)
    ax2.set_xlim(0, max(vals) * 1.22 if vals else 1)
    qc = []
    if "BrainSegVol-to-eTIV" in measures:
        qc.append(f"BrainSegVol/eTIV = {measures['BrainSegVol-to-eTIV']:.3f}")
    if "SurfaceHoles" in measures:
        qc.append(f"surface holes = {int(measures['SurfaceHoles'])}")
    if qc:
        ax2.text(
            0.98,
            0.03,
            "QC:  " + "   |   ".join(qc),
            transform=ax2.transAxes,
            fontsize=7,
            ha="right",
            va="bottom",
            color="#6a040f",
        )

    ax3 = fig.add_subplot(gs[0, 2])
    interesting = [
        "Left-Hippocampus",
        "Right-Hippocampus",
        "Left-Amygdala",
        "Right-Amygdala",
        "Left-Thalamus",
        "Right-Thalamus",
        "Left-Caudate",
        "Right-Caudate",
        "Left-Putamen",
        "Right-Putamen",
    ]
    d = dict(rows)
    lab, val = [], []
    for name in interesting:
        for cand in (name, name + "-Proper"):
            if cand in d:
                lab.append(name.replace("Left-", "L ").replace("Right-", "R "))
                val.append(d[cand] / 1000.0)
                break
    colors = ["#e76f51" if l.startswith("L") else "#f4a261" for l in lab]
    ax3.barh(lab[::-1], val[::-1], color=colors[::-1])
    for i, v in enumerate(val[::-1]):
        ax3.text(v, i, f" {v:.2f}", va="center", fontsize=7)
    ax3.set_xlabel("volume (cm³)", fontsize=8)
    ax3.set_title("Per-structure volumes\n(L/R asymmetry is a clinical cue)", fontsize=9)
    ax3.tick_params(labelsize=7)

    fig.suptitle(
        "Figure 11 — Quantitative morphometry: the numbers a research engineer reports and QCs",
        fontsize=10,
    )
    finish(
        fig,
        out / "fig11_volumetrics.png",
        f"Source: {stats_path.name} produced by FastSurfer 2.4.2 for subject TBI011204. "
        "eTIV is used to normalise volumes across head sizes.",
    )


def fig_anatomy_pipeline_map(out):
    fig, ax = plt.subplots(figsize=(13, 6.6))
    ax.set_xlim(0, 12)
    ax.set_ylim(0, 8)
    ax.axis("off")

    def box(x, y, w, h, text, fc, fontsize=8):
        ax.add_patch(
            mpatches.FancyBboxPatch(
                (x, y),
                w,
                h,
                boxstyle="round,pad=0.06",
                fc=fc,
                ec="#333333",
                lw=1.0,
            )
        )
        ax.text(x + w / 2, y + h / 2, text, ha="center", va="center", fontsize=fontsize)

    def arrow(x1, y1, x2, y2, color="#333333", style="->"):
        ax.annotate(
            "",
            xy=(x2, y2),
            xytext=(x1, y1),
            arrowprops=dict(arrowstyle=style, color=color, lw=1.4),
        )

    ax.text(6, 7.6, "Anatomy / physiology → pipeline component → failure mode", fontsize=11, ha="center")

    anat = [
        (0.2, 6.2, "Cortical GM ribbon\n(folded 2-D sheet)", "#c7f9cc"),
        (0.2, 4.9, "White matter\n(myelinated axons)", "#fff3b0"),
        (0.2, 3.6, "Subcortical GM\n(deep nuclei)", "#ffd6c0"),
        (0.2, 2.3, "CSF spaces\n(ventricles, sulci)", "#cfe8ff"),
        (0.2, 1.0, "Pathology\n(lesion, oedema, blood)", "#f6c5d0"),
    ]
    for x, y, t, c in anat:
        box(x, y, 2.6, 1.0, t, c)

    comp = [
        (4.0, 6.2, "FreeSurfer/FastSurfer\nsurfaces + aparc", "#e8e8e8"),
        (4.0, 4.9, "SS3T CSD → FOD\ntckgen (iFOD2)", "#e8e8e8"),
        (4.0, 3.6, "aseg → 5TT vol 1\nACT termination", "#e8e8e8"),
        (4.0, 2.3, "5TT vol 3 (CSF)\nACT rejection", "#e8e8e8"),
        (4.0, 1.0, "5TT vol 4\n(pathological tissue)", "#e8e8e8"),
    ]
    for x, y, t, c in comp:
        box(x, y, 3.0, 1.0, t, c)

    fail = [
        (8.0, 6.2, "Surface defect → GM ribbon\nwrong → false streamline\nterminations", "#f1f1f1"),
        (8.0, 4.9, "Low SNR / crossing fibres\n→ spurious FOD peaks\n→ false-positive edges", "#f1f1f1"),
        (8.0, 3.6, "Nucleus mis-segmented\n→ node volume error\n→ biased edge weights", "#f1f1f1"),
        (8.0, 2.3, "Sulcal CSF labelled GM\n→ streamlines jump gyri\n→ inflated local edges", "#f1f1f1"),
        (8.0, 1.0, "Lesion read as WM\n→ tracking through\nnon-viable tissue", "#f1f1f1"),
    ]
    for x, y, t, c in fail:
        box(x, y, 3.8, 1.0, t, c, fontsize=7.5)

    for (_, y, _, _) in anat:
        arrow(2.85, y + 0.5, 3.95, y + 0.5)
        arrow(7.05, y + 0.5, 7.95, y + 0.5, color="#a4161a")

    ax.text(1.5, 7.05, "Biology", fontsize=9.5, ha="center", weight="bold")
    ax.text(5.5, 7.05, "Pipeline component", fontsize=9.5, ha="center", weight="bold")
    ax.text(9.9, 7.05, "What goes wrong", fontsize=9.5, ha="center", weight="bold", color="#a4161a")

    fig.suptitle(
        "Figure 12 — Mapping neuroanatomy onto pipeline components and their characteristic failures",
        fontsize=10,
    )
    finish(fig, out / "fig12_anatomy_pipeline_map.png")


# --------------------------------------------------------------------------
def main():
    ap = argparse.ArgumentParser()
    default_results = Path(
        os.environ.get(
            "BRAIN_FIG_RESULTS",
            "/mnt/nfs/home/urmc-sh.rochester.edu/pndagiji/Documents/CIDUR_BIDS/dwi_test2_fast",
        )
    )
    ap.add_argument("--results-root", type=Path, default=default_results)
    ap.add_argument("--subject", default="sub-TBI011204")
    ap.add_argument("--session", default="ses-2WK")
    ap.add_argument(
        "--out-dir",
        type=Path,
        default=Path(__file__).resolve().parents[1] / "figures" / "brain",
    )
    args = ap.parse_args()

    R = args.results_root
    sub = args.subject
    ses = args.session
    fs = R / "freesurfer" / sub
    recon_deriv = (
        R / "qsirecon_single_run_output" / "derivatives" / "qsirecon-MRtrix3_fork-SS3T_act-HSVS" / sub / ses / "dwi"
    )
    paths = {
        "t1": fs / "mri" / "T1.mgz",
        "aseg": fs / "mri" / "aseg.mgz",
        "aparc": fs / "mri" / "aparc+aseg.mgz",
        "surf": fs / "surf",
        "stats": fs / "stats",
        "preproc_t1w": R
        / "qsiprep_single_run_output"
        / sub
        / "anat"
        / f"{sub}_desc-preproc_T1w.nii.gz",
        "dwiref": R
        / "qsiprep_single_run_output"
        / sub
        / ses
        / "dwi"
        / f"{sub}_{ses}_acq-b1000_space-T1w_dwiref.nii.gz",
        "hsvs": R
        / "qsirecon_single_run_output"
        / sub
        / "anat"
        / f"{sub}_space-ACPC_seg-hsvs_probseg.nii.gz",
        "conn": recon_deriv / f"{sub}_{ses}_acq-b1000_space-T1w_connectivity.mat",
    }

    out = args.out_dir
    out.mkdir(parents=True, exist_ok=True)
    print(f"Writing figures to {out}")

    jobs = [
        ("normal anatomy", lambda: fig_normal_anatomy(paths, out)),
        ("tissue classes", lambda: fig_tissue_classes(paths, out)),
        ("subcortical GM", lambda: fig_subcortical(paths, out)),
        ("parcellation", lambda: fig_parcellation(paths, out)),
        ("cortical surfaces", lambda: fig_surfaces(paths, out)),
        ("HSVS 5TT", lambda: fig_5tt(paths, out)),
        ("coordinate spaces", lambda: fig_spaces(paths, out)),
        ("connectome", lambda: fig_connectome(paths, out)),
        ("MRI contrast table", lambda: fig_contrast_schematic(out)),
        ("lesion patterns", lambda: fig_lesion_schematic(out)),
        ("volumetrics", lambda: fig_volumetrics(paths, out)),
        ("anatomy/pipeline map", lambda: fig_anatomy_pipeline_map(out)),
    ]
    for name, fn in jobs:
        print(f"[fig] {name}")
        try:
            fn()
        except Exception as exc:  # keep going so one missing input is not fatal
            print(f"  SKIPPED ({type(exc).__name__}: {exc})")


if __name__ == "__main__":
    main()
