#!/usr/bin/env python3
"""Map Deep Atropos integer segmentation to MRtrix ACT base 5TT (5 channels).

Label indices follow MRtrix ``5ttgen deep_atropos`` (integer mode):
  0 background, 1 CSF, 2 cortical GM, 3 WM, 4 subcortical GM, 5 brain stem, 6 cerebellum.

Output channel order (MRtrix ACT):
  0 cortical GM, 1 subcortical GM, 2 WM, 3 CSF, 4 pathology (zeros in base 5TT).
"""

from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

import nibabel as nib
import numpy as np

# Deep Atropos label -> MRtrix 5TT channel index (pathology channel 4 unused in base).
_LABEL_TO_CHANNEL: dict[int, int | None] = {
    0: None,
    1: 3,  # CSF
    2: 0,  # cortical GM
    3: 2,  # WM
    4: 1,  # subcortical GM
    5: 2,  # brain stem -> WM (MRtrix deep_atropos convention)
    6: 2,  # cerebellum -> WM
}


def _resample_to_reference(
    seg_img: nib.Nifti1Image, ref_img: nib.Nifti1Image
) -> np.ndarray:
    if seg_img.shape == ref_img.shape and np.allclose(seg_img.affine, ref_img.affine):
        return np.rint(seg_img.get_fdata()).astype(np.int16)

    from nibabel.processing import resample_from_to

    resampled = resample_from_to(seg_img, ref_img, order=0)
    return np.rint(resampled.get_fdata()).astype(np.int16)


def deep_atropos_seg_to_5tt(seg_data: np.ndarray) -> np.ndarray:
    """Return float32 array (X, Y, Z, 5) with one-hot tissue channels."""
    shape = seg_data.shape
    out = np.zeros(shape + (5,), dtype=np.float32)
    labels = np.unique(seg_data)
    unknown = sorted(int(v) for v in labels if int(v) not in _LABEL_TO_CHANNEL)
    if unknown:
        raise ValueError(f"unexpected Deep Atropos labels: {unknown}")
    for label, channel in _LABEL_TO_CHANNEL.items():
        if channel is None:
            continue
        mask = seg_data == label
        if mask.any():
            out[..., channel][mask] = 1.0
    return out


def convert(
    *,
    t1w: Path,
    segmentation: Path,
    output_nii: Path,
    output_json: Path | None = None,
) -> dict:
    t1w_img = nib.load(str(t1w))
    seg_img = nib.load(str(segmentation))
    seg_data = _resample_to_reference(seg_img, t1w_img)
    five_tt = deep_atropos_seg_to_5tt(seg_data)
    channel_sum = five_tt.sum(axis=-1)
    if not np.all((channel_sum == 0) | np.isclose(channel_sum, 1.0)):
        bad = int(((channel_sum > 0) & ~np.isclose(channel_sum, 1.0)).sum())
        raise ValueError(f"5TT channels do not sum to 0 or 1 at {bad} voxels")

    out_img = nib.Nifti1Image(five_tt.astype(np.float32), t1w_img.affine, t1w_img.header)
    output_nii.parent.mkdir(parents=True, exist_ok=True)
    nib.save(out_img, str(output_nii))

    payload = {
        "t1w_reference": str(t1w.resolve()),
        "deep_atropos_segmentation": str(segmentation.resolve()),
        "base_5tt_native_nii": str(output_nii.resolve()),
        "label_map": {str(k): v for k, v in _LABEL_TO_CHANNEL.items()},
        "shape": list(five_tt.shape),
        "resampled_segmentation_to_t1w": seg_img.shape != t1w_img.shape
        or not np.allclose(seg_img.affine, t1w_img.affine),
    }
    if output_json is not None:
        output_json.write_text(json.dumps(payload, indent=2) + "\n")
    return payload


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--t1w", type=Path, required=True, help="BIDS T1w reference grid")
    parser.add_argument("--segmentation", type=Path, required=True, help="Deep Atropos integer seg")
    parser.add_argument("--output", type=Path, required=True, help="Output 4D NIfTI (5 channels)")
    parser.add_argument("--json", type=Path, default=None, help="Optional provenance JSON")
    args = parser.parse_args()
    for path in (args.t1w, args.segmentation):
        if not path.is_file():
            print(f"ERROR: missing input: {path}", file=sys.stderr)
            raise SystemExit(1)
    convert(
        t1w=args.t1w,
        segmentation=args.segmentation,
        output_nii=args.output,
        output_json=args.json,
    )


if __name__ == "__main__":
    main()
