#!/usr/bin/env python3
"""Within-site LOSO P_L on Kirby mini-scale (expect better ECE than cross-site n=2).

Default: use pack C0.npy when present, else dkt_connectome_count (counts-only).
Use --require-packs to wait for full U/F packs. Use --allow-partial to run on
available SIDs (min 3) while e.g. KKI239 is still pending.
"""

from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

import numpy as np

from leftover import COUNT_FLOOR, moved_mask
from retest_pack import session_paths

HERE = Path(__file__).resolve().parent
R = HERE / "work" / "R"
OUT = R / "paper2" / "within_site_kirby"
IU = np.triu_indices(78, 1)

# KKI849 + mini list
SIDS = ["KKI849", "KKI113", "KKI127", "KKI142", "KKI239"]


def _load_count(path: Path) -> np.ndarray:
    c = np.loadtxt(path, delimiter=",")
    if c.ndim != 2:
        c = np.loadtxt(path)
    return np.asarray(c, dtype=np.float64)


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--require-packs", action="store_true", help="fail if any SID lacks C0.npy pack")
    ap.add_argument("--allow-partial", action="store_true", help="run on available SIDs (min 3)")
    ap.add_argument("--min-subjects", type=int, default=3)
    args = ap.parse_args()

    sys.path.insert(0, "/mnt/nfs/home/urmc-sh.rochester.edu/pndagiji/Documents/edgeuq/src")
    from edgeuq.instability import score_neg_log_count
    from edgeuq.leftover_cal import loso_PL
    from c2_soft import auroc

    OUT.mkdir(parents=True, exist_ok=True)
    subjects = []
    missing = []
    sources = {}
    baselines = {}
    for sid in SIDS:
        pk = R / f"kirby21_{sid}_ses-1"
        b1 = session_paths("kirby21", sid, 1)
        b2 = session_paths("kirby21", sid, 2)
        pack_ok = (pk / "C0.npy").is_file()
        counts_ok = b1["count"].is_file() and b2["count"].is_file()
        if args.require_packs and not pack_ok:
            missing.append(sid)
            continue
        if not pack_ok and not counts_ok:
            missing.append(sid)
            continue
        if not counts_ok and pack_ok:
            # pack without ses-2 count cannot form leftover y
            if not b2["count"].is_file():
                missing.append(sid)
                continue
        try:
            c0 = np.load(pk / "C0.npy").astype(np.float64) if pack_ok else _load_count(b1["count"])
            c1 = _load_count(b2["count"])
        except Exception as e:  # noqa: BLE001 — surface per-SID skip
            missing.append(f"{sid}:{e}")
            continue
        key = f"kirby21/{sid}"
        subjects.append({"key": key, "c_run1": c0, "c_run2": c1})
        sources[key] = "pack_C0" if pack_ok else "dkt_connectome_count"
        elig = np.maximum(c0, c1)[IU] >= COUNT_FLOOR
        y = moved_mask(c0, c1)[IU][elig].astype(float)
        L = score_neg_log_count(c0)[IU][elig]
        baselines[key] = {
            "n": int(elig.sum()),
            "y_rate": float(y.mean()) if y.size else None,
            "auroc_L": float(auroc(L, y)) if y.size and y.min() < y.max() else None,
        }

    if missing and not args.allow_partial:
        rec = {
            "status": "waiting",
            "missing": missing,
            "have": [s["key"] for s in subjects],
            "hint": "re-run with --allow-partial for interim n>=3, or wait for packs",
        }
        (OUT / "status.json").write_text(json.dumps(rec, indent=2) + "\n")
        print(json.dumps(rec, indent=2))
        return 2

    if len(subjects) < args.min_subjects:
        rec = {
            "status": "too_few",
            "n": len(subjects),
            "missing": missing,
            "have": [s["key"] for s in subjects],
        }
        (OUT / "status.json").write_text(json.dumps(rec, indent=2) + "\n")
        print(json.dumps(rec, indent=2))
        return 2

    rec = loso_PL(subjects)
    rec["site"] = "kirby21"
    rec["question"] = "Is P_L ECE fail only cross-site (Kirby↔Boekel) base-rate clash?"
    rec["baselines"] = baselines
    rec["sources"] = sources
    rec["missing"] = missing
    rec["not_hatU"] = True
    eces = [f["ECE_P_L"] for f in rec["folds"]]
    yrates = [f["y_rate"] for f in rec["folds"]]
    complete = len(missing) == 0 and len(subjects) == len(SIDS)
    rec["status"] = "complete_n5" if complete else f"interim_n{len(subjects)}"
    rec["summary"] = {
        "n_subjects": len(subjects),
        "mean_ECE_P_L": float(np.mean(eces)),
        "mean_y_rate": float(np.mean(yrates)),
        "y_rate_range": [float(min(yrates)), float(max(yrates))],
        "vs_cross_site_pilot_ECE": 0.18,
        "interpretation": (
            "If mean ECE << ~0.18 and y_rates similar across folds, cross-site clash was a major driver; "
            "if ECE still high with matched y_rates, model/calibration limit."
        ),
        "not_hatU": True,
    }
    out_name = "P_L_loso_within_kirby.json" if complete else f"P_L_loso_within_kirby_interim_n{len(subjects)}.json"
    (OUT / out_name).write_text(json.dumps(rec, indent=2) + "\n")
    # keep a stable pointer for the latest run
    (OUT / "P_L_loso_within_kirby_latest.json").write_text(json.dumps(rec, indent=2) + "\n")
    print(json.dumps(rec["summary"], indent=2))
    print(f"wrote {OUT / out_name}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
