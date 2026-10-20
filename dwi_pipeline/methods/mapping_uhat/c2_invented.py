#!/usr/bin/env python3
"""C2 secondary: profile of count>=10 edges that E[C] invents (development only). Descriptive. Not hat{U}."""

from __future__ import annotations

import json
import sys
from pathlib import Path

import numpy as np

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))

from assign_frozen import N_NODES  # noqa: E402
from c2_soft import OUT, SESSIONS  # noqa: E402
from c_calib_u import FIT  # noqa: E402
from leftover import COUNT_FLOOR  # noqa: E402

NEAR_LOW = 5.0
P_LO, P_HI = 0.1, 0.9


def profile(sid: str) -> dict:
    d = OUT / sid
    c0 = np.load(d / "C0.npy").astype(np.float64)
    es = np.load(d / "Esoft.npy").astype(np.float64)
    iu = np.triu_indices(N_NODES, 1)
    inv = (es[iu] >= COUNT_FLOOR) & (c0[iu] < COUNT_FLOOR)
    lost = (es[iu] < COUNT_FLOOR) & (c0[iu] >= COUNT_FLOOR)
    edges = [
        {"i": int(i) + 1, "j": int(j) + 1, "C0": float(c0[i, j]), "Esoft": float(es[i, j])}
        for i, j, k in zip(*iu, inv)
        if k
    ]
    rec = {
        "session_id": sid,
        "split": "dev" if sid in FIT else "confirm",
        "n_invented": int(inv.sum()),
        "n_lost": int(lost.sum()),
        "invented_near_threshold": int(sum(5.0 <= e["C0"] < COUNT_FLOOR for e in edges)),
        "invented_C0_lt_5": int(sum(e["C0"] < NEAR_LOW for e in edges)),
        "invented_C0_eq_0": int(sum(e["C0"] == 0 for e in edges)),
        "edges": edges,
    }
    cs = d / "Cs.npy"
    if cs.is_file():
        s = np.load(cs).astype(np.float64)
        p10 = (s >= COUNT_FLOOR).mean(axis=0)[iu]
        flag = (p10 > P_LO) & (p10 < P_HI)
        elig = np.maximum(c0, es)[iu] >= COUNT_FLOOR
        rec["threshold_uncertain_edges"] = int(flag.sum())
        rec["threshold_uncertain_frac_of_eligible"] = float(flag[elig].mean())
        rec["invented_flagged"] = int((flag & inv).sum())
    return rec


def main() -> int:
    rows = [profile(sid) for sid in SESSIONS]
    rec = {
        "experiment": "C2 secondary (amendment 2026-10-20b)",
        "descriptive_only": True,
        "does_not_rescue_invent_rule": True,
        "sessions": rows,
        "not_hatU": True,
    }
    (OUT / "invented_profile.json").write_text(json.dumps(rec, indent=2) + "\n")
    for r in rows:
        extra = {k: r[k] for k in r if k.startswith("threshold") or k == "invented_flagged"}
        print(r["session_id"][:24], {k: r[k] for k in ("n_invented", "n_lost", "invented_near_threshold", "invented_C0_lt_5", "invented_C0_eq_0")}, extra)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
