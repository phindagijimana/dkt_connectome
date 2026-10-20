#!/usr/bin/env python3
"""Experiment L plant: leftover-sized label translation. Not hat{U}. Cluster only for 10M."""

from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

import nibabel as nib
import numpy as np
from scipy.ndimage import shift

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))

from assign_frozen import RADIAL_MM, assign_endpoints, connectome_from_assignments  # noqa: E402

SEED0 = 2601
INDEX = {
    "tbi-011011-neurolit-lesion": 0,
    "tbi-011021-neurolit-lesion": 1,
    "tbi-011204-neurolit-lesion": 2,
}


def draw_plant(m_k: list[float], subject_index: int) -> dict:
    rng = np.random.default_rng(SEED0 + subject_index)
    idx = int(rng.integers(0, len(m_k)))
    t = float(m_k[idx])
    vec = rng.normal(size=3)
    nrm = float(np.linalg.norm(vec))
    ehat = (vec / nrm).tolist()
    return {"k_index": idx, "t_mm": t, "ehat": ehat, "seed": SEED0 + subject_index}


def translate_labels(nodes: np.ndarray, affine: np.ndarray, t_mm: float, ehat: np.ndarray) -> np.ndarray:
    shift_world = np.asarray(ehat, dtype=np.float64) * float(t_mm)
    shift_vox = np.linalg.inv(affine[:3, :3]) @ shift_world
    return shift(nodes, shift=shift_vox, order=0, mode="constant", cval=0).astype(np.int32)


def main() -> int:
    ap = argparse.ArgumentParser(description="L leftover-sized plant. Not hat{U}.")
    ap.add_argument("--session-id", required=True)
    ap.add_argument("--a5", type=Path, default=HERE / "work" / "a5")
    ap.add_argument("--a6", type=Path, default=HERE / "work" / "a6")
    ap.add_argument("--work", type=Path, default=HERE / "work" / "L")
    args = ap.parse_args()
    sid = args.session_id
    if sid not in INDEX:
        raise SystemExit(f"L plant is locked to held-out TBI; got {sid}")
    out = args.work / sid
    out.mkdir(parents=True, exist_ok=True)
    dest = out / "C_leftover.npy"
    meta_p = out / "plant.json"
    if dest.is_file() and meta_p.is_file():
        print(json.dumps({"session_id": sid, "skip": True}))
        return 0
    leftover = json.loads((args.a5 / sid / "leftover.json").read_text())
    plant = draw_plant([float(x) for x in leftover["m_k"]], INDEX[sid])
    plant["session_id"] = sid
    plant["not_hatU"] = True
    meta_p.write_text(json.dumps(plant, indent=2) + "\n")
    l0 = nib.load(str(args.a6 / sid / "L0_dkt.nii.gz"))
    nodes = np.rint(l0.get_fdata()).astype(np.int32)
    aff = np.asarray(l0.affine, dtype=np.float64)
    moved = translate_labels(nodes, aff, plant["t_mm"], np.asarray(plant["ehat"]))
    nib.save(nib.Nifti1Image(moved.astype(np.int16), aff), str(out / "L_leftover.nii.gz"))
    ends = np.load(args.a6 / sid / "ends_identity.npy")
    print(f"[L] assign {sid} n={ends.shape[0]} t={plant['t_mm']:.4f} mm", flush=True)
    asg = assign_endpoints(ends, moved, aff, kind="radial", radius_mm=RADIAL_MM)
    mat = connectome_from_assignments(asg)
    np.save(dest, mat.astype(np.float32))
    plant["n_streamlines"] = int(ends.shape[0])
    plant["C_sum"] = float(mat.sum() / 2.0)
    meta_p.write_text(json.dumps(plant, indent=2) + "\n")
    print(json.dumps({"session_id": sid, "t_mm": plant["t_mm"], "C_sum": plant["C_sum"]}))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
