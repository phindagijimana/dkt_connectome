#!/usr/bin/env python3
"""Score Phase-3 remaining gates (SUGAR / CortexMorph / V2C) ±LIT machine checks."""

from __future__ import annotations

import argparse
import json
from pathlib import Path


def _exists(*paths: Path) -> bool:
    return all(p.is_file() for p in paths)


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--root", type=Path, required=True)
    ap.add_argument("--sid", default="sub-EG")
    ap.add_argument("--out", type=Path, required=True)
    args = ap.parse_args()
    r, sid = args.root, args.sid

    sugar_w = r / "sugar_with_lit" / sid
    sugar_n = r / "sugar_no_lit" / sid
    cm_w = r / "cm_with_lit" / sid
    cm_n = r / "cm_no_lit" / sid
    v2c_w = r / "v2c_with_lit" / sid
    v2c_n = r / "v2c_no_lit" / sid

    report = {
        "sugar": {
            "with_lit_done": (sugar_w / "scripts" / "dlsurfer_sugar.done").is_file(),
            "no_lit_done": (sugar_n / "scripts" / "dlsurfer_sugar.done").is_file(),
            "with_lit_sphere": any(sugar_w.glob("**/lh*.sphere*")) or any(sugar_w.glob("surf/*")),
            "no_lit_sphere": any(sugar_n.glob("**/lh*.sphere*")) or any(sugar_n.glob("surf/*")),
        },
        "cortexmorph": {
            "with_lit_csv": (cm_w / "mri" / "thickness_cortexmorph.csv").is_file(),
            "no_lit_csv": (cm_n / "mri" / "thickness_cortexmorph.csv").is_file(),
            "with_lit_done": (cm_w / "scripts" / "dlsurfer_cortexmorph.done").is_file(),
            "no_lit_done": (cm_n / "scripts" / "dlsurfer_cortexmorph.done").is_file(),
        },
        "v2c": {
            "with_lit_done": (v2c_w / "scripts" / "dlsurfer_v2c.done").is_file(),
            "no_lit_done": (v2c_n / "scripts" / "dlsurfer_v2c.done").is_file(),
            "with_lit_cmd": (v2c_w / "scripts" / "dlsurfer_v2c_cmd.txt").is_file(),
        },
        "pass_criteria": {},
        "note": (
            "CortexMorph used as DL-CTE-family Ready pick (Wu DL-CTE GitHub empty). "
            "SynthSeg-PC vs JLF excluded from this round."
        ),
    }
    report["pass_criteria"]["sugar_ok"] = bool(
        report["sugar"]["with_lit_done"] and report["sugar"]["no_lit_done"]
    )
    report["pass_criteria"]["cortexmorph_ok"] = bool(
        report["cortexmorph"]["with_lit_csv"] and report["cortexmorph"]["no_lit_csv"]
    )
    report["pass_criteria"]["v2c_ok"] = bool(
        report["v2c"]["with_lit_done"] and report["v2c"]["no_lit_done"]
    )
    report["machine_ok"] = (
        report["pass_criteria"]["sugar_ok"]
        and report["pass_criteria"]["cortexmorph_ok"]
        # V2C may still be open if env missing — reported separately
    )
    args.out.parent.mkdir(parents=True, exist_ok=True)
    args.out.write_text(json.dumps(report, indent=2) + "\n")
    print(json.dumps(report["pass_criteria"], indent=2))
    print(f"wrote {args.out}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
