#!/usr/bin/env python3
"""Generate a minimal public BIDS fixture for CI smoke tests."""

from __future__ import annotations

import json
from pathlib import Path

import nibabel as nib
import numpy as np

ROOT = Path(__file__).resolve().parent / "bids_minimal"
SUB = "EXAMPLE"
SES = "ses-1"


def _write_nii(path: Path, shape: tuple[int, ...], dtype=np.float32) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    data = np.zeros(shape, dtype=dtype)
    img = nib.Nifti1Image(data, np.eye(4))
    nib.save(img, path)


def main() -> None:
    ROOT.mkdir(parents=True, exist_ok=True)

    (ROOT / "dataset_description.json").write_text(
        json.dumps(
            {
                "Name": "TrackTBI Connectome minimal example",
                "BIDSVersion": "1.8.0",
                "DatasetType": "raw",
                "Authors": ["TrackTBI / CIDUR"],
                "License": "CC0",
            },
            indent=2,
        )
        + "\n"
    )
    (ROOT / "participants.tsv").write_text("participant_id\tage\tsex\nsub-EXAMPLE\t30\tF\n")

    base = ROOT / f"sub-{SUB}" / SES
    t1w = base / "anat" / f"sub-{SUB}_{SES}_T1w.nii.gz"
    dwi = base / "dwi" / f"sub-{SUB}_{SES}_dwi.nii.gz"
    lesion = base / "anat" / f"sub-{SUB}_{SES}_T1w_label-lesion_roi.nii.gz"

    _write_nii(t1w, (8, 8, 8))
    _write_nii(dwi, (8, 8, 8, 6))
    _write_nii(lesion, (8, 8, 8), dtype=np.uint8)

    (base / "anat" / f"sub-{SUB}_{SES}_T1w.json").write_text(
        json.dumps({"RepetitionTime": 2.0, "FlipAngle": 9}) + "\n"
    )
    (base / "dwi" / f"sub-{SUB}_{SES}_dwi.json").write_text(
        json.dumps(
            {
                "PhaseEncodingDirection": "j-",
                "TotalReadoutTime": 0.05,
                "EffectiveEchoSpacing": 0.0005,
            }
        )
        + "\n"
    )
    (base / "dwi" / f"sub-{SUB}_{SES}_dwi.bval").write_text("0 1000 1000 1000 1000 1000\n")
    (base / "dwi" / f"sub-{SUB}_{SES}_dwi.bvec").write_text(
        "0 0 0\n1 0 0\n0 1 0\n0 0 1\n1 1 0\n0 1 1\n"
    )

    print(f"Wrote minimal BIDS fixture under {ROOT}")


if __name__ == "__main__":
    main()
