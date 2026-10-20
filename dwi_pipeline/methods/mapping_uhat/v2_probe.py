#!/usr/bin/env python3
"""Phase 4: V2 probe. Inventory + import check. Not a warp posterior. Not hat{U}."""

from __future__ import annotations

import importlib.util
import json
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
INV = HERE / "work" / "inventory.json"
OUT = HERE / "work" / "V2"
SESSIONS = (
    "ideas-sub-1-ses-1",
    "ideas-sub-6-ses-1",
    "btc-sub-PAT20-ses-preop",
    "tbi-011011-neurolit-lesion",
    "tbi-011021-neurolit-lesion",
    "tbi-011204-neurolit-lesion",
)
MODELS = ("voxelmorph", "neurite", "tensorflow", "torch")


def _exists(p: str | None) -> bool:
    return bool(p) and Path(p).is_file()


def main() -> int:
    lock = json.loads((OUT / "LOCK.json").read_text())
    if not lock.get("locked"):
        raise SystemExit("V2 LOCK not locked")
    inv = {s["session_id"]: s for s in json.loads(INV.read_text())["sessions"]}
    rows = []
    for sid in SESSIONS:
        rec = inv[sid]
        t1 = rec.get("t1w")
        dwi = rec.get("dwiref")
        rows.append(
            {
                "session_id": sid,
                "t1w": t1,
                "dwiref": dwi,
                "t1w_exists": _exists(t1),
                "dwiref_exists": _exists(dwi),
            }
        )
    imports = {}
    for name in MODELS:
        imports[name] = importlib.util.find_spec(name) is not None
    model_ok = bool(imports["voxelmorph"])
    inv_ok = all(r["t1w_exists"] and r["dwiref_exists"] for r in rows)
    if not inv_ok:
        status = "fail_missing_images"
    elif not model_ok:
        status = "blocked_on_model"
    else:
        status = "model_importable_not_run"
    probe_win = status in {"blocked_on_model", "model_importable_not_run"}
    summary = {
        "experiment": "V2_probe",
        "status": status,
        "probe_win": probe_win,
        "python": sys.executable,
        "inventory_ok": inv_ok,
        "imports": imports,
        "sessions": rows,
        "posterior_run": False,
        "claim": (
            "V2 probe only: images inventoried; no p(phi|images) computed. Not hat{U}."
            if probe_win
            else "V2 probe fail: missing T1/dwiref. Not hat{U}."
        ),
        "not_hatU": True,
        "not_Simpson_posterior": True,
        "not_VoxelMorph_run": True,
    }
    OUT.mkdir(parents=True, exist_ok=True)
    (OUT / "v2_probe.json").write_text(json.dumps(summary, indent=2) + "\n")
    print(json.dumps({"status": status, "probe_win": probe_win, "imports": imports}, indent=2))
    return 0 if probe_win else 1


if __name__ == "__main__":
    raise SystemExit(main())
