#!/usr/bin/env python3
"""Experiment G: frozen calibrated U vs leftover y. No ECE until the gate opens."""

from __future__ import annotations

import json
import sys
from pathlib import Path

import numpy as np

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))

from leftover import (  # noqa: E402
    COUNT_FLOOR,
    RELCHANGE_CUT,
    apply_isotonic,
    bin_stats,
    ece,
    moved_mask,
)

G = HERE / "work" / "G"
LIST = HERE / "work" / "sites_v1" / "LIST.json"
ISO = HERE / "work" / "C" / "isotonic.json"
GOLD_FLAG = G / "GOLD_LOCKED"
BAND = 0.15
HIGH_N = 20
FORBIDDEN_SIDS = {
    "tbi-011011-neurolit-lesion",
    "tbi-011021-neurolit-lesion",
    "tbi-011204-neurolit-lesion",
    "TBI011011",
    "TBI011021",
    "TBI011204",
    "TBI021030",
    "tbi-021030",
    "sub-TBI021030",
}


def load_isotonic() -> tuple[np.ndarray, np.ndarray]:
    raw = json.loads(ISO.read_text())
    return np.asarray(raw["X_thresholds"], dtype=np.float64), np.asarray(
        raw["y_thresholds"], dtype=np.float64
    )


def leftover_y(c_a: np.ndarray, c_b: np.ndarray) -> np.ndarray:
    """Locked moved between two leftover connectomes. Not 1 mm."""
    return moved_mask(c_a, c_b).astype(np.float64)


def occupied_bins_ok(p: np.ndarray, y: np.ndarray) -> tuple[bool, list[dict]]:
    bins = bin_stats(p, y)
    scored = [b for b in bins if int(b["n"]) >= HIGH_N]
    ok = all(abs(float(b["mean_y"]) - float(b["mean_p"])) <= BAND for b in scored)
    return ok, bins


def gate() -> dict:
    lock = json.loads((G / "LOCK.json").read_text())
    lst = json.loads(LIST.read_text())
    sessions = list(lst.get("sessions") or [])
    n = int(lst.get("n") or 0)
    reasons = []
    if not lock.get("rules_locked"):
        reasons.append("G rules not locked")
    if lock.get("run_locked"):
        reasons.append("run_locked true without leftover")
    if n < 2 or len(sessions) < 2:
        reasons.append("LIST.json has <2 leftover sessions")
    if not GOLD_FLAG.is_file():
        reasons.append("GOLD_LOCKED file absent (user must write GOLD locked)")
    for s in sessions:
        sid = str(s.get("session_id") or s.get("subject") or "")
        if sid in FORBIDDEN_SIDS:
            reasons.append(f"forbidden leftover id: {sid}")
    return {
        "open": len(reasons) == 0,
        "reasons": reasons,
        "n_list": n,
        "n_sessions": len(sessions),
        "not_hatU": True,
        "not_proxy_hatU": True,
    }


def exam_from_pairs(pairs: list[tuple[np.ndarray, np.ndarray, np.ndarray]]) -> dict:
    """pairs = (U, C_a, C_b). Frozen P = isotonic(U). y = leftover moved."""
    xt, yt = load_isotonic()
    ps, ys = [], []
    for u, ca, cb in pairs:
        iu = np.triu_indices(u.shape[0], 1)
        mask = np.maximum(ca, cb)[iu] >= COUNT_FLOOR
        p = apply_isotonic(u[iu][mask], xt, yt)
        y = leftover_y(ca, cb)[iu][mask]
        ps.append(p)
        ys.append(y)
    p = np.concatenate(ps)
    y = np.concatenate(ys)
    bins_ok, bins = occupied_bins_ok(p, y)
    ece_p = ece(p, y)
    win = bool(bins_ok and p.size > 0)
    return {
        "n": int(p.size),
        "y_rate": float(y.mean()) if p.size else None,
        "ECE_calibrated_U": ece_p,
        "occupied_bins_ok": bins_ok,
        "bins": bins,
        "win": win,
        "relchange_cut": RELCHANGE_CUT,
        "count_floor": COUNT_FLOOR,
        "not_proxy_hatU": True,
        "claim": (
            "G win: leftover y; calibrated U may be named hat{U}."
            if win
            else "G fail or blocked. Keep calibrated U as a 1 mm probability. Not hat{U}."
        ),
    }


def main() -> int:
    g = gate()
    G.mkdir(parents=True, exist_ok=True)
    if not g["open"]:
        rec = {
            "experiment": "G",
            "status": "blocked",
            "gate": g,
            "ECE": None,
            "claim": "No leftover ECE. Keep calibrated U. Not hat{U}. Not proxy-hat{U}.",
        }
        (G / "g_blocked.json").write_text(json.dumps(rec, indent=2) + "\n")
        print(json.dumps({"status": "blocked", "reasons": g["reasons"]}, indent=2))
        return 2
    rec = {
        "experiment": "G",
        "status": "open_but_pairs_not_in_this_phase",
        "gate": g,
        "note": "Phase 3 only opens the gate check. Phase 5 loads leftover U/C_a/C_b after GOLD locked.",
        "not_hatU": True,
    }
    (G / "g_open.json").write_text(json.dumps(rec, indent=2) + "\n")
    print(json.dumps({"status": "open"}, indent=2))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
