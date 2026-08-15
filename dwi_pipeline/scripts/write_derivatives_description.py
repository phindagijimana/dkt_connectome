#!/usr/bin/env python3
"""Write dataset_description.json for pipeline derivatives (RESULTS_ROOT).

This documents provenance at the derivatives root. The on-disk folder layout
is site-specific and not fully BIDS Derivatives spec compliant — see
docs/derivatives.md.
"""

from __future__ import annotations

import argparse
import json
from datetime import datetime, timezone
from pathlib import Path

PIPELINE_NAME = "DKT Connectome"
PIPELINE_VERSION = "0.2.0"
CODE_URL = "https://github.com/phindagijimana/dkt_connectome"


def build_provenance(bids_dir: Path | None, results_root: Path) -> dict:
    generated = {
        "Name": PIPELINE_NAME,
        "Version": PIPELINE_VERSION,
        "CodeURL": CODE_URL,
        "Description": (
            "QSIPrep → optional inpainting → recon → QSIRecon → DKT connectome "
            "→ optional disconnectome → node strength"
        ),
    }
    out: dict = {
        "Name": f"{PIPELINE_NAME} derivatives",
        "BIDSVersion": "1.9.0",
        "DatasetType": "derivative",
        "GeneratedBy": [generated],
        "HowToAcknowledge": (
            "Cite QSIPrep, QSIRecon, FreeSurfer/FastSurfer, and Griffis et al. 2019 "
            "for disconnectome methods."
        ),
        "PipelineResultsRoot": str(results_root.resolve()),
        "WrittenAt": datetime.now(timezone.utc).replace(microsecond=0).isoformat(),
        "LayoutNote": (
            "Internal custom layout (qsiprep_single_run_output/, connectomes/, …). "
            "BIDS Derivatives export available at derivatives/ via export_bids_derivatives.py. "
            "See dwi_pipeline/docs/derivatives.md."
        ),
    }
    if bids_dir is not None:
        out["SourceDatasets"] = [
            {
                "URL": f"file://{bids_dir.resolve()}",
                "Version": "unspecified",
            }
        ]
    return out


def main() -> None:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--results-root", type=Path, required=True)
    ap.add_argument("--bids-dir", type=Path, default=None)
    ap.add_argument("--dry-run", action="store_true")
    args = ap.parse_args()

    results_root = args.results_root.resolve()
    results_root.mkdir(parents=True, exist_ok=True)
    out_path = results_root / "dataset_description.json"
    payload = build_provenance(args.bids_dir.resolve() if args.bids_dir else None, results_root)

    if args.dry_run:
        print(json.dumps(payload, indent=2))
        return

    out_path.write_text(json.dumps(payload, indent=2) + "\n")
    print(f"Wrote {out_path}")


if __name__ == "__main__":
    main()
