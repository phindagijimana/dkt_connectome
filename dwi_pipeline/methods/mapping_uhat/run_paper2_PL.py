#!/usr/bin/env python3
"""Paper 2 pilot: LOSO P_L on GOLD pilots + baselines. Not hat{U}. Protocol demo if n=2."""

from __future__ import annotations

import json
import sys
from pathlib import Path

import numpy as np

from assign_frozen import N_NODES
from c2_soft import auroc
from leftover import COUNT_FLOOR, moved_mask
from retest_pack import session_paths

HERE = Path(__file__).resolve().parent
R = HERE / "work" / "R"
OUT = R / "paper2"
IU = np.triu_indices(N_NODES, 1)
PAIRS = [("kirby21", "KKI849"), ("boekel_dwi_retest", "pp01")]


def main() -> int:
    sys.path.insert(0, "/mnt/nfs/home/urmc-sh.rochester.edu/pndagiji/Documents/edgeuq/src")
    from edgeuq.io import save_matrix
    from edgeuq.leftover_cal import loso_PL
    from edgeuq.instability import score_neg_log_count

    OUT.mkdir(parents=True, exist_ok=True)
    subjects = []
    baselines = {}
    loso_spec = []
    for ds, sid in PAIRS:
        pk = R / f"{ds}_{sid}_ses-1"
        b = session_paths(ds, sid, 2)
        c0 = np.load(pk / "C0.npy").astype(np.float64)
        c1 = np.loadtxt(b["count"], delimiter=",")
        if c1.ndim != 2:
            c1 = np.loadtxt(b["count"])
        key = f"{ds}/{sid}"
        subjects.append({"key": key, "c_run1": c0, "c_run2": c1})
        # write CSVs for edgeuq CLI reproducibility
        d = OUT / "matrices" / key.replace("/", "_")
        d.mkdir(parents=True, exist_ok=True)
        save_matrix(d / "C0.csv", c0, fmt="%d")
        save_matrix(d / "C1.csv", c1, fmt="%d")
        loso_spec.append({"key": key, "count_run1": str(d / "C0.csv"), "count_run2": str(d / "C1.csv")})
        elig = np.maximum(c0, c1)[IU] >= COUNT_FLOOR
        y = moved_mask(c0, c1)[IU][elig].astype(float)
        u = np.loadtxt(pk / "U.csv", delimiter=",")[IU][elig]
        f = np.load(pk / "F.npy")[IU][elig]
        L = score_neg_log_count(c0)[IU][elig]
        baselines[key] = {
            "auroc_L": float(auroc(L, y)),
            "auroc_U_shift_baseline_only": float(auroc(u, y)),
            "auroc_F_jitter_baseline_only": float(auroc(f, y)),
            "n": int(elig.sum()),
            "y_rate": float(y.mean()),
        }

    (OUT / "loso_subjects.json").write_text(json.dumps(loso_spec, indent=2) + "\n")
    rec = loso_PL(subjects)
    rec["baselines_within_subject"] = baselines
    rec["paper"] = 2
    rec["status"] = "pilot_protocol_demo"
    rec["claim"] = (
        "LOSO P_L on n=2 pilots is a design check: ranking of L transfers across sites, "
        "but ECE remains poor under base-rate shift. Not hat{U}. Scale required for calibration claims."
    )
    (OUT / "P_L_loso.json").write_text(json.dumps(rec, indent=2) + "\n")
    md = [
        "# Paper 2 — pilot LOSO \(P_L\)",
        "",
        rec["claim"],
        "",
        "## Baselines (within-subject AUROC vs leftover y)",
        "",
        "| Pair | L | U (baseline) | F (baseline) |",
        "|---|---:|---:|---:|",
    ]
    for k, v in baselines.items():
        md.append(
            f"| `{k}` | {v['auroc_L']:.3f} | {v['auroc_U_shift_baseline_only']:.3f} | {v['auroc_F_jitter_baseline_only']:.3f} |"
        )
    md += ["", "## LOSO folds", ""]
    for f in rec["folds"]:
        md.append(
            f"- test `{f['test']}`: AUROC L={f['auroc_L']:.3f}, P_L={f['auroc_P_L']:.3f}, ECE={f['ECE_P_L']:.3f}, "
            f"mean P={f['mean_P_L']:.3f} vs y={f['y_rate']:.3f}"
        )
    md.append("")
    (OUT / "P_L_loso.md").write_text("\n".join(md))
    print(json.dumps({"wrote": str(OUT / "P_L_loso.json"), "folds": len(rec["folds"])}, indent=2))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
