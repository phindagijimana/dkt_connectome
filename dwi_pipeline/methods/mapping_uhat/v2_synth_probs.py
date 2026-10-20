#!/usr/bin/env python3
"""V2 synth-probs: train use_probs on synthetic contrasts, sample phi. Not hat{U}."""

from __future__ import annotations

import json
import os
import socket
import sys
from pathlib import Path

import numpy as np
import torch
import torch.nn as nn
import torch.nn.functional as F

HERE = Path(__file__).resolve().parent
LOCK = HERE / "work" / "V2" / "SYNTH_PROBS_LOCK.json"
INV = HERE / "work" / "inventory.json"
OUT = HERE / "work" / "V2" / "synth_probs"
SESSIONS = (
    "ideas-sub-1-ses-1",
    "ideas-sub-6-ses-1",
    "btc-sub-PAT20-ses-preop",
    "tbi-011011-neurolit-lesion",
    "tbi-011021-neurolit-lesion",
    "tbi-011204-neurolit-lesion",
)
SIZE = 64
N_LABELS = 8
STEPS = 3000
N_SAMPLES = 8
IMAGE_SIGMA = 0.01
PRIOR_LAMBDA = 25.0
NB_FEATURES = (16, 16, 16)


def _device() -> torch.device:
    return torch.device("cuda" if torch.cuda.is_available() else "cpu")


class VxmPairwiseProbs(nn.Module):
    """VxmPairwise backbone with Dalca mean+log_sigma sample head."""

    def __init__(self, device: str = "cpu"):
        super().__init__()
        import voxelmorph.nn.models as models
        import voxelmorph.nn.modules as modules

        self.core = models.VxmPairwise(
            ndim=3,
            source_channels=1,
            target_channels=1,
            nb_features=NB_FEATURES,
            integration_steps=5,
            device=device,
        )
        self.log_sigma = nn.Conv3d(3, 3, kernel_size=3, padding=1)
        nn.init.normal_(self.log_sigma.weight, mean=0.0, std=1e-10)
        nn.init.constant_(self.log_sigma.bias, -10.0)
        self.integrator = modules.IntegrateVelocityField(steps=5)
        self.transformer = modules.SpatialTransformer()
        self.use_probs = True

    def forward(self, source: torch.Tensor, target: torch.Tensor, sample: bool = True):
        feats = self.core.model(torch.cat([source, target], dim=1))
        mean = self.core.flow_layer(feats)
        log_sigma = self.log_sigma(feats)
        if sample:
            velocity = mean + torch.exp(log_sigma) * torch.randn_like(mean)
        else:
            velocity = mean
        disp = self.integrator(velocity)
        warped = self.transformer(source, disp)
        return {
            "mean": mean,
            "log_sigma": log_sigma,
            "velocity": velocity,
            "disp": disp,
            "warped": warped,
        }


def kl_loss(mean: torch.Tensor, log_sigma: torch.Tensor, prior_lambda: float = PRIOR_LAMBDA) -> torch.Tensor:
    """Port of voxelmorph.losses.KL (Dalca 2019 GMRF). Channels-first."""
    prec = mean.new_zeros(())
    for dim in (2, 3, 4):
        a = mean.narrow(dim, 1, mean.size(dim) - 1)
        b = mean.narrow(dim, 0, mean.size(dim) - 1)
        prec = prec + (a - b).pow(2).mean()
    prec = 0.5 * prec / 3.0
    sigma_term = (prior_lambda * 6.0 * torch.exp(log_sigma) - log_sigma).mean()
    return 0.5 * 3.0 * (sigma_term + prior_lambda * prec)


def random_labels(size: int, device: torch.device) -> torch.Tensor:
    zz, yy, xx = torch.meshgrid(
        torch.arange(size, device=device, dtype=torch.float32),
        torch.arange(size, device=device, dtype=torch.float32),
        torch.arange(size, device=device, dtype=torch.float32),
        indexing="ij",
    )
    vol = torch.zeros((size, size, size), dtype=torch.long, device=device)
    for lab in range(1, N_LABELS):
        c = torch.rand(3, device=device) * size
        r = 6.0 + torch.rand(3, device=device) * (size / 4.0)
        mask = ((zz - c[0]) / r[0]).pow(2) + ((yy - c[1]) / r[1]).pow(2) + ((xx - c[2]) / r[2]).pow(2) <= 1.0
        vol[mask] = lab
    return vol


