#!/usr/bin/env python3
"""
build_imaging_panels.py -- radiology-style imaging panels (not statistics)

Renders the pipeline's own volumetric images, the way a radiologist would
look at them, rather than derived numbers:

  G_segmentation_overlay.png        DKT aparc+aseg overlaid on native T1w
  H_lesion_overlay_montage.png      traced lesion mask overlaid on native T1w
  I_inpainting_fullbrain_montage.png  original (lesioned) vs inpainted T1w
  J_dwi_qc.png                      QSIPrep DWI reference + brain mask

Also writes the DKT segmentation, in native (rawavg) space, to
reports/<subject>/data/ so other scripts (build_imaging_stat_overlays.py)
and anyone opening the report folder in a viewer have it without reaching
back into RESULTS_ROOT.
"""

from common import (
    CONNECTOME_DIR,
    FS_DIR,
    INPAINT_DIR,
    REPORTS_DIR,
    RESULTS_ROOT,
    SESSION,
    SUBJECT,
)

import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
import nibabel as nib
from nilearn import plotting as nlp
from nilearn.image import resample_to_img

OUT = REPORTS_DIR / "imaging"
DATA_OUT = REPORTS_DIR / "data"
OUT.mkdir(parents=True, exist_ok=True)
DATA_OUT.mkdir(parents=True, exist_ok=True)

QSIPREP_DWI_DIR = RESULTS_ROOT / "qsiprep_single_run_output" / SUBJECT / SESSION / "dwi"


def stash_native_dkt_segmentation():
    """Copy the DKT segmentation already warped to native (rawavg) T1w space
    into the report's data/ folder, as .nii.gz and .mgz, for reuse."""
    src = CONNECTOME_DIR / "aparc+aseg_in_rawavg.nii.gz"
    img = nib.load(str(src))
    nii_out = DATA_OUT / "aparc.DKTatlas+aseg_in_rawavg.nii.gz"
    mgz_out = DATA_OUT / "aparc.DKTatlas+aseg_in_rawavg.mgz"
    nib.save(img, str(nii_out))
    nib.save(nib.MGHImage(img.get_fdata().astype("int32"), img.affine), str(mgz_out))
    return nii_out


def panel_g_segmentation(seg_path):
    rawavg = nib.load(str(FS_DIR / "mri" / "rawavg.mgz"))
    seg = nib.load(str(seg_path))
    fig = plt.figure(figsize=(12, 5))
    nlp.plot_roi(
        seg, bg_img=rawavg, display_mode="ortho",
        title=f"{SUBJECT} -- DKT segmentation on native T1w (rawavg)",
        cmap="tab20", alpha=0.55, figure=fig,
    )
    fig.savefig(OUT / "G_segmentation_overlay.png", dpi=150)
    plt.close(fig)


def panel_h_lesion_overlay():
    import numpy as np

    rawavg = nib.load(str(FS_DIR / "mri" / "rawavg.mgz"))
    mask_img = nib.load(str(INPAINT_DIR / "lesion_mask_prepared.nii.gz"))
    mask_data = mask_img.get_fdata()
    ijk = np.array(np.where(mask_data > 0)).mean(axis=1)
    centroid_xyz = nib.affines.apply_affine(mask_img.affine, ijk)

    fig = plt.figure(figsize=(12, 5))
    nlp.plot_roi(
        mask_img, bg_img=rawavg, display_mode="ortho", cut_coords=tuple(centroid_xyz),
        title=f"{SUBJECT} -- traced lesion mask on native T1w (core=1, oedema=2), centred on lesion",
        cmap="autumn", alpha=0.7, figure=fig,
    )
    fig.savefig(OUT / "H_lesion_overlay_montage.png", dpi=150)
    plt.close(fig)


def panel_i_inpainting_montage():
    import numpy as np

    result = nib.load(str(INPAINT_DIR / "inpainting_volumes" / "inpainting_result.nii.gz"))
    original_256iso = nib.load(str(INPAINT_DIR / "inpainting_volumes" / "inpainting_original_image.nii.gz"))
    mask_img = nib.load(str(INPAINT_DIR / "lesion_mask_prepared.nii.gz"))

    # Original comes back from LIT on its internal 1mm-iso conformed grid;
    # resample onto the same native (--keepgeom) grid as `result` so the two
    # panels are directly comparable voxel-for-voxel, exactly what --keepgeom
    # itself does for the volume Step 2 actually consumes.
    original_native = resample_to_img(original_256iso, result, interpolation="continuous")

    mask_data = mask_img.get_fdata()
    ijk = np.array(np.where(mask_data > 0)).mean(axis=1)
    lesion_z = nib.affines.apply_affine(mask_img.affine, ijk)[2]

    fig, axes = plt.subplots(1, 3, figsize=(15, 5.5))
    nlp.plot_anat(original_native, display_mode="z", cut_coords=[lesion_z], axes=axes[0],
                  title="original (lesioned), resampled to native grid", annotate=False)
    nlp.plot_anat(result, display_mode="z", cut_coords=[lesion_z], axes=axes[1],
                  title="inpainted (pseudo-healthy)", annotate=False)
    nlp.plot_roi(mask_img, bg_img=result, display_mode="z", cut_coords=[lesion_z], axes=axes[2],
                 title="lesion mask, for reference", cmap="autumn", alpha=0.7, annotate=False)
    fig.suptitle(f"{SUBJECT} -- Step 1.5 inpainting: before / after (slice through lesion centroid)")
    fig.savefig(OUT / "I_inpainting_fullbrain_montage.png", dpi=150)
    plt.close(fig)


def panel_j_dwi_qc():
    dwiref = QSIPREP_DWI_DIR / f"{SUBJECT}_ses-2WK_space-T1w_dwiref.nii.gz"
    mask = QSIPREP_DWI_DIR / f"{SUBJECT}_ses-2WK_space-T1w_desc-brain_mask.nii.gz"
    fig = plt.figure(figsize=(12, 5))
    nlp.plot_roi(
        str(mask), bg_img=str(dwiref), display_mode="ortho",
        title=f"{SUBJECT} -- QSIPrep DWI reference + brain mask (T1w space)",
        cmap="cool", alpha=0.35, figure=fig,
    )
    fig.savefig(OUT / "J_dwi_qc.png", dpi=150)
    plt.close(fig)


def main():
    seg_path = stash_native_dkt_segmentation()
    panel_g_segmentation(seg_path)
    panel_h_lesion_overlay()
    panel_i_inpainting_montage()
    panel_j_dwi_qc()
    print(f"Wrote panels to {OUT}")
    print(f"Wrote native DKT segmentation to {DATA_OUT}")


if __name__ == "__main__":
    main()
