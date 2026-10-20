#!/usr/bin/env python3
"""L2 plant: leftover-sized endpoint translation. Same (t,ehat) as L. Not hat{U}."""

from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

import nibabel as nib
import numpy as np

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))

from assign_frozen import RADIAL_MM, assign_endpoints, connectome_from_assignments  # noqa: E402

INDEX = {
    "tbi-011011-neurolit-lesion": 0,
    "tbi-011021-neurolit-lesion": 1,
    "tbi-011204-neurolit-lesion": 2,
}


def translate_endpoints(ends: np.ndarray, t_mm: float, ehat: np.ndarray) -> np.ndarray:
    delta = (np.asarray(ehat, dtype=np.float64) * float(t_mm)).astype(np.float32)
    out = np.asarray(ends, dtype=np.float32).copy()
    out += delta
    return out


def main() -> int:
    ap = argparse.ArgumentParser(description="L2 leftover-sized endpoint plant. Not hat{U}.")
    ap.add_argument("--session-id", required=True)
    ap.add_argument("--a6", type=Path, default=HERE / "work" / "a6")
    ap.add_argument("--l1", type=Path, default=HERE / "work" / "L")
    ap.add_argument("--work", type=Path, default=HERE / "work" / "L2")
    args = ap.parse_args()
    sid = args.session_id
    if sid not in INDEX:
        raise SystemExit(f"L2 locked to held-out TBI; got {sid}")
    src = args.l1 / sid / "plant.json"
    if not src.is_file():
        raise SystemExit(f"missing L plant vectors {src}")
    plant = json.loads(src.read_text())
    out = args.work / sid
    out.mkdir(parents=True, exist_ok=True)
    dest = out / "C_leftover.npy"
    meta_p = out / "plant.json"
    if dest.is_file() and meta_p.is_file():
        print(json.dumps({"session_id": sid, "skip": True}))
        return 0
    plant = {
        **plant,
        "operator": "endpoints += t*ehat; L0 fixed",
        "reused_L_vector": True,
        "experiment": "L2",
    }
    meta_p.write_text(json.dumps(plant, indent=2) + "\n")
    l0 = nib.load(str(args.a6 / sid / "L0_dkt.nii.gz"))
    nodes = np.rint(l0.get_fdata()).astype(np.int32)
    aff = np.asarray(l0.affine, dtype=np.float64)
    ends = translate_endpoints(np.load(args.a6 / sid / "ends_identity.npy"), plant["t_mm"], plant["ehat"])
    print(f"[L2] assign {sid} n={ends.shape[0]} t={plant['t_mm']:.4f} mm", flush=True)
    asg = assign_endpoints(ends, nodes, aff, kind="radial", radius_mm=RADIAL_MM)
    mat = connectome_from_assignments(asg)
    np.save(dest, mat.astype(np.float32))
    c0 = np.load(args.a6 / sid / "C000_identity.npy")
    plant["n_streamlines"] = int(ends.shape[0])
    plant["C_sum"] = float(mat.sum() / 2.0)
    plant["C_max_abs_vs_C0"] = float(np.max(np.abs(mat - c0)))
    plant["noop"] = bool(plant["C_max_abs_vs_C0"] == 0)
    meta_p.write_text(json.dumps(plant, indent=2) + "\n")
    print(json.dumps({"session_id": sid, "t_mm": plant["t_mm"], "C_max_abs": plant["C_max_abs_vs_C0"]}))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