def labels_to_image(labels: torch.Tensor) -> torch.Tensor:
    out = torch.zeros(labels.shape, dtype=torch.float32, device=labels.device)
    for lab in labels.unique():
        mask = labels == lab
        mean = 0.1 + 0.8 * torch.rand((), device=labels.device)
        noise = 0.05 * torch.randn(int(mask.sum()), device=labels.device)
        out[mask] = (mean + noise).clamp(0.0, 1.0)
    return out


def warp_labels(labels: torch.Tensor, disp: torch.Tensor) -> torch.Tensor:
    """Nearest-neighbor warp of a (D,H,W) label volume by disp (1,3,D,H,W)."""
    lab = labels.float()[None, None]
    warped = F.grid_sample(
        lab,
        _disp_to_grid(disp),
        mode="nearest",
        padding_mode="zeros",
        align_corners=True,
    )
    return warped[0, 0].long()


def _disp_to_grid(disp: torch.Tensor) -> torch.Tensor:
    """Voxel displacement (B,3,D,H,W) -> grid_sample coords (B,D,H,W,3) in [-1,1]."""
    b, _, d, h, w = disp.shape
    zz = torch.linspace(-1.0, 1.0, d, device=disp.device)
    yy = torch.linspace(-1.0, 1.0, h, device=disp.device)
    xx = torch.linspace(-1.0, 1.0, w, device=disp.device)
    grid = torch.stack(torch.meshgrid(zz, yy, xx, indexing="ij"), dim=-1)
    scale = torch.tensor([2.0 / max(d - 1, 1), 2.0 / max(h - 1, 1), 2.0 / max(w - 1, 1)], device=disp.device)
    # disp channels are (z,y,x) in voxels; grid_sample wants (x,y,z)
    delta = disp.permute(0, 2, 3, 4, 1) * scale
    delta = torch.stack([delta[..., 2], delta[..., 1], delta[..., 0]], dim=-1)
    return (grid + delta).expand(b, -1, -1, -1, -1)


def make_pair(device: torch.device) -> tuple[torch.Tensor, torch.Tensor]:
    labels = random_labels(SIZE, device)
    src = labels_to_image(labels)
    coarse = torch.randn(1, 3, 8, 8, 8, device=device) * 1.5
    disp = F.interpolate(coarse, size=(SIZE, SIZE, SIZE), mode="trilinear", align_corners=True)
    labels_t = warp_labels(labels, disp)
    tgt = labels_to_image(labels_t)
    return src[None, None], tgt[None, None]


def _volume64(path: Path) -> np.ndarray:
    import nibabel as nib

    vol = np.asanyarray(nib.load(str(path)).dataobj, dtype=np.float32)
    if vol.ndim == 4:
        vol = vol[..., 0]
    t = torch.from_numpy(vol)[None, None]
    t = F.interpolate(t, size=(SIZE, SIZE, SIZE), mode="trilinear", align_corners=True)
    arr = t[0, 0].numpy()
    lo, hi = np.percentile(arr, (1, 99))
    arr = np.clip(arr, lo, hi)
    if hi > lo:
        arr = (arr - lo) / (hi - lo)
    return arr


def train(model: VxmPairwiseProbs, device: torch.device) -> dict:
    opt = torch.optim.Adam(model.parameters(), lr=1e-4)
    hist = []
    model.train()
    for step in range(1, STEPS + 1):
        src, tgt = make_pair(device)
        out = model(src, tgt, sample=True)
        img = F.mse_loss(out["warped"], tgt) / (IMAGE_SIGMA ** 2)
        kll = kl_loss(out["mean"], out["log_sigma"])
        loss = img + kll
        opt.zero_grad()
        loss.backward()
        opt.step()
        if step == 1 or step % 100 == 0 or step == STEPS:
            rec = {
                "step": step,
                "loss": float(loss.detach().cpu()),
                "img": float(img.detach().cpu()),
                "kl": float(kll.detach().cpu()),
            }
            hist.append(rec)
            print(json.dumps(rec), flush=True)
    ckpt = {
        "use_probs": True,
        "train_grid": [SIZE, SIZE, SIZE],
        "image_sigma": IMAGE_SIGMA,
        "prior_lambda": PRIOR_LAMBDA,
        "steps": STEPS,
        "state_dict": {k: v.detach().cpu() for k, v in model.state_dict().items()},
        "history": hist,
    }
    torch.save(ckpt, OUT / "checkpoint.pt")
    (OUT / "train.json").write_text(json.dumps({"history": hist, "use_probs": True}, indent=2) + "\n")
    return ckpt


