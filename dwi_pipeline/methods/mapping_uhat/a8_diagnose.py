#!/usr/bin/env python3
"""A8 post-fail diagnosis. Does not retune. Does not rename. Not a new exam."""

from __future__ import annotations

import json
import sys
from pathlib import Path

import numpy as np

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))

from a8_exam import CONFIRM, FIT, SHIP, TEST, exam_a, fit_u_scale, session_moved  # noqa: E402
from leftover import COUNT_FLOOR, bin_stats, ece, u_as_p  # noqa: E402


def _upper(a: np.ndarray) -> np.ndarray:
    iu = np.triu_indices(a.shape[0], k=1)
    return np.asarray(a, dtype=np.float64)[iu]


def _load_csv(p: Path) -> np.ndarray:
    return np.loadtxt(p, delimiter=",")


def auroc(score: np.ndarray, y: np.ndarray) -> float:
    s = np.asarray(score, dtype=np.float64).ravel()
    yy = np.asarray(y, dtype=np.float64).ravel()
    pos = s[yy > 0.5]
    neg = s[yy <= 0.5]
    if pos.size == 0 or neg.size == 0:
        return float("nan")
    # Mann–Whitney: P(pos>neg)+0.5 P(eq)
    neg_s = np.sort(neg)
    n_less = np.searchsorted(neg_s, pos, side="left")
    n_le = np.searchsorted(neg_s, pos, side="right")
    n_eq = n_le - n_less
    return float((n_less + 0.5 * n_eq).mean() / neg.size)


def spearman(a: np.ndarray, b: np.ndarray) -> float:
    ra = np.argsort(np.argsort(a))
    rb = np.argsort(np.argsort(b))
    ra = ra.astype(np.float64)
    rb = rb.astype(np.float64)
    ra -= ra.mean()
    rb -= rb.mean()
    den = np.sqrt((ra * ra).sum() * (rb * rb).sum())
    if den <= 0:
        return float("nan")
    return float((ra * rb).sum() / den)


def ece_parts(p: np.ndarray, y: np.ndarray) -> list[dict]:
    bins = bin_stats(p, y)
    n = float(p.size)
    out = []
    for b in bins:
        if b["n"] == 0:
            out.append({**b, "gap": None, "weight": 0.0, "contrib": 0.0})
            continue
        gap = abs(b["mean_y"] - b["mean_p"])
        w = b["n"] / n
        out.append({**b, "gap": gap, "weight": w, "contrib": w * gap})
    return out


