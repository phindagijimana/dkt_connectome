#!/usr/bin/env python3
"""LeAPP-compatible virtual brain transplant (VBT).

This ports the sequence in BrainModes/LeAPP
PROCESSING/Code/Structural/Scripts/VirtualBrainTransplant.sh and
CreateTransplant.py: mirror, lesion-masked rigid registration, half-transform
midline alignment, smoothed contralesional blending, and inverse transform to
the original T1w grid.
"""

from __future__ import annotations

import argparse
import os
import shutil
import subprocess
import tempfile
from pathlib import Path

import nibabel as nib
import numpy as np
from scipy.ndimage import gaussian_filter


REQUIRED_FSL_COMMANDS = (
    "fslswapdim",
    "flirt",
    "midtrans",
    "convert_xfm",
    "fslmaths",
)


def run(*args: str) -> None:
    print("+", " ".join(args), flush=True)
    subprocess.run(args, check=True)


def require_fsl() -> Path:
    missing = [command for command in REQUIRED_FSL_COMMANDS if not shutil.which(command)]
    if missing:
        raise RuntimeError(f"missing FSL commands: {', '.join(missing)}")
    fsldir = Path(os.environ.get("FSLDIR", ""))
    identity = fsldir / "etc" / "flirtsch" / "ident.mat"
    if not identity.is_file():
        raise RuntimeError(f"missing FSL identity transform: {identity}")
    return identity


def save_like(data: np.ndarray, reference: nib.spatialimages.SpatialImage, path: Path) -> None:
    header = reference.header.copy()
    header.set_data_dtype(np.float32)
    nib.save(nib.Nifti1Image(data.astype(np.float32), reference.affine, header), path)


def create_transplant(work: Path, smoothing_factor: float) -> None:
    original_img = nib.load(work / "OrigMidline.nii.gz")
    mirror_img = nib.load(work / "MirrorMidline.nii.gz")
    mask_img = nib.load(work / "MaskMidline.nii.gz")
    original = original_img.get_fdata(dtype=np.float32)
    mirror = mirror_img.get_fdata(dtype=np.float32)
    mask = mask_img.get_fdata(dtype=np.float32) != 0
    if original.shape != mirror.shape or original.shape != mask.shape:
        raise ValueError("midline-aligned VBT inputs have different dimensions")
    if not mask.any():
        raise ValueError("VBT lesion mask is empty")

    smooth = gaussian_filter(mask.astype(np.float32), smoothing_factor)
    maximum = float(smooth.max())
    if maximum <= 0:
        raise ValueError("VBT smoothed lesion mask is empty")
    smooth[mask] = maximum
    smooth /= maximum
    smooth[smooth <= 0.1] = 0

    # This follows LeAPP CreateTransplant.py exactly. The transplant contains
    # the mirrored signal plus the original signal only in the smooth border.
    mask_inverse = 1.0 - (smooth != 0).astype(np.float32)
    smooth_inverse = 1.0 - smooth
    smooth_inverse[smooth_inverse == 1.0] = 0
    transplant = original * smooth_inverse + mirror * smooth

    save_like(mask_inverse, mask_img, work / "VBTMaskInverse.nii.gz")
    save_like(transplant, mask_img, work / "Transplant.nii.gz")


