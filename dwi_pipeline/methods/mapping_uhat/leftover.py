"""A5 leftover mm + A7 proxyUhat algebra. Not hat{U}."""

from __future__ import annotations

import numpy as np

A5_FLOOR_MM = 0.05
RELCHANGE_CUT = 0.25
COUNT_FLOOR = 10
EPS = 1e-9


def relchange(a: np.ndarray, b: np.ndarray, eps: float = EPS) -> np.ndarray:
    """FORMULA.md: |a-b| / max(a, b, eps). Locked U cut. Do not retune."""
    aa = np.asarray(a, dtype=np.float64)
    bb = np.asarray(b, dtype=np.float64)
    return np.abs(aa - bb) / np.maximum(np.maximum(aa, bb), eps)


def moved_mask(
    c0: np.ndarray,
    ck: np.ndarray,
    *,
    cut: float = RELCHANGE_CUT,
    floor: int = COUNT_FLOOR,
) -> np.ndarray:
    c0 = np.asarray(c0, dtype=np.float64)
    ck = np.asarray(ck, dtype=np.float64)
    return (relchange(c0, ck) > cut) & (np.maximum(c0, ck) >= floor)


M_BINS = 10
HIGH_BIN = 9  # B9 = [0.8, 0.9)
HIGH_BIN_N = 20
BAND = 0.15


def ece(p: np.ndarray, y: np.ndarray, m: int = M_BINS) -> float:
    """Naeini 2015 equal-width ECE. Empty bins drop."""
    p = np.asarray(p, dtype=np.float64).ravel()
    y = np.asarray(y, dtype=np.float64).ravel()
    if p.size == 0:
        return float("nan")
    edges = np.linspace(0.0, 1.0, m + 1)
    acc = 0.0
    n = float(p.size)
    for i in range(m):
        lo, hi = edges[i], edges[i + 1]
        if i < m - 1:
            sel = (p >= lo) & (p < hi)
        else:
            sel = (p >= lo) & (p <= hi)
        k = int(sel.sum())
        if k == 0:
            continue
        acc += (k / n) * abs(float(y[sel].mean()) - float(p[sel].mean()))
    return float(acc)


def bin_stats(p: np.ndarray, y: np.ndarray, m: int = M_BINS) -> list[dict]:
    p = np.asarray(p, dtype=np.float64).ravel()
    y = np.asarray(y, dtype=np.float64).ravel()
    edges = np.linspace(0.0, 1.0, m + 1)
    out = []
    for i in range(m):
        lo, hi = edges[i], edges[i + 1]
        if i < m - 1:
            sel = (p >= lo) & (p < hi)
        else:
            sel = (p >= lo) & (p <= hi)
        k = int(sel.sum())
        out.append(
            {
                "bin": i + 1,
                "lo": float(lo),
                "hi": float(hi),
                "n": k,
                "mean_p": None if k == 0 else float(p[sel].mean()),
                "mean_y": None if k == 0 else float(y[sel].mean()),
            }
        )
    return out


def u_as_p(u: np.ndarray, umin: float, umax: float) -> np.ndarray:
    """Min–max scale locked on fit demos. Do not refit on TBI."""
    span = max(float(umax) - float(umin), 1e-12)
    return np.clip((np.asarray(u, dtype=np.float64) - umin) / span, 0.0, 1.0)


def apply_isotonic(
    u: np.ndarray,
    x_thresholds: np.ndarray,
    y_thresholds: np.ndarray,
) -> np.ndarray:
    """Frozen C map. 1 mm probability only. Not hat{U}."""
    x = np.asarray(x_thresholds, dtype=np.float64).ravel()
    y = np.asarray(y_thresholds, dtype=np.float64).ravel()
    if x.size == 0:
        raise ValueError("apply_isotonic: empty thresholds")
    uu = np.clip(np.asarray(u, dtype=np.float64), float(x[0]), float(x[-1]))
    return np.interp(uu, x, y)


def proxyuhat(
    c0: np.ndarray,
    cks: list[np.ndarray],
    *,
    cut: float = RELCHANGE_CUT,
    floor: int = COUNT_FLOOR,
) -> np.ndarray:
    """Empirical frequency. FORMULA.md §3. Filename must say proxyUhat. Not hat{U}."""
    if not cks:
        raise ValueError("proxyuhat: empty ensemble")
    acc = np.zeros(np.asarray(c0).shape, dtype=np.float64)
    for ck in cks:
        acc += moved_mask(c0, ck, cut=cut, floor=floor).astype(np.float64)
    return acc / float(len(cks))
