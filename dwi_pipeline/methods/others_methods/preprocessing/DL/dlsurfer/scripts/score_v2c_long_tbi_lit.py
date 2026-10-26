#!/usr/bin/env python3
"""Score tbi_lit_v2c_long after sbatch_phase3_v2c_long_tbi_lit.sh."""

from __future__ import annotations

import argparse
import json
from pathlib import Path


def _arm_ok(root: Path, sid: str) -> dict:
    scripts = root / sid / "scripts"
    done = scripts / "dlsurfer_v2c_long.done"
    flow = scripts / "dlsurfer_v2c_long_flow_base.exit"
    mean = scripts / "dlsurfer_v2c_long_mean_meshes.exit"
    long = scripts / "dlsurfer_v2c_long_v2c_long.exit"
    meshes = scripts / "dlsurfer_v2c_long_meshes.txt"
    fs_inst = scripts / "dlsurfer_v2c_long_fs_install.exit"

    def _read_exit(p: Path) -> str:
        return p.read_text().strip() if p.is_file() else ""

    ok = done.is_file() and done.read_text().strip() == "ok"
    ply_count = 0
    if meshes.is_file():
        ply_count = sum(1 for ln in meshes.read_text().splitlines() if ln.strip())

    return {
        "done": ok,
        "exit_flow_base": _read_exit(flow),
        "exit_mean_meshes": _read_exit(mean),
        "exit_v2c_long": _read_exit(long),
        "mesh_paths_listed": ply_count,
        "fs_install_exit": _read_exit(fs_inst),
        "surf_white_lh": (root / sid / "surf" / "lh.white").is_file(),
        "surf_pial_lh": (root / sid / "surf" / "lh.pial").is_file(),
    }


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--root", type=Path, required=True, help="work/phase3_v2c_long")
    ap.add_argument("--sid", default="sub-TBI011021")
    ap.add_argument("--job", type=int, default=0)
    ap.add_argument("--cohort-note", default="")
    ap.add_argument("--out", type=Path, required=True)
    args = ap.parse_args()

    with_lit = _arm_ok(args.root / "with_lit", args.sid)
    no_lit = _arm_ok(args.root / "no_lit", args.sid)
    machine_ok = with_lit["done"] and no_lit["done"]

    payload = {
        "job": args.job,
        "sid": args.sid,
        "cohort_note": args.cohort_note,
        "machine_ok": machine_ok,
        "morphometric_equivalence_claim": False,
        "note": (
            "Longitudinal V2C-Long 3-step inference + optional FS surf install; "
            "not claimed equal to fs-long morphometry."
        ),
        "with_lit": with_lit,
        "no_lit": no_lit,
    }
    args.out.parent.mkdir(parents=True, exist_ok=True)
    args.out.write_text(json.dumps(payload, indent=2) + "\n")
    print(json.dumps(payload, indent=2))
    return 0 if machine_ok else 1


if __name__ == "__main__":
    raise SystemExit(main())
