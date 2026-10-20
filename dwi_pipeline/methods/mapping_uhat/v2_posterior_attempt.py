#!/usr/bin/env python3
"""V2 posterior attempt. Sample phi only if the loaded model is variational. Not hat{U}."""

from __future__ import annotations

import json
import os
import socket
import sys
from pathlib import Path

import numpy as np

HERE = Path(__file__).resolve().parent
OUT = HERE / "work" / "V2" / "posterior"
LOCK = HERE / "work" / "V2" / "POSTERIOR_LOCK.json"
INV = HERE / "work" / "inventory.json"
WEIGHTS = HERE / "work" / "V2" / "weights" / "brains-dice-vel-0.5-res-16-256f.h5"
REF = HERE / "work" / "V2" / "weights" / "ref.nii.gz"
SESSIONS = (
    "ideas-sub-1-ses-1",
    "ideas-sub-6-ses-1",
    "btc-sub-PAT20-ses-preop",
    "tbi-011011-neurolit-lesion",
    "tbi-011021-neurolit-lesion",
    "tbi-011204-neurolit-lesion",
)
N_SAMPLES_IF_PROBS = 8


def _h5_config(path: Path) -> dict:
    import h5py

    with h5py.File(path, "r") as f:
        raw = f.attrs["model_config"]
    if isinstance(raw, bytes):
        raw = raw.decode()
    return json.loads(raw)


def _resample_to_ref(path: Path, ref_img) -> np.ndarray:
    import nibabel as nib
    from nibabel.processing import resample_from_to

    img = nib.load(str(path))
    data = np.asanyarray(img.dataobj)
    if data.ndim == 4:
        data = data[..., 0]
        img = nib.Nifti1Image(data, img.affine, img.header)
    res = resample_from_to(img, (ref_img.shape, ref_img.affine), order=1)
    vol = np.asanyarray(res.dataobj, dtype=np.float32)
    lo, hi = np.percentile(vol, (1, 99))
    vol = np.clip(vol, lo, hi)
    if hi > lo:
        vol = (vol - lo) / (hi - lo)
    return vol


def main() -> int:
    lock = json.loads(LOCK.read_text())
    if not lock.get("locked"):
        raise SystemExit("POSTERIOR_LOCK not locked")
    OUT.mkdir(parents=True, exist_ok=True)

    if not WEIGHTS.is_file():
        rec = {
            "experiment": "V2_POSTERIOR_ATTEMPT",
            "status": "blocked_on_published_weights",
            "host": socket.gethostname(),
            "job": os.environ.get("SLURM_JOB_ID"),
            "not_posterior": True,
            "not_hatU": True,
            "claim": "No published h5 on disk. Not p(phi|images). Not hat{U}.",
        }
        (OUT / "posterior_attempt.json").write_text(json.dumps(rec, indent=2) + "\n")
        print(json.dumps(rec, indent=2))
        return 2

    cfg = _h5_config(WEIGHTS)
    conf = cfg.get("config", {})
    use_probs = bool(conf.get("use_probs"))
    inshape = [int(x) for x in conf.get("inshape", [])]

    import tensorflow as tf
    import voxelmorph as vxm

    model = vxm.networks.VxmDense.load(str(WEIGHTS))
    inv = {s["session_id"]: s for s in json.loads(INV.read_text())["sessions"]}
    import nibabel as nib

    ref_img = nib.load(str(REF))
    rows = []
    all_ok = True
    for sid in SESSIONS:
        rec = inv[sid]
        t1 = Path(rec["t1w"])
        dwi = Path(rec["dwiref"])
        if not t1.is_file() or not dwi.is_file():
            rows.append({"session_id": sid, "status": "missing_images"})
            all_ok = False
            continue
        moving = _resample_to_ref(t1, ref_img)
        fixed = _resample_to_ref(dwi, ref_img)
        src = moving[None, ..., None]
        trg = fixed[None, ..., None]
        if use_probs:
            warps = []
            for k in range(N_SAMPLES_IF_PROBS):
                w = model.register(src, trg)
                warps.append(np.asarray(w))
            arr = np.stack(warps, axis=0)
            npy = OUT / f"{sid}_phi_samples.npy"
            label = "dalca_samples"
        else:
            warp = model.register(src, trg)
            arr = np.asarray(warp)
            npy = OUT / f"{sid}_phihat_synthmorph.npy"
            label = "trained_point_estimate_not_posterior"
        np.save(npy, arr)
        finite = bool(np.isfinite(arr).all())
        all_ok = all_ok and finite
        rows.append(
            {
                "session_id": sid,
                "status": "ok" if finite else "nonfinite",
                "npy": str(npy),
                "shape": list(arr.shape),
                "finite": finite,
                "abs_median": float(np.median(np.abs(arr))),
                "abs_p95": float(np.percentile(np.abs(arr), 95)),
                "label": label,
                "grid": "resample_to_synthmorph_ref_no_fs_affine",
            }
        )

    if use_probs and all_ok:
        status = "ok_samples"
        claim = (
            "Dalca VxmDense use_probs wrote sample warps. "
            "Not leftover mm. Not hat{U}."
        )
    else:
        status = "blocked_on_probabilistic_weights"
        claim = (
            "Published SynthMorph brains is VxmDense use_probs=false. "
            "Wrote trained point-estimate warps only. Not p(phi|images). Not hat{U}."
        )

    summary = {
        "experiment": "V2_POSTERIOR_ATTEMPT",
        "status": status,
        "host": socket.gethostname(),
        "job": os.environ.get("SLURM_JOB_ID"),
        "python": sys.executable,
        "tf": tf.__version__,
        "vxm": getattr(vxm, "__version__", None),
        "weights": str(WEIGHTS),
        "weights_class": cfg.get("class_name"),
        "use_probs": use_probs,
        "inshape": inshape,
        "grid": "synthmorph ref.nii.gz 160x160x192; header affine only, not SAMSEG/mri_robust_register",
        "domain": "SynthMorph brains is contrast-agnostic. Still T1 vs dwiref after grid match. Not leftover mm.",
        "sessions": rows,
        "not_posterior": not use_probs,
        "not_Dalca_2019_posterior": not use_probs,
        "not_hatU": True,
        "not_leftover_mm": True,
        "v2_full_win": bool(use_probs and all_ok),
        "claim": claim,
    }
    (OUT / "posterior_attempt.json").write_text(json.dumps(summary, indent=2) + "\n")
    print(
        json.dumps(
            {
                "status": status,
                "use_probs": use_probs,
                "v2_full_win": summary["v2_full_win"],
                "n_ok": sum(1 for r in rows if r.get("status") == "ok"),
            },
            indent=2,
        )
    )
    return 0 if all_ok else 1


if __name__ == "__main__":
    raise SystemExit(main())
