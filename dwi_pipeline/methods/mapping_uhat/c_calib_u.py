#!/usr/bin/env python3
"""Experiment C: isotonic calibration of locked U on 1 mm moved. Not hat{U}."""

from __future__ import annotations

import json
import sys
from pathlib import Path

import numpy as np
from sklearn.isotonic import IsotonicRegression

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))

from leftover import (  # noqa: E402
    COUNT_FLOOR,
    RELCHANGE_CUT,
    apply_isotonic,
    bin_stats,
    ece,
    relchange,
)

SHIP = HERE.parents[1] / "experiments" / "mapping_screen" / "work" / "ship"
FOLLOW = HERE.parents[1] / "experiments" / "mapping_screen" / "work" / "followup"
CONFIRM = HERE.parents[1] / "experiments" / "mapping_screen" / "work" / "confirmation_uq"

FIT = (
    "ideas-sub-1-ses-1",
    "ideas-sub-6-ses-1",
    "btc-sub-PAT20-ses-preop",
)
TEST = (
    "tbi-011011-neurolit-lesion",
    "tbi-011021-neurolit-lesion",
    "tbi-011204-neurolit-lesion",
)
MM1 = (
    "tx_m1mm_count.npy",
    "tx_p1mm_count.npy",
    "ty_m1mm_count.npy",
    "ty_p1mm_count.npy",
    "tz_m1mm_count.npy",
    "tz_p1mm_count.npy",
)
BAND = 0.15
HIGH_N = 20


def _root(sid: str) -> Path:
    return FOLLOW / sid if sid in FIT else CONFIRM / sid


def session_event(sid: str) -> tuple[np.ndarray, np.ndarray, np.ndarray]:
    root = _root(sid)
    c0 = np.load(root / "identity_count.npy").astype(np.float64)
    e = np.zeros_like(c0)
    mx = c0.copy()
    for p in sorted((root / "u_shifts").glob("*_count.npy")):
        ck = np.load(p).astype(np.float64)
        mx = np.maximum(mx, ck)
        if p.name in MM1:
            pair = np.maximum(c0, ck)
            e = np.maximum(e, np.where(pair >= COUNT_FLOOR, relchange(c0, ck), 0.0))
    y = (e > RELCHANGE_CUT).astype(np.float64)
    return e, y, mx


def _edges(sid: str) -> tuple[np.ndarray, np.ndarray]:
    _e, y, mx = session_event(sid)
    u = np.loadtxt(SHIP / sid / "dkt_connectome_U.csv", delimiter=",")
    iu = np.triu_indices(78, 1)
    m = mx[iu] >= COUNT_FLOOR
    return np.clip(u[iu][m], 0.0, 1.0), y[iu][m]


def high_bin_from_fit(p: np.ndarray) -> int | None:
    bins = bin_stats(p, np.zeros_like(p))
    for b in reversed(bins):
        if b["n"] >= HIGH_N:
            return int(b["bin"])
    return None


def main() -> int:
    lock = json.loads((HERE / "work" / "C" / "LOCK.json").read_text())
    if not lock.get("locked"):
        raise SystemExit("C LOCK not locked")
    out = HERE / "work" / "C"
    out.mkdir(parents=True, exist_ok=True)

    u_fit, y_fit = [], []
    for sid in FIT:
        u, y = _edges(sid)
        u_fit.append(u)
        y_fit.append(y)
    u_fit = np.concatenate(u_fit)
    y_fit = np.concatenate(y_fit)
    iso = IsotonicRegression(increasing=True, out_of_bounds="clip")
    iso.fit(u_fit, y_fit)
    p_fit = iso.predict(u_fit)
    hb = high_bin_from_fit(p_fit)
    xt = np.asarray(iso.X_thresholds_, dtype=np.float64)
    yt = np.asarray(iso.y_thresholds_, dtype=np.float64)
    (out / "isotonic.json").write_text(
        json.dumps(
            {
                "X_thresholds": xt.tolist(),
                "y_thresholds": yt.tolist(),
                "increasing": True,
                "out_of_bounds": "clip",
                "event": "planted_1mm",
                "not_hatU": True,
            },
            indent=2,
        )
        + "\n"
    )
    (out / "fit.json").write_text(
        json.dumps(
            {
                "n_fit": int(u_fit.size),
                "y_rate_fit": float(y_fit.mean()),
                "high_bin": hb,
                "method": "isotonic",
                "frozen_before_test_ECE": True,
                "isotonic": "isotonic.json",
            },
            indent=2,
        )
        + "\n"
    )
    for sid in (*FIT, *TEST):
        u_mat = np.loadtxt(SHIP / sid / "dkt_connectome_U.csv", delimiter=",")
        p_mat = apply_isotonic(u_mat, xt, yt)
        p_mat = 0.5 * (p_mat + p_mat.T)
        np.fill_diagonal(p_mat, 0.0)
        dest = SHIP / sid / "dkt_connectome_Ucal.csv"
        np.savetxt(dest, p_mat, delimiter=",", fmt="%.8f")

    us, ys, ps = [], [], []
    per = []
    for sid in TEST:
        u, y = _edges(sid)
        p = iso.predict(u)
        us.append(u)
        ys.append(y)
        ps.append(p)
        per.append({"session_id": sid, "n": int(u.size), "y_rate": float(y.mean())})
        np.savetxt(out / f"{sid}_U_calibrated_edges.csv", np.column_stack([u, p, y]), delimiter=",", header="U,P_cal,y", comments="")
    u = np.concatenate(us)
    y = np.concatenate(ys)
    p = np.concatenate(ps)
    ece_cal = ece(p, y)
    ece_raw = ece(u, y)
    bins = bin_stats(p, y)
    cov = None
    evaluable = False
    band_ok = False
    if hb is not None:
        cov = bins[hb - 1]
        evaluable = int(cov["n"]) >= HIGH_N and cov["mean_y"] is not None
        if evaluable:
            band_ok = abs(cov["mean_y"] - cov["mean_p"]) <= BAND
    win = bool(ece_cal < ece_raw and evaluable and band_ok)
    summary = {
        "experiment": "C",
        "win": win,
        "n": int(p.size),
        "y_rate": float(y.mean()),
        "ECE_calibrated_U": ece_cal,
        "ECE_raw_U": ece_raw,
        "ece_better": bool(ece_cal < ece_raw),
        "high_bin_from_fit": hb,
        "coverage": cov,
        "evaluable": evaluable,
        "band_ok": band_ok,
        "sessions": per,
        "bins": bins,
        "claim": (
            "C win: calibrated U is a probability for planted 1 mm. Still not leftover. Not hat{U}."
            if win
            else "C fail: keep U as a ranker. Do not print U as a percent. Not hat{U}."
        ),
        "not_hatU": True,
        "not_A8": True,
    }
    (out / "c_summary.json").write_text(json.dumps(summary, indent=2) + "\n")
    print(json.dumps({"win": win, "ECE_cal": ece_cal, "ECE_raw": ece_raw, "high_bin": hb, "evaluable": evaluable, "n": int(p.size)}, indent=2))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
