#!/usr/bin/env python3
"""Resolve the target BIDS session for a subject, the Snakemake-engine
counterpart of subject.sh's ``_resolve_target_session``.

Used at Snakemake DAG-build time (called from rules/common.smk) so that
output paths that embed ``ses-<session>`` (e.g. Step 1.1 inpainting results)
can be declared before any rule actually runs.

Resolution order (mirrors subject.sh exactly):
  1. --recon-session, if given (explicit override; same as RECON_SESSION env var)
  2. dwi-select filter's "dwi.session" field, building the filter cache first
     via build_bids_filter.py if it does not already exist

Prints the resolved session (without "ses-") to stdout on success.
"""

from __future__ import annotations

import argparse
import json
import subprocess
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
BUILD_BIDS_FILTER = HERE.parent.parent / "scripts" / "build_bids_filter.py"


def _read_session_from_filter(filter_path: Path) -> str:
    data = json.loads(filter_path.read_text())
    dwi = data.get("dwi") or {}
    ses = dwi.get("session")
    if ses is None:
        raise SystemExit(f"ERROR: dwi filter has no session entity: {filter_path}")
    if isinstance(ses, list):
        if len(ses) != 1:
            raise SystemExit(f"ERROR: ambiguous sessions in dwi filter: {ses}")
        return str(ses[0])
    return str(ses)


def main() -> None:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--bids-dir", required=True)
    ap.add_argument("--subject", required=True)
    ap.add_argument("--filter-cache", required=True, help="Path to read/write the bids_filter JSON cache")
    ap.add_argument("--dwi-select-json", default=None, help="dwi-select config JSON (omit if --recon-session set)")
    ap.add_argument("--static-bids-filter", default=None, help="Static QSIPrep bids filter JSON (QSIPREP_BIDS_FILTER)")
    ap.add_argument("--recon-session", default=None, help="Explicit session override (RECON_SESSION)")
    args = ap.parse_args()

    if args.recon_session:
        print(args.recon_session)
        return

    filter_cache = Path(args.filter_cache)
    if not filter_cache.is_file():
        if args.static_bids_filter:
            static = Path(args.static_bids_filter)
            if not static.is_file():
                raise SystemExit(f"ERROR: missing static bids filter: {static}")
            filter_cache.parent.mkdir(parents=True, exist_ok=True)
            filter_cache.write_text(static.read_text())
        elif args.dwi_select_json:
            subprocess.run(
                [
                    sys.executable,
                    str(BUILD_BIDS_FILTER),
                    "--bids-dir", args.bids_dir,
                    "--subject", args.subject,
                    "--select-json", args.dwi_select_json,
                    "--output", str(filter_cache),
                ],
                check=True,
            )
        else:
            raise SystemExit(
                "ERROR: no filter cache and no --dwi-select-json / --static-bids-filter to build one"
            )

    print(_read_session_from_filter(filter_cache))


if __name__ == "__main__":
    main()
