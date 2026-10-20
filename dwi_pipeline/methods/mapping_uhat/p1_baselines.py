#!/usr/bin/env python3
"""P1: cheap baselines + cut sensitivity for locked U on planted 1 mm. Descriptive. Not hat{U}."""

from __future__ import annotations

import json
import sys
from pathlib import Path

import nibabel as nib
import numpy as np
from scipy.ndimage import distance_transform_edt
from scipy.stats import spearmanr

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))

from assign_frozen import N_NODES  # noqa: E402
from c2_soft import auroc  # noqa: E402
from c_calib_u import FIT, MM1, SHIP, TEST, _root  # noqa: E402

A6 = HERE / "work" / "a6"
C2 = HERE / "work" / "C2"
OUT = HERE / "work" / "P1"
FIT_SHIFTS = tuple(f"t{a}_{s}{m}mm_count.npy" for a in "xyz" for s in "mp" for m in ("0.25", "0.5"))
EPS = 1e-9


def rel_matrix(ref: np.ndarray, other: np.ndarray, floor: float) -> np.ndarray:
    rel = np.abs(ref - other) / np.maximum(np.maximum(ref, other), EPS)
    return np.where(np.maximum(ref, other) >= floor, rel, 0.0)


def u_e_mask(c0: np.ndarray, fit: list[np.ndarray], test: list[np.ndarray], floor: float):
    u = np.zeros_like(c0)
    for c in fit:
        u = np.maximum(u, rel_matrix(c0, c, floor))
    e = np.zeros_like(c0)
    for c in test:
        e = np.maximum(e, rel_matrix(c0, c, floor))
    mx = np.maximum(c0, np.maximum.reduce([c0, *fit, *test]))
    return u, e, mx >= floor


def load_maps(sid: str):
    root = _root(sid)
    c0 = np.load(root / "identity_count.npy").astype(np.float64)
    fit = [np.load(root / "u_shifts" / n).astype(np.float64) for n in FIT_SHIFTS]
    test = [np.load(root / "u_shifts" / n).astype(np.float64) for n in MM1]
    return c0, fit, test


def boundary_distance(nodes: np.ndarray, spacing: np.ndarray) -> np.ndarray:
    b = np.zeros(nodes.shape, dtype=bool)
    for ax in range(3):
        for sh in (1, -1):
            b |= nodes != np.roll(nodes, sh, axis=ax)
    return distance_transform_edt(~b, sampling=spacing)


def edge_baselines(sid: str) -> dict[str, np.ndarray]:
    l0 = nib.load(str(A6 / sid / "L0_dkt.nii.gz"))
    nodes = np.rint(l0.get_fdata()).astype(np.int32)
    aff = np.asarray(l0.affine, dtype=np.float64)
    spacing = np.sqrt((aff[:3, :3] ** 2).sum(axis=0))
    dist = boundary_distance(nodes, spacing)
    ends = np.load(A6 / sid / "ends_identity.npy", mmap_mode="r")
    asg = np.load(_root(sid) / "identity_asn.npy", mmap_mode="r")
    a, b = np.asarray(asg[:, 0]), np.asarray(asg[:, 1])
    ok = (a > 0) & (b > 0) & (a != b) & (a <= N_NODES) & (b <= N_NODES)
    lin = (np.minimum(a, b) - 1) * N_NODES + (np.maximum(a, b) - 1)
    inv = np.linalg.inv(aff)
    shape = np.asarray(nodes.shape)
    dmin = None
    unl = np.zeros(a.size, dtype=np.float64)
    for k in (0, 1):
        xyz = np.asarray(ends[:, k, :], dtype=np.float64)
        vox = np.rint(xyz @ inv[:3, :3].T + inv[:3, 3]).astype(np.int64)
        inside = np.all((vox >= 0) & (vox < shape), axis=1)
        v = np.clip(vox, 0, shape - 1)
        d = np.where(inside, dist[v[:, 0], v[:, 1], v[:, 2]], 0.0)
        lab = np.where(inside, nodes[v[:, 0], v[:, 1], v[:, 2]], 0)
        unl += (lab == 0).astype(np.float64) / 2.0
        dmin = d if dmin is None else np.minimum(dmin, d)
    length = np.linalg.norm(np.asarray(ends[:, 0, :], dtype=np.float64) - np.asarray(ends[:, 1, :], dtype=np.float64), axis=1)
    n2 = N_NODES * N_NODES
    cnt = np.bincount(lin[ok], minlength=n2).astype(np.float64)
    out = {}
    for name, val in (("boundary", dmin), ("unlabeled", unl), ("length", length)):
        s = np.bincount(lin[ok], weights=val[ok], minlength=n2)
        m = np.where(cnt > 0, s / np.maximum(cnt, 1.0), np.nan).reshape(N_NODES, N_NODES)
        m = np.where(np.isnan(m), m.T, m)
        out[name] = m
    return out


