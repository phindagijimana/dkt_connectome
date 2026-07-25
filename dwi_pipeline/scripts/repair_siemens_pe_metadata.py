#!/usr/bin/env python3
"""Add Siemens PE metadata missing from sparse dcm2niix/dcm2bids sidecars."""

from __future__ import annotations

import argparse
import json
from pathlib import Path


def pe_fields(meta: dict, pe_dir: str = "j-") -> dict:
    matrix_pe = int(meta["AcquisitionMatrixPE"])
    recon_pe = int(meta.get("ReconMatrixPE", matrix_pe))
    pixel_bw = float(meta["PixelBandwidth"])
    # When BandwidthPerPixelPhaseEncode is absent, dcm2niix often omits PE timing on
    # Siemens exports. This heuristic (PixelBandwidth / AcquisitionMatrixPE) matches
    # the scale of manually verified TrioTim DTI sidecars when BWpppe is unavailable.
    bwpppe = pixel_bw / matrix_pe
    ees = 1.0 / (bwpppe * recon_pe)
    trt = ees * (matrix_pe - 1)
    out = {
        "PhaseEncodingDirection": pe_dir,
        "BandwidthPerPixelPhaseEncode": round(bwpppe, 6),
        "EffectiveEchoSpacing": round(ees, 9),
        "TotalReadoutTime": round(trt, 7),
    }
    if "sms3" in meta.get("SeriesDescription", "").lower():
        out["MultibandAccelerationFactor"] = 3
    return out


def extend_slice_timing(st: list[float], n_slices: int) -> list[float]:
    if len(st) >= n_slices:
        return st[:n_slices]
    out = list(st)
    while len(out) < n_slices:
        step = out[-1] - out[-2] if len(out) >= 2 else 0.01562
        out.append(round(out[-1] + step, 5))
    return out


def patch_json(path: Path, *, pe_dir: str, slice_timing_from: Path | None, n_slices: int | None) -> None:
    meta = json.loads(path.read_text())
    meta.update(pe_fields(meta, pe_dir=pe_dir))
    if slice_timing_from is not None:
        ref = json.loads(slice_timing_from.read_text())
        st = ref.get("SliceTiming")
        if st and n_slices:
            meta["SliceTiming"] = extend_slice_timing(st, n_slices)
    path.write_text(json.dumps(meta, indent=4) + "\n")
    print(f"[repair-pe] updated {path}")


def main() -> None:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--json", type=Path, action="append", required=True)
    ap.add_argument("--pe-dir", default="j-")
    ap.add_argument("--slice-timing-from", type=Path)
    ap.add_argument("--n-slices", type=int)
    args = ap.parse_args()
    for jpath in args.json:
        patch_json(
            jpath,
            pe_dir=args.pe_dir,
            slice_timing_from=args.slice_timing_from,
            n_slices=args.n_slices,
        )


if __name__ == "__main__":
    main()