def main() -> int:
    a7 = HERE / "work" / "a7"
    a5 = HERE / "work" / "a5"
    a = exam_a(a7)
    umin, umax = fit_u_scale()

    ps, ys, us, es = [], [], [], []
    per = []
    for sid in TEST:
        e, y, elig = session_moved(sid)
        p = _load_csv(a7 / sid / "dkt_connectome_proxyUhat.csv")
        u = _load_csv(SHIP / sid / "dkt_connectome_U.csv")
        iu = np.triu_indices(y.shape[0], k=1)
        mask = elig[iu]
        p_u = _upper(p)[mask]
        y_u = _upper(y)[mask]
        u_u = _upper(u)[mask]
        e_u = _upper(e)[mask]
        ps.append(p_u)
        ys.append(y_u)
        us.append(u_u)
        es.append(e_u)
        leftover = json.loads((a5 / sid / "leftover.json").read_text())
        per.append(
            {
                "session_id": sid,
                "n": int(mask.sum()),
                "y_rate": float(y_u.mean()),
                "proxy_mean": float(p_u.mean()),
                "proxy_median": float(np.median(p_u)),
                "proxy_max": float(p_u.max()),
                "proxy_n_pos": int((p_u > 0).sum()),
                "proxy_n_ge_08": int((p_u >= 0.8).sum()),
                "proxy_n_ge_07": int((p_u >= 0.7).sum()),
                "proxy_n_ge_05": int((p_u >= 0.5).sum()),
                "U_mean": float(u_u.mean()),
                "U_max": float(u_u.max()),
                "M_s_mm": leftover.get("M_s"),
                "p95_mm": leftover.get("p95_pooled"),
            }
        )

    p = np.concatenate(ps)
    y = np.concatenate(ys)
    u = np.concatenate(us)
    e = np.concatenate(es)
    pu = u_as_p(u, umin, umax)

    # A5 m_k vs 1 mm for TBI (Exam B would draw t from these)
    mk = []
    for sid in TEST:
        leftover = json.loads((a5 / sid / "leftover.json").read_text())
        for row in leftover.get("per_k", leftover.get("m_k", [])):
            if isinstance(row, dict):
                mk.append(float(row.get("m_k", row.get("median_mm", 0.0))))
            else:
                mk.append(float(row))

    diag = {
        "item": "A8_diagnose",
        "not_a_new_exam": True,
        "does_not_change_A8": True,
        "claim": "Diagnosis only. keep U. Not proxy-hat{U}. Not hat{U}.",
        "n": int(p.size),
        "y_rate_1mm": float(y.mean()),
        "ece": {
            "proxyUhat": float(ece(p, y)),
            "U_as_P": float(ece(pu, y)),
            "delta_proxy_minus_U": float(ece(p, y) - ece(pu, y)),
        },
        "ranking_not_a_win_rule": {
            "AUROC_proxy_vs_1mm": auroc(p, y),
            "AUROC_U_vs_1mm": auroc(pu, y),
            "Spearman_proxy_vs_1mm_e": spearman(p, e),
            "Spearman_U_vs_1mm_e": spearman(pu, e),
            "Spearman_proxy_vs_U": spearman(p, pu),
        },
        "proxy_mass": {
            "mean": float(p.mean()),
            "median": float(np.median(p)),
            "max": float(p.max()),
            "n_zero": int((p == 0).sum()),
            "frac_zero": float((p == 0).mean()),
            "n_ge_0.5": int((p >= 0.5).sum()),
            "n_ge_0.7": int((p >= 0.7).sum()),
            "n_ge_0.8": int((p >= 0.8).sum()),
            "n_ge_0.9": int((p >= 0.9).sum()),
        },
        "U_as_P_mass": {
            "mean": float(pu.mean()),
            "median": float(np.median(pu)),
            "max": float(pu.max()),
            "umin_fit": umin,
            "umax_fit": umax,
            "n_ge_0.8": int((pu >= 0.8).sum()),
        },
        "ece_contrib_proxy": ece_parts(p, y),
        "ece_contrib_U": ece_parts(pu, y),
        "sessions": per,
        "a5_vs_1mm": {
            "TBI_M_s_mm": {s["session_id"]: s["M_s_mm"] for s in per},
            "note": "FORMULA A5 split: if M_s << 1 mm, Exam A is a larger event than the ensemble.",
            "m_k_n": len(mk),
            "m_k_median": None if not mk else float(np.median(mk)),
            "m_k_p95": None if not mk else float(np.percentile(mk, 95)),
            "frac_mk_ge_1mm": None if not mk else float(np.mean(np.array(mk) >= 1.0)),
        },
        "why": {
            "miss_1_ECE": "proxy ECE not strictly < U-as-P ECE",
            "miss_2_B9": "B9 n=0 < 20; 80% clause not evaluable; Exam B not run",
            "mechanism": (
                "proxyUhat is frequency under leftover-sized ANTs label warps (A5 M_s ~0.66–0.81 mm). "
                "Exam A y is moved under locked 1 mm six-axis planted counts. "
                "Most eligible edges have proxyUhat=0 while 15% still move at 1 mm."
            ),
        },
        "forward_this_protocol": {
            "A8_win_path": False,
            "A9_name_proxy": False,
            "A10_A14": False,
            "keep_U": True,
            "new_protocol_requires": "user explicitly reopens a new pre-specified protocol (WAVE_AGENT §7)",
        },
    }
    out = HERE / "work" / "a8" / "diagnosis.json"
    out.write_text(json.dumps(diag, indent=2) + "\n")
    print(
        json.dumps(
            {
                "ECE_proxy": diag["ece"]["proxyUhat"],
                "ECE_U": diag["ece"]["U_as_P"],
                "AUROC_proxy": diag["ranking_not_a_win_rule"]["AUROC_proxy_vs_1mm"],
                "AUROC_U": diag["ranking_not_a_win_rule"]["AUROC_U_vs_1mm"],
                "Spearman_proxy_U": diag["ranking_not_a_win_rule"]["Spearman_proxy_vs_U"],
                "proxy_max": diag["proxy_mass"]["max"],
                "proxy_n_ge_08": diag["proxy_mass"]["n_ge_0.8"],
                "frac_zero": diag["proxy_mass"]["frac_zero"],
            },
            indent=2,
        )
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
