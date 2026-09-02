#!/usr/bin/env python3
"""Check expected pipeline artifacts for one subject under RESULTS_ROOT."""

from __future__ import annotations

import argparse
import sys
from pathlib import Path

PARC = "dkt"


def ok(path: Path) -> bool:
    try:
        return path.is_file() or (path.is_symlink() and path.exists())
    except OSError:
        return False


def checks_for(root: Path, subject: str, *, mode: str) -> dict[str, bool]:
    sub = f"sub-{subject}"
    markers = root / ".snakemake_markers" / sub
    conn = root / "connectomes" / sub
    tract = root / "tractography" / sub
    fs = root / "freesurfer" / sub / "mri" / "aparc+aseg.mgz"
    ns = root / "node_strength" / "strength" / "per_subject" / f"{sub}_strength.csv"
    disc = root / "connectomes" / sub / "disconnectome" / "disconnectome.json"
    qc = root / "qc" / sub / "subject_qc.html"

    out: dict[str, bool] = {}
    if mode in ("all", "qsiprep"):
        out["qsiprep"] = (markers / "qsiprep.done").is_file()
    if mode in ("all", "recon"):
        out["recon"] = ok(fs)
    if mode in ("all", "qsirecon"):
        out["qsirecon"] = (markers / "qsirecon.done").is_file()
    if mode in ("all", "connectome"):
        out["connectome_csv"] = ok(conn / f"{PARC}_connectome.csv")
        out["connectome_nodes"] = ok(conn / f"{PARC}_nodes.mif")
        out["sdstream_tck"] = ok(tract / "model-SDSTREAM_streamlines.tck")
    if mode in ("all", "disconnectome"):
        out["disconnectome"] = ok(disc)
    if mode in ("all", "nodestrength"):
        out["nodestrength"] = ok(ns)
    if mode == "all":
        out["subject_qc"] = ok(qc)
    return out


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--results-root", type=Path, required=True)
    parser.add_argument("--subject", required=True, help="Subject ID without sub- prefix")
    parser.add_argument(
        "--mode",
        default="all",
        choices=("all", "qsiprep", "recon", "qsirecon", "connectome", "disconnectome", "nodestrength"),
    )
    args = parser.parse_args()
    root = args.results_root.expanduser().resolve()
    subject = args.subject.removeprefix("sub-")

    if not root.is_dir():
        print(f"ERROR: results root not found: {root}", file=sys.stderr)
        return 2

    results = checks_for(root, subject, mode=args.mode)
    missing = [name for name, present in results.items() if not present]

    print(f"check: sub-{subject} mode={args.mode} root={root}")
    for name, present in results.items():
        mark = "OK" if present else "MISSING"
        print(f"  [{mark:7}] {name}")

    if missing:
        print(f"check: FAIL — {len(missing)} missing artifact(s)", file=sys.stderr)
        return 1
    print("check: OK")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
