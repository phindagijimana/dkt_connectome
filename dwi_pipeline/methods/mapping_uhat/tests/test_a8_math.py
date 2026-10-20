"""A8 ECE / U-as-P on tiny vectors. No 10M. Not leftover truth."""

import sys
from pathlib import Path

import numpy as np

HERE = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(HERE))

from leftover import BAND, HIGH_BIN, HIGH_BIN_N, M_BINS, bin_stats, ece, u_as_p


def test_ece_perfect_and_worst():
    p = np.array([0.1, 0.1, 0.8, 0.8])
    y = np.array([0.0, 0.0, 1.0, 1.0])
    assert ece(p, y) < 0.15
    y_flip = np.array([1.0, 1.0, 0.0, 0.0])
    assert ece(p, y_flip) > 0.7


def test_b9_window_and_empty_drop():
    p = np.array([0.05, 0.12, 0.85, 0.88])
    y = np.array([0.0, 0.0, 1.0, 1.0])
    bins = bin_stats(p, y)
    assert len(bins) == M_BINS
    assert HIGH_BIN == 9
    assert abs(bins[8]["lo"] - 0.8) < 1e-12
    assert abs(bins[8]["hi"] - 0.9) < 1e-12
    assert bins[8]["n"] == 2
    assert bins[2]["n"] == 0
    assert bins[2]["mean_p"] is None
    assert HIGH_BIN_N == 20
    assert BAND == 0.15


def test_u_as_p_locked_scale():
    out = u_as_p(np.array([0.0, 0.5, 1.0, 2.0]), 0.0, 1.0)
    assert abs(out[1] - 0.5) < 1e-12
    assert out[3] == 1.0  # clip; do not refit


if __name__ == "__main__":
    test_ece_perfect_and_worst()
    test_b9_window_and_empty_drop()
    test_u_as_p_locked_scale()
    print("test_a8_math ok")
