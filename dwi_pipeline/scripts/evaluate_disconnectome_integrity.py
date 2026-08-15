#!/usr/bin/env python3
"""QC checks for Step 4.5 disconnectome outputs — data-integrity sanity tests.

Verifies that primary (P) and spared connectomes use consistent weighting and
that disconnection indices are internally coherent.

Usage:
  python3 evaluate_disconnectome_integrity.py \\
    --disconnectome-dir connectomes/sub-TBI011011/disconnectome
  python3 evaluate_disconnectome_integrity.py --disconnectome-dir ... --json-out report.json
"""

from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

import numpy as np

SPARED_CONNECTOME_FILES = {
    "A": "dkt_connectome_A_parcexcised.csv",
    "B": "dkt_connectome_B_streamexcluded.csv",
    "C": "dkt_connectome_C_both.csv",
}


def load_csv(path: Path) -> np.ndarray:
    rows = []
    with path.open() as fh:
        for line in fh:
            line = line.strip()
            if line:
                rows.append([float(x) for x in line.split(",")])
    return np.asarray(rows, dtype=np.float64)


def edge_stats(primary: np.ndarray, spared: np.ndarray) -> dict:
    mask = primary > 0
    n = int(mask.sum())
    if n == 0:
        return {"n_active": 0}
    tri = np.triu(np.ones_like(primary, dtype=bool), k=1) & mask
    p_vals = primary[tri]
    s_vals = spared[tri]
    corr = float(np.corrcoef(p_vals, s_vals)[0, 1]) if p_vals.size else float("nan")
    spared_gt = int(((spared > primary) & mask).sum())
    d = np.clip(1.0 - spared[mask] / primary[mask], 0.0, 1.0)
    edges_d_gt_0 = int((d > 0).sum())
    return {
        "n_active": n,
        "total_primary": float(primary.sum()),
        "total_spared": float(spared.sum()),
        "total_ratio_spared_over_primary": float(spared.sum() / primary.sum()) if primary.sum() else 0.0,
        "corr_upper_triangle": corr,
        "edges_spared_gt_primary": spared_gt,
        "fraction_spared_gt_primary": spared_gt / n,
        "mean_disconnection_clipped": float(d.mean()),
        "max_disconnection": float(d.max()),
        "edges_disconnection_gt_0": edges_d_gt_0,
    }


def _status_for_option(stats: dict, weighting: str) -> str:
    status = "PASS"
    if stats.get("edges_spared_gt_primary", 0) > 0 and weighting == "count":
        if stats.get("fraction_spared_gt_primary", 0.0) > 0.05:
            status = "WARN"
    if stats.get("total_ratio_spared_over_primary", 1.0) > 1.05:
        status = "WARN"
    return status


def overall_status(checks: list[dict]) -> str:
    statuses = {c["status"] for c in checks}
    if "FAIL" in statuses:
        return "FAIL"
    if "WARN" in statuses:
        return "WARN"
    return "PASS"


def collect_integrity_report(ddir: Path) -> dict:
    ddir = ddir.resolve()
    prov_path = ddir / "disconnectome.json"
    if not prov_path.is_file():
        raise FileNotFoundError(f"missing {prov_path}")

    prov = json.loads(prov_path.read_text())
    primary_path = Path(prov["primary_connectome"])
    weighting = prov.get("connectome_weighting", "unknown")
    checks: list[dict] = []

    for label in ("A", "B", "C"):
        spared_path = ddir / SPARED_CONNECTOME_FILES[label]
        if not spared_path.is_file():
            continue
        stats = edge_stats(load_csv(primary_path), load_csv(spared_path))
        checks.append(
            {
                "name": f"Option {label} vs primary",
                "status": _status_for_option(stats, weighting),
                "stats": stats,
            }
        )

    spared_label = prov.get("disconnection_spared", "C")
    d_path = ddir / "disconnection_matrix.csv"
    d_recalc_path = ddir / f"disconnection_matrix_{spared_label}.csv"
    if d_path.is_file() and d_recalc_path.is_file():
        d_main = load_csv(d_path)
        d_copy = load_csv(d_recalc_path)
        checks.append(
            {
                "name": f"disconnection_matrix.csv matches _{spared_label}",
                "status": "PASS" if np.allclose(d_main, d_copy) else "FAIL",
                "stats": {},
            }
        )

    roi = ddir / "lesion_roi_metrics.csv"
    checks.append(
        {
            "name": "lesion_roi_metrics.csv exists",
            "status": "PASS" if roi.is_file() else "FAIL",
            "stats": {},
        }
    )

    lesion_meta = prov.get("lesion_selection") or {}
    disconnection_summary = prov.get("disconnection_summary") or {}
    disconnection_by_option = prov.get("disconnection_by_option") or {}

    return {
        "disconnectome_dir": str(ddir),
        "subject": prov.get("subject", ""),
        "session": prov.get("session", ""),
        "weighting": weighting,
        "disconnection_spared": spared_label,
        "lesion_selection": lesion_meta,
        "disconnection_summary": disconnection_summary,
        "disconnection_by_option": disconnection_by_option,
        "checks": checks,
        "overall_status": overall_status(checks),
    }


def exit_code_from_report(report: dict, fail_on_warning: bool = False) -> int:
    for check in report["checks"]:
        if check["status"] == "FAIL":
            return 1
        if check["status"] == "WARN" and fail_on_warning:
            return 1
    return 0


def print_report(report: dict) -> None:
    print(
        f"Disconnectome integrity: {Path(report['disconnectome_dir']).name} "
        f"(weighting={report['weighting']}, overall={report['overall_status']})"
    )
    for check in report["checks"]:
        print(f"  [{check['status']}] {check['name']}")
        for key, value in check.get("stats", {}).items():
            if isinstance(value, float):
                print(f"         {key}: {value:.6f}")
            else:
                print(f"         {key}: {value}")


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--disconnectome-dir", type=Path, required=True)
    ap.add_argument("--fail-on-warning", action="store_true", help="Exit 1 if any check warns")
    ap.add_argument("--json-out", type=Path, help="Write structured JSON report")
    args = ap.parse_args()

    try:
        report = collect_integrity_report(args.disconnectome_dir)
    except FileNotFoundError as exc:
        print(f"ERROR: {exc}", file=sys.stderr)
        return 2

    print_report(report)
    if args.json_out:
        args.json_out.write_text(json.dumps(report, indent=2) + "\n")

    return exit_code_from_report(report, fail_on_warning=args.fail_on_warning)


if __name__ == "__main__":
    sys.exit(main())
