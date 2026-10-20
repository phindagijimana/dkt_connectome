#!/usr/bin/env python3
"""Experiment V1: voxel leftover on phi from A5 SyN norms. Not hat{U}."""

from __future__ import annotations

import json
import sys
from pathlib import Path

import numpy as np

HERE = Path(__file__).resolve().parent
A5 = HERE / "work" / "a5"
OUT = HERE / "work" / "V"
SANITY_MM = 0.05
SESSIONS = (
    "ideas-sub-1-ses-1",
    "ideas-sub-6-ses-1",
    "btc-sub-PAT20-ses-preop",
    "tbi-011011-neurolit-lesion",
    "tbi-011021-neurolit-lesion",
    "tbi-011204-neurolit-lesion",
)


def syn_norms(session_dir: Path) -> tuple[np.ndarray, list[int], int]:
    """Stack A5 SyN leftover magnitudes. Rows = members, cols = labeled voxels."""
    stacks = []
    ks = []
    n_lab = None
    for meta_path in sorted(session_dir.glob("k*.json")):
        if meta_path.name.endswith("_summary.json"):
            continue
        meta = json.loads(meta_path.read_text())
        if meta.get("transform") != "syn":
            continue
        npy = meta.get("norms_npy")
        local = session_dir / f"{meta_path.stem}_norms.npy"
        path = Path(npy) if npy and Path(npy).is_file() else local
        if not path.is_file():
            alt = local
            if not alt.is_file():
                raise FileNotFoundError(f"missing SyN norms for {meta_path}")
            path = alt
        arr = np.load(path).astype(np.float64).ravel()
        if n_lab is None:
            n_lab = int(arr.size)
        elif int(arr.size) != n_lab:
            raise ValueError(f"norms length mismatch {meta_path}: {arr.size} vs {n_lab}")
        stacks.append(arr)
        ks.append(int(meta["k"]))
    if not stacks:
        raise FileNotFoundError(f"no SyN members in {session_dir}")
    return np.vstack(stacks), ks, int(n_lab)


def voxel_maps(stack: np.ndarray) -> tuple[np.ndarray, np.ndarray]:
    """Voxel-wise median and SD of leftover mm. SD uses ddof=1 if K>1."""
    med = np.median(stack, axis=0)
    if stack.shape[0] < 2:
        sd = np.zeros(stack.shape[1], dtype=np.float64)
    else:
        sd = np.std(stack, axis=0, ddof=1)
    return med, sd


def session_v(sid: str) -> dict:
    d = A5 / sid
    leftover = json.loads((d / "leftover.json").read_text())
    syn_ms = float(leftover["splits"]["transform"]["syn"]["M_s"])
    stack, ks, n_lab = syn_norms(d)
    med, sd = voxel_maps(stack)
    session_median = float(np.median(med))
    out_d = OUT / sid
    out_d.mkdir(parents=True, exist_ok=True)
    np.save(out_d / "phi_median.npy", med.astype(np.float32))
    np.save(out_d / "phi_sd.npy", sd.astype(np.float32))
    rec = {
        "session_id": sid,
        "K_syn": int(stack.shape[0]),
        "ks": ks,
        "n_labeled": n_lab,
        "syn_M_s_from_a5": syn_ms,
        "median_of_voxel_medians_mm": session_median,
        "median_of_voxel_sd_mm": float(np.median(sd)),
        "p95_of_voxel_medians_mm": float(np.percentile(med, 95)),
        "p95_of_voxel_sd_mm": float(np.percentile(sd, 95)),
        "sanity_delta_mm": abs(session_median - syn_ms),
        "sanity_ok": abs(session_median - syn_ms) <= SANITY_MM,
        "not_hatU": True,
        "not_proxy_hatU": True,
        "not_assignment": True,
    }
    (out_d / "session.json").write_text(json.dumps(rec, indent=2) + "\n")
    return rec


def main() -> int:
    rows = []
    for sid in SESSIONS:
        rows.append(session_v(sid))
    win = all(r["sanity_ok"] for r in rows) and len(rows) == 6
    summary = {
        "experiment": "V1",
        "win": win,
        "n_sessions": len(rows),
        "sanity_mm": SANITY_MM,
        "sessions": rows,
        "claim": (
            "voxel leftover-mm maps on labeled voxels (Hub/Kybic SyN ensemble)"
            if win
            else "V1 fail. Keep A5 session M_s."
        ),
        "not_hatU": True,
        "not_proxy_hatU": True,
        "not_Simpson": True,
        "not_VoxelMorph": True,
    }
    OUT.mkdir(parents=True, exist_ok=True)
    (OUT / "v_summary.json").write_text(json.dumps(summary, indent=2) + "\n")
    print(json.dumps({"win": win, "n": len(rows)}, indent=2))
    return 0 if win else 1


if __name__ == "__main__":
    sys.exit(main())
