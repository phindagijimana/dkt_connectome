#!/usr/bin/env python3
"""QC for a LIT inpainting run: is the volume usable, and what did it change?

LIT internally conforms to a 1mm-isotropic grid and (with --keepgeom) resamples
its result back onto the input T1w's native grid. That round trip alone
introduces a small amount of interpolation blur even with zero lesion and a
perfect model, so a raw "correlation outside the lesion" number is slightly
pessimistic. This script also computes a resampling-only control (the same
conform -> deconform round trip applied to the *original* image, no
inpainting involved) and reports how much further the real run's outside-
lesion correlation falls below that control ceiling.

Hard FAIL (ok=false) only when the step is unusable:
  missing volume, wrong grid, NaN correlation, or empty mask.

Outside-mask Pearson r, resampling-control r, and drop are always printed
as descriptive IQMs (MRIQC-style). Optional local defaults 0.995 / 0.01 are
not a published cutoff (Pollak et al. 2025 reports SSIM/PSNR and Dice/HD95;
MRIQC uses visual reports). They color ok=false only with --fail-on-thresholds
(INPAINT_FAIL_ON_QC=1).

Output: --json provenance with ok, hard_failures, threshold_notes, and the IQMs.
"""

from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

import nibabel as nib
import numpy as np

# Optional local defaults for inspection / --fail-on-thresholds. Not a published cutoff.
DEFAULT_MIN_OUTSIDE_CORR = 0.995
DEFAULT_MAX_CORR_DROP = 0.01

PUBLIC_INSPECTION_NOTE = (
    "Inpaint finished. Outside-mask Pearson r is reported for inspection. "
    "0.995 / 0.01 are optional pipeline defaults, not a published cutoff. "
    "Judge the before/after PNGs (Pollak et al. 2025; MRIQC visual QC)."
)


def log(msg: str) -> None:
    print(f"[check-inpainting] {msg}", file=sys.stderr)


def decide_qc_status(
    *,
    geometry_matches_original: bool,
    outside_lesion_correlation: float,
    correlation_drop_vs_control: float,
    lesion_voxels: int,
    min_outside_corr: float = DEFAULT_MIN_OUTSIDE_CORR,
    max_corr_drop: float = DEFAULT_MAX_CORR_DROP,
    fail_on_thresholds: bool = False,
) -> dict:
    """Separate unusable outputs from optional local correlation defaults."""
    hard_failures: list[str] = []
    if not geometry_matches_original:
        hard_failures.append(
            "inpainted result did not preserve the original T1w geometry (--keepgeom not honoured?)"
        )
    if np.isnan(outside_lesion_correlation):
        hard_failures.append("outside-lesion correlation is NaN; mask or intensities unusable")
    if lesion_voxels <= 0:
        hard_failures.append("prepared lesion mask is empty")

    threshold_notes: list[str] = []
    if (
        not np.isnan(outside_lesion_correlation)
        and outside_lesion_correlation < min_outside_corr
    ):
        threshold_notes.append(
            f"outside-mask Pearson r is {outside_lesion_correlation} "
            f"(optional local default {min_outside_corr}; not a published cutoff)"
        )
    if (
        not np.isnan(correlation_drop_vs_control)
        and correlation_drop_vs_control > max_corr_drop
    ):
        threshold_notes.append(
            f"correlation drop vs resampling-only control is {correlation_drop_vs_control} "
            f"(optional local default {max_corr_drop}; not a published cutoff)"
        )

    failures = list(hard_failures)
    if fail_on_thresholds:
        failures.extend(threshold_notes)
    return {
        "ok": not failures,
        "hard_failures": hard_failures,
        "threshold_notes": threshold_notes,
        "failures": failures,
        "fail_on_thresholds": bool(fail_on_thresholds),
    }


def pearson_r(a: np.ndarray, b: np.ndarray) -> float:
    a = a.astype(np.float64)
    b = b.astype(np.float64)
    if a.size < 2 or np.std(a) == 0 or np.std(b) == 0:
        return float("nan")
    return float(np.corrcoef(a, b)[0, 1])


