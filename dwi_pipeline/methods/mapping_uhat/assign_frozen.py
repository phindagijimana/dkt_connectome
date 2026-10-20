"""Frozen radial_4 assigner (mapping_screen). Not a new radius. Not leftover U."""

from __future__ import annotations

import gzip
from pathlib import Path

import numpy as np
from numpy.typing import NDArray

N_NODES = 78
RADIAL_MM = 4.0


def extract_endpoints(tck_path: Path, max_streamlines: int | None = None) -> NDArray[np.float32]:
    """Read first/last XYZ (mm) from a .tck or .tck.gz without loading all points."""
    opener = gzip.open if str(tck_path).endswith(".gz") else open
    firsts: list[NDArray[np.float32]] = []
    lasts: list[NDArray[np.float32]] = []
    with opener(tck_path, "rb") as fh:
        data_offset: int | None = None
        while True:
            line = fh.readline()
            if not line:
                raise ValueError(f"{tck_path}: no END in tck header")
            if line.lower().startswith(b"file:"):
                parts = line.decode("ascii", "replace").split()
                if len(parts) >= 3 and parts[1] == ".":
                    data_offset = int(parts[2])
            if line.strip() == b"END":
                break
        if data_offset is not None:
            extra = data_offset - fh.tell()
            if extra > 0:
                fh.read(extra)
            elif extra < 0:
                raise ValueError(f"{tck_path}: file offset {data_offset} is before END")
        leftover = b""
        cur_first: NDArray[np.float32] | None = None
        cur_last: NDArray[np.float32] | None = None
        done = False
        while not done:
            buf = leftover + fh.read(12 * 2_000_000)
            if len(buf) < 12:
                break
            n = len(buf) // 12
            leftover = buf[n * 12 :]
            pts = np.frombuffer(buf[: n * 12], dtype="<f4").reshape(-1, 3)
            for pt in pts:
                if np.isinf(pt[0]):
                    done = True
                    break
                if np.isnan(pt[0]):
                    if cur_first is not None and cur_last is not None:
                        firsts.append(cur_first)
                        lasts.append(cur_last)
                    cur_first = None
                    cur_last = None
                    if max_streamlines is not None and len(firsts) >= max_streamlines:
                        done = True
                        break
                    continue
                if cur_first is None:
                    cur_first = pt.copy()
                cur_last = pt.copy()
        if cur_first is not None and cur_last is not None:
            if max_streamlines is None or len(firsts) < max_streamlines:
                firsts.append(cur_first)
                lasts.append(cur_last)
    if not firsts:
        raise ValueError(f"{tck_path}: no streamlines")
    out = np.empty((len(firsts), 2, 3), dtype=np.float32)
    out[:, 0] = np.stack(firsts)
    out[:, 1] = np.stack(lasts)
    return out


def _world_to_voxel(xyz: NDArray[np.float32], affine: NDArray[np.float64]) -> NDArray[np.float64]:
    inv = np.linalg.inv(affine)
    hom = np.ones((xyz.shape[0], 4), dtype=np.float64)
    hom[:, :3] = xyz
    return (inv @ hom.T).T[:, :3]


def assign_endpoints(
    endpoints: NDArray[np.float32],
    nodes: NDArray[np.int32],
    affine: NDArray[np.float64],
    kind: str,
    radius_mm: float,
    chunk: int = 250_000,
) -> NDArray[np.int32]:
    """Assign each endpoint to a node (0 = unassigned). MRtrix-style radial search."""
    n = endpoints.shape[0]
    out = np.zeros((n, 2), dtype=np.int32)
    shape = np.asarray(nodes.shape, dtype=np.int32)
    spacing = np.sqrt((affine[:3, :3] ** 2).sum(axis=0))
    for end_i in (0, 1):
        for start in range(0, n, chunk):
            sl = slice(start, min(start + chunk, n))
            vox = _world_to_voxel(endpoints[sl, end_i], affine)
            nearest = np.rint(vox).astype(np.int32)
            inside = np.all((nearest >= 0) & (nearest < shape), axis=1)
            vals = np.zeros(nearest.shape[0], dtype=np.int32)
            if np.any(inside):
                ii = nearest[inside]
                vals[inside] = nodes[ii[:, 0], ii[:, 1], ii[:, 2]]
            if kind == "end_voxels":
                out[sl, end_i] = vals
                continue
            need = vals == 0
            if not np.any(need):
                out[sl, end_i] = vals
                continue
            rad_vox = np.ceil(radius_mm / np.maximum(spacing, 1e-6)).astype(int)
            rx, ry, rz = (int(rad_vox[0]), int(rad_vox[1]), int(rad_vox[2]))
            offsets = np.array(
                [
                    (i, j, k)
                    for i in range(-rx, rx + 1)
                    for j in range(-ry, ry + 1)
                    for k in range(-rz, rz + 1)
                ],
                dtype=np.int32,
            )
            sel = np.where(need)[0]
            v = vox[sel]
            cand = nearest[sel][:, None, :] + offsets[None, :, :]
            valid = np.all((cand >= 0) & (cand < shape), axis=2)
            centres = cand.astype(np.float64)
            delta_vox = centres - v[:, None, :]
            delta_mm = delta_vox * spacing
            dist = np.sqrt((delta_mm**2).sum(axis=2))
            dist = np.where(valid, dist, np.inf)
            dist = np.where(dist <= radius_mm + 1e-6, dist, np.inf)
            labels = np.zeros(cand.shape[:2], dtype=np.int32)
            if np.any(valid):
                xyz = cand.reshape(-1, 3)
                ok = valid.ravel()
                picked = np.zeros(xyz.shape[0], dtype=np.int32)
                picked[ok] = nodes[xyz[ok, 0], xyz[ok, 1], xyz[ok, 2]]
                labels = picked.reshape(cand.shape[:2])
            labels = np.where(labels > 0, labels, 0)
            dist = np.where(labels > 0, dist, np.inf)
            best = np.argmin(dist, axis=1)
            got = labels[np.arange(labels.shape[0]), best]
            got = np.where(np.isfinite(dist[np.arange(dist.shape[0]), best]), got, 0)
            vals[sel] = got
            out[sl, end_i] = vals
    return out


def connectome_from_assignments(
    assignments: NDArray[np.int32],
    n_nodes: int = N_NODES,
    weights: NDArray[np.float32] | None = None,
) -> NDArray[np.float64]:
    mat = np.zeros((n_nodes, n_nodes), dtype=np.float64)
    a = assignments[:, 0]
    b = assignments[:, 1]
    ok = (a > 0) & (b > 0) & (a != b) & (a <= n_nodes) & (b <= n_nodes)
    w = np.ones(assignments.shape[0], dtype=np.float64) if weights is None else weights.astype(np.float64)
    ia = np.minimum(a[ok], b[ok]) - 1
    ib = np.maximum(a[ok], b[ok]) - 1
    np.add.at(mat, (ia, ib), w[ok])
    mat = mat + mat.T
    return mat
