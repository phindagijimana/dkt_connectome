#!/usr/bin/env python3
"""Compare dlsurfer_metrics.tsv compute seconds vs SLURM sacct wall time."""

from __future__ import annotations

import argparse
import csv
import json
import subprocess
from pathlib import Path


def _read_metrics(path: Path) -> dict:
    rows = []
    with path.open() as f:
        r = csv.DictReader(f, delimiter="\t")
        for row in r:
            rows.append(row)
    by_dev: dict[str, float] = {}
    total = 0.0
    for row in rows:
        try:
            sec = float(row.get("seconds", 0))
        except ValueError:
            continue
        total += sec
        dev = row.get("device", "?")
        by_dev[dev] = by_dev.get(dev, 0.0) + sec
    return {"steps": rows, "total_compute_s": total, "by_device_s": by_dev}


def _sacct(jobid: str) -> dict:
    cmd = [
        "sacct",
        "-j",
        jobid,
        "--format=JobID,State,Elapsed,TotalCPU,MaxRSS,ExitCode",
        "-P",
        "-n",
    ]
    try:
        out = subprocess.check_output(cmd, text=True, stderr=subprocess.DEVNULL)
    except (subprocess.CalledProcessError, FileNotFoundError) as exc:
        return {"error": str(exc)}
    lines = [ln for ln in out.strip().splitlines() if ln]
    return {"raw": lines, "primary": lines[0] if lines else None}


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--metrics", type=Path, required=True, help="…/scripts/dlsurfer_metrics.tsv")
    ap.add_argument("--jobid", default=None, help="SLURM job id for sacct")
    ap.add_argument("--out", type=Path, default=None)
    args = ap.parse_args()

    report = {"metrics": _read_metrics(args.metrics)}
    if args.jobid:
        report["sacct"] = _sacct(args.jobid)
        report["note"] = (
            "Compute seconds in metrics.tsv exclude queue wait; "
            "sacct Elapsed includes queue+run. Prefer metrics for device split, "
            "sacct for wall-clock / MaxRSS."
        )
    text = json.dumps(report, indent=2) + "\n"
    if args.out:
        args.out.parent.mkdir(parents=True, exist_ok=True)
        args.out.write_text(text)
    print(text)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