def resampling_control(original_img: nib.Nifti1Image) -> np.ndarray:
    """Conform to 1mm iso and back, with no inpainting -- isolates the
    correlation loss caused purely by LIT's internal resampling round trip."""
    from nibabel.processing import conform, resample_from_to

    conformed = conform(original_img, out_shape=(256, 256, 256), voxel_size=(1.0, 1.0, 1.0), orientation="LIA")
    roundtrip = resample_from_to(conformed, original_img, order=1)
    return np.asarray(roundtrip.get_fdata())


def main() -> None:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--original", type=Path, required=True, help="Original (lesioned) T1w")
    ap.add_argument("--inpainted", type=Path, required=True, help="LIT inpainting_result.nii.gz")
    ap.add_argument("--mask", type=Path, required=True, help="Prepared lesion mask, on the original T1w grid")
    ap.add_argument("--json", type=Path, required=True, help="Provenance JSON output path")
    ap.add_argument("--min-outside-corr", type=float, default=DEFAULT_MIN_OUTSIDE_CORR,
                     help="Optional local default for inspection / --fail-on-thresholds "
                          f"(default {DEFAULT_MIN_OUTSIDE_CORR}; not a published cutoff)")
    ap.add_argument("--max-corr-drop", type=float, default=DEFAULT_MAX_CORR_DROP,
                     help="Optional local default for inspection / --fail-on-thresholds "
                          f"(default {DEFAULT_MAX_CORR_DROP}; not a published cutoff)")
    ap.add_argument("--fail-on-thresholds", action="store_true",
                     help="Set ok=false when r or drop miss the optional local defaults "
                          "(INPAINT_FAIL_ON_QC=1). Default: report only.")
    ap.add_argument("--foreground-threshold", type=float, default=0.0,
                     help="Original-image intensity above which a voxel counts as foreground (default 0)")
    ap.add_argument("--diff-threshold", type=float, default=None,
                     help="Absolute intensity change (after rescaling, see below) above which a voxel "
                          "counts as regenerated. Default: adaptive, 3x the 95th-percentile change seen "
                          "on outside-lesion voxels (the noise floor from resampling/quantization alone).")
    args = ap.parse_args()

    for p in (args.original, args.inpainted, args.mask):
        if not p.is_file():
            raise SystemExit(f"Missing input: {p}")

    original_img = nib.load(str(args.original))
    inpainted_img = nib.load(str(args.inpainted))
    mask_img = nib.load(str(args.mask))

    original = np.asarray(original_img.get_fdata())
    mask = np.rint(np.asarray(mask_img.get_fdata())) != 0

    geometry_matches_original = inpainted_img.shape == original_img.shape and np.allclose(
        inpainted_img.affine, original_img.affine, atol=1e-2
    )
    if geometry_matches_original:
        inpainted = np.asarray(inpainted_img.get_fdata())
    else:
        log(
            f"WARNING: inpainted grid {inpainted_img.shape} != original grid {original_img.shape}; "
            "resampling inpainted result onto the original T1w grid for QC"
        )
        from nibabel.processing import resample_from_to

        inpainted = np.asarray(resample_from_to(inpainted_img, original_img, order=1).get_fdata())

    if mask.shape != original.shape:
        raise SystemExit(f"Mask grid {mask.shape} does not match original T1w grid {original.shape}")

    foreground = original > args.foreground_threshold
    outside = foreground & ~mask
    outside_lesion_voxels = int(outside.sum())
    if outside_lesion_voxels < 1000:
        raise SystemExit("Fewer than 1000 outside-lesion foreground voxels; check --foreground-threshold/--mask")

    outside_lesion_correlation = round(pearson_r(original[outside], inpainted[outside]), 6)

    control = resampling_control(original_img)
    resampling_control_correlation = round(pearson_r(original[outside], control[outside]), 6)
    correlation_drop_vs_control = round(resampling_control_correlation - outside_lesion_correlation, 6)

    # LIT's result can come back on a different global intensity scale than the
    # input even with --keepgeom (which only preserves geometry, not units) --
    # e.g. this build rescales to roughly 0-255 regardless of the input's own
    # range. A raw intensity difference would then flag almost every foreground
    # voxel as "changed" even though outside-lesion correlation is ~1. Fit a
    # linear map on outside-lesion voxels (where nothing should have changed
    # beyond ordinary resampling) and rescale before comparing intensities
    # directly, so "regenerated" reflects what LIT actually touched.
    rescale_slope, rescale_intercept = 1.0, 0.0
    if np.std(inpainted[outside]) > 0:
        rescale_slope, rescale_intercept = np.polyfit(inpainted[outside], original[outside], 1)
    inpainted_rescaled = inpainted * rescale_slope + rescale_intercept

    diff = np.abs(inpainted_rescaled - original)
    # The rescale fit above only removes a global linear (slope+offset) shift;
    # per-voxel resampling/quantization noise remains, and its magnitude
    # depends entirely on the input's own intensity units, so a fixed absolute
    # --diff-threshold cannot work across datasets. Default to a threshold
    # anchored to that noise floor as measured outside the lesion instead.
    outside_noise_floor = float(np.percentile(diff[outside], 95))
    diff_threshold = args.diff_threshold if args.diff_threshold is not None else max(3.0 * outside_noise_floor, 1.0)
    regenerated_voxels = int((diff > diff_threshold).sum())

    lesion_voxels = int(mask.sum())
    reference_mean = float(original[outside].mean())
    lesion_relative_intensity_before = round(float(original[mask].mean()) / reference_mean, 4) if lesion_voxels else None
    lesion_relative_intensity_after = (
        round(float(inpainted_rescaled[mask].mean()) / reference_mean, 4) if lesion_voxels else None
    )

    decision = decide_qc_status(
        geometry_matches_original=bool(geometry_matches_original),
        outside_lesion_correlation=outside_lesion_correlation,
        correlation_drop_vs_control=correlation_drop_vs_control,
        lesion_voxels=lesion_voxels,
        min_outside_corr=args.min_outside_corr,
        max_corr_drop=args.max_corr_drop,
        fail_on_thresholds=args.fail_on_thresholds,
    )
    ok = decision["ok"]

    result = {
        "original": str(args.original),
        "inpainted": str(args.inpainted),
        "original_shape": list(original_img.shape),
        "inpainted_shape": list(inpainted_img.shape),
        "original_zooms": [round(float(z), 4) for z in original_img.header.get_zooms()[:3]],
        "inpainted_zooms": [round(float(z), 4) for z in inpainted_img.header.get_zooms()[:3]],
        "geometry_matches_original": bool(geometry_matches_original),
        "mask_used_for_qc": str(args.mask),
        "intensity_rescale_slope": round(float(rescale_slope), 6),
        "intensity_rescale_intercept": round(float(rescale_intercept), 4),
        "regenerated_voxels_diff_threshold": round(diff_threshold, 4),
        "regenerated_voxels": regenerated_voxels,
        "lesion_voxels": lesion_voxels,
        "outside_lesion_voxels": outside_lesion_voxels,
        "outside_lesion_correlation": outside_lesion_correlation,
        "resampling_control_correlation": resampling_control_correlation,
        "correlation_drop_vs_control": correlation_drop_vs_control,
        "lesion_relative_intensity_before": lesion_relative_intensity_before,
        "lesion_relative_intensity_after": lesion_relative_intensity_after,
        "ok": ok,
        "hard_failures": decision["hard_failures"],
        "threshold_notes": decision["threshold_notes"],
        "fail_on_thresholds": decision["fail_on_thresholds"],
        "optional_defaults": {
            "min_outside_corr": args.min_outside_corr,
            "max_corr_drop": args.max_corr_drop,
            "published_cutoff": False,
        },
        "inspection_note": PUBLIC_INSPECTION_NOTE,
    }
    if decision["failures"]:
        result["failures"] = decision["failures"]

    args.json.parent.mkdir(parents=True, exist_ok=True)
    args.json.write_text(json.dumps(result, indent=2) + "\n")

    log(
        f"outside_lesion_correlation={outside_lesion_correlation} "
        f"control={resampling_control_correlation} drop={correlation_drop_vs_control} "
        f"regenerated_voxels={regenerated_voxels} ok={ok}"
    )
    log(PUBLIC_INSPECTION_NOTE)
    for note in decision["threshold_notes"]:
        log(f"NOTE: {note}")
    if not ok:
        for f in decision["failures"]:
            log(f"FAILURE: {f}")


if __name__ == "__main__":
    main()
