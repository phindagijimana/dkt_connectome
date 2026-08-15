#!/usr/bin/env python3
"""Prepare a raw BIDS lesion mask for LIT: resample onto the T1w grid, select
labels, optionally binarize, and record provenance.

Manually-traced lesion masks (``*_label-lesion_roi.nii.gz``) are usually
multi-class (e.g. 1=core, 2=oedema) and are drawn directly on the subject's
native T1w, so they normally already share its grid. This script still
verifies that and resamples (nearest-neighbour) if it does not, so a mask
traced on a slightly different resolution/FOV T1w does not silently
misalign inside LIT.

Output:
  --out         prepared mask, same grid as --t1w, written with the T1w affine
  --json        provenance: label inventory, voxel counts, selection, whether
                the mask was binarized

Usage:
  python3 prepare_lesion_mask.py --t1w sub-01_T1w.nii.gz \\
      --mask sub-01_T1w_label-lesion_roi.nii.gz \\
      --out lesion_mask_prepared.nii.gz --json lesion_mask_prepared.json
"""

from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

import nibabel as nib
import numpy as np

# Multi-label lesion mask convention used in several cohorts (1=core, 2=oedema). Any label not
# in this table is reported by its number instead of a name.
KNOWN_LABEL_NAMES = {1: "core", 2: "oedema"}


def log(msg: str) -> None:
    print(f"[prepare-lesion-mask] {msg}", file=sys.stderr)


def resample_nearest(mask_img: nib.Nifti1Image, target_img: nib.Nifti1Image) -> nib.Nifti1Image:
    from nilearn.image import resample_to_img

    return resample_to_img(mask_img, target_img, interpolation="nearest", force_resample=True, copy_header=True)


def parse_labels_arg(raw: str, labels_present: list[int]) -> list[int]:
    if raw in ("all", "", None):
        return labels_present
    wanted = {int(tok) for tok in raw.split(",") if tok.strip()}
    selected = sorted(wanted & set(labels_present))
    missing = sorted(wanted - set(labels_present))
    if missing:
        log(f"WARNING: requested labels not present in mask, ignoring: {missing}")
    if not selected:
        raise SystemExit(f"None of the requested labels {sorted(wanted)} are present in the mask")
    return selected


def main() -> None:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--t1w", type=Path, required=True, help="Native T1w this mask will be applied to")
    ap.add_argument("--mask", type=Path, required=True, help="Raw BIDS lesion mask (*_label-lesion_roi.nii.gz)")
    ap.add_argument("--out", type=Path, required=True, help="Prepared mask output path")
    ap.add_argument("--json", type=Path, required=True, help="Provenance JSON output path")
    ap.add_argument("--labels", default="all", help="Comma-separated label values to keep, or 'all' (default)")
    ap.add_argument("--binarize", action="store_true", help="Collapse selected labels to a single value (1)")
    args = ap.parse_args()

    if not args.t1w.is_file():
        raise SystemExit(f"Missing T1w: {args.t1w}")
    if not args.mask.is_file():
        raise SystemExit(f"Missing lesion mask: {args.mask}")

    t1w_img = nib.load(str(args.t1w))
    mask_img = nib.load(str(args.mask))
    input_dtype = str(mask_img.get_data_dtype())

    same_grid = mask_img.shape == t1w_img.shape and np.allclose(
        mask_img.affine, t1w_img.affine, atol=1e-3
    )
    if not same_grid:
        log(
            f"mask grid {mask_img.shape} differs from T1w grid {t1w_img.shape}; "
            "resampling mask onto T1w grid (nearest-neighbour)"
        )
        mask_img = resample_nearest(mask_img, t1w_img)
    else:
        log(f"mask already shares the T1w grid {t1w_img.shape}")

    mask_data = np.rint(mask_img.get_fdata()).astype(np.int32)
    labels_present = sorted(int(v) for v in np.unique(mask_data) if v != 0)
    if not labels_present:
        raise SystemExit(f"Lesion mask {args.mask} has no nonzero voxels")

    labels_selected = parse_labels_arg(args.labels, labels_present)

    voxels_per_label = {str(lbl): int((mask_data == lbl).sum()) for lbl in labels_present}
    selected_bool = np.isin(mask_data, labels_selected)
    voxels_selected = int(selected_bool.sum())

    zooms = t1w_img.header.get_zooms()[:3]
    voxel_volume_mm3 = round(float(zooms[0] * zooms[1] * zooms[2]), 4)
    volume_selected_mm3 = round(voxels_selected * voxel_volume_mm3, 2)

    if args.binarize:
        out_data = selected_bool.astype(np.uint8)
    else:
        out_data = np.where(selected_bool, mask_data, 0).astype(np.int16)

    args.out.parent.mkdir(parents=True, exist_ok=True)
    out_img = nib.Nifti1Image(out_data, t1w_img.affine, header=t1w_img.header)
    out_img.header.set_data_dtype(out_data.dtype)
    nib.save(out_img, str(args.out))

    label_names = {str(lbl): KNOWN_LABEL_NAMES.get(lbl, str(lbl)) for lbl in labels_present}

    provenance = {
        "t1w": str(args.t1w),
        "mask_input": str(args.mask),
        "mask_prepared": str(args.out),
        "input_dtype": input_dtype,
        "labels_present": labels_present,
        "labels_selected": labels_selected,
        "label_names": label_names,
        "binarized": bool(args.binarize),
        "voxel_volume_mm3": voxel_volume_mm3,
        "voxels_per_label": voxels_per_label,
        "voxels_selected": voxels_selected,
        "volume_selected_mm3": volume_selected_mm3,
    }
    args.json.parent.mkdir(parents=True, exist_ok=True)
    args.json.write_text(json.dumps(provenance, indent=2) + "\n")

    log(
        f"labels_present={labels_present} labels_selected={labels_selected} "
        f"binarized={args.binarize} voxels_selected={voxels_selected} "
        f"({volume_selected_mm3} mm3) -> {args.out}"
    )


if __name__ == "__main__":
    main()
