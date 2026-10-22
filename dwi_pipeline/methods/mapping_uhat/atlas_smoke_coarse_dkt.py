#!/usr/bin/env python3
"""Cheap atlas smoke without Schaefer: coarse-grain DKT-78 count matrices → 39.

Aggregates existing C0/C1 by pairing node labels (1–2→1, …). Compares leftover
AUROC of L on DKT-78 vs coarse DKT-39 for KKI849.

Not a full N3 Schaefer stress (no alternate nodes on disk). Not hat{U}.
"""
from __future__ import annotations

import json
import sys
from pathlib import Path

import numpy as np

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
sys.path.insert(0, "/mnt/nfs/home/urmc-sh.rochester.edu/pndagiji/Documents/edgeuq/src")

from edgeuq.leftover_cal import leftover_y  # noqa: E402
from edgeuq.metrics import auroc  # noqa: E402
from retest_pack import session_paths  # noqa: E402

R = HERE / "work" / "R"
OUT = R / "paper2" / "within_site_kirby"
SID = "KKI849"
N_FINE = 78
N_COARSE = 39


def coarsen_matrix(c: np.ndarray) -> np.ndarray:
    """Aggregate fine 78×78 counts into 39×39 by pairing labels."""
    c = np.asarray(c, dtype=np.float64)
    out = np.zeros((N_COARSE, N_COARSE), dtype=np.float64)
    for i in range(N_FINE):
        for j in range(i + 1, N_FINE):
            ii, jj = i // 2, j // 2
            if ii == jj:
                continue
            a, b = min(ii, jj), max(ii, jj)
            out[a, b] += c[i, j]
    out = out + out.T
    return out


def load_c1(sid: str) -> np.ndarray:
    b2 = session_paths("kirby21", sid, 2)
    c1 = np.loadtxt(b2["count"], delimiter=",")
    if c1.ndim != 2:
        c1 = np.loadtxt(b2["count"])
    return np.asarray(c1, dtype=np.float64)


def eval_pair(c0: np.ndarray, c1: np.ndarray) -> dict:
    L, y, _ = leftover_y(c0, c1)
    return {
        "n_edges": int(y.size),
        "y_rate": float(y.mean()),
        "auroc_L": float(auroc(L, y)),
        "n_nodes": int(c0.shape[0]),
    }


def main() -> int:
    pack = R / f"kirby21_{SID}_ses-1"
    c0_fine = np.load(pack / "C0.npy").astype(np.float64)
    c1_fine = load_c1(SID)
    c0_coarse = coarsen_matrix(c0_fine)
    c1_coarse = coarsen_matrix(c1_fine)

    fine = eval_pair(c0_fine, c1_fine)
    coarse = eval_pair(c0_coarse, c1_coarse)
    delta = coarse["auroc_L"] - fine["auroc_L"]
    rec = {
        "smoke": "coarse_dkt39_vs_dkt78_matrix_aggregate",
        "sid": SID,
        "not_hatU": True,
        "note": "Cheap N3 stand-in: paired DKT labels → 39. Not Schaefer/Lausanne (unavailable on pilots).",
        "dkt78": fine,
        "dkt39_coarse": coarse,
        "delta_auroc_L": delta,
        "pass_heuristic": abs(delta) < 0.15,
    }
    OUT.mkdir(parents=True, exist_ok=True)
    (OUT / "atlas_smoke_coarse_dkt.json").write_text(json.dumps(rec, indent=2) + "\n")
    (OUT / "atlas_smoke_coarse_dkt.md").write_text(
        f"# Atlas smoke — coarse DKT-39 vs DKT-78 ({SID})\n\n"
        f"Not Schaefer (unavailable on pilots). Matrix aggregation by paired labels.\n\n"
        f"| Atlas | y_rate | AUROC $L$ |\n|-------|-------:|----------:|\n"
        f"| DKT-78 | {fine['y_rate']:.3f} | {fine['auroc_L']:.3f} |\n"
        f"| DKT-39 coarse | {coarse['y_rate']:.3f} | {coarse['auroc_L']:.3f} |\n\n"
        f"ΔAUROC = {delta:+.3f}; heuristic |Δ|<0.15: **{rec['pass_heuristic']}**.\n"
    )
    print(json.dumps(rec, indent=2))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
