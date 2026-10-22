#!/usr/bin/env python3
"""Freeze interim Kirby leftover φ_L (isotonic). Not hat{U}.

Primary release candidate: n=4 excluding KKI239 (skip-mtnorm outlier).
Also writes n=5 sensitivity map for lab use only.
"""

from __future__ import annotations

import json
import sys
from datetime import datetime, timezone
from pathlib import Path

import numpy as np

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
sys.path.insert(0, "/mnt/nfs/home/urmc-sh.rochester.edu/pndagiji/Documents/edgeuq/src")

from leftover import COUNT_FLOOR, moved_mask  # noqa: E402
from retest_pack import session_paths  # noqa: E402
from edgeuq.instability import score_neg_log_count  # noqa: E402
from edgeuq.leftover_cal import attach_stratum_metadata, fit_PL, leftover_y, loso_PL  # noqa: E402

R = HERE / "work" / "R"
OUT = R / "paper2" / "within_site_kirby" / "maps"
EDGEUQ_DATA = Path("/mnt/nfs/home/urmc-sh.rochester.edu/pndagiji/Documents/edgeuq/src/edgeuq/data")
IU = np.triu_indices(78, 1)
STRATUM = "kirby21_ifod2_radial4"
VERSION = "2026-10-22_interim"


def load_pair(sid: str) -> dict:
    pk = R / f"kirby21_{sid}_ses-1"
    b1 = session_paths("kirby21", sid, 1)
    b2 = session_paths("kirby21", sid, 2)
    if (pk / "C0.npy").is_file():
        c0 = np.load(pk / "C0.npy").astype(np.float64)
    else:
        c0 = np.loadtxt(b1["count"], delimiter=",")
        if c0.ndim != 2:
            c0 = np.loadtxt(b1["count"])
        c0 = np.asarray(c0, dtype=np.float64)
    c1 = np.loadtxt(b2["count"], delimiter=",")
    if c1.ndim != 2:
        c1 = np.loadtxt(b2["count"])
    return {"key": f"kirby21/{sid}", "c_run1": c0, "c_run2": np.asarray(c1, dtype=np.float64)}


def pool_fit(subjects: list[dict]) -> dict:
    L_all, y_all = [], []
    for s in subjects:
        L, y, _ = leftover_y(s["c_run1"], s["c_run2"])
        L_all.append(L)
        y_all.append(y)
    model = fit_PL(np.concatenate(L_all), np.concatenate(y_all))
    return attach_stratum_metadata(model, stratum=STRATUM, version=VERSION)


def main() -> int:
    OUT.mkdir(parents=True, exist_ok=True)
    sids_n4 = ["KKI849", "KKI113", "KKI127", "KKI142"]
    sids_n5 = sids_n4 + ["KKI239"]
    sub4 = [load_pair(s) for s in sids_n4]
    sub5 = [load_pair(s) for s in sids_n5]

    map4 = pool_fit(sub4)
    map4.update(
        {
            "fit_subjects": [f"kirby21/{s}" for s in sids_n4],
            "excluded": ["kirby21/KKI239"],
            "exclude_reason": "ses-2 skip-mtnormalise rescue; within-site LOSO outlier (y_rate~0.83, AUROC_L~0.55)",
            "loso_mean_ECE_ref": 0.043,
            "status": "interim_pre_scale",
            "not_hatU": True,
            "created": datetime.now(timezone.utc).isoformat(),
        }
    )
    map5 = pool_fit(sub5)
    map5.update(
        {
            "fit_subjects": [f"kirby21/{s}" for s in sids_n5],
            "status": "sensitivity_includes_KKI239_skip_mtnorm",
            "not_hatU": True,
            "created": datetime.now(timezone.utc).isoformat(),
        }
    )

    p4 = OUT / f"isotonic_leftover_{STRATUM}_n4.json"
    p5 = OUT / f"isotonic_leftover_{STRATUM}_n5_sensitivity.json"
    p4.write_text(json.dumps(map4, indent=2) + "\n")
    p5.write_text(json.dumps(map5, indent=2) + "\n")

    # ship n4 into edgeuq package data (interim; cite Paper 2)
    ship = EDGEUQ_DATA / "isotonic_leftover_kirby21_ifod2_radial4.json"
    ship.write_text(json.dumps(map4, indent=2) + "\n")

    loso4 = loso_PL(sub4)
    eces = [f["ECE_P_L"] for f in loso4["folds"]]
    summary = {
        "primary_map": str(p4),
        "shipped": str(ship),
        "sensitivity_map": str(p5),
        "stratum": STRATUM,
        "loso_n4_mean_ECE": float(np.mean(eces)),
        "apply": (
            "edgeuq apply-leftover-map "
            f"--map {ship} --stratum {STRATUM} --count-run1 <C0.csv> --out <dir>"
        ),
        "not_hatU": True,
    }
    (OUT / "freeze_summary.json").write_text(json.dumps(summary, indent=2) + "\n")
    print(json.dumps(summary, indent=2))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
