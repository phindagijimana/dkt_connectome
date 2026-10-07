"""Square-matrix helpers for Paper 2B (mirrors fMRI_pipeline fc_matrix_utils)."""

from __future__ import annotations

import numpy as np


def load_square_matrix_csv(path) -> np.ndarray:
    arr = np.loadtxt(path, delimiter=",")
    if arr.ndim != 2 or arr.shape[0] != arr.shape[1]:
        raise ValueError(f"Expected square matrix, got shape {getattr(arr, 'shape', None)}")
    return arr


def upper_triangle_vector(matrix: np.ndarray) -> np.ndarray:
    n = matrix.shape[0]
    vals: list[float] = []
    for i in range(n):
        for j in range(i + 1, n):
            v = matrix[i, j]
            if np.isfinite(v):
                vals.append(float(v))
    return np.asarray(vals, dtype=float)


def safe_pearson(x: np.ndarray, y: np.ndarray) -> float:
    if x.size < 3 or y.size < 3:
        return float("nan")
    if np.std(x) == 0 or np.std(y) == 0:
        return float("nan")
    return float(np.corrcoef(x, y)[0, 1])
