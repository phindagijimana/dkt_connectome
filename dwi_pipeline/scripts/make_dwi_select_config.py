#!/usr/bin/env python3
"""Write dwi_select_b<SHELL>.json for QSIPrep series selection."""

from __future__ import annotations

import argparse
import json
from pathlib import Path


def build_config(
    *,
    target_shell_b: int,
    dwi_acquisition: str | None = None,
    exclude_fmap_acquisitions: list[str] | None = None,
    fmap_fallback: str = "intended_for",
) -> dict:
    acq = dwi_acquisition or f"b{target_shell_b}"
    return {
        "target_shell_b": target_shell_b,
        "shell_tolerance": 100,
        "b0_tolerance": 50,
        "match_mode": "contains_target",
        "allow_multi_shell": False,
        "include_fmaps": True,
        "exclude_fmap_acquisitions": exclude_fmap_acquisitions or ["rs"],
        "include_sessions": None,
        "exclude_acquisitions": [],
        "on_no_match": "error",
        "dwi_acquisition": acq,
    }


def main() -> None:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--target-shell-b", type=int, required=True, help="e.g. 1000 for acq-b1000")
    ap.add_argument("--dwi-acquisition", help="BIDS acq label (default: b<TARGET_SHELL_B>)")
    ap.add_argument(
        "--output",
        type=Path,
        help="Output JSON path (default: ../config/dwi_select_b<SHELL>.json next to this script)",
    )
    ap.add_argument("--exclude-fmap-acq", action="append", default=["rs"])
    ap.add_argument("--fmap-fallback", default="intended_for")
    args = ap.parse_args()

    cfg = build_config(
        target_shell_b=args.target_shell_b,
        dwi_acquisition=args.dwi_acquisition,
        exclude_fmap_acquisitions=args.exclude_fmap_acq,
        fmap_fallback=args.fmap_fallback,
    )
    out = args.output
    if out is None:
        out = Path(__file__).resolve().parent.parent / "config" / f"dwi_select_b{args.target_shell_b}.json"
    out.parent.mkdir(parents=True, exist_ok=True)
    out.write_text(json.dumps(cfg, indent=2) + "\n")
    print(out)


if __name__ == "__main__":
    main()
