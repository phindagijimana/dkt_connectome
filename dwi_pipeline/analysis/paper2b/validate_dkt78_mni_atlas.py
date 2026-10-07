#!/usr/bin/env python3
"""QC DKT-78 MNI parcellation for LQT (78 contiguous labels 1..78)."""

from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

import nibabel as nib
import numpy as np


def load_lut_indices(lut_path: Path) -> list[int]:
    ids: list[int] = []
    for line in lut_path.read_text().splitlines():
        line = line.strip()
        if not line or line.startswith("#"):
            continue
        parts = line.split()
        if parts[0].isdigit():
            node_id = int(parts[0])
            if node_id > 0:
                ids.append(node_id)
    return sorted(set(ids))


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--atlas-nii", type=Path, required=True)
    ap.add_argument("--lut", type=Path, required=True)
    ap.add_argument("--output-json", type=Path, required=True)
    ap.add_argument("--reference-subject", required=True)
    ap.add_argument("--reference-session", default="2WK")
    args = ap.parse_args()

    expected = load_lut_indices(args.lut)
    if len(expected) != 78:
        print(f"WARNING: LUT has {len(expected)} indices, expected 78", file=sys.stderr)

    data = np.rint(nib.load(str(args.atlas_nii)).get_fdata()).astype(np.int32)
    present = sorted(int(x) for x in np.unique(data) if x > 0)

    missing = [i for i in expected if i not in present]
    extra = [i for i in present if i not in expected]

    report = {
        "atlas_nii": str(args.atlas_nii),
        "reference_subject": args.reference_subject,
        "reference_session": args.reference_session,
        "lut": str(args.lut),
        "n_labels_present": len(present),
        "n_labels_expected": len(expected),
        "missing_labels": missing,
        "extra_labels": extra,
        "ok": len(missing) == 0 and len(extra) == 0 and len(present) == 78,
    }

    args.output_json.parent.mkdir(parents=True, exist_ok=True)
    args.output_json.write_text(json.dumps(report, indent=2) + "\n")

    if not report["ok"]:
        print(json.dumps(report, indent=2), file=sys.stderr)
        print("ERROR: atlas failed DKT-78 QC", file=sys.stderr)
        return 1

    print(f"DKT-78 MNI atlas OK: {args.atlas_nii}")
    print(f"Wrote {args.output_json}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