def virtual_brain_transplant(
    t1w: Path,
    mask: Path,
    output: Path,
    smoothing_factor: float,
    work: Path,
) -> None:
    identity = require_fsl()
    t1w_img = nib.load(t1w)
    mask_img = nib.load(mask)
    if t1w_img.shape != mask_img.shape or not np.allclose(t1w_img.affine, mask_img.affine):
        raise ValueError("VBT mask must already match the T1w grid and affine")

    shutil.copy2(t1w, work / "Orig.nii.gz")
    binary_mask = (mask_img.get_fdata() != 0).astype(np.float32)
    save_like(binary_mask, t1w_img, work / "Mask.nii.gz")
    save_like(1.0 - binary_mask, t1w_img, work / "Mask_invert.nii.gz")

    run("fslswapdim", str(work / "Orig.nii.gz"), "-x", "y", "z", str(work / "Mirror.nii.gz"))
    run("fslswapdim", str(work / "Mask.nii.gz"), "-x", "y", "z", str(work / "MaskMirror.nii.gz"))

    run(
        "flirt",
        "-dof",
        "6",
        "-interp",
        "nearestneighbour",
        "-in",
        str(work / "Orig.nii.gz"),
        "-inweight",
        str(work / "Mask_invert.nii.gz"),
        "-ref",
        str(work / "Mirror.nii.gz"),
        "-omat",
        str(work / "orig2mirror.mat"),
        "-out",
        str(work / "orig2mirror.nii.gz"),
    )
    run(
        "midtrans",
        f"--template={work / 'Orig.nii.gz'}",
        f"--separate={work / 'MidtransO2H'}",
        f"--out={work / 'mir2half.txt'}",
        str(work / "orig2mirror.mat"),
        str(identity),
    )

    for source, reference, transform, destination in (
        ("Orig.nii.gz", "Orig.nii.gz", "MidtransO2H0001.mat", "OrigMidline.nii.gz"),
        ("Mirror.nii.gz", "Mirror.nii.gz", "MidtransO2H0002.mat", "MirrorMidline.nii.gz"),
        ("Mask.nii.gz", "Mask.nii.gz", "MidtransO2H0001.mat", "MaskMidline.nii.gz"),
    ):
        run(
            "flirt",
            "-applyxfm",
            "-init",
            str(work / transform),
            "-in",
            str(work / source),
            "-ref",
            str(work / reference),
            "-out",
            str(work / destination),
        )

    create_transplant(work, smoothing_factor)
    run(
        "convert_xfm",
        str(work / "MidtransO2H0001.mat"),
        "-inverse",
        "-omat",
        str(work / "Mid2Orig.mat"),
    )
    for source, destination in (
        ("Transplant.nii.gz", "TransplantOrig.nii.gz"),
        ("VBTMaskInverse.nii.gz", "VBTMaskInverseOrig.nii.gz"),
    ):
        run(
            "flirt",
            "-applyxfm",
            "-init",
            str(work / "Mid2Orig.mat"),
            "-in",
            str(work / source),
            "-ref",
            str(work / "Orig.nii.gz"),
            "-out",
            str(work / destination),
        )

    run(
        "fslmaths",
        str(work / "Orig.nii.gz"),
        "-mul",
        str(work / "VBTMaskInverseOrig.nii.gz"),
        str(work / "HealthySignal.nii.gz"),
    )
    output.parent.mkdir(parents=True, exist_ok=True)
    run(
        "fslmaths",
        str(work / "HealthySignal.nii.gz"),
        "-add",
        str(work / "TransplantOrig.nii.gz"),
        str(output),
        "-odt",
        "int",
    )

    result = nib.load(output)
    if result.shape != t1w_img.shape or not np.allclose(result.affine, t1w_img.affine):
        raise RuntimeError("VBT output did not preserve the original T1w geometry")


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--t1w", type=Path, required=True)
    parser.add_argument("--mask", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument(
        "--smoothing-factor",
        type=float,
        default=2.0,
        help="Gaussian sigma in voxels, matching the LeAPP code default",
    )
    parser.add_argument("--work-dir", type=Path)
    args = parser.parse_args()
    if args.smoothing_factor <= 0:
        parser.error("--smoothing-factor must be greater than zero")

    if args.work_dir:
        args.work_dir.mkdir(parents=True, exist_ok=True)
        virtual_brain_transplant(
            args.t1w, args.mask, args.output, args.smoothing_factor, args.work_dir
        )
    else:
        with tempfile.TemporaryDirectory(prefix="vbt_") as temp:
            virtual_brain_transplant(
                args.t1w,
                args.mask,
                args.output,
                args.smoothing_factor,
                Path(temp),
            )


if __name__ == "__main__":
    main()
