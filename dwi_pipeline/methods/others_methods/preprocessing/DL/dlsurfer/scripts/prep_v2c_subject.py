#!/usr/bin/env python3
"""Stage a FreeSurfer/FastSurfer subject for V2C-Flow test inference.

Creates RAW_DATA_DIR/<sid>/{mri,aseg}.nii.gz sized to V2C patch (192,208,192)
and split files. GT meshes are omitted (test mode inserts dummies).
"""

from __future__ import annotations

import argparse
import os
import shutil
import subprocess
from pathlib import Path

import nibabel as nib
import numpy as np
from scipy.ndimage import zoom


PATCH = (192, 208, 192)


def _mgz_to_nii(src: Path, dst: Path, fs_sif: str | None, license: str | None) -> None:
    dst.parent.mkdir(parents=True, exist_ok=True)
    if src.suffixes[-2:] == [".nii", ".gz"] or src.suffix == ".nii":
        shutil.copy2(src, dst)
        return
    if fs_sif and Path(fs_sif).is_file():
        cmd = [
            "apptainer",
            "exec",
            "--bind",
            f"{src.parent}:{src.parent}",
            "--bind",
            f"{dst.parent}:{dst.parent}",
            fs_sif,
            "mri_convert",
            str(src),
            str(dst),
        ]
        env = os.environ.copy()
        if license:
            env["FS_LICENSE"] = license
        subprocess.check_call(cmd, env=env)
        return
    # Fallback: nibabel reads .mgz
    img = nib.load(str(src))
    nib.save(nib.Nifti1Image(np.asanyarray(img.dataobj), img.affine), str(dst))


def _fit_patch(nii: Path, is_seg: bool) -> None:
    img = nib.load(str(nii))
    data = np.asanyarray(img.dataobj)
    if data.ndim == 4:
        data = data[..., 0]
    factors = [t / s for t, s in zip(PATCH, data.shape[:3])]
    order = 0 if is_seg else 1
    out = zoom(data.astype(np.float32), factors, order=order)
    if is_seg:
        out = np.rint(out).astype(np.int16)
    else:
        out = out.astype(np.float32)
    # Identity-like 1mm affine centered (machine gate; not paper MNI152)
    aff = np.diag([1.0, 1.0, 1.0, 1.0])
    aff[:3, 3] = -0.5 * (np.array(PATCH) - 1)
    nib.save(nib.Nifti1Image(out, aff), str(nii))


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--subjects-dir", type=Path, required=True)
    ap.add_argument("--sid", required=True, help="Subject folder under SUBJECTS_DIR")
    ap.add_argument(
        "--out-sid",
        default="",
        help="Sample id under RAW_DATA_DIR (default: same as --sid)",
    )
    ap.add_argument("--raw-dir", type=Path, required=True, help="V2C RAW_DATA_DIR")
    ap.add_argument("--fs-sif", default=os.environ.get("SIF_FREESURFER", ""))
    ap.add_argument("--fs-license", default=os.environ.get("FS_LICENSE", ""))
    args = ap.parse_args()
    out_sid = args.out_sid or args.sid

    sub = args.subjects_dir / args.sid / "mri"
    orig = next(
        (sub / n for n in ("orig.mgz", "T1.mgz", "brain.mgz", "norm.mgz") if (sub / n).is_file()),
        None,
    )
    aseg = next(
        (
            sub / n
            for n in ("aseg.mgz", "aparc.DKTatlas+aseg.deep.mgz", "aseg.auto_noCCseg.mgz")
            if (sub / n).is_file()
        ),
        None,
    )
    if orig is None or aseg is None:
        raise SystemExit(f"missing orig/aseg under {sub}")

    out = args.raw_dir / out_sid
    out.mkdir(parents=True, exist_ok=True)
    mri_p = out / "mri.nii.gz"
    aseg_p = out / "aseg.nii.gz"
    _mgz_to_nii(orig, mri_p, args.fs_sif or None, args.fs_license or None)
    _mgz_to_nii(aseg, aseg_p, args.fs_sif or None, args.fs_license or None)
    _fit_patch(mri_p, is_seg=False)
    _fit_patch(aseg_p, is_seg=True)

    # Split files (test-only arm for inference)
    for name, lines in (
        ("dlsurfer_train.txt", []),
        ("dlsurfer_val.txt", []),
        ("dlsurfer_test.txt", [out_sid]),
    ):
        p = args.raw_dir / name
        p.write_text("".join(f"{x}\n" for x in lines))

    print(f"staged {out}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