def score_row(score: np.ndarray, e: np.ndarray, y: np.ndarray) -> dict:
    ok = np.isfinite(score)
    return {
        "spearman": float(spearmanr(score[ok], e[ok]).statistic),
        "auroc": auroc(score[ok], y[ok]),
        "n": int(ok.sum()),
    }


def main() -> int:
    lock = json.loads((OUT / "LOCK.json").read_text())
    if not lock.get("locked"):
        raise SystemExit("P1 LOCK not locked")
    iu = np.triu_indices(N_NODES, 1)
    base_rows, sens_rows, checks = [], [], []
    for sid in (*FIT, *TEST):
        split = "dev" if sid in FIT else "confirm"
        c0, fit, test = load_maps(sid)
        u, e, m = u_e_mask(c0, fit, test, 10.0)
        ship = np.loadtxt(SHIP / sid / "dkt_connectome_U.csv", delimiter=",")
        checks.append({"session_id": sid, "U_recomputed_vs_ship_max_abs": float(np.max(np.abs(u - ship)))})
        mk = m[iu]
        ee, yy = e[iu][mk], (e[iu][mk] > 0.25).astype(float)
        bl = edge_baselines(sid)
        scores = {
            "U": u[iu][mk],
            "B_lowcount": -c0[iu][mk],
            "B_boundary": -bl["boundary"][iu][mk],
            "B_unlabeled": bl["unlabeled"][iu][mk],
            "B_short": -bl["length"][iu][mk],
        }
        fpath = C2 / sid / "F.npy"
        if fpath.is_file():
            scores["C2_F"] = np.load(fpath).astype(np.float64)[iu][mk]
        for name, s in scores.items():
            base_rows.append({"session_id": sid, "split": split, "score": name, "y_rate": float(yy.mean()), **score_row(s, ee, yy)})
        for cut in lock["sensitivity_grid"]["relchange_cut"]:
            for floor in lock["sensitivity_grid"]["count_floor"]:
                u2, e2, m2 = u_e_mask(c0, fit, test, float(floor))
                mk2 = m2[iu]
                y2 = (e2[iu][mk2] > cut).astype(float)
                sens_rows.append(
                    {
                        "session_id": sid,
                        "split": split,
                        "relchange_cut": cut,
                        "count_floor": floor,
                        "primary": bool(cut == 0.25 and floor == 10),
                        "n": int(mk2.sum()),
                        "y_rate": float(y2.mean()),
                        "spearman": float(spearmanr(u2[iu][mk2], e2[iu][mk2]).statistic),
                        "auroc": auroc(u2[iu][mk2], y2),
                    }
                )
        print(f"[P1] {sid} done", flush=True)
    summary = {
        "experiment": "P1",
        "descriptive": True,
        "U_algebra_check": checks,
        "baselines": base_rows,
        "sensitivity": sens_rows,
        "not_hatU": True,
    }
    (OUT / "p1_summary.json").write_text(json.dumps(summary, indent=2) + "\n")
    print(json.dumps({"U_algebra_check": checks}, indent=2))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
