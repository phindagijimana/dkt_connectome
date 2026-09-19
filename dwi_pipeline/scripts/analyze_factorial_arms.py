#!/usr/bin/env python3
"""Factorial sensitivity analysis for experiment-arm connectome outputs.

Harvests connectome / disconnectome / node-strength matrices across
`RESULTS_ROOT/arms/<arm>/` trees and computes pre-specified Paper 1 contrasts
(std vs lesion; anatomy backends; optional Deep Atropos supplement).

Designed for single-subject pilots (e.g. sub-TBI011011) and scales unchanged
to cohort factorial runs once multiple subjects exist.

Usage:
  python3.12 dwi_pipeline/scripts/analyze_factorial_arms.py \\
    --experiment-root /path/to/sub-TBI011011_fastsurfer_experiment \\
    --subject TBI011011

Outputs under ``<experiment-root>/analysis/``:
  arm_summary.csv, contrast_metrics.csv, disconnectome_summary.csv,
  nodestrength_contrasts.csv, report.md, figures/*.png
"""

from __future__ import annotations

import argparse
import csv
import json
import math
import sys
from dataclasses import asdict, dataclass
from datetime import datetime, timezone
from pathlib import Path
from typing import Iterable

import numpy as np

# Six-arm factorial (Paper 1 core design).
FACTORIAL: dict[str, tuple[str, str]] = {
    "orig": ("orig-std", "orig-lesion"),
    "neurolit": ("neurolit-std", "neurolit-lesion"),
    "vbt": ("vbt-std", "vbt-lesion"),
}

SUPPLEMENT_ARMS = ("deep-atropos-pilot",)

CONNECTOME_VARIANTS = {
    "count": "dkt_connectome_count.csv",
    "primary": "dkt_connectome.csv",
    "sift2": "dkt_connectome_sift2.csv",
}

DISCONNECTOME_FILE = "disconnectome/disconnection_matrix.csv"
DISCONNECTOME_QC = "disconnectome/disconnectome_qc.json"
NODESTRENGTH_FILE = "node_strength/strength/per_subject/sub-{subject}_strength.csv"


@dataclass
class ArmStats:
    arm: str
    matrix_kind: str
    n_nodes: int
    n_edges_upper: int
    n_edges_active: int
    total_weight: float
    mean_edge_weight: float
    density: float
    empty_nodes: int


@dataclass
class ContrastMetrics:
    contrast_id: str
    contrast_level: str
    matrix_kind: str
    arm_a: str
    arm_b: str
    pearson_r_all: float
    pearson_r_both_active: float
    spearman_r_all: float
    mean_abs_diff: float
    median_abs_diff: float
    mean_abs_pct_change: float
    frobenius_rel_diff: float
    total_a: float
    total_b: float
    pct_total_change: float
    n_edges_compared: int


def load_matrix(path: Path) -> np.ndarray:
    rows: list[list[float]] = []
    with path.open(newline="") as fh:
        for line in fh:
            line = line.strip()
            if not line:
                continue
            rows.append([float(x) for x in line.split(",")])
    if not rows:
        raise ValueError(f"empty matrix: {path}")
    mat = np.asarray(rows, dtype=np.float64)
    if mat.shape[0] != mat.shape[1]:
        raise ValueError(f"non-square matrix {mat.shape}: {path}")
    return mat


def upper_triangle_mask(n: int) -> np.ndarray:
    return np.triu(np.ones((n, n), dtype=bool), k=1)


def active_mask(a: np.ndarray, b: np.ndarray | None = None) -> np.ndarray:
    tri = upper_triangle_mask(a.shape[0])
    if b is None:
        return tri & (a > 0)
    return tri & ((a > 0) | (b > 0))


def both_active_mask(a: np.ndarray, b: np.ndarray) -> np.ndarray:
    tri = upper_triangle_mask(a.shape[0])
    return tri & (a > 0) & (b > 0)


def pearson(x: np.ndarray, y: np.ndarray) -> float:
    if x.size < 2:
        return float("nan")
    if np.allclose(x, x[0]) or np.allclose(y, y[0]):
        return float("nan")
    return float(np.corrcoef(x, y)[0, 1])


