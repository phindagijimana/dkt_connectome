#!/usr/bin/env python3
"""
build_panels.py -- ENIGMA-style connectome panels from a Step 4 dkt_connectome.csv

Reads the 78x78 DKT structural connectome produced by dwi_pipeline's Step 4
(dkt_connectome.sif) and the DKT lookup table used to build it, and renders
four panels that a doctor/researcher would recognize from a connectomics
report:

  A_matrix.png            adjacency matrix heatmap (log-scaled streamline count)
  B_connectogram.png      circular connectogram, top edges, lesion-adjacent
                           nodes highlighted
  C_surface_strength.png  node strength painted onto the subject's own
                           cortical surface (native DKT annotation, not a
                           group template)
  D_summary.png           global graph metrics + left/right asymmetry per
                           bilateral node pair

"Lesion-adjacent" nodes are found by intersecting the prepared lesion mask
(Step 1.5 output) with the same DKT parcellation image used to build the
connectome, in native T1w (rawavg) space -- both are on the acquisition grid,
so no extra registration is needed here.

Run with the system python3 (nibabel/nilearn/networkx/pandas/matplotlib are
all it needs -- no enigmatoolbox/VTK dependency, unlike build_subcortical_3d.py).
"""

import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import common as C

import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
import networkx as nx
import nibabel as nib
import numpy as np
import pandas as pd

SUBJECT = C.SUBJECT
CONNECTOME_DIR = C.CONNECTOME_DIR
FS_DIR = C.FS_DIR
LESION_MASK = C.LESION_MASK
OUT = C.out_dir("connectome")

load_lut = C.load_dkt_lut
hemisphere_of = C.hemisphere_of
bilateral_pairs = C.bilateral_pairs
fs_code_for_node = C.fs_code_for_node


def find_lesion_adjacent_nodes(lut):
    """Nodes whose FreeSurfer-coded territory overlaps the lesion mask, in
    the same native (rawavg) space the connectome parcellation was warped to.
    """
    parc_path = CONNECTOME_DIR / "aparc+aseg_in_rawavg.nii.gz"
    if not (parc_path.exists() and LESION_MASK.exists()):
        return set()
    parc = nib.load(str(parc_path)).get_fdata().astype(int)
    mask_img = nib.load(str(LESION_MASK))
    mask = mask_img.get_fdata()
    if mask.shape != parc.shape:
        print(f"WARNING: lesion mask shape {mask.shape} != parcellation shape "
              f"{parc.shape}; skipping lesion-adjacency (grids differ, would "
              f"need registration this demo script does not do).")
        return set()
    lesion_codes = set(np.unique(parc[mask > 0]).tolist()) - {0}
    adjacent = set()
    for idx, (_, name) in lut.items():
        try:
            code = fs_code_for_node(name)
        except KeyError:
            continue
        if code in lesion_codes:
            adjacent.add(idx)
    return adjacent


def panel_a_matrix(mat, lut, lesion_nodes):
    n = mat.shape[0]
    labels = [lut[i + 1][0] for i in range(n)]
    fig, ax = plt.subplots(figsize=(11, 10))
    disp = np.log1p(mat)
    im = ax.imshow(disp, cmap="viridis", aspect="equal")
    ax.set_xticks(range(n))
    ax.set_yticks(range(n))
    ax.set_xticklabels(labels, fontsize=4, rotation=90)
    ax.set_yticklabels(labels, fontsize=4)
    for i in range(n):
        if (i + 1) in lesion_nodes:
            ax.get_xticklabels()[i].set_color("red")
            ax.get_yticklabels()[i].set_color("red")
    ax.set_title(f"{SUBJECT} -- DKT structural connectome (log1p streamline count)\n"
                 f"red labels = lesion-adjacent nodes ({len(lesion_nodes)})")
    fig.colorbar(im, ax=ax, fraction=0.03, pad=0.02, label="log1p(streamlines)")
    fig.tight_layout()
    fig.savefig(OUT / "A_matrix.png", dpi=160)
    plt.close(fig)


def panel_b_connectogram(mat, lut, lesion_nodes, top_frac=0.08):
    n = mat.shape[0]
    order = sorted(range(1, n + 1), key=lambda i: (hemisphere_of(lut[i][1]) != "L", lut[i][1]))
    angle = {node: 2 * np.pi * k / n for k, node in enumerate(order)}
    pos = {node: (np.cos(a), np.sin(a)) for node, a in angle.items()}

    flat = [(mat[i, j], i + 1, j + 1) for i in range(n) for j in range(i + 1, n) if mat[i, j] > 0]
    flat.sort(reverse=True)
    keep = flat[: max(1, int(len(flat) * top_frac))]
    wmax = keep[0][0] if keep else 1.0

    fig, ax = plt.subplots(figsize=(9, 9))
    for w, i, j in keep:
        x = [pos[i][0], pos[j][0]]
        y = [pos[i][1], pos[j][1]]
        ax.plot(x, y, color="steelblue", alpha=0.15 + 0.55 * (w / wmax), linewidth=0.6 + 1.8 * (w / wmax))
    for node in order:
        x, y = pos[node]
        color = "crimson" if node in lesion_nodes else ("darkorange" if hemisphere_of(lut[node][1]) == "L" else "seagreen")
        ax.scatter([x], [y], s=45 if node in lesion_nodes else 22, color=color, zorder=3,
                   edgecolors="black" if node in lesion_nodes else "none", linewidths=0.8)
        ax.text(x * 1.08, y * 1.08, lut[node][0], fontsize=4.2, ha="center", va="center")
    ax.set_xlim(-1.35, 1.35)
    ax.set_ylim(-1.35, 1.35)
    ax.set_aspect("equal")
    ax.axis("off")
    ax.set_title(f"{SUBJECT} -- connectogram, top {len(keep)}/{len(flat)} edges\n"
                 f"orange=left, green=right, red=lesion-adjacent")
    fig.tight_layout()
    fig.savefig(OUT / "B_connectogram.png", dpi=160)
    plt.close(fig)


