#!/usr/bin/env python3
"""Challenge A8 assumptions. Not a retune. Not a new win rule."""

from __future__ import annotations

import json
import sys
from pathlib import Path

import numpy as np

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))

from a8_exam import CONFIRM, FIT, MM1, SHIP, TEST, exam_a  # noqa: E402
from leftover import COUNT_FLOOR, RELCHANGE_CUT, bin_stats, ece, relchange, u_as_p  # noqa: E402

A6 = HERE / "work" / "a6"
A7 = HERE / "work" / "a7"
UQ = json.loads((CONFIRM / "uq_summary.json").read_text())
UQ_N = {s["session_id"]: s for s in UQ["sessions"]}


def _upper(a: np.ndarray) -> np.ndarray:
    iu = np.triu_indices(a.shape[0], k=1)
    return np.asarray(a, dtype=np.float64)[iu]


def _load_csv(p: Path) -> np.ndarray:
    return np.loadtxt(p, delimiter=",")


def session_e(sid: str) -> tuple[np.ndarray, np.ndarray, np.ndarray, np.ndarray]:
    c0 = np.load(CONFIRM / sid / "identity_count.npy").astype(np.float64)
    e = np.zeros_like(c0)
    mx = c0.copy()
    for name in MM1:
        ck = np.load(CONFIRM / sid / "u_shifts" / name).astype(np.float64)
        rc = relchange(c0, ck)
        pair = np.maximum(c0, ck)
        mx = np.maximum(mx, ck)
        e = np.maximum(e, np.where(pair >= COUNT_FLOOR, rc, 0.0))
    y = (e > RELCHANGE_CUT).astype(np.float64)
    return c0, e, y, mx


def auroc(score: np.ndarray, y: np.ndarray) -> float:
    s = np.asarray(score, dtype=np.float64).ravel()
    yy = np.asarray(y, dtype=np.float64).ravel()
    pos = s[yy > 0.5]
    neg = s[yy <= 0.5]
    if pos.size == 0 or neg.size == 0:
        return float("nan")
    neg_s = np.sort(neg)
    n_less = np.searchsorted(neg_s, pos, side="left")
    n_le = np.searchsorted(neg_s, pos, side="right")
    return float((n_less + 0.5 * (n_le - n_less)).mean() / neg.size)


