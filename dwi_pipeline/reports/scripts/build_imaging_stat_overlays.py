#!/usr/bin/env python3
"""
build_imaging_stat_overlays.py -- statistical values painted onto imaging

The connectome/morphometry panels report values per named region as a
table/plot. This script instead paints those same numbers back onto the
subject's own segmentation volume, voxel-by-voxel, so a viewer can see
*where* in this brain a high or low value sits, in the same space as the
T1w they already know how to read:

  K_node_strength_on_imaging.png   DKT connectome node strength, painted
                                    onto native T1w via the DKT segmentation
  L_volume_map_DK.png               DK-68 regional volumes, painted onto the
                                    DK segmentation (cortex GrayVol + aseg
                                    subcortical volumes)
  M_volume_map_DKT.png              same, using the DKT segmentation instead

L/M need a recon-all (or FastSurfer --fast-fs) tree for DK; see
pipeline_science.md Sec2.6. This subject's tree has both.
"""

import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import common as C

import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
import nibabel as nib
import numpy as np
import pandas as pd
from nilearn import plotting as nlp

OUT = C.out_dir("imaging_stat_overlays")


def render(seg, code_to_value):
    """seg: int array of raw FreeSurfer codes. Returns a float array with
    code_to_value[code] at every voxel whose code is a key, 0 elsewhere."""
    out = np.zeros(seg.shape, dtype=float)
    for code, val in code_to_value.items():
        out[seg == code] = val
    return out


def panel_k_node_strength():
    lut = C.load_dkt_lut()
    mat = pd.read_csv(C.CONNECTOME_DIR / "dkt_connectome.csv", header=None).to_numpy(dtype=float)
    strength = mat.sum(axis=1)

    seg_img = nib.load(str(C.DATA_DIR / "aparc.DKTatlas+aseg_in_rawavg.nii.gz"))
    seg = seg_img.get_fdata().astype(int)
    code_to_value = {}
    for idx, (_, name) in lut.items():
        try:
            code_to_value[C.fs_code_for_node(name)] = strength[idx - 1]
        except KeyError:
            continue

    vol = render(seg, code_to_value)
    stat_img = nib.Nifti1Image(vol, seg_img.affine)
    rawavg = nib.load(str(C.FS_DIR / "mri" / "rawavg.mgz"))

    fig = plt.figure(figsize=(12, 5))
    nlp.plot_stat_map(
        stat_img, bg_img=rawavg, display_mode="ortho", cmap="inferno",
        title=f"{C.SUBJECT} -- DKT node strength painted onto native T1w",
        colorbar=True, figure=fig, threshold=1,
    )
    fig.savefig(OUT / "K_node_strength_on_imaging.png", dpi=150)
    plt.close(fig)


def _cortical_volume_map(aparc_stats_lh, aparc_stats_rh, aseg_vols, hemi_prefix_map):
    code_to_value = {}
    for hemi, stats in [("lh", aparc_stats_lh), ("rh", aparc_stats_rh)]:
        offset = 1000 if hemi == "lh" else 2000
        for region_name, row in stats.items():
            if region_name in C.DKT_EXCLUDED and hemi_prefix_map == "dkt":
                continue
            try:
                code = offset + C.fs_code_for_ctx_name(region_name)
            except KeyError:
                continue
            code_to_value[code] = row["GrayVol"]
    for struct_name, vol_mm3 in aseg_vols.items():
        for prefix, side in [("Left-", "Left-"), ("Right-", "Right-")]:
            if struct_name.startswith(prefix):
                stem = struct_name[len(prefix):]
                key = f"{side}{stem}"
                if key in C.FS_SUBCORT_CODE:
                    code_to_value[C.FS_SUBCORT_CODE[key]] = vol_mm3
    return code_to_value


def panel_volume_map(atlas, seg_filename, aparc_glob, out_name, title):
    lh_stats = C.parse_aparc_stats(C.FS_DIR / "stats" / f"lh.{aparc_glob}.stats")
    rh_stats = C.parse_aparc_stats(C.FS_DIR / "stats" / f"rh.{aparc_glob}.stats")
    _etiv, aseg_vols = C.parse_aseg_stats(C.FS_DIR / "stats" / "aseg.stats")
    code_to_value = _cortical_volume_map(lh_stats, rh_stats, aseg_vols, atlas)

    seg_img = nib.load(str(C.FS_DIR / "mri" / seg_filename))
    seg = np.asarray(seg_img.dataobj).astype(int)
    vol = render(seg, code_to_value)
    stat_img = nib.MGHImage(vol.astype("float32"), seg_img.affine)
    brain = nib.load(str(C.FS_DIR / "mri" / "brain.mgz"))

    fig = plt.figure(figsize=(12, 5))
    nlp.plot_stat_map(
        stat_img, bg_img=brain, display_mode="ortho", cmap="viridis",
        title=title, colorbar=True, figure=fig, threshold=1,
    )
    fig.savefig(OUT / out_name, dpi=150)
    plt.close(fig)


def main():
    panel_k_node_strength()
    panel_volume_map(
        "dk", "aparc+aseg.mgz", "aparc",
        "L_volume_map_DK.png",
        f"{C.SUBJECT} -- DK-68 regional volumes (mm^3) on native T1w",
    )
    panel_volume_map(
        "dkt", "aparc.DKTatlas+aseg.mgz", "aparc.DKTatlas",
        "M_volume_map_DKT.png",
        f"{C.SUBJECT} -- DKT regional volumes (mm^3) on native T1w",
    )
    print(f"Wrote panels to {OUT}")


if __name__ == "__main__":
    main()
