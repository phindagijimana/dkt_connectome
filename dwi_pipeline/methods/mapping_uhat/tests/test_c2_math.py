"""C2 tiny algebra. No 10M. Not leftover truth."""

import sys
from pathlib import Path

import numpy as np

HERE = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(HERE))

from c2_soft import auroc, leakage, same_edge, sigma_from_v1  # noqa: E402


def test_sigma_maxwell_median():
    rng = np.random.default_rng(0)
    s = sigma_from_v1(0.9)
    r = np.linalg.norm(rng.normal(0.0, s, size=(200_000, 3)), axis=1)
    assert abs(np.median(r) - 0.9) < 0.01


def test_same_edge_is_unordered():
    a0 = np.array([1, 2, 3])
    b0 = np.array([2, 3, 4])
    assert same_edge(a0, b0, np.array([2, 2, 3]), np.array([1, 3, 5])).tolist() == [True, True, False]


def test_leakage_half():
    asg0 = np.array([[1, 2], [1, 2], [2, 3], [0, 3]], dtype=np.int32)
    stay = np.array([4, 0, 4, 4], dtype=np.uint16)
    f, c0 = leakage(asg0, stay, 4, n_nodes=3)
    assert c0[0, 1] == 2 and c0[1, 2] == 1
    assert abs(f[0, 1] - 0.5) < 1e-12 and f[1, 0] == f[0, 1]
    assert f[1, 2] == 0.0 and f[0, 2] == 0.0


def test_auroc_direction():
    assert auroc(np.array([0.9, 0.8, 0.1, 0.2]), np.array([1, 1, 0, 0])) == 1.0


if __name__ == "__main__":
    test_sigma_maxwell_median()
    test_same_edge_is_unordered()
    test_leakage_half()
    test_auroc_direction()
    print("test_c2_math ok")
