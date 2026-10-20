#!/usr/bin/env python3
"""Check the standalone edgeuq package reproduces frozen U and C2 outputs on a public dev session."""

from __future__ import annotations

import json
import sys
from pathlib import Path

import nibabel as nib
import numpy as np

HERE = Path(__file__).resolve().parent
PKG = Path.home() / "Documents" / "edgeuq" / "src"
sys.path.insert(0, str(PKG))

from edgeuq.jitter import run_jitter  # noqa: E402
from edgeuq.io import extract_endpoints  # noqa: E402
from edgeuq.shift import compute_u  # noqa: E402

SID = "ideas-sub-1-ses-1"
A6 = HERE / "work" / "a6" / SID
C2 = HERE / "work" / "C2" / SID
SHIP = HERE.parents[1] / "experiments" / "mapping_screen" / "work" / "ship" / SID
INV = HERE / "work" / "inventory.json"
OUT = HERE / "work" / "package_parity.json"


def tck_path() -> Path:
    found: list[str] = []

    def walk(x):
        if isinstance(x, dict):
            if "tck" in x and SID in json.dumps(x)[:200]:
                found.append(x["tck"])
                return
            for v in x.values():
                walk(v)
        elif isinstance(x, list):
            for v in x:
                walk(v)

    walk(json.loads(INV.read_text()))
    return Path(found[0])


def maxabs(a, b) -> float:
    return float(np.max(np.abs(np.asarray(a, dtype=np.float64) - np.asarray(b, dtype=np.float64))))


def main() -> int:
    what = sys.argv[1] if len(sys.argv) > 1 else "u"
    rec = json.loads(OUT.read_text()) if OUT.is_file() else {"session": SID}
    ends_ref = np.load(A6 / "ends_identity.npy").astype(np.float32)
    l0 = nib.load(str(A6 / "L0_dkt.nii.gz"))
    nodes = np.rint(l0.get_fdata()).astype(np.int32)
    aff = np.asarray(l0.affine, dtype=np.float64)
    if what == "u":
        ends = extract_endpoints(tck_path())
        rec["endpoints_equal"] = bool(ends.shape == ends_ref.shape and np.array_equal(ends, ends_ref))
        res = compute_u(ends_ref, nodes, aff, 78)
        rec["C0_maxabs_vs_identity"] = maxabs(res["C0"], np.load(A6 / "C000_identity.npy"))
        rec["U_maxabs_vs_shipped"] = maxabs(res["U"], np.loadtxt(SHIP / "dkt_connectome_U.csv", delimiter=","))
        rec["u_summary"] = res["summary"]
    else:
        s = json.loads((C2 / "session.json").read_text())
        res = run_jitter(ends_ref, nodes, aff, 78, float(s["sigma_mm"]), int(s["S"]), int(s["seed"]))
        rec["F_maxabs_vs_C2"] = maxabs(res["F"], np.load(C2 / "F.npy"))
        rec["Esoft_maxabs_vs_C2"] = maxabs(res["Esoft"], np.load(C2 / "Esoft.npy"))
    OUT.write_text(json.dumps(rec, indent=2) + "\n")
    print(json.dumps(rec, indent=2))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
