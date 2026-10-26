#!/usr/bin/env python3
"""Closest-point surface distances (Hausdorff / Chamfer) for FreeSurfer meshes.

Works across unequal vertex counts (e.g. TopoFit template vs recon-surf).
"""

from __future__ import annotations

from pathlib import Path
from typing import Any


def surf_xyz(path: Path):
    import nibabel.freesurfer.io as fsio

    coords, faces = fsio.read_geometry(str(path))
    return coords, faces


def pairwise_distances(a_xyz, b_xyz) -> dict[str, float]:
    """Asymmetric + symmetric distances in mesh coordinate units (usually mm)."""
    import numpy as np
    from scipy.spatial import cKDTree

    ta = cKDTree(a_xyz)
    tb = cKDTree(b_xyz)
    d_ab, _ = tb.query(a_xyz, k=1, workers=-1)
    d_ba, _ = ta.query(b_xyz, k=1, workers=-1)
    return {
        "mean_a_to_b": float(np.mean(d_ab)),
        "mean_b_to_a": float(np.mean(d_ba)),
        "chamfer_mean": float(0.5 * (np.mean(d_ab) + np.mean(d_ba))),
        "hausdorff_95": float(max(np.percentile(d_ab, 95), np.percentile(d_ba, 95))),
        "hausdorff_max": float(max(np.max(d_ab), np.max(d_ba))),
        "n_a": int(a_xyz.shape[0]),
        "n_b": int(b_xyz.shape[0]),
    }


def compare_surfs(pred: Path, ref: Path) -> dict[str, Any]:
    out: dict[str, Any] = {
        "pred": str(pred),
        "ref": str(ref),
        "exists": pred.is_file() and ref.is_file(),
    }
    if not out["exists"]:
        return out
    try:
        a, _ = surf_xyz(pred)
        b, _ = surf_xyz(ref)
        out.update(pairwise_distances(a, b))
    except Exception as exc:  # noqa: BLE001
        out["error"] = str(exc)
    return out
