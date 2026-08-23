#!/usr/bin/env python3
"""Render static QC figures for documentation (from local golden runs).

Reads from a gitignored dwi_test_TBI RESULTS_ROOT and writes to docs/img/qc/.
Do not commit participant-derived PNGs; regenerate locally when needed.
"""

from __future__ import annotations

import csv
import os
from pathlib import Path

import matplotlib

matplotlib.use("Agg")
import matplotlib.pyplot as plt
import numpy as np

ROOT = Path(__file__).resolve().parents[1]
SUBJECT = os.environ.get("QC_DOC_SUBJECT", "EXAMPLE")
RESULTS_SUFFIX = os.environ.get("QC_DOC_RESULTS_SUFFIX", "fastsurfer_inpaint")
GOLDEN = ROOT / "dwi_test_TBI" / f"sub-{SUBJECT}_{RESULTS_SUFFIX}"
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
    conn = GOLDEN / "connectomes" / f"sub-{SUBJECT}" / "dkt_connectome.csv"
    disc = (
        GOLDEN
        / "connectomes"
        / f"sub-{SUBJECT}"
        / "disconnectome"
        / "disconnection_matrix_C.csv"
    )
    if not conn.is_file():
        raise SystemExit(f"Missing golden connectome: {conn}")
    slug = SUBJECT.lower()
    _heatmap(conn, f"DKT connectome ({SUBJECT}, count)", OUT / f"{slug}_connectome.png")
    if disc.is_file():
        _heatmap(
            disc,
            f"Disconnection matrix option C ({SUBJECT})",
            OUT / f"{slug}_disconnection.png",
            vmax=1.0,
        )


if __name__ == "__main__":
    main()
