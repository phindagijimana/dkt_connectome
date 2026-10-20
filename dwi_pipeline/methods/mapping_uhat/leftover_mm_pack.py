#!/usr/bin/env python3
"""Phase 2: package A5 session leftover + V1 voxel maps. Millimetres only. Not P."""

from __future__ import annotations

import json
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
A5 = HERE / "work" / "a5"
V1 = HERE / "work" / "V"
OUT = HERE / "work" / "leftover_mm"

SESSIONS = (
    "ideas-sub-1-ses-1",
    "ideas-sub-6-ses-1",
    "btc-sub-PAT20-ses-preop",
    "tbi-011011-neurolit-lesion",
    "tbi-011021-neurolit-lesion",
    "tbi-011204-neurolit-lesion",
)


def main() -> int:
    a5 = json.loads((A5 / "a5_summary.json").read_text())
    v1 = json.loads((V1 / "v_summary.json").read_text())
    if a5.get("a5_fail") is True:
        raise SystemExit("A5 failed; do not package leftover mm as a product")
    if not v1.get("win"):
        raise SystemExit("V1 did not win; keep A5 session M_s only")
    v_by = {r["session_id"]: r for r in v1["sessions"]}
    rows = []
    for sid in SESSIONS:
        vr = v_by[sid]
        rows.append(
            {
                "session_id": sid,
                "A5_M_s_mm": float(a5["M_s"][sid]),
                "A5_syn_M_s_mm": float(vr["syn_M_s_from_a5"]),
                "V1_voxel_median_mm": float(vr["median_of_voxel_medians_mm"]),
                "V1_voxel_sd_mm": float(vr["median_of_voxel_sd_mm"]),
                "V1_p95_voxel_median_mm": float(vr["p95_of_voxel_medians_mm"]),
                "not_P": True,
                "not_hatU": True,
            }
        )
    OUT.mkdir(parents=True, exist_ok=True)
    summary = {
        "phase": 2,
        "product": "leftover millimetres (A5 + V1). Limitation of the 1 mm paper. Not a probability.",
        "a5_fail": False,
        "v1_win": True,
        "sessions": rows,
        "claim": "Leftover after usual T1-dwiref alignment is real (~0.6-0.8 mm on confirmation). Not hat{U}.",
        "not_hatU": True,
        "not_proxy_hatU": True,
        "no_ECE": True,
    }
    (OUT / "leftover_mm_summary.json").write_text(json.dumps(summary, indent=2) + "\n")
    cols = [
        "session_id",
        "A5_M_s_mm",
        "A5_syn_M_s_mm",
        "V1_voxel_median_mm",
        "V1_voxel_sd_mm",
        "V1_p95_voxel_median_mm",
    ]
    lines = [",".join(cols)]
    for r in rows:
        lines.append(",".join(str(r[c]) if c == "session_id" else f"{r[c]:.6f}" for c in cols))
    (OUT / "leftover_mm_table.csv").write_text("\n".join(lines) + "\n")
    print(json.dumps({"n": len(rows), "not_P": True}, indent=2))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
