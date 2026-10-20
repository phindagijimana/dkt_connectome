#!/usr/bin/env python3
"""V2 CPU smoke: one VxmPairwise pass on 32^3. Not a posterior. Not hat{U}."""

from __future__ import annotations

import json
import sys
from pathlib import Path

import numpy as np
import torch

HERE = Path(__file__).resolve().parent
OUT = HERE / "work" / "V2" / "smoke"
LOCK = HERE / "work" / "V2" / "SMOKE_LOCK.json"
T1 = (
    HERE.parents[1]
    / "sample_data/ideas/results/sub-1_public_demo/qsiprep_single_run_output/sub-1/anat/sub-1_desc-preproc_T1w.nii.gz"
)
DWI = (
    HERE.parents[1]
    / "sample_data/ideas/results/sub-1_public_demo/qsiprep_single_run_output/sub-1/ses-1/dwi/sub-1_ses-1_space-T1w_dwiref.nii.gz"
)
SIZE = 32


def _crop32(path: Path) -> np.ndarray:
    import nibabel as nib
    from numpy import percentile

    vol = np.asanyarray(nib.load(str(path)).dataobj, dtype=np.float32)
    if vol.ndim == 4:
        vol = vol[..., 0]
    step = tuple(max(1, s // SIZE) for s in vol.shape)
    vol = vol[:: step[0], :: step[1], :: step[2]]
    vol = vol[:SIZE, :SIZE, :SIZE]
    pad = [(0, max(0, SIZE - s)) for s in vol.shape]
    vol = np.pad(vol, pad, mode="constant")
    lo, hi = percentile(vol, (1, 99))
    vol = np.clip(vol, lo, hi)
    if hi > lo:
        vol = (vol - lo) / (hi - lo)
    return vol


def main() -> int:
    lock = json.loads(LOCK.read_text())
    if not lock.get("locked"):
        raise SystemExit("SMOKE_LOCK not locked")
    OUT.mkdir(parents=True, exist_ok=True)
    import voxelmorph.nn.models as models

    src = torch.from_numpy(_crop32(T1)[None, None]).float()
    tgt = torch.from_numpy(_crop32(DWI)[None, None]).float()
    net = models.VxmPairwise(
        ndim=3,
        source_channels=1,
        target_channels=1,
        nb_features=(8, 8, 8),
        integration_steps=1,
        device="cpu",
    )
    net.eval()
    with torch.no_grad():
        field = net(src, tgt, return_field_type="displacement")
    arr = field.detach().cpu().numpy()
    rec = {
        "experiment": "V2_CPU_SMOKE",
        "status": "ok",
        "python": sys.executable,
        "device": "cpu",
        "shape": list(arr.shape),
        "finite": bool(np.isfinite(arr).all()),
        "abs_median": float(np.median(np.abs(arr))),
        "abs_p95": float(np.percentile(np.abs(arr), 95)),
        "not_posterior": True,
        "not_hatU": True,
        "claim": "CPU VxmPairwise forward pass ran. Not p(phi|images). Not hat{U}.",
    }
    (OUT / "smoke.json").write_text(json.dumps(rec, indent=2) + "\n")
    print(json.dumps({k: rec[k] for k in ("status", "shape", "finite", "not_posterior")}, indent=2))
    return 0 if rec["finite"] else 1


if __name__ == "__main__":
    raise SystemExit(main())
