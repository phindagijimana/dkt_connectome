#!/usr/bin/env python3
"""Render Paper 1/2 submission figures (PDF+SVG) from locked pilot JSON.

Not hat{U}. Scale forest panels deferred. Outputs under docs/papers/mapping_uhat/figures/.
"""
from __future__ import annotations

import json
from pathlib import Path

import matplotlib

matplotlib.use("Agg")
import matplotlib.pyplot as plt
import numpy as np

HERE = Path(__file__).resolve().parent
R = HERE / "work" / "R"
N = R / "strengthen" / "N"
P2 = R / "paper2" / "within_site_kirby"
OUT = HERE.parent.parent / "docs" / "papers" / "mapping_uhat" / "figures"
OUT.mkdir(parents=True, exist_ok=True)


def _save(fig: plt.Figure, stem: str) -> None:
    for ext in ("pdf", "svg", "png"):
        fig.savefig(OUT / f"{stem}.{ext}", bbox_inches="tight", dpi=200)
    plt.close(fig)
    print(f"wrote {stem}.{{pdf,svg,png}}")


def fig_plant_neq_leftover() -> None:
    """Honesty figure: U/F/L on leftover y (Kirby mini) + plant vs leftover claim split (N16)."""
    base = json.loads((P2 / "leftover_baselines_kirby.json").read_text())
    rows = [s for s in base["subjects"] if s["sid"] != "KKI239"]
    labels = [s["sid"] for s in rows]
    metrics = ["L", "U", "F", "neg_FA", "neg_length", "random"]
    pretty = {"L": r"$L$", "U": r"$U$", "F": r"$F$", "neg_FA": r"$-$FA", "neg_length": r"$-$len", "random": "rand"}
    means = []
    for m in metrics:
        vals = [s["auroc"].get(m) for s in rows if s["auroc"].get(m) is not None]
        means.append(float(np.mean(vals)) if vals else np.nan)

    n16 = json.loads((N / "N16_simulation_plant_vs_count.json").read_text())
    pairs = n16["pairs"]

    fig, axes = plt.subplots(1, 2, figsize=(10.5, 4.2))
    ax = axes[0]
    x = np.arange(len(metrics))
    colors = ["#1b9e77", "#d95f02", "#7570b3", "#e7298a", "#66a61e", "#a6761d"]
    ax.bar(x, means, color=colors, edgecolor="black", linewidth=0.4)
    ax.axhline(0.5, color="0.5", ls="--", lw=0.8)
    ax.set_xticks(x)
    ax.set_xticklabels([pretty[m] for m in metrics])
    ax.set_ylim(0.35, 0.85)
    ax.set_ylabel("AUROC vs leftover $y$")
    ax.set_title("A. Kirby mini (n=4 excl. 239): leftover ranking")
    for i, v in enumerate(means):
        if np.isfinite(v):
            ax.text(i, v + 0.015, f"{v:.2f}", ha="center", va="bottom", fontsize=8)

    ax = axes[1]
    names = list(pairs.keys())
    width = 0.35
    churn_L = [pairs[k]["synth_count_churn"]["auroc_L"] for k in names]
    churn_U = [pairs[k]["synth_count_churn"]["auroc_U"] for k in names]
    plant_L = [pairs[k]["synth_plant_1mm_ty"]["auroc_L"] for k in names]
    plant_U = [pairs[k]["synth_plant_1mm_ty"]["auroc_U"] for k in names]
    xpos = np.arange(len(names))
    # two grouped clusters per subject: count-churn and plant
    ax.bar(xpos - width / 2 - 0.02, churn_L, width / 2, label=r"count-churn $L$", color="#1b9e77")
    ax.bar(xpos - 0.02, churn_U, width / 2, label=r"count-churn $U$", color="#d95f02")
    ax.bar(xpos + 0.02, plant_L, width / 2, label=r"plant-1mm $L$", color="#1b9e77", alpha=0.45)
    ax.bar(xpos + width / 2 + 0.02, plant_U, width / 2, label=r"plant-1mm $U$", color="#d95f02", alpha=0.45)
    ax.set_xticks(xpos)
    ax.set_xticklabels([n.split("/")[-1] for n in names])
    ax.set_ylim(0.5, 1.0)
    ax.set_ylabel("AUROC (synthetic $y$)")
    ax.set_title(r"B. Claim split (N16): plant $\neq$ leftover")
    ax.legend(fontsize=7, loc="lower right", ncol=2)
    ax.axhline(0.5, color="0.5", ls="--", lw=0.8)

    fig.suptitle(r"Plant fragility $\neq$ leftover instability (not $\hat{U}$)", fontsize=11, y=1.02)
    fig.tight_layout()
    _save(fig, "fig_plant_neq_leftover")


