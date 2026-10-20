#!/usr/bin/env python3
"""Fill Boekel TotalReadoutTime from Boekel 2017 published bandwidth. Not leftover y. Not gold.

Boekel, Forstmann, Keuken (2017) Psychophysiology: bandwidth 32.1 Hz/Px,
FOV 224 mm, 2 mm iso → recon PE 112, SENSE AP=2.
BIDS: EES = 1 / (BW_pe * ReconMatrixPE); TRT = EES * (ReconMatrixPE - 1).
Does not invent 0.05 s. No vendor PAR in the NITRC V2 tars.
"""

from __future__ import annotations

import json
from pathlib import Path

BIDS = Path(__file__).resolve().parents[4] / "sample_data/boekel_dwi_retest/bids"
OUT = Path(__file__).resolve().parent / "boekel_trt_repair.json"
BW_PE = 32.1
RECON_PE = 112
EES = 1.0 / (BW_PE * RECON_PE)
TRT = EES * (RECON_PE - 1)
NOTE = (
    "Boekel 2017 Psychophysiology 54:24-33: bandwidth 32.1 Hz/Px, FOV 224 mm, "
    "2 mm iso (ReconMatrixPE=112), SENSE AP=2. "
    "EffectiveEchoSpacing=1/(32.1*112); TotalReadoutTime=EES*(112-1). "
    "Not invented 0.05. Not leftover y."
)


def main() -> int:
    rows = []
    for p in sorted(BIDS.glob("sub-*/ses-*/dwi/*_dwi.json")):
        d = json.loads(p.read_text())
        before = d.get("TotalReadoutTime")
        d["BandwidthPerPixelPhaseEncode"] = BW_PE
        d["ReconMatrixPE"] = RECON_PE
        d["EffectiveEchoSpacing"] = EES
        d["TotalReadoutTime"] = TRT
        d["TotalReadoutTimeNote"] = NOTE
        p.write_text(json.dumps(d, indent=2) + "\n")
        rows.append({"file": str(p), "before": before, "after": TRT})
    rec = {
        "n": len(rows),
        "BandwidthPerPixelPhaseEncode": BW_PE,
        "ReconMatrixPE": RECON_PE,
        "EffectiveEchoSpacing": EES,
        "TotalReadoutTime": TRT,
        "citation": "Boekel, Forstmann, Keuken 2017 Psychophysiology 54:24-33",
        "formula": "TRT = (ReconMatrixPE-1) / (BW_pe * ReconMatrixPE)",
        "not_invented_005": True,
        "not_gold": True,
        "not_leftover_y": True,
        "rows": rows,
    }
    OUT.write_text(json.dumps(rec, indent=2) + "\n")
    print(
        json.dumps(
            {
                "n": len(rows),
                "TotalReadoutTime": TRT,
                "EffectiveEchoSpacing": EES,
            },
            indent=2,
        )
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
