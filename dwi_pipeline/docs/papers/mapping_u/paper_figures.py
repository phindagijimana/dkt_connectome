#!/usr/bin/env python3
"""U-paper figures from locked C / UQ / leftover-mm JSON. Not hat{U}."""

from __future__ import annotations

import json
from pathlib import Path

import matplotlib.pyplot as plt
import numpy as np

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[2]
C = json.loads((ROOT / "methods/mapping_uhat/work/C/c_summary.json").read_text())
MM = json.loads((ROOT / "methods/mapping_uhat/work/leftover_mm/leftover_mm_summary.json").read_text())
DEV = json.loads((ROOT / "experiments/mapping_screen/work/followup/uq_summary.json").read_text())
CON = json.loads((ROOT / "experiments/mapping_screen/work/confirmation_uq/uq_summary.json").read_text())
OUT = HERE / "figures"
OUT.mkdir(parents=True, exist_ok=True)

SHORT = {
    "ideas-sub-1-ses-1": "IDEAS-1",
    "ideas-sub-6-ses-1": "IDEAS-6",
    "btc-sub-PAT20-ses-preop": "PAT20",
    "tbi-011011-neurolit-lesion": "TBI011011",
    "tbi-011021-neurolit-lesion": "TBI011021",
    "tbi-011204-neurolit-lesion": "TBI011204",
}


def fig_ranker() -> None:
    rows = [("dev", r) for r in DEV["sessions"]] + [("confirm", r) for r in CON["sessions"]]
    labels = [SHORT[r["session_id"]] for _, r in rows]
    sp = [r["spearman"] for _, r in rows]
    au = [r["auroc"] for _, r in rows]
    x = np.arange(len(labels))
    fig, ax = plt.subplots(figsize=(7.2, 3.6))
    ax.bar(x - 0.18, sp, 0.36, label="Spearman (U, e)", color="#1f4e79")
    ax.bar(x + 0.18, au, 0.36, label="AUROC vs 1 mm moved", color="#7a9bb8")
    ax.axhline(0.5, color="0.4", ls="--", lw=0.8)
    ax.axhline(0.7, color="0.5", ls=":", lw=0.8)
    ax.set_xticks(x)
    ax.set_xticklabels(labels, rotation=20, ha="right")
    ax.set_ylim(0, 1.05)
    ax.set_ylabel("Locked metric")
    ax.set_title("Ranker U vs planted 1 mm (not leftover)")
    ax.legend(frameon=False, loc="lower right")
    fig.tight_layout()
    fig.savefig(OUT / "fig1_ranker_U.png", dpi=200)
    plt.close(fig)


def fig_calib() -> None:
    bins = [b for b in C["bins"] if b["n"] and b["mean_p"] is not None]
    p = [b["mean_p"] for b in bins]
    y = [b["mean_y"] for b in bins]
    n = [b["n"] for b in bins]
    fig, ax = plt.subplots(figsize=(5.2, 5.0))
    ax.plot([0, 1], [0, 1], color="0.5", lw=1, ls="--", label="perfect")
    ax.scatter(p, y, s=[max(18, k / 8) for k in n], c="#1f4e79", zorder=3)
    for b in bins:
        ax.text(b["mean_p"], b["mean_y"] + 0.03, str(b["n"]), ha="center", fontsize=7, color="0.3")
    ax.set_xlim(0, 1)
    ax.set_ylim(0, 1)
    ax.set_xlabel("Mean calibrated U (1 mm P)")
    ax.set_ylabel("1 mm moved rate")
    ax.set_title(f"Calibrated U (held-out ECE {C['ECE_calibrated_U']:.3f}; not U-hat)")
    ax.set_aspect("equal")
    ax.legend(frameon=False)
    fig.tight_layout()
    fig.savefig(OUT / "fig2_calibration.png", dpi=200)
    plt.close(fig)


def fig_leftover() -> None:
    rows = MM["sessions"]
    labels = [SHORT[r["session_id"]] for r in rows]
    a5 = [r["A5_M_s_mm"] for r in rows]
    v1 = [r["V1_voxel_median_mm"] for r in rows]
    x = np.arange(len(labels))
    fig, ax = plt.subplots(figsize=(7.2, 3.6))
    ax.bar(x - 0.18, a5, 0.36, label="A5 session leftover", color="#6b3a2a")
    ax.bar(x + 0.18, v1, 0.36, label="V1 voxel-median leftover", color="#c08a5a")
    ax.axhline(1.0, color="0.4", ls="--", lw=0.8, label="1 mm plant")
    ax.set_xticks(x)
    ax.set_xticklabels(labels, rotation=20, ha="right")
    ax.set_ylabel("mm")
    ax.set_title("Leftover millimetres (limitation, not a P)")
    ax.legend(frameon=False)
    fig.tight_layout()
    fig.savefig(OUT / "fig3_leftover_mm.png", dpi=200)
    plt.close(fig)


def main() -> None:
    fig_ranker()
    fig_calib()
    fig_leftover()
    print(json.dumps({"out": str(OUT), "not_hatU": True}, indent=2))


if __name__ == "__main__":
    main()