def spearman(x: np.ndarray, y: np.ndarray) -> float:
    if x.size < 2:
        return float("nan")
    rx = np.argsort(np.argsort(x))
    ry = np.argsort(np.argsort(y))
    return pearson(rx.astype(float), ry.astype(float))


def arm_connectome_path(arms_root: Path, arm: str, subject: str, filename: str) -> Path:
    return arms_root / arm / "connectomes" / f"sub-{subject}" / filename


def summarize_arm(arm: str, matrix_kind: str, mat: np.ndarray) -> ArmStats:
    n = mat.shape[0]
    tri = upper_triangle_mask(n)
    active = tri & (mat > 0)
    n_active = int(active.sum())
    total = float(mat.sum())
    empty_nodes = int((mat.sum(axis=0) + mat.sum(axis=1) == 0).sum())
    return ArmStats(
        arm=arm,
        matrix_kind=matrix_kind,
        n_nodes=n,
        n_edges_upper=int(tri.sum()),
        n_edges_active=n_active,
        total_weight=total,
        mean_edge_weight=float(mat[active].mean()) if n_active else 0.0,
        density=n_active / int(tri.sum()) if tri.sum() else 0.0,
        empty_nodes=empty_nodes,
    )


def compare_matrices(
    arm_a: str,
    arm_b: str,
    mat_a: np.ndarray,
    mat_b: np.ndarray,
    *,
    contrast_id: str,
    contrast_level: str,
    matrix_kind: str,
) -> ContrastMetrics:
    mask = active_mask(mat_a, mat_b)
    both = both_active_mask(mat_a, mat_b)
    va = mat_a[mask]
    vb = mat_b[mask]
    ba = mat_a[both]
    bb = mat_b[both]
    diff = vb - va
    with np.errstate(divide="ignore", invalid="ignore"):
        pct = np.where(va > 0, 100.0 * diff / va, np.nan)
    fro_a = float(np.linalg.norm(mat_a))
    fro_d = float(np.linalg.norm(mat_b - mat_a))
    total_a = float(mat_a.sum())
    total_b = float(mat_b.sum())
    return ContrastMetrics(
        contrast_id=contrast_id,
        contrast_level=contrast_level,
        matrix_kind=matrix_kind,
        arm_a=arm_a,
        arm_b=arm_b,
        pearson_r_all=pearson(va, vb),
        pearson_r_both_active=pearson(ba, bb),
        spearman_r_all=spearman(va, vb),
        mean_abs_diff=float(np.abs(diff).mean()) if diff.size else float("nan"),
        median_abs_diff=float(np.median(np.abs(diff))) if diff.size else float("nan"),
        mean_abs_pct_change=float(np.nanmean(np.abs(pct))) if pct.size else float("nan"),
        frobenius_rel_diff=fro_d / fro_a if fro_a else float("nan"),
        total_a=total_a,
        total_b=total_b,
        pct_total_change=100.0 * (total_b - total_a) / total_a if total_a else float("nan"),
        n_edges_compared=int(mask.sum()),
    )


def load_nodestrength(arms_root: Path, arm: str, subject: str) -> np.ndarray | None:
    path = arms_root / arm / NODESTRENGTH_FILE.format(subject=subject)
    if not path.is_file():
        return None
    values: list[float] = []
    with path.open(newline="") as fh:
        reader = csv.DictReader(fh)
        for row in reader:
            values.append(float(row["strength"]))
    return np.asarray(values, dtype=np.float64)


def load_disconnectome_qc(arms_root: Path, arm: str, subject: str) -> dict | None:
    path = arms_root / arm / "connectomes" / f"sub-{subject}" / DISCONNECTOME_QC
    if not path.is_file():
        return None
    return json.loads(path.read_text())


