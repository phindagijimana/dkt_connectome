#!/usr/bin/env python3
"""V2 GPU point estimate: VxmPairwise on 32^3 inventory crops. Not a posterior. Not hat{U}."""

from __future__ import annotations

import json
import os
import socket
import sys
from pathlib import Path

import numpy as np
import torch

HERE = Path(__file__).resolve().parent
OUT = HERE / "work" / "V2" / "gpu_phihat"
LOCK = HERE / "work" / "V2" / "GPU_LOCK.json"
INV = HERE / "work" / "inventory.json"
SESSIONS = (
    "ideas-sub-1-ses-1",
    "ideas-sub-6-ses-1",
    "btc-sub-PAT20-ses-preop",
    "tbi-011011-neurolit-lesion",
    "tbi-011021-neurolit-lesion",
    "tbi-011204-neurolit-lesion",
)
SIZE = 32


def _crop32(path: Path) -> tuple[np.ndarray, list[int]]:
    import nibabel as nib
    from numpy import percentile

    img = nib.load(str(path))
    vol = np.asanyarray(img.dataobj, dtype=np.float32)
    if vol.ndim == 4:
        vol = vol[..., 0]
    orig = [int(s) for s in vol.shape]
    step = tuple(max(1, s // SIZE) for s in vol.shape)
    vol = vol[:: step[0], :: step[1], :: step[2]]
    vol = vol[:SIZE, :SIZE, :SIZE]
    pad = [(0, max(0, SIZE - s)) for s in vol.shape]
    vol = np.pad(vol, pad, mode="constant")
    lo, hi = percentile(vol, (1, 99))
    vol = np.clip(vol, lo, hi)
    if hi > lo:
        vol = (vol - lo) / (hi - lo)
    return vol, orig


def main() -> int:
    lock = json.loads(LOCK.read_text())
    if not lock.get("locked"):
        raise SystemExit("GPU_LOCK not locked")
    if not torch.cuda.is_available():
        rec = {
            "experiment": "V2_GPU_POINT_ESTIMATE",
            "status": "fail_no_cuda",
            "host": socket.gethostname(),
            "job": os.environ.get("SLURM_JOB_ID"),
            "cuda_visible": os.environ.get("CUDA_VISIBLE_DEVICES"),
            "not_posterior": True,
            "not_hatU": True,
            "claim": "Allocated host has no CUDA. Not p(phi|images). Not hat{U}.",
        }
        OUT.mkdir(parents=True, exist_ok=True)
        (OUT / "gpu_run.json").write_text(json.dumps(rec, indent=2) + "\n")
        print(json.dumps(rec, indent=2))
        return 2

    device = "cuda"
    inv = {s["session_id"]: s for s in json.loads(INV.read_text())["sessions"]}
    import voxelmorph.nn.models as models

    torch.manual_seed(0)
    net = models.VxmPairwise(
        ndim=3,
        source_channels=1,
        target_channels=1,
        nb_features=(8, 8, 8),
        integration_steps=1,
        device=device,
    )
    net.to(device)
    net.eval()

    OUT.mkdir(parents=True, exist_ok=True)
    rows = []
    all_finite = True
    for sid in SESSIONS:
        rec = inv[sid]
        t1 = Path(rec["t1w"])
        dwi = Path(rec["dwiref"])
        if not t1.is_file() or not dwi.is_file():
            rows.append({"session_id": sid, "status": "missing_images"})
            all_finite = False
            continue
        src_np, t1_shape = _crop32(t1)
        tgt_np, dwi_shape = _crop32(dwi)
        src = torch.from_numpy(src_np[None, None]).float().to(device)
        tgt = torch.from_numpy(tgt_np[None, None]).float().to(device)
        with torch.no_grad():
            field = net(src, tgt, return_field_type="displacement")
        arr = field.detach().cpu().numpy()
        finite = bool(np.isfinite(arr).all())
        all_finite = all_finite and finite
        npy = OUT / f"{sid}_phihat.npy"
        np.save(npy, arr)
        row = {
            "session_id": sid,
            "status": "ok" if finite else "nonfinite",
            "npy": str(npy),
            "shape": list(arr.shape),
            "t1_orig_shape": t1_shape,
            "dwiref_orig_shape": dwi_shape,
            "finite": finite,
            "abs_median": float(np.median(np.abs(arr))),
            "abs_p95": float(np.percentile(np.abs(arr), 95)),
            "displacement_units": "cropped_grid_voxels",
        }
        rows.append(row)

    summary = {
        "experiment": "V2_GPU_POINT_ESTIMATE",
        "status": "ok" if all_finite and len(rows) == len(SESSIONS) else "fail",
        "label": "point_estimate_not_posterior",
        "python": sys.executable,
        "host": socket.gethostname(),
        "job": os.environ.get("SLURM_JOB_ID"),
        "device": device,
        "gpu_name": torch.cuda.get_device_name(0),
        "cuda_visible": os.environ.get("CUDA_VISIBLE_DEVICES"),
        "crop": SIZE,
        "random_init": True,
        "pretrained_weights": False,
        "sessions": rows,
        "not_posterior": True,
        "not_Dalca_2019": True,
        "not_Simpson": True,
        "not_hatU": True,
        "not_leftover_mm": True,
        "claim": (
            "Interactive GPU VxmPairwise wrote finite phi-hat crops. "
            "Random init. Not p(phi|images). Not leftover mm. Not hat{U}."
        ),
    }
    (OUT / "gpu_run.json").write_text(json.dumps(summary, indent=2) + "\n")
    print(
        json.dumps(
            {
                "status": summary["status"],
                "host": summary["host"],
                "gpu_name": summary["gpu_name"],
                "n_ok": sum(1 for r in rows if r.get("status") == "ok"),
                "not_posterior": True,
            },
            indent=2,
        )
    )
    return 0 if summary["status"] == "ok" else 1


if __name__ == "__main__":
    raise SystemExit(main())