def fig_within_site_PL() -> None:
    """Paper 2 hinge: within-Kirby LOSO ECE and y-rates."""
    pl = json.loads((P2 / "P_L_loso_within_kirby.json").read_text())
    folds = pl["folds"]
    tests = [f["test"].split("/")[-1] for f in folds]
    ece = [f["ECE_P_L"] for f in folds]
    yrate = [f["y_rate"] for f in folds]
    auroc = [f["auroc_L"] for f in folds]

    fig, axes = plt.subplots(1, 3, figsize=(11, 3.8))
    colors = ["#4daf4a" if t != "KKI239" else "#e41a1c" for t in tests]

    ax = axes[0]
    ax.bar(range(len(tests)), ece, color=colors, edgecolor="black", linewidth=0.4)
    ax.axhline(0.18, color="#377eb8", ls="--", lw=1, label="cross-site ECE≈0.18")
    ax.axhline(0.043, color="#4daf4a", ls=":", lw=1, label="n=4 mean≈0.043")
    ax.set_xticks(range(len(tests)))
    ax.set_xticklabels(tests, rotation=30, ha="right")
    ax.set_ylabel(r"ECE($P_L$)")
    ax.set_title("A. Within-Kirby LOSO ECE")
    ax.legend(fontsize=7)

    ax = axes[1]
    ax.bar(range(len(tests)), yrate, color=colors, edgecolor="black", linewidth=0.4)
    ax.set_xticks(range(len(tests)))
    ax.set_xticklabels(tests, rotation=30, ha="right")
    ax.set_ylabel("leftover y-rate")
    ax.set_title("B. Base rates (239 outlier)")

    ax = axes[2]
    ax.bar(range(len(tests)), auroc, color=colors, edgecolor="black", linewidth=0.4)
    ax.axhline(0.5, color="0.5", ls="--", lw=0.8)
    ax.set_xticks(range(len(tests)))
    ax.set_xticklabels(tests, rotation=30, ha="right")
    ax.set_ylabel(r"AUROC($L$)")
    ax.set_ylim(0.45, 0.85)
    ax.set_title("C. Ranking $L$")

    fig.suptitle(r"Within-site $P_L$ (n=5; primary map excludes 239)", fontsize=11, y=1.03)
    fig.tight_layout()
    _save(fig, "fig_within_site_PL")


def fig_paper1_leftover_bars() -> None:
    """Paper 1 Fig3-style: mean AUROC on leftover for pilots (subset of honesty fig)."""
    # reuse Kirby n=4 means + add pilot note from manuscript for Boekel if in baselines only Kirby
    base = json.loads((P2 / "leftover_baselines_kirby.json").read_text())
    rows = [s for s in base["subjects"] if s["sid"] != "KKI239"]
    metrics = ["U", "F", "L"]
    means = [float(np.mean([s["auroc"][m] for s in rows])) for m in metrics]
    fig, ax = plt.subplots(figsize=(4.5, 3.6))
    ax.bar(metrics, means, color=["#d95f02", "#7570b3", "#1b9e77"], edgecolor="black", linewidth=0.4)
    ax.axhline(0.5, color="0.5", ls="--", lw=0.8)
    ax.set_ylim(0.4, 0.85)
    ax.set_ylabel("AUROC vs leftover $y$")
    ax.set_title("Paper 1 Claim B — leftover boundary (Kirby n=4)")
    for i, v in enumerate(means):
        ax.text(i, v + 0.02, f"{v:.2f}", ha="center")
    fig.tight_layout()
    _save(fig, "fig_paper1_leftover_boundary")


def main() -> int:
    fig_plant_neq_leftover()
    fig_within_site_PL()
    fig_paper1_leftover_bars()
    (OUT / "README.md").write_text(
        "# Paper figures (rendered)\n\n"
        "Generated by `methods/mapping_uhat/render_paper_figures.py` from locked pilot JSON.\n"
        "Not $\\hat{U}$. Scale forest panels deferred.\n\n"
        "| File | Content |\n|------|----------|\n"
        "| `fig_plant_neq_leftover` | Honesty: leftover ranking + N16 claim split |\n"
        "| `fig_within_site_PL` | Within-Kirby LOSO ECE / y-rate / AUROC |\n"
        "| `fig_paper1_leftover_boundary` | Paper 1 Claim B bars |\n"
    )
    print(f"outdir={OUT}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
