#!/usr/bin/env python3
"""Paper 2B RQ1: patient-specific vs LQT (or other) SDC edge agreement."""

from __future__ import annotations

import argparse
import csv
import json
import sys
from pathlib import Path

import numpy as np

from matrix_utils import load_square_matrix_csv, safe_pearson, upper_triangle_vector


def patient_sdc_path(connectomes: Path, subject: str) -> Path:
    return connectomes / f"sub-{subject}" / "disconnectome" / "disconnection_matrix.csv"


def lqt_sdc_path(lqt_dir: Path, subject: str) -> Path:
    """Expected after LQT batch: sub-*/lqt/disconnection_matrix_dkt78.csv (configure when LQT lands)."""
    for pat in (
        lqt_dir / f"sub-{subject}" / "lqt_disconnection_matrix.csv",
        lqt_dir / f"sub-{subject}" / "disconnection_matrix.csv",
    ):
        if pat.is_file():
            return pat
    return lqt_dir / f"sub-{subject}" / "lqt_disconnection_matrix.csv"


def compare_one(connectomes: Path, lqt_dir: Path | None, subject: str) -> dict:
    p_ps = patient_sdc_path(connectomes, subject)
    if not p_ps.is_file():
        return {"subject": subject, "status": "missing_patient_sdc", "path": str(p_ps)}

    ps = load_square_matrix_csv(p_ps)
    row: dict = {
        "subject": subject,
        "status": "patient_only",
        "patient_sdc": str(p_ps),
        "n_edges": int(upper_triangle_vector(ps).size),
    }

    if lqt_dir is None:
        return row

    p_lqt = lqt_sdc_path(lqt_dir, subject)
    if not p_lqt.is_file():
        row["status"] = "missing_lqt"
        row["lqt_expected"] = str(p_lqt)
        return row

    lqt = load_square_matrix_csv(p_lqt)
    if lqt.shape != ps.shape:
        row["status"] = "shape_mismatch"
        row["patient_shape"] = list(ps.shape)
        row["lqt_shape"] = list(lqt.shape)
        return row

    v_ps = upper_triangle_vector(ps)
    v_lqt = upper_triangle_vector(lqt)
    if v_ps.size != v_lqt.size:
        row["status"] = "edge_count_mismatch"
        return row

    np_abs = np.abs(v_ps - v_lqt)
    row.update(
        {
            "status": "ok",
            "lqt_sdc": str(p_lqt),
            "pearson_r": safe_pearson(v_ps, v_lqt),
            "mean_abs_diff": float(np_abs.mean()),
            "median_abs_diff": float(np.median(np_abs)),
        }
    )
    return row


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--dwi-connectomes", type=Path, required=True)
    ap.add_argument("--lqt-dir", type=Path, default=None, help="Normative SDC outputs (optional until LQT run)")
    ap.add_argument("--subject", action="append", dest="subjects", required=True)
    ap.add_argument("--output-dir", type=Path, required=True)
    args = ap.parse_args()

    args.output_dir.mkdir(parents=True, exist_ok=True)
    rows = [compare_one(args.dwi_connectomes, args.lqt_dir, s) for s in args.subjects]

    tsv = args.output_dir / "sdc_method_agreement.tsv"
    if rows:
        with tsv.open("w", newline="") as f:
            w = csv.DictWriter(f, fieldnames=sorted({k for r in rows for k in r}), delimiter="\t")
            w.writeheader()
            w.writerows(rows)

    ok = [r for r in rows if r.get("status") == "ok"]
    summary = {
        "step": "compare_sdc_methods",
        "dwi_connectomes": str(args.dwi_connectomes),
        "lqt_dir": str(args.lqt_dir) if args.lqt_dir else None,
        "n_subjects": len(rows),
        "n_with_lqt": len(ok),
        "per_subject": rows,
    }
    if ok:
        rs = [r["pearson_r"] for r in ok]
        summary["cohort"] = {
            "mean_pearson_r": float(np.nanmean(rs)),
            "frac_r_lt_0.7": float(sum(1 for r in rs if r < 0.7) / len(rs)),
        }

    json_path = args.output_dir / "sdc_method_agreement.json"
    json_path.write_text(json.dumps(summary, indent=2) + "\n")
    print(f"Wrote {tsv}")
    print(f"Wrote {json_path}")
    if args.lqt_dir is None:
        print("NOTE: --lqt-dir not set; patient-only rows (RQ1 pending LQT).", file=sys.stderr)
    return 0


if __name__ == "__main__":
    sys.exit(main())