def iter_contrasts(arms: Iterable[str]) -> list[tuple[str, str, str, str]]:
    """Yield (contrast_id, level, arm_a, arm_b)."""
    out: list[tuple[str, str, str, str]] = []

    for anatomy, (std_arm, lesion_arm) in FACTORIAL.items():
        out.append((f"{anatomy}_std_vs_lesion", "primary_std_vs_lesion", std_arm, lesion_arm))

    for act in ("std", "lesion"):
        refs = [FACTORIAL[k][0 if act == "std" else 1] for k in ("orig", "neurolit", "vbt")]
        labels = ("orig", "neurolit", "vbt")
        for i in range(len(labels)):
            for j in range(i + 1, len(labels)):
                out.append(
                    (
                        f"{labels[i]}_vs_{labels[j]}_{act}",
                        f"secondary_anatomy_{act}",
                        refs[i],
                        refs[j],
                    )
                )

    # ACT effect magnitude: compare lesion-std delta proxies via stored pairs already;
    # add cross-anatomy std and lesion references for interaction inspection.
    for std_a, std_b in (("orig-std", "neurolit-std"), ("orig-std", "vbt-std"), ("neurolit-std", "vbt-std")):
        out.append((f"{std_a}_vs_{std_b}", "secondary_anatomy_std", std_a, std_b))
    for les_a, les_b in (
        ("orig-lesion", "neurolit-lesion"),
        ("orig-lesion", "vbt-lesion"),
        ("neurolit-lesion", "vbt-lesion"),
    ):
        out.append((f"{les_a}_vs_{les_b}", "secondary_anatomy_lesion", les_a, les_b))

    # Deep Atropos supplement vs closest lesion-aware HSVS arm.
    for sup in SUPPLEMENT_ARMS:
        if sup in arms:
            out.append(
                (f"deep_atropos_vs_neurolit_lesion", "supplement", sup, "neurolit-lesion")
            )
            out.append((f"deep_atropos_vs_orig_lesion", "supplement", sup, "orig-lesion"))

    return out


def write_csv(path: Path, rows: list[dict]) -> None:
    if not rows:
        return
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w", newline="") as fh:
        writer = csv.DictWriter(fh, fieldnames=list(rows[0].keys()))
        writer.writeheader()
        writer.writerows(rows)


def fmt(x: float, nd: int = 4) -> str:
    if x is None or (isinstance(x, float) and (math.isnan(x) or math.isinf(x))):
        return "—"
    return f"{x:.{nd}f}"


def build_report(
    *,
    subject: str,
    experiment_root: Path,
    arm_rows: list[dict],
    contrast_rows: list[dict],
    disc_rows: list[dict],
    ns_rows: list[dict],
) -> str:
    primary = [r for r in contrast_rows if r["contrast_level"] == "primary_std_vs_lesion" and r["matrix_kind"] == "count"]
    lines = [
        "# Factorial arm analysis report",
        "",
        f"- **Subject:** sub-{subject}",
        f"- **Experiment root:** `{experiment_root}`",
        f"- **Generated:** {datetime.now(timezone.utc).isoformat()}",
        f"- **Note:** N=1 pilot — descriptive sensitivity only; not inferential.",
        "",
        "## Primary contrasts (std vs lesion, count connectome)",
        "",
        "| Anatomy | Pearson r | Mean |Δedge| | Total Δ% |",
        "|---------|-----------|-------------|----------|",
    ]
    for row in primary:
        anatomy = row["contrast_id"].replace("_std_vs_lesion", "")
        lines.append(
            f"| {anatomy} | {fmt(row['pearson_r_all'])} | {fmt(row['mean_abs_diff'], 2)} | {fmt(row['pct_total_change'], 2)}% |"
        )

    lines.extend(
        [
            "",
            "## Arm summary (count connectome)",
            "",
            "| Arm | Active edges | Total streamlines | Density | Empty nodes |",
            "|-----|--------------|-------------------|---------|-------------|",
        ]
    )
    for row in sorted(arm_rows, key=lambda r: r["arm"]):
        if row["matrix_kind"] != "count":
            continue
        lines.append(
            f"| {row['arm']} | {row['n_edges_active']} | {fmt(row['total_weight'], 0)} | {fmt(row['density'])} | {row['empty_nodes']} |"
        )

    if disc_rows:
        lines.extend(
            [
                "",
                "## Disconnectome summary (option C)",
                "",
                "| Arm | Mean disconnection | Edges disrupted | Spared / primary |",
                "|-----|-------------------|-----------------|------------------|",
            ]
        )
        for row in sorted(disc_rows, key=lambda r: r["arm"]):
            lines.append(
                f"| {row['arm']} | {fmt(row['mean_disconnection_on_primary_edges'])} | "
                f"{row['n_edges_disrupted_gt0']} | {fmt(row['total_spared_over_primary'])} |"
            )

    if ns_rows:
        lines.extend(
            [
                "",
                "## Node strength contrasts (primary std vs lesion)",
                "",
                "| Anatomy | Pearson r | Mean |Δstrength| |",
                "|---------|-----------|----------------|",
            ]
        )
        for row in ns_rows:
            lines.append(
                f"| {row['contrast_id']} | {fmt(row['pearson_r'])} | {fmt(row['mean_abs_diff'], 2)} |"
            )

    lines.extend(
        [
            "",
            "## Output files",
            "",
            "- `arm_summary.csv`",
            "- `contrast_metrics.csv`",
            "- `disconnectome_summary.csv`",
            "- `nodestrength_contrasts.csv`",
            "- `figures/contrast_heatmap_count.png`",
            "- `figures/primary_std_vs_lesion_count.png`",
            "- `figures/disconnectome_mean_by_arm.png`",
        ]
    )
    return "\n".join(lines) + "\n"


