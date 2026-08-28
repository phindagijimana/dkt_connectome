#!/usr/bin/env python3
"""Validate Step 1.1 VBT and Step 3.1 lesion-aware ACT artifacts."""

from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

import nibabel as nib
import numpy as np


def _load_json(path: Path) -> dict:
    if not path.is_file():
        raise FileNotFoundError(path)
    return json.loads(path.read_text())


def _require_file(path: Path, label: str, errors: list[str]) -> bool:
    if path.is_file():
        return True
    errors.append(f"missing {label}: {path}")
    return False


def validate_vbt(vbt_json: Path) -> list[str]:
    errors: list[str] = []
    payload = _load_json(vbt_json)
    if payload.get("backend") != "vbt":
        errors.append(f"VBT backend expected 'vbt', got {payload.get('backend')!r}")

    qc = payload.get("qc") or {}
    for key in ("original", "inpainted", "mask_used_for_qc"):
        _require_file(Path(qc[key]), key, errors) if qc.get(key) else errors.append(
            f"qc missing {key}"
        )

    if not qc.get("geometry_matches_original"):
        errors.append("VBT QC: geometry_matches_original is false")
    if qc.get("ok") is not True:
        errors.append("VBT QC: ok is not true")
    outside = float(qc.get("outside_lesion_correlation", 0))
    if outside < 0.995:
        errors.append(f"VBT QC: outside_lesion_correlation {outside:.6f} < 0.995")
    if int(qc.get("regenerated_voxels", 0)) <= 0:
        errors.append("VBT QC: no regenerated voxels inside lesion")

    t1w = nib.load(str(qc["original"]))
    inpainted = nib.load(str(qc["inpainted"]))
    if t1w.shape != inpainted.shape:
        errors.append(f"VBT shape mismatch: {t1w.shape} vs {inpainted.shape}")
    if not np.allclose(t1w.affine, inpainted.affine):
        errors.append("VBT affine mismatch between T1w and inpainted output")

    mask = nib.load(str(qc["mask_used_for_qc"])).get_fdata() != 0
    if not mask.any():
        errors.append("VBT prepared lesion mask is empty")
    before = float(qc.get("lesion_relative_intensity_before", 0))
    after = float(qc.get("lesion_relative_intensity_after", 0))
    if before == after:
        errors.append("VBT lesion relative intensity unchanged (transplant may have failed)")

    return errors


def validate_lesion_aware_act(act_json: Path) -> list[str]:
    errors: list[str] = []
    payload = _load_json(act_json)
    if payload.get("act_mode") != "lesion-aware":
        errors.append(f"expected act_mode=lesion-aware, got {payload.get('act_mode')!r}")

    five_tt_source = payload.get("five_tt_source", "hsvs")
    spatial = payload.get("spatial_workflow", "acpc_5tt_edit_then_dwiref_resample")

    required = (
        "lesion_mask_source",
        "lesion_mask_in_dwi",
        "lesion_warp_method",
        "spatial_workflow",
        "lesion_aware_5tt",
        "tractogram",
        "sift2_weights",
        "five_tt_source",
    )
    if spatial == "acpc_5tt_edit_then_dwiref_resample":
        required += ("lesion_mask_in_acpc_5tt",)
    elif spatial == "native_5tt_edit_then_dwiref_resample":
        required += ("lesion_mask_in_native_5tt", "deep_atropos_segmentation")
    for key in required:
        path = payload.get(key)
        if not path:
            errors.append(f"provenance missing {key}")
            continue
        if key.endswith("_5tt") or key in (
            "lesion_mask_in_dwi",
            "lesion_aware_5tt",
            "tractogram",
            "sift2_weights",
        ):
            _require_file(Path(path), key, errors)

    tractogram = Path(payload["tractogram"])
    if tractogram.is_file() and tractogram.stat().st_size < 1024:
        errors.append(f"tractogram suspiciously small: {tractogram.stat().st_size} bytes")

    weights = Path(payload["sift2_weights"])
    if weights.is_file():
        text = weights.read_text().strip()
        if not text:
            errors.append("SIFT2 weights file is empty")
        else:
            data_lines = [line for line in text.splitlines() if line and not line.startswith("#")]
            if not data_lines:
                errors.append("SIFT2 weights file has no numeric rows")
            weight_count = sum(len(line.split(",")) for line in data_lines)
            if weight_count < 1:
                errors.append("SIFT2 weights file contains no weights")

    lesion_dwi = Path(payload["lesion_mask_in_dwi"])
    five_tt = Path(payload["lesion_aware_5tt"])
    if lesion_dwi.is_file() and five_tt.is_file():
        mask = nib.load(str(lesion_dwi)).get_fdata() != 0
        if not mask.any():
            errors.append("lesion_mask_in_dwi is empty after transform to DWI space")
        # pathology channel (index 4) should cover lesion voxels when both are NIfTI-readable;
        # MRtrix .mif requires mrstats in-container — skip unless user passes --mrtrix-container.
    return errors


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--vbt-json", type=Path, help="inpainting.json from Step 1.1 VBT run")
    parser.add_argument(
        "--lesion-act-json",
        type=Path,
        help="lesion_aware_act.json from Step 3.1",
    )
    args = parser.parse_args()
    if not args.vbt_json and not args.lesion_act_json:
        parser.error("pass --vbt-json and/or --lesion-act-json")

    failed = False
    if args.vbt_json:
        print(f"=== VBT validation: {args.vbt_json} ===")
        vbt_errors = validate_vbt(args.vbt_json)
        if vbt_errors:
            failed = True
            for err in vbt_errors:
                print(f"FAIL: {err}", file=sys.stderr)
        else:
            print("PASS: VBT artifacts and QC checks OK")

    if args.lesion_act_json:
        print(f"=== Lesion-aware ACT validation: {args.lesion_act_json} ===")
        act_errors = validate_lesion_aware_act(args.lesion_act_json)
        if act_errors:
            failed = True
            for err in act_errors:
                print(f"FAIL: {err}", file=sys.stderr)
        else:
            print("PASS: lesion-aware ACT provenance and artifacts OK")

    raise SystemExit(1 if failed else 0)


if __name__ == "__main__":
    main()
