#!/usr/bin/env python3
"""Stage ≥2 visits for V2C-Long (TEST_DATASET_LONG) and write longitudinal CSV."""

from __future__ import annotations

import argparse
import csv
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
    aff = np.diag([1.0, 1.0, 1.0, 1.0])
    aff[:3, 3] = -0.5 * (np.array(PATCH) - 1)
    nib.save(nib.Nifti1Image(out, aff), str(nii))


def _fs_visit(subjects_dir: Path, sid: str, scan_id: str, raw_dir: Path, fs_sif: str, fs_license: str) -> None:
    sub = subjects_dir / sid / "mri"
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
        raise SystemExit(f"missing orig/aseg under {sub} for {sid}")
    out = raw_dir / scan_id
    out.mkdir(parents=True, exist_ok=True)
    mri_p = out / "mri.nii.gz"
    aseg_p = out / "aseg.nii.gz"
    _mgz_to_nii(orig, mri_p, fs_sif or None, fs_license or None)
    _mgz_to_nii(aseg, aseg_p, fs_sif or None, fs_license or None)
    _fit_patch(mri_p, is_seg=False)
    _fit_patch(aseg_p, is_seg=True)


def _t1_visit(t1: Path, aseg: Path | None, scan_id: str, raw_dir: Path) -> None:
    if not t1.is_file():
        raise SystemExit(f"missing T1: {t1}")
    out = raw_dir / scan_id
    out.mkdir(parents=True, exist_ok=True)
    mri_p = out / "mri.nii.gz"
    shutil.copy2(t1, mri_p)
    _fit_patch(mri_p, is_seg=False)
    if aseg and aseg.is_file():
        aseg_p = out / "aseg.nii.gz"
        shutil.copy2(aseg, aseg_p)
        _fit_patch(aseg_p, is_seg=True)
    else:
        raise SystemExit(
            f"V2C-Long requires aseg for {scan_id}; pass --aseg or stage from FastSurfer SUBJECTS_DIR"
        )


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--raw-dir", type=Path, required=True, help="V2C_LONG_RAW_DATA_DIR root")
    ap.add_argument("--csv-out", type=Path, required=True)
    ap.add_argument("--ptid", required=True, help="PTID column (e.g. sub-EG)")
    ap.add_argument(
        "--visit",
        action="append",
        default=[],
        metavar="SCAN_ID:T1[:ASEG]",
        help="Repeat per timepoint (scan folder name under raw-dir)",
    )
    ap.add_argument("--subjects-dir", type=Path, default=None)
    ap.add_argument("--sid", default="", help="With --subjects-dir, FS subject folder name")
    ap.add_argument(
        "--scan-ids",
        default="",
        help="Comma-separated scan ids when using two FS trees via --subjects-dir (single dir only)",
    )
    ap.add_argument("--fs-sif", default=os.environ.get("SIF_FREESURFER", ""))
    ap.add_argument("--fs-license", default=os.environ.get("FS_LICENSE", ""))
    ap.add_argument("--split", default="test")
    args = ap.parse_args()

    args.raw_dir.mkdir(parents=True, exist_ok=True)
    visits: list[tuple[str, Path | None, Path | None]] = []

    if args.visit:
        for spec in args.visit:
            parts = spec.split(":")
            if len(parts) < 2:
                raise SystemExit(f"bad --visit {spec!r}")
            scan_id, t1 = parts[0], Path(parts[1])
            aseg = Path(parts[2]) if len(parts) > 2 else None
            visits.append((scan_id, t1, aseg))
    elif args.subjects_dir and args.sid:
        scan_ids = [x.strip() for x in args.scan_ids.split(",") if x.strip()]
        if len(scan_ids) < 2:
            scan_ids = [f"{args.sid}_tp0", f"{args.sid}_tp1"]
        for scan_id in scan_ids:
            _fs_visit(
                args.subjects_dir,
                args.sid,
                scan_id,
                args.raw_dir,
                args.fs_sif,
                args.fs_license,
            )
        visits = [(sid, None, None) for sid in scan_ids]
    else:
        raise SystemExit("provide --visit SCAN:T1[:ASEG] and/or --subjects-dir + --sid")

    if args.visit:
        for scan_id, t1, aseg in visits:
            assert t1 is not None
            _t1_visit(t1, aseg, scan_id, args.raw_dir)

    if len(visits) < 2:
        raise SystemExit("V2C-Long requires ≥2 visits")

    rows = []
    for i, (scan_id, _, _) in enumerate(visits):
        rows.append(
            {
                "PTID": args.ptid,
                "VISCODE": f"tp{i}",
                "IMAGEUID": scan_id,
                "OVERALLQC": "Pass",
                "SCAN_NO": i,
                "SPLIT": args.split,
                "MONTHS": float(i),
            }
        )

    fieldnames = ["PTID", "VISCODE", "IMAGEUID", "OVERALLQC", "SCAN_NO", "SPLIT", "MONTHS"]
    args.csv_out.parent.mkdir(parents=True, exist_ok=True)
    with args.csv_out.open("w", newline="") as f:
        w = csv.DictWriter(f, fieldnames=fieldnames)
        w.writeheader()
        w.writerows(rows)

    print(f"staged {len(visits)} visits under {args.raw_dir}")
    print(f"wrote {args.csv_out}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
