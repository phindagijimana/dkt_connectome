"""G/C apply algebra. No leftover truth. Not hat{U}."""

import sys
from pathlib import Path

import numpy as np

HERE = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(HERE))

from leftover import apply_isotonic, moved_mask  # noqa: E402
from g_exam import FORBIDDEN_SIDS, leftover_y as g_y, occupied_bins_ok  # noqa: E402


def test_isotonic_clip_and_interp():
    p = apply_isotonic(np.array([0.0, 0.5, 1.0, 2.0]), [0.2, 0.8], [0.1, 0.9])
    assert abs(p[0] - 0.1) < 1e-12
    assert abs(p[2] - 0.9) < 1e-12
    assert abs(p[3] - 0.9) < 1e-12
    assert 0.1 < p[1] < 0.9


def test_leftover_y_uses_locked_cuts():
    a = np.array([[0.0, 100.0], [100.0, 0.0]])
    b = np.array([[0.0, 10.0], [10.0, 0.0]])
    y = g_y(a, b)
    assert bool(y[0, 1])
    assert np.array_equal(y, moved_mask(a, b).astype(np.float64))


def test_occupied_bin_band():
    p = np.concatenate([np.full(25, 0.95), np.full(25, 0.15)])
    y = np.concatenate([np.ones(25), np.zeros(25)])
    ok, bins = occupied_bins_ok(p, y)
    assert ok
    assert any(b["n"] >= 20 for b in bins)


def test_021030_forbidden():
    assert "TBI021030" in FORBIDDEN_SIDS
    assert "tbi-011011-neurolit-lesion" in FORBIDDEN_SIDS


if __name__ == "__main__":
    test_isotonic_clip_and_interp()
    test_leftover_y_uses_locked_cuts()
    test_occupied_bin_band()
    test_021030_forbidden()
    print("ok")
