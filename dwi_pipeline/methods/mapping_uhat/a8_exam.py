#!/usr/bin/env python3
"""A8 Exam A (1 mm moved vs U-as-P). Not leftover truth. Not hat{U}."""

from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

import numpy as np

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))

from leftover import (  # noqa: E402
    BAND,
    COUNT_FLOOR,
    HIGH_BIN,
    HIGH_BIN_N,
    RELCHANGE_CUT,
    bin_stats,
    ece,
    relchange,
    u_as_p,
)

SHIP = HERE.parents[1] / "experiments" / "mapping_screen" / "work" / "ship"
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


def _load_csv(p: Path) -> np.ndarray:
    return np.loadtxt(p, delimiter=",")


def _upper(a: np.ndarray) -> np.ndarray:
    iu = np.triu_indices(a.shape[0], k=1)
    return np.asarray(a, dtype=np.float64)[iu]


def fit_u_scale() -> tuple[float, float]:
    vals = []
    for sid in FIT:
        u = _load_csv(SHIP / sid / "dkt_connectome_U.csv")
        # U already 0 below the count floor in the writer
        vals.append(_upper(u))
    cat = np.concatenate(vals)
    cat = cat[np.isfinite(cat)]
    return float(cat.min()), float(cat.max())


def session_moved(sid: str) -> tuple[np.ndarray, np.ndarray, np.ndarray]:
    c0 = np.load(CONFIRM / sid / "identity_count.npy").astype(np.float64)
    e = np.zeros_like(c0)
    for name in MM1:
        ck = np.load(CONFIRM / sid / "u_shifts" / name).astype(np.float64)
        rc = relchange(c0, ck)
        ok = np.maximum(c0, ck) >= COUNT_FLOOR
        e = np.maximum(e, np.where(ok, rc, 0.0))
    y = (e > RELCHANGE_CUT).astype(np.float64)
    elig = c0 >= COUNT_FLOOR
    return e, y, elig


def exam_a(a7: Path) -> dict:
    umin, umax = fit_u_scale()
    ps, ys, us = [], [], []
    per = []
    for sid in TEST:
        _e, y, elig = session_moved(sid)
        p = _load_csv(a7 / sid / "dkt_connectome_proxyUhat.csv")
        u = _load_csv(SHIP / sid / "dkt_connectome_U.csv")
        iu = np.triu_indices(y.shape[0], k=1)
        mask = elig[iu]
        ps.append(_upper(p)[mask])
        ys.append(_upper(y)[mask])
        us.append(_upper(u)[mask])
        per.append(
            {
                "session_id": sid,
                "n_eligible": int(mask.sum()),
                "y_rate": float(_upper(y)[mask].mean()) if mask.any() else None,
            }
        )
    p = np.concatenate(ps)
    y = np.concatenate(ys)
    u = np.concatenate(us)
    pu = u_as_p(u, umin, umax)
    ece_p = ece(p, y)
    ece_u = ece(pu, y)
    bins = bin_stats(p, y)
    b9 = bins[HIGH_BIN - 1]
    n9 = int(b9["n"])
    evaluable = n9 >= HIGH_BIN_N
    band_ok = False
    if evaluable and b9["mean_y"] is not None and b9["mean_p"] is not None:
        band_ok = abs(b9["mean_y"] - b9["mean_p"]) <= BAND
    win_a = bool(ece_p < ece_u and evaluable and band_ok)
    return {
        "exam": "A",
        "event": "locked U 1 mm moved; not leftover truth",
        "n": int(p.size),
        "y_rate": float(y.mean()),
        "u_scale": {"umin": umin, "umax": umax, "fit": list(FIT)},
        "ECE_proxyUhat": ece_p,
        "ECE_U_as_P": ece_u,
        "ece_better": bool(ece_p < ece_u),
        "B9": b9,
        "n9": n9,
        "evaluable": evaluable,
        "band_ok": band_ok,
        "win": win_a,
        "sessions": per,
        "bins": bins,
        "not_hatU": True,
    }


def main() -> int:
    ap = argparse.ArgumentParser(description="A8 Exam A. Not hat{U}.")
    ap.add_argument("--a7", type=Path, default=HERE / "work" / "a7")
    ap.add_argument("--work", type=Path, default=HERE / "work" / "a8")
    args = ap.parse_args()
    args.work.mkdir(parents=True, exist_ok=True)
    a = exam_a(args.a7)
    (args.work / "exam_a.json").write_text(json.dumps(a, indent=2) + "\n")
    # Exam B needs n9>=20 to be a naming exam. Empty B9 → not evaluable; do not plant 10M.
    b = {
        "exam": "B",
        "seed": 2601,
        "note": "Coverage on B9. If n9<20 the exam is not evaluable; no 10M plant.",
        "n9_from_A": a["n9"],
        "evaluable": bool(a["evaluable"]),
        "win": False,
        "ran_plant": False,
    }
    if not a["evaluable"]:
        b["skip_reason"] = "B9 n<20; A8 cannot win; no leftover-sized plant"
    (args.work / "exam_b.json").write_text(json.dumps(b, indent=2) + "\n")
    win = bool(a["win"] and b["win"])
    out = {
        "item": "A8",
        "win": win,
        "exam_A_win": a["win"],
        "exam_B_win": b["win"],
        "rule": "ECE_proxy < ECE_UasP and B9 evaluable ±15 and Exam B coverage ±15",
        "decision": "proxy-hat{U}" if win else "keep_U",
        "claim": (
            "A8 win: proxy-hat{U} only. Not gold hat{U}."
            if win
            else "A8 fail: keep U. Not proxy-hat{U}. Not hat{U}."
        ),
        "exam_A": a,
        "exam_B": b,
    }
    (args.work / "a8_summary.json").write_text(json.dumps(out, indent=2) + "\n")
    print(json.dumps({"win": win, "exam_A": a["win"], "ECE_proxy": a["ECE_proxyUhat"], "ECE_U": a["ECE_U_as_P"], "n9": a["n9"]}, indent=2))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
