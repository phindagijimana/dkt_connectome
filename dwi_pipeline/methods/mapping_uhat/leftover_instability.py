#!/usr/bin/env python3
"""Direction 5 as code: write leftover-instability L via edgeuq and verify pilot AUROCs.

Usage:
  PYTHONPATH=.../edgeuq/src python3 leftover_instability.py [--out work/R/directions]
"""

from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

import numpy as np

from edgeuq.cli import main as edgeuq_main
from edgeuq.instability import evaluate_leftover, score_neg_log_count
from edgeuq.io import save_matrix

ROOT = Path(__file__).resolve().parent
R = ROOT / "work" / "R"
SD = ROOT.parent.parent / "sample_data"

PILOTS = (
    {
        "key": "kirby21/KKI849",
        "pack": R / "kirby21_KKI849_ses-1",
        "c1": SD / "kirby21/freeze/sub-KKI849/connectomes/sub-KKI849/ses-2/dkt_connectome_count.csv",
    },
    {
        "key": "boekel_dwi_retest/pp01",
        "pack": R / "boekel_dwi_retest_pp01_ses-1",
        "c1": SD
        / "boekel_dwi_retest/freeze/sub-pp01/connectomes/sub-pp01/ses-2/dkt_connectome_count.csv",
    },
)


def _p10_from_cs(cs: np.ndarray, floor: float = 10.0) -> np.ndarray:
    return (cs >= floor).mean(axis=0)


def run_one(pilot: dict, out_dir: Path) -> dict:
    pack = pilot["pack"]
    c0 = np.load(pack / "C0.npy").astype(np.float64)
    c1 = np.loadtxt(pilot["c1"], delimiter=",")
    if c1.ndim != 2:
        c1 = np.loadtxt(pilot["c1"])
    u = np.loadtxt(pack / "U.csv", delimiter=",")
    f = np.load(pack / "F.npy").astype(np.float64)
    cs = np.load(pack / "Cs.npy")
    p10 = _p10_from_cs(cs)

    dest = out_dir / "instability" / pilot["key"].replace("/", "_")
    dest.mkdir(parents=True, exist_ok=True)
    c0_csv = dest / "C0.csv"
    p10_csv = dest / "P_ge_floor.csv"
    u_csv = dest / "U.csv"
    f_csv = dest / "F.csv"
    save_matrix(c0_csv, c0, fmt="%d")
    save_matrix(p10_csv, p10)
    save_matrix(u_csv, u)
    save_matrix(f_csv, f)

    rc = edgeuq_main(
        [
            "instability",
            "--count-run1",
            str(c0_csv),
            "--count-run2",
            str(pilot["c1"]),
            "--p10",
            str(p10_csv),
            "--u",
            str(u_csv),
            "--f",
            str(f_csv),
            "--out",
            str(dest),
        ]
    )
    if rc != 0:
        raise SystemExit(rc)

    L = score_neg_log_count(c0)
    np.save(pack / "L.npy", L)
    save_matrix(pack / "L.csv", L)
    ev = evaluate_leftover(c0, c1, p10=p10, u=u, f=f)
    return {"key": pilot["key"], "pack_L": str(pack / "L.csv"), "edgeuq_out": str(dest), **ev}


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--out", type=Path, default=R / "directions")
    args = ap.parse_args()
    args.out.mkdir(parents=True, exist_ok=True)

    rows = [run_one(p, args.out) for p in PILOTS]
    auroc_by_pair = {
        r["key"]: {
            "U": r["auroc"].get("U_shift"),
            "F": r["auroc"].get("F_jitter"),
            "neg_log1p_C0_only": r["auroc"]["L_neg_log1p_C0"],
            "one_minus_P10": r["auroc"].get("L_one_minus_P10"),
            "hybrid_C0_P10": r["auroc"].get("L_hybrid_C0_P10"),
            "n": r["n_eligible"],
            "y_rate": r["y_rate"],
        }
        for r in rows
    }
    rec = {
        "direction": 5,
        "implemented_as_code": True,
        "edgeuq_subcommand": "instability",
        "primary": "L_neg_log1p_C0",
        "not_hatU": True,
        "question": "Can a leftover-instability score (≠U) rank scan-rescan movers?",
        "auroc_by_pair": auroc_by_pair,
        "claim": (
            "Ses-1-only low-count (-log1p C0) AUROC ~0.70 beats U/F (~0.58–0.60) "
            "for leftover y on both pilots. Implemented as edgeuq instability (L)."
        ),
        "runs": rows,
    }
    (args.out / "05_leftover_score.json").write_text(json.dumps(rec, indent=2) + "\n")
    md = args.out / "05_leftover_score.md"
    lines = [
        "# Direction 5 — Separate leftover-instability score (code)",
        "",
        "Implemented as `edgeuq instability` → `L = -log1p(C0)`. Not hat{U}.",
        "",
        "| Pair | L AUROC | U | F | n |",
        "|---|---:|---:|---:|---:|",
    ]
    for k, v in auroc_by_pair.items():
        lines.append(
            f"| `{k}` | {v['neg_log1p_C0_only']:.3f} | {v['U']:.3f} | {v['F']:.3f} | {v['n']} |"
        )
    lines += [
        "",
        "## Claim",
        "",
        rec["claim"],
        "",
    ]
    md.write_text("\n".join(lines))
    print(json.dumps({"wrote": str(args.out / "05_leftover_score.json"), "pairs": list(auroc_by_pair)}, indent=2))
    return 0


if __name__ == "__main__":
    sys.exit(main())
