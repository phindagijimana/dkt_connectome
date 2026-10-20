#!/usr/bin/env python3
"""Drop the Philips isotropic/trace volume from Boekel DWI runs. Not leftover y. Not gold.

Each Boekel run ends with a volume labelled b=1000 but with a zero gradient
vector. Its signal equals the geometric mean of the run's DWIs, i.e. the scanner
trace image, not a diffusion direction. FSL eddy's GP model cannot place a
zero-direction DW volume and fails in NewSphericalKMatrix::GetHyperParGuess.
Originals are kept under boekel_dwi_retest/trace_backup/.
"""

from __future__ import annotations

import json
import shutil
from pathlib import Path

import nibabel as nib
import numpy as np

ROOT = Path(__file__).resolve().parents[4] / "sample_data/boekel_dwi_retest"
BIDS = ROOT / "bids"
BACKUP = ROOT / "trace_backup"
OUT = Path(__file__).resolve().parent / "boekel_trace_repair.json"
ZERO_NORM = 0.5
MIN_CORR = 0.9


def trace_index(bvals: np.ndarray, bvecs: np.ndarray) -> list[int]:
    norms = np.linalg.norm(bvecs, axis=0)
    return [int(i) for i in np.where((bvals > 0) & (norms < ZERO_NORM))[0]]


def geomean_match(data: np.ndarray, bvals: np.ndarray, idx: int) -> tuple[float, float]:
    """(corr, median ratio) of volume idx vs the geometric mean of the other DWIs."""
    b0 = data[..., bvals == 0].mean(-1)
    mask = b0 > np.percentile(b0, 70)
    dw = [i for i in np.where(bvals > 0)[0] if i != idx]
    gm = np.exp(np.log(np.clip(data[..., dw], 1.0, None)).mean(-1))
    t = data[..., idx][mask]
    return float(np.corrcoef(t, gm[mask])[0, 1]), float(np.median(t / gm[mask]))


def repair_run(nii: Path) -> dict:
    stub = Path(str(nii)[: -len(".nii.gz")])
    bval_p, bvec_p = stub.with_suffix(".bval"), stub.with_suffix(".bvec")
    bvals = np.loadtxt(bval_p).ravel()
    bvecs = np.loadtxt(bvec_p).reshape(3, -1)
    bad = trace_index(bvals, bvecs)
    row = {"file": str(nii), "nvol_before": int(bvals.size), "trace_idx": bad}
    rel = nii.relative_to(BIDS).parent
    dest = BACKUP / rel
    if not bad:
        row["action"] = "already_repaired" if (dest / nii.name).is_file() else "none"
        return row
    if bad != [bvals.size - 1]:
        raise SystemExit(f"{nii}: zero-vector DW volumes not only last: {bad}")
    img = nib.load(str(nii))
    data = np.asanyarray(img.dataobj)
    corr, ratio = geomean_match(data.astype(np.float32), bvals, bad[0])
    if corr < MIN_CORR:
        raise SystemExit(f"{nii}: last volume is not the trace image (corr {corr:.3f})")
    dest.mkdir(parents=True, exist_ok=True)
    for p in (nii, bval_p, bvec_p):
        if not (dest / p.name).exists():
            shutil.copy2(p, dest / p.name)
    keep = np.arange(bvals.size) != bad[0]
    hdr = img.header.copy()
    nib.save(nib.Nifti1Image(data[..., keep], img.affine, hdr), str(nii))
    bval_p.write_text(" ".join(f"{x:.6g}" for x in bvals[keep]) + "\n")
    bvec_p.write_text("\n".join(" ".join(f"{x:.8f}" for x in bvecs[i, keep]) for i in range(3)) + "\n")
    row.update(
        {
            "action": "dropped_last",
            "trace_corr_geomean": corr,
            "trace_over_geomean": ratio,
            "nvol_after": int(keep.sum()),
        }
    )
    return row


def main() -> int:
    rows = [repair_run(p) for p in sorted(BIDS.glob("sub-*/ses-*/dwi/*_dwi.nii.gz"))]
    rec = {
        "n_runs": len(rows),
        "n_dropped": sum(r["action"] == "dropped_last" for r in rows),
        "n_already_repaired": sum(r["action"] == "already_repaired" for r in rows),
        "n_untouched": sum(r["action"] == "none" for r in rows),
        "reason": "Philips trace image (b>0, zero bvec, = geometric mean of DWIs) breaks eddy GP",
        "backup": str(BACKUP),
        "not_gold": True,
        "not_leftover_y": True,
        "rows": rows,
    }
    OUT.write_text(json.dumps(rec, indent=2) + "\n")
    print(json.dumps({k: rec[k] for k in ("n_runs", "n_dropped")}, indent=2))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