def main() -> int:
    out: dict = {"item": "A8_challenge", "not_a_new_exam": True}

    # --- 1. Reconstruct locked U n_edges / n_test_moved ---
    recon = []
    for sid in TEST:
        c0, e, y, mx = session_e(sid)
        u = _load_csv(SHIP / sid / "dkt_connectome_U.csv")
        iu = np.triu_indices(c0.shape[0], k=1)
        c0u, yu, eu, mxu, uu = c0[iu], y[iu], e[iu], mx[iu], u[iu]
        # directed off-diag
        off = ~np.eye(c0.shape[0], dtype=bool)
        locked = UQ_N[sid]
        candidates = {
            "triu_C0_ge10": (c0u >= 10, int((c0u >= 10).sum()), int(yu[c0u >= 10].sum())),
            "triu_maxC0_1mm_ge10": (mxu >= 10, int((mxu >= 10).sum()), int(yu[mxu >= 10].sum())),
            "triu_U_gt0": (uu > 0, int((uu > 0).sum()), int(yu[uu > 0].sum())),
            "triu_U_or_C0": ((uu > 0) | (c0u >= 10), int(((uu > 0) | (c0u >= 10)).sum()), int(yu[(uu > 0) | (c0u >= 10)].sum())),
            "triu_all": (np.ones(c0u.size, bool), int(c0u.size), int(yu.sum())),
            "dir_C0_ge10": (c0[off] >= 10, int((c0[off] >= 10).sum()), int(y[off][c0[off] >= 10].sum())),
            "dir_max_ge10": (mx[off] >= 10, int((mx[off] >= 10).sum()), int(y[off][mx[off] >= 10].sum())),
        }
        match = {
            k: {
                "n": n,
                "n_moved": nm,
                "match_n": n == int(locked["n_edges"]),
                "match_moved": nm == int(locked["n_test_moved"]),
            }
            for k, (_m, n, nm) in candidates.items()
        }
        recon.append(
            {
                "session_id": sid,
                "locked_n_edges": locked["n_edges"],
                "locked_n_moved": locked["n_test_moved"],
                "shape": list(c0.shape),
                "symmetric_C0": bool(np.allclose(c0, c0.T)),
                "symmetric_y": bool(np.allclose(y, y.T)),
                "symmetric_U": bool(np.allclose(u, u.T)),
                "candidates": match,
            }
        )
    out["reconstruct_U_mask"] = recon

    # --- 2. A6 C000 vs confirmation identity ---
    align = []
    for sid in TEST:
        c_conf = np.load(CONFIRM / sid / "identity_count.npy").astype(np.float64)
        c_a6 = np.load(A6 / sid / "C000_identity.npy").astype(np.float64)
        p = _load_csv(A7 / sid / "dkt_connectome_proxyUhat.csv")
        iu = np.triu_indices(78, k=1)
        a = c_conf[iu]
        b = c_a6[iu]
        rel = relchange(a, b)
        align.append(
            {
                "session_id": sid,
                "a6_exists": True,
                "same_shape": c_conf.shape == c_a6.shape,
                "max_abs_diff": float(np.max(np.abs(c_conf - c_a6))),
                "median_relchange": float(np.median(rel)),
                "mean_relchange": float(np.mean(rel)),
                "frac_rel_gt_025": float(np.mean(rel > 0.25)),
                "spearman_counts": float(
                    np.corrcoef(np.argsort(np.argsort(a)), np.argsort(np.argsort(b)))[0, 1]
                ),
                "proxy_symmetric": bool(np.allclose(p, p.T)),
                "proxy_max": float(p.max()),
                "proxy_max_on_C0ge10": float(p[iu][c_conf[iu] >= 10].max()) if (c_conf[iu] >= 10).any() else None,
            }
        )
    out["a6_vs_confirmation_identity"] = align

    # --- 3. U-as-P scale variants (diagnosis, not a new lock) ---
    scales = {}
    # all-upper (what A8 used)
    all_u = []
    ge10_u = []
    for sid in FIT:
        u = _load_csv(SHIP / sid / "dkt_connectome_U.csv")
        # need a count for ge10 — use ship? confirmation only has TBI.
        # Demos: followup identity if present, else U>0 as proxy for floor
        all_u.append(_upper(u))
        ge10_u.append(_upper(u)[_upper(u) > 0])
    cat = np.concatenate(all_u)
    pos = np.concatenate(ge10_u) if ge10_u else cat
    scales["A8_used_all_upper"] = {"umin": float(cat.min()), "umax": float(cat.max())}
    scales["U_gt0_only"] = {"umin": float(pos.min()), "umax": float(pos.max())}
    out["u_as_p_scales"] = scales

    # --- 4. ECE under honest alternate masks (challenge, not win) ---
    a = exam_a(A7)
    umin, umax = scales["A8_used_all_upper"]["umin"], scales["A8_used_all_upper"]["umax"]
    variants = {}
    for name, mask_fn in [
        ("C0_ge10_triu", lambda c0, e, y, mx, u: c0 >= 10),
        ("maxC_1mm_ge10_triu", lambda c0, e, y, mx, u: mx >= 10),
        ("U_gt0_triu", lambda c0, e, y, mx, u: u > 0),
    ]:
        ps, ys, pus = [], [], []
        max_p = []
        n9 = 0
        for sid in TEST:
            c0, e, y, mx = session_e(sid)
            u = _load_csv(SHIP / sid / "dkt_connectome_U.csv")
            p = _load_csv(A7 / sid / "dkt_connectome_proxyUhat.csv")
            iu = np.triu_indices(78, k=1)
            m = mask_fn(c0[iu], e[iu], y[iu], mx[iu], u[iu])
            ps.append(p[iu][m])
            ys.append(y[iu][m])
            pus.append(u_as_p(u[iu][m], umin, umax))
            if m.any():
                max_p.append(float(p[iu][m].max()))
        p = np.concatenate(ps)
        yv = np.concatenate(ys)
        pu = np.concatenate(pus)
        bins = bin_stats(p, yv)
        n9 = int(bins[8]["n"])
        variants[name] = {
            "n": int(p.size),
            "y_rate": float(yv.mean()),
            "ECE_proxy": float(ece(p, yv)),
            "ECE_U": float(ece(pu, yv)),
            "ece_better": bool(ece(p, yv) < ece(pu, yv)),
            "n9": n9,
            "proxy_max": max(max_p) if max_p else None,
            "AUROC_proxy": auroc(p, yv),
            "AUROC_U": auroc(pu, yv),
        }
    out["ece_under_masks"] = variants
    out["A8_as_run"] = {
        "n": a["n"],
        "ECE_proxy": a["ECE_proxyUhat"],
        "ECE_U": a["ECE_U_as_P"],
        "n9": a["n9"],
    }

    # --- 5. Can any honest mask populate B9? ---
    out["b9_reachable_without_retune"] = {
        "any_mask_n9_ge20": any(v["n9"] >= 20 for v in variants.values()),
        "any_mask_ece_better": any(v["ece_better"] for v in variants.values()),
        "any_mask_proxy_max_ge08": any(
            (v["proxy_max"] or 0) >= 0.8 for v in variants.values()
        ),
    }

    dest = HERE / "work" / "a8" / "challenge.json"
    dest.write_text(json.dumps(out, indent=2) + "\n")
    print(json.dumps({
        "recon_matches": [
            {r["session_id"]: {k: v["match_n"] and v["match_moved"] for k, v in r["candidates"].items()}}
            for r in recon
        ],
        "align": [{x["session_id"]: {"max_abs": x["max_abs_diff"], "med_rel": x["median_relchange"], "frac_gt025": x["frac_rel_gt_025"]}} for x in align],
        "variants": variants,
        "b9": out["b9_reachable_without_retune"],
        "scales": scales,
    }, indent=2))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
