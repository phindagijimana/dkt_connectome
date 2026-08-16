#!/usr/bin/env python3
"""Render static QC figures for documentation (from bundled TBI golden runs)."""

from __future__ import annotations

import csv
from pathlib import Path

import matplotlib

matplotlib.use("Agg")
import matplotlib.pyplot as plt
import numpy as np

ROOT = Path(__file__).resolve().parents[1]
TBI = ROOT / "dwi_test_TBI" / "sub-TBI011011_fastsurfer_inpaint"
OUT = ROOT / "docs" / "img" / "qc"


def _read_matrix(path: Path) -> np.ndarray:
    rows: list[list[float]] = []
    with path.open() as fh:
        reader = csv.reader(fh)
        for row in reader:
            if not row:
                continue
            rows.append([float(x) for x in row])
    return np.asarray(rows, dtype=float)


def _heatmap(mat: Path, title: str, out: Path, *, vmax: float | None = None) -> None:
    data = _read_matrix(mat)
    fig, ax = plt.subplots(figsize=(6, 5), dpi=120)
    im = ax.imshow(data, cmap="viridis", vmin=0, vmax=vmax or np.nanmax(data))
    ax.set_title(title, fontsize=11)
    ax.set_xlabel("Node")
    ax.set_ylabel("Node")
    fig.colorbar(im, ax=ax, fraction=0.046, pad=0.04)
    fig.tight_layout()
    out.parent.mkdir(parents=True, exist_ok=True)
    fig.savefig(out, bbox_inches="tight")
    plt.close(fig)
    print(f"Wrote {out}")


def main() -> None:
    conn = TBI / "connectomes" / "sub-TBI011011" / "dkt_connectome.csv"
    disc = TBI / "connectomes" / "sub-TBI011011" / "disconnectome" / "disconnection_matrix_C.csv"
    if not conn.is_file():
        raise SystemExit(f"Missing golden connectome: {conn}")
    _heatmap(conn, "DKT connectome (TBI011011, count)", OUT / "tbi011011_connectome.png")
    if disc.is_file():
        _heatmap(disc, "Disconnection matrix option C (TBI011011)", OUT / "tbi011011_disconnection.png", vmax=1.0)


if __name__ == "__main__":
    main()
