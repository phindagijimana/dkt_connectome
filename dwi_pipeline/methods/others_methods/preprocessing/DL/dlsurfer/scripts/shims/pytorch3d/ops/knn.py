"""Drop-in knn_points for SUGAR when full pytorch3d is unavailable.

SUGAR indexes the return as result_all[1] (legacy tuple API).
Uses chunked pairwise distances so fsaverage6 (~40k verts) fits in ~24GB.
"""

from __future__ import annotations

from typing import NamedTuple

import torch


class _KNN(NamedTuple):
    dists: torch.Tensor
    idx: torch.Tensor


def knn_points(p1: torch.Tensor, p2: torch.Tensor, K: int = 3, **_kwargs) -> _KNN:
    """Return (dists, idx) matching pytorch3d.ops.knn.knn_points for K-NN.

    p1, p2: (N, P, 3) or (P, 3).
    """
    if p1.dim() == 2:
        p1 = p1.unsqueeze(0)
    if p2.dim() == 2:
        p2 = p2.unsqueeze(0)

    n, p1n, _ = p1.shape
    k = min(K, p2.shape[1])
    chunk = 512 if p1n > 2048 else max(p1n, 1)
    dists_chunks = []
    idx_chunks = []
    for i in range(0, p1n, chunk):
        q = p1[:, i : i + chunk]
        d2 = torch.cdist(q, p2, p=2).pow(2)
        d, ix = torch.topk(d2, k=k, dim=-1, largest=False)
        dists_chunks.append(d)
        idx_chunks.append(ix)
        del d2
    dists = torch.cat(dists_chunks, dim=1)
    idx = torch.cat(idx_chunks, dim=1)
    return _KNN(dists=dists, idx=idx)
