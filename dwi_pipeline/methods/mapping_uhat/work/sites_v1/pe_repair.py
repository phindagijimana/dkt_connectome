#!/usr/bin/env python3
"""Fill PhaseEncodingDirection from PhaseEncodingAxis when polarity is absent.

Does not invent j-. Site-07 Siemens already has j-. Not leftover y. Not gold.
"""

from __future__ import annotations

import json
from pathlib import Path

BIDS = Path(__file__).resolve().parents[4] / "sample_data/tracktbi_othersite/bids"
OUT = Path(__file__).resolve().parent / "pe_repair.json"


def main() -> int:
    rows = []
    for p in sorted(BIDS.glob("sub-*/ses-2WK/dwi/*.json")):
        d = json.loads(p.read_text())
        before = d.get("PhaseEncodingDirection")
        axis = d.get("PhaseEncodingAxis")
        action = "keep"
        if not before and axis in {"i", "j", "k"}:
            d["PhaseEncodingDirection"] = axis
            d["PhaseEncodingDirectionNote"] = (
                "Copied from PhaseEncodingAxis. Polarity (+/-) was not in the sidecar. Not invented j-."
            )
            p.write_text(json.dumps(d, indent="\t") + "\n")
            action = "set_from_axis_no_polarity"
        rows.append(
            {
                "file": str(p),
                "before": before,
                "axis": axis,
                "after": d.get("PhaseEncodingDirection"),
                "action": action,
            }
        )
    OUT.write_text(json.dumps({"n": len(rows), "rows": rows, "not_gold": True}, indent=2) + "\n")
    print(json.dumps({"n": len(rows), "repaired": sum(r["action"] != "keep" for r in rows)}, indent=2))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