def panel_c_surface_strength(strength, lut):
    """Paint node strength onto the subject's own native cortical surface,
    using their own DKT annotation rather than a group template -- this is
    this subject's anatomy, not a normative comparison."""
    from nilearn import plotting as nlp
    from nibabel.freesurfer.io import read_annot, read_geometry

    fig = plt.figure(figsize=(12, 6))
    for col, hemi in enumerate(["lh", "rh"]):
        coords, faces = read_geometry(str(FS_DIR / "surf" / f"{hemi}.inflated"))
        labels, _ctab, names = read_annot(str(FS_DIR / "label" / f"{hemi}.aparc.DKTatlas.annot"))
        names = [n.decode() if isinstance(n, bytes) else n for n in names]

        prefix = "ctx-lh-" if hemi == "lh" else "ctx-rh-"
        name_to_strength = {}
        for idx, (_, longname) in lut.items():
            if longname.startswith(prefix):
                name_to_strength[longname[len(prefix):]] = strength[idx - 1]

        vertex_vals = np.zeros(labels.shape[0], dtype=float)
        for local_idx, region_name in enumerate(names):
            vertex_vals[labels == local_idx] = name_to_strength.get(region_name, 0.0)

        ax = fig.add_subplot(1, 2, col + 1, projection="3d")
        nlp.plot_surf_stat_map(
            (coords, faces), vertex_vals,
            hemi="left" if hemi == "lh" else "right",
            view="lateral", colorbar=True, cmap="inferno",
            title=f"{hemi} node strength", axes=ax,
        )
    fig.suptitle(f"{SUBJECT} -- DKT node strength on native cortical surface")
    fig.savefig(OUT / "C_surface_strength.png", dpi=150)
    plt.close(fig)


def panel_d_summary(mat, lut, lesion_nodes):
    n = mat.shape[0]
    G = nx.from_numpy_array(mat)
    density = nx.density(G)
    strength = mat.sum(axis=1)
    total_streamlines = mat.sum() / 2

    fig, axes = plt.subplots(1, 2, figsize=(13, 5.5))

    ax = axes[0]
    metrics = {
        "nodes": n,
        "edges (weighted, w>0)": int((mat > 0).sum() / 2),
        "density": density,
        "total streamlines": total_streamlines,
        "mean node strength": strength.mean(),
        "lesion-adjacent nodes": len(lesion_nodes),
    }
    ax.axis("off")
    text = "\n".join(f"{k:>24s} : {v:,.4g}" if isinstance(v, float) else f"{k:>24s} : {v}"
                      for k, v in metrics.items())
    ax.text(0.02, 0.5, text, fontsize=11, family="monospace", va="center")
    ax.set_title("Global network metrics")

    pairs = bilateral_pairs(lut)
    labels = [stem for _, _, stem in pairs]
    asym = []
    for li, ri, _ in pairs:
        sl, sr = strength[li - 1], strength[ri - 1]
        asym.append(0.0 if (sl + sr) == 0 else (sl - sr) / (sl + sr))
    ax = axes[1]
    colors = ["crimson" if (li in lesion_nodes or ri in lesion_nodes) else "steelblue"
              for li, ri, _ in pairs]
    ax.barh(range(len(pairs)), asym, color=colors)
    ax.set_yticks(range(len(pairs)))
    ax.set_yticklabels(labels, fontsize=5)
    ax.axvline(0, color="black", linewidth=0.8)
    ax.set_xlabel("(L - R) / (L + R) node strength")
    ax.set_title("Left/right asymmetry per bilateral pair\n(red = lesion-adjacent on either side)")
    fig.tight_layout()
    fig.savefig(OUT / "D_summary.png", dpi=150)
    plt.close(fig)


def main():
    lut = load_lut()
    mat = pd.read_csv(CONNECTOME_DIR / "dkt_connectome.csv", header=None).to_numpy(dtype=float)
    if mat.shape != (78, 78):
        print(f"WARNING: expected a 78x78 DKT matrix, got {mat.shape}", file=sys.stderr)
    strength = mat.sum(axis=1)
    lesion_nodes = find_lesion_adjacent_nodes(lut)
    print(f"Lesion-adjacent nodes: {sorted(lut[i][1] for i in lesion_nodes)}")

    panel_a_matrix(mat, lut, lesion_nodes)
    panel_b_connectogram(mat, lut, lesion_nodes)
    panel_c_surface_strength(strength, lut)
    panel_d_summary(mat, lut, lesion_nodes)
    print(f"Wrote panels to {OUT}")


if __name__ == "__main__":
    main()
