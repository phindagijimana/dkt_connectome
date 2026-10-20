#!/usr/bin/env python3
"""Leftover-sized exam (L / L2). Run after plants exist. Not hat{U}."""

from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

import numpy as np

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))

from leftover import COUNT_FLOOR, RELCHANGE_CUT, bin_stats, ece, relchange  # noqa: E402

SHIP = HERE.parents[1] / "experiments" / "mapping_screen" / "work" / "ship"
A6 = HERE / "work" / "a6"
A7 = HERE / "work" / "a7"
TEST = (
    "tbi-011011-neurolit-lesion",
    "tbi-011021-neurolit-lesion",
    "tbi-011204-neurolit-lesion",
)
BAND = 0.15
HIGH_N = 20


def main() -> int:
    ap = argparse.ArgumentParser(description="L/L2 leftover exam. Not hat{U}.")
    ap.add_argument("--work", type=Path, default=HERE / "work" / "L")
    args = ap.parse_args()
    LROOT = args.work
    lock = json.loads((LROOT / "LOCK.json").read_text())
    if not lock.get("locked"):
        raise SystemExit("LOCK not locked")
    missing = [s for s in TEST if not (LROOT / s / "C_leftover.npy").is_file()]
    if missing:
        print(json.dumps({"waiting": missing}))
        return 2
    ps, ys, us = [], [], []
    plants = []
    noop = []
    for sid in TEST:
        c0 = np.load(A6 / sid / "C000_identity.npy").astype(np.float64)
        ck = np.load(LROOT / sid / "C_leftover.npy").astype(np.float64)
        if float(np.max(np.abs(c0 - ck))) == 0.0:
            noop.append(sid)
        pair = np.maximum(c0, ck)
        e = np.where(pair >= COUNT_FLOOR, relchange(c0, ck), 0.0)
        y = (e > RELCHANGE_CUT).astype(np.float64)
        p = np.loadtxt(A7 / sid / "dkt_connectome_proxyUhat.csv", delimiter=",")
        u = np.loadtxt(SHIP / sid / "dkt_connectome_U.csv", delimiter=",")
        iu = np.triu_indices(78, 1)
        m = pair[iu] >= COUNT_FLOOR
        ps.append(p[iu][m])
        ys.append(y[iu][m])
        us.append(np.clip(u[iu][m], 0.0, 1.0))
        plants.append(json.loads((LROOT / sid / "plant.json").read_text()))
    p = np.concatenate(ps)
    y = np.concatenate(ys)
    u = np.concatenate(us)
    bins = bin_stats(p, y)
    occ = [b for b in bins if b["n"] >= HIGH_N]
    cov = occ[-1] if occ else None
    evaluable = cov is not None
    band_ok = False
    if evaluable and cov["mean_y"] is not None:
        band_ok = abs(cov["mean_y"] - cov["mean_p"]) <= BAND
    ece_p = ece(p, y)
    ece_u = ece(u, y)
    plant_ok = len(noop) == 0
    win = bool(plant_ok and ece_p < ece_u and evaluable and band_ok)
    name = str(lock.get("experiment", "L"))
    out = {
        "experiment": name,
        "win": win,
        "plant_ok": plant_ok,
        "noop_sessions": noop,
        "n": int(p.size),
        "y_rate": float(y.mean()),
        "ECE_proxyUhat": ece_p,
        "ECE_U_as_P": ece_u,
        "ece_better": bool(ece_p < ece_u),
        "coverage_bin": cov,
        "evaluable": evaluable,
        "band_ok": band_ok,
        "plants": plants,
        "bins": bins,
        "claim": (
            f"{name} win: frozen proxyUhat is calibrated to leftover-sized assignment change. Not gold hat{{U}}."
            if win
            else (
                f"{name} not evaluable: plant no-op. Not leftover fail. Not hat{{U}}."
                if not plant_ok
                else f"{name} fail: keep U. Frequency not a leftover-sized probability. Not proxy-hat{{U}}. Not hat{{U}}."
            )
        ),
        "not_hatU": True,
        "not_A8": True,
    }
    (LROOT / "l_summary.json").write_text(json.dumps(out, indent=2) + "\n")
    print(json.dumps({"win": win, "ECE_proxy": ece_p, "ECE_U": ece_u, "n": int(p.size), "y_rate": float(y.mean())}, indent=2))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
