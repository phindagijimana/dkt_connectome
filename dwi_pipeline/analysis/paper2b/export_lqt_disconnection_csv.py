#!/usr/bin/env python3
"""Normalize LQT parcel disconnection output to lqt_disconnection_matrix.csv (78×78)."""

from __future__ import annotations

import argparse
import csv
import json
import shutil
import sys
from pathlib import Path

# Candidate filenames from LQT / manual export (newest first).
_CANDIDATES = (
    "lqt_disconnection_matrix.csv",
    "disconnection_matrix.csv",
    "parcel_disconnection_matrix.csv",
    "sdc_matrix.csv",
)


def _find_matrix(lqt_sub: Path) -> Path | None:
    for name in _CANDIDATES:
        p = lqt_sub / name
        if p.is_file():
            return p
    for p in sorted(lqt_sub.glob("**/*disconnection*.csv")):
        if p.is_file():
            return p
    return None


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--subject", required=True)
    ap.add_argument("--lqt-subject-dir", type=Path, required=True)
    ap.add_argument("--output", type=Path, required=True)
    args = ap.parse_args()

    src = _find_matrix(args.lqt_subject_dir)
    if src is None:
        print(
            f"ERROR: no disconnection CSV under {args.lqt_subject_dir}",
            file=sys.stderr,
        )
        return 1

    args.output.parent.mkdir(parents=True, exist_ok=True)
    if src.resolve() != args.output.resolve():
        shutil.copy2(src, args.output)

    prov = args.output.with_suffix(".provenance.json")
    prov.write_text(
        json.dumps(
            {
                "subject": args.subject,
                "source_csv": str(src),
                "output": str(args.output),
            },
            indent=2,
        )
        + "\n"
    )
    # Quick shape check (square numeric CSV).
    with args.output.open(newline="") as f:
        rows = list(csv.reader(f))
    n = len(rows)
    if n < 2 or any(len(r) != len(rows[0]) for r in rows):
        print("WARNING: matrix may not be square", file=sys.stderr)
    print(f"Wrote {args.output} ({n} rows)")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