def make_figures(
    out_dir: Path,
    contrast_rows: list[dict],
    disc_rows: list[dict],
    all_arms: list[str],
) -> None:
    try:
        import matplotlib.pyplot as plt
    except ImportError:
        print("matplotlib not available — skipping figures", file=sys.stderr)
        return

    fig_dir = out_dir / "figures"
    fig_dir.mkdir(parents=True, exist_ok=True)

    count_rows = [r for r in contrast_rows if r["matrix_kind"] == "count"]
    by_id = {r["contrast_id"]: r for r in count_rows}

    # Primary bar chart: std vs lesion Pearson r.
    primary = [r for r in count_rows if r["contrast_level"] == "primary_std_vs_lesion"]
    if primary:
        fig, ax = plt.subplots(figsize=(7, 4))
        labels = [r["contrast_id"].replace("_std_vs_lesion", "") for r in primary]
        vals = [r["pearson_r_all"] for r in primary]
        ax.bar(labels, vals, color=["#4C72B0", "#55A868", "#C44E52"])
        ax.set_ylim(0, 1.05)
        ax.set_ylabel("Pearson r (count connectome)")
        ax.set_title("Primary contrast: std vs lesion-aware ACT")
        ax.axhline(1.0, color="gray", ls="--", lw=0.8)
        fig.tight_layout()
        fig.savefig(fig_dir / "primary_std_vs_lesion_count.png", dpi=150)
        plt.close(fig)

    # Heatmap of all pairwise correlations between arms (using stored contrasts).
    n = len(all_arms)
    mat = np.eye(n)
    arm_index = {a: i for i, a in enumerate(all_arms)}
    for row in count_rows:
        a, b = row["arm_a"], row["arm_b"]
        if a in arm_index and b in arm_index:
            i, j = arm_index[a], arm_index[b]
            mat[i, j] = row["pearson_r_all"]
            mat[j, i] = row["pearson_r_all"]

    fig, ax = plt.subplots(figsize=(8, 7))
    im = ax.imshow(mat, vmin=0.9, vmax=1.0, cmap="viridis")
    ax.set_xticks(range(n), all_arms, rotation=45, ha="right")
    ax.set_yticks(range(n), all_arms)
    ax.set_title("Inter-arm Pearson r (count connectome, upper-triangle edges)")
    fig.colorbar(im, ax=ax, fraction=0.046)
    fig.tight_layout()
    fig.savefig(fig_dir / "contrast_heatmap_count.png", dpi=150)
    plt.close(fig)

    if disc_rows:
        fig, ax = plt.subplots(figsize=(8, 4))
        arms = [r["arm"] for r in disc_rows]
        vals = [r["mean_disconnection_on_primary_edges"] for r in disc_rows]
        ax.bar(range(len(arms)), vals, color="#8172B3")
        ax.set_xticks(range(len(arms)), arms, rotation=45, ha="right")
        ax.set_ylabel("Mean disconnection (option C)")
        ax.set_title("Disconnectome by arm")
        fig.tight_layout()
        fig.savefig(fig_dir / "disconnectome_mean_by_arm.png", dpi=150)
        plt.close(fig)


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--experiment-root",
        type=Path,
        required=True,
        help="Path to sub-<ID>_fastsurfer_experiment (contains arms/)",
    )
    parser.add_argument("--subject", required=True, help="Subject ID without sub- prefix")
    parser.add_argument(
        "--output-dir",
        type=Path,
        default=None,
        help="Default: <experiment-root>/analysis",
    )
    args = parser.parse_args()

    subject = args.subject.removeprefix("sub-")
    experiment_root = args.experiment_root.resolve()
    arms_root = experiment_root / "arms"
    if not arms_root.is_dir():
        print(f"ERROR: missing arms/ under {experiment_root}", file=sys.stderr)
        return 1

    out_dir = (args.output_dir or experiment_root / "analysis").resolve()
    out_dir.mkdir(parents=True, exist_ok=True)

    all_arms = sorted(
        p.name
        for p in arms_root.iterdir()
        if p.is_dir() and (arms_root / p.name / "connectomes" / f"sub-{subject}").is_dir()
    )

    # Load matrices.
    matrices: dict[tuple[str, str], np.ndarray] = {}
    arm_rows: list[dict] = []
    for arm in all_arms:
        for kind, fname in CONNECTOME_VARIANTS.items():
            path = arm_connectome_path(arms_root, arm, subject, fname)
            if not path.is_file():
                continue
            mat = load_matrix(path)
            matrices[(arm, kind)] = mat
            arm_rows.append(asdict(summarize_arm(arm, kind, mat)))

    contrast_rows: list[dict] = []
    for contrast_id, level, arm_a, arm_b in iter_contrasts(all_arms):
        if arm_a not in all_arms or arm_b not in all_arms:
            continue
        for kind in CONNECTOME_VARIANTS:
            key_a, key_b = (arm_a, kind), (arm_b, kind)
            if key_a not in matrices or key_b not in matrices:
                continue
            cm = compare_matrices(
                arm_a,
                arm_b,
                matrices[key_a],
                matrices[key_b],
                contrast_id=contrast_id,
                contrast_level=level,
                matrix_kind=kind,
            )
            contrast_rows.append(asdict(cm))

    disc_rows: list[dict] = []
    for arm in all_arms:
        qc = load_disconnectome_qc(arms_root, arm, subject)
        if not qc:
            continue
        summary = qc.get("disconnection_summary", {})
        disc_rows.append(
            {
                "arm": arm,
                "weighting": qc.get("weighting", ""),
                "disconnection_spared": qc.get("disconnection_spared", ""),
                **{k: summary.get(k) for k in (
                    "n_edges_primary_gt0",
                    "n_edges_disrupted_gt0",
                    "n_edges_spared_gt_primary",
                    "mean_disconnection_on_primary_edges",
                    "mean_disconnection_unclipped",
                    "total_primary",
                    "total_spared",
                    "total_spared_over_primary",
                )},
            }
        )

    ns_rows: list[dict] = []
    ns_vectors: dict[str, np.ndarray] = {}
    for arm in all_arms:
        vec = load_nodestrength(arms_root, arm, subject)
        if vec is not None:
            ns_vectors[arm] = vec
    for anatomy, (std_arm, lesion_arm) in FACTORIAL.items():
        if std_arm not in ns_vectors or lesion_arm not in ns_vectors:
            continue
        a, b = ns_vectors[std_arm], ns_vectors[lesion_arm]
        ns_rows.append(
            {
                "contrast_id": anatomy,
                "arm_a": std_arm,
                "arm_b": lesion_arm,
                "pearson_r": pearson(a, b),
                "mean_abs_diff": float(np.abs(b - a).mean()),
                "total_a": float(a.sum()),
                "total_b": float(b.sum()),
            }
        )

    write_csv(out_dir / "arm_summary.csv", arm_rows)
    write_csv(out_dir / "contrast_metrics.csv", contrast_rows)
    write_csv(out_dir / "disconnectome_summary.csv", disc_rows)
    write_csv(out_dir / "nodestrength_contrasts.csv", ns_rows)

    report = build_report(
        subject=subject,
        experiment_root=experiment_root,
        arm_rows=arm_rows,
        contrast_rows=contrast_rows,
        disc_rows=disc_rows,
        ns_rows=ns_rows,
    )
    (out_dir / "report.md").write_text(report)
    make_figures(out_dir, contrast_rows, disc_rows, all_arms)

    print(report)
    print(f"Wrote analysis to {out_dir}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