def infer(model: VxmPairwiseProbs, device: torch.device) -> dict:
    model.eval()
    inv = {s["session_id"]: s for s in json.loads(INV.read_text())["sessions"]}
    rows = []
    all_ok = True
    for sid in SESSIONS:
        rec = inv[sid]
        t1, dwi = Path(rec["t1w"]), Path(rec["dwiref"])
        if not t1.is_file() or not dwi.is_file():
            rows.append({"session_id": sid, "status": "missing_images"})
            all_ok = False
            continue
        src = torch.from_numpy(_volume64(t1)[None, None]).float().to(device)
        tgt = torch.from_numpy(_volume64(dwi)[None, None]).float().to(device)
        samples = []
        with torch.no_grad():
            for _ in range(N_SAMPLES):
                samples.append(model(src, tgt, sample=True)["disp"].detach().cpu().numpy())
        arr = np.stack(samples, axis=0)
        npy = OUT / f"{sid}_phi_samples.npy"
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
                "sample_std_median": float(np.median(arr.std(axis=0))),
                "label": "dalca_samples",
                "grid": f"{SIZE}^3",
            }
        )
    return {"sessions": rows, "all_ok": all_ok}


def main() -> int:
    lock = json.loads(LOCK.read_text())
    if not lock.get("locked"):
        raise SystemExit("SYNTH_PROBS_LOCK not locked")
    OUT.mkdir(parents=True, exist_ok=True)
    device = _device()
    torch.manual_seed(0)
    model = VxmPairwiseProbs(device=str(device)).to(device)
    print(
        json.dumps(
            {
                "host": socket.gethostname(),
                "job": os.environ.get("SLURM_JOB_ID"),
                "device": str(device),
                "gpu": torch.cuda.get_device_name(0) if device.type == "cuda" else None,
                "use_probs": True,
                "dataset": "synthmorph_style_synthetics",
            },
            indent=2,
        ),
        flush=True,
    )
    train(model, device)
    infer_rec = infer(model, device)
    summary = {
        "experiment": "V2_SYNTH_PROBS",
        "status": "ok_samples" if infer_rec["all_ok"] else "fail",
        "v2_full_win": bool(infer_rec["all_ok"]),
        "use_probs": True,
        "dataset": "synthmorph_style_synthetics",
        "train_grid": [SIZE, SIZE, SIZE],
        "n_samples": N_SAMPLES,
        "host": socket.gethostname(),
        "job": os.environ.get("SLURM_JOB_ID"),
        "python": sys.executable,
        "device": str(device),
        "sessions": infer_rec["sessions"],
        "not_hatU": True,
        "not_leftover_mm": True,
        "not_inventory_train": True,
        "label": "dalca_samples",
        "claim": (
            "Trained use_probs on synthetic contrasts. Wrote sample warps. "
            "64^3. Not leftover mm. Not hat{U}."
            if infer_rec["all_ok"]
            else "Synth-probs infer failed. Not hat{U}."
        ),
    }
    (OUT / "synth_probs.json").write_text(json.dumps(summary, indent=2) + "\n")
    print(
        json.dumps(
            {
                "status": summary["status"],
                "v2_full_win": summary["v2_full_win"],
                "use_probs": True,
                "n_ok": sum(1 for r in infer_rec["sessions"] if r.get("status") == "ok"),
            },
            indent=2,
        )
    )
    return 0 if infer_rec["all_ok"] else 1


if __name__ == "__main__":
    raise SystemExit(main())
