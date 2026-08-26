#!/usr/bin/env python3
"""Remove home NFS pipeline outputs for CIDUR backfill Group 2 (GE/no-fmap)."""
from __future__ import annotations

import argparse
import shutil
import subprocess
import sys
from datetime import datetime, timezone
from pathlib import Path

DEFAULT_LIST = (
    Path(__file__).resolve().parent.parent / "subject_list_cidur_backfill_group2.txt"
)
DEFAULT_HOME = Path(__file__).resolve().parent.parent / "results"


def du_human(p: Path) -> str:
    if not p.exists():
        return "0"
    try:
        out = subprocess.check_output(["du", "-sh", str(p)], text=True, stderr=subprocess.DEVNULL)
        return out.split()[0]
    except Exception:
        return "?"


def paths_for_subject(home: Path, sid: str) -> list[Path]:
    s = f"sub-{sid}"
    qsir_deriv = (
        home
        / "qsirecon_single_run_output"
        / "derivatives"
        / "qsirecon-MRtrix3_fork-SS3T_act-HSVS"
        / s
    )
    return [
        home / "qsiprep_single_run_output" / s,
        home / "freesurfer" / s,
        home / "qsirecon_single_run_output" / s,
        qsir_deriv,
        home / "connectomes" / s,
        home / "tractography" / s,
        home / ".snakemake_workdir" / s,
        home / ".snakemake_markers" / s,
        home / "node_strength" / "reports" / s,
        home / "node_strength" / "strength" / "per_subject" / f"{s}_strength.csv",
        home / "node_strength" / "strength" / "per_subject" / f"{s}_ai.csv",
        home / "node_strength" / "strength" / "per_subject" / f"{s}_strength_inter.csv",
        home / "node_strength" / "strength" / "per_subject" / f"{s}_strength_intra.csv",
        home / "node_strength" / "strength" / "per_subject" / f"{s}_ai_inter.csv",
        home / "node_strength" / "strength" / "per_subject" / f"{s}_ai_intra.csv",
        home / "node_strength" / "volume" / "per_subject" / f"{s}_volume.csv",
        home / "node_strength" / "volume" / "per_subject" / f"{s}_volume_ai.csv",
        home / "intermediate_results_qsiprep_single" / f"bids_filter_{s}.json",
        home / "intermediate_results_qsirecon_single" / f"bids_filter_{s}.json",
        *sorted((home / "logs").glob(f"{s}_*")),
    ]


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--home-results", type=Path, default=DEFAULT_HOME)
    ap.add_argument("--subject-list", type=Path, default=DEFAULT_LIST)
    ap.add_argument("--dry-run", action="store_true")
    args = ap.parse_args()

    subjects = [
        ln.strip()
        for ln in args.subject_list.read_text().splitlines()
        if ln.strip() and not ln.startswith("#")
    ]
    log_dir = Path(__file__).resolve().parent.parent.parent / "logs"
    log_dir.mkdir(parents=True, exist_ok=True)
    log_path = log_dir / f"delete_group2_home_{datetime.now(timezone.utc).strftime('%Y%m%d_%H%M%S')}.log"

    removed = 0
    with log_path.open("w", encoding="utf-8") as log:
        def emit(msg: str) -> None:
            print(msg)
            log.write(msg + "\n")

        emit(f"Delete Group 2 from {args.home_results} ({len(subjects)} subjects)")
        emit(f"Before: {du_human(args.home_results)}")
        if args.dry_run:
            emit("DRY RUN")

        for sid in subjects:
            emit(f"--- sub-{sid} ---")
            for p in paths_for_subject(args.home_results, sid):
                if not p.exists():
                    continue
                emit(f"  rm {p} ({du_human(p)})")
                if not args.dry_run:
                    if p.is_dir():
                        shutil.rmtree(p)
                    else:
                        p.unlink()
                    removed += 1

        emit(f"Removed {removed} paths")
        if not args.dry_run:
            emit(f"After: {du_human(args.home_results)}")
        emit(f"Log: {log_path}")

    return 0


if __name__ == "__main__":
    sys.exit(main())
