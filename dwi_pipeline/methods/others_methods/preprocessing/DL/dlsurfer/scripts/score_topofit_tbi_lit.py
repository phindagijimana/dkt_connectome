#!/usr/bin/env python3
"""Score Phase-3 TopoFit ±LIT arms vs recon-surf reference (files + Hausdorff)."""

from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

_SCRIPTS = Path(__file__).resolve().parent
if str(_SCRIPTS) not in sys.path:
    sys.path.insert(0, str(_SCRIPTS))

from surface_hausdorff import compare_surfs  # noqa: E402


def _surf_stats(path: Path) -> dict:
    if not path.is_file():
        return {"exists": False, "path": str(path)}
    out: dict = {"exists": True, "path": str(path), "bytes": path.stat().st_size}
    try:
        import nibabel.freesurfer.io as fsio

        coords, faces = fsio.read_geometry(str(path))
        out["n_vertices"] = int(coords.shape[0])
        out["n_faces"] = int(faces.shape[0])
        out["xyz_mean"] = [float(x) for x in coords.mean(axis=0)]
        out["xyz_std"] = [float(x) for x in coords.std(axis=0)]
    except Exception as exc:  # noqa: BLE001
        out["load_error"] = str(exc)
    return out


def _arm(root: Path) -> dict:
    surf = root / "surf"
    return {
        "root": str(root),
        "aseg": (root / "mri" / "aseg.mgz").is_file()
        or (root / "mri" / "aseg.auto_noCCseg.mgz").is_file(),
        "lh_white": _surf_stats(surf / "lh.white"),
        "rh_white": _surf_stats(surf / "rh.white"),
        "lh_white_topofit": _surf_stats(surf / "lh.white.topofit"),
        "rh_white_topofit": _surf_stats(surf / "rh.white.topofit"),
    }


def _write_freeview(out_script: Path, with_lit: Path, no_lit: Path, ref: Path) -> None:
    lines = [
        "#!/bin/bash",
        "# Generated FreeView QC for TopoFit ±LIT vs recon-surf white",
        "set -euo pipefail",
        f'WITH="{with_lit}"',
        f'NOLIT="{no_lit}"',
        f'REF="{ref}"',
        'freeview \\',
        '  -v "$WITH/mri/orig.mgz" \\',
        '  -f "$WITH/surf/lh.white.topofit":edgecolor=red:edgethickness=1 \\',
        '  -f "$WITH/surf/rh.white.topofit":edgecolor=red:edgethickness=1 \\',
        '  -f "$REF/surf/lh.white":edgecolor=green:edgethickness=1 \\',
        '  -f "$REF/surf/rh.white":edgecolor=green:edgethickness=1 \\',
        '  -f "$NOLIT/surf/lh.white.topofit":edgecolor=yellow:edgethickness=1 \\',
        '  -f "$NOLIT/surf/rh.white.topofit":edgecolor=yellow:edgethickness=1 \\',
        '  "$@" || true',
        'echo "Legend: red=TopoFit+LIT  yellow=TopoFit noLIT  green=recon-surf ref"',
    ]
    out_script.parent.mkdir(parents=True, exist_ok=True)
    out_script.write_text("\n".join(lines) + "\n")
    out_script.chmod(0o755)


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--with-lit", type=Path, required=True)
    ap.add_argument("--no-lit", type=Path, required=True)
    ap.add_argument("--ref-white-dir", type=Path, required=True, help="recon-surf EG ref subject")
    ap.add_argument("--out", type=Path, required=True)
    ap.add_argument(
        "--chamfer-max-mm",
        type=float,
        default=4.0,
        help="Soft QC bar on mean Chamfer (mm); preferred when vertex counts differ",
    )
    ap.add_argument(
        "--hausdorff-max-mm",
        type=float,
        default=15.0,
        help="Informational 95%% Hausdorff bar (often loose across unequal meshes)",
    )
    args = ap.parse_args()

    report = {
        "with_lit": _arm(args.with_lit),
        "no_lit": _arm(args.no_lit),
        "ref_recon_surf": {
            "lh_white": _surf_stats(args.ref_white_dir / "surf" / "lh.white"),
            "rh_white": _surf_stats(args.ref_white_dir / "surf" / "rh.white"),
        },
        "hausdorff": {},
        "pass_criteria": {
            "topofit_both_hemis_with_lit": False,
            "topofit_both_hemis_no_lit": False,
            "chamfer_soft_ok": False,
            "hausdorff95_soft_ok": False,
            "note": (
                "machine_ok = both hemi TopoFit files. "
                "chamfer_soft_ok = mean Chamfer ≤ threshold (cross-topology). "
                "hausdorff_95 is often inflated vs unequal meshes — use FreeView."
            ),
        },
    }
    w = report["with_lit"]
    n = report["no_lit"]
    report["pass_criteria"]["topofit_both_hemis_with_lit"] = bool(
        w["lh_white_topofit"].get("exists") and w["rh_white_topofit"].get("exists")
    )
    report["pass_criteria"]["topofit_both_hemis_no_lit"] = bool(
        n["lh_white_topofit"].get("exists") and n["rh_white_topofit"].get("exists")
    )

    hd: dict = {}
    chamfer_ok = True
    hd95_ok = True
    for arm_name, arm_root in (("with_lit", args.with_lit), ("no_lit", args.no_lit)):
        hd[arm_name] = {}
        for hemi in ("lh", "rh"):
            pred = arm_root / "surf" / f"{hemi}.white.topofit"
            ref = args.ref_white_dir / "surf" / f"{hemi}.white"
            cmp = compare_surfs(pred, ref)
            hd[arm_name][hemi] = cmp
            cm = cmp.get("chamfer_mean")
            h95 = cmp.get("hausdorff_95")
            if cm is None or cm > args.chamfer_max_mm:
                chamfer_ok = False
            if h95 is None or h95 > args.hausdorff_max_mm:
                hd95_ok = False
    report["hausdorff"] = hd
    report["pass_criteria"]["chamfer_soft_ok"] = bool(chamfer_ok)
    report["pass_criteria"]["hausdorff95_soft_ok"] = bool(hd95_ok)
    report["machine_ok"] = (
        report["pass_criteria"]["topofit_both_hemis_with_lit"]
        and report["pass_criteria"]["topofit_both_hemis_no_lit"]
    )
    report["qc_ok"] = report["machine_ok"] and report["pass_criteria"]["chamfer_soft_ok"]

    args.out.parent.mkdir(parents=True, exist_ok=True)
    args.out.write_text(json.dumps(report, indent=2) + "\n")
    fv = args.out.with_name("freeview_topofit_qc.sh")
    _write_freeview(fv, args.with_lit, args.no_lit, args.ref_white_dir)

    print(json.dumps(report["pass_criteria"], indent=2))
    print(
        f"wrote {args.out} machine_ok={report['machine_ok']} "
        f"qc_ok={report['qc_ok']} freeview={fv}"
    )
    return 0 if report["machine_ok"] else 2


if __name__ == "__main__":
    raise SystemExit(main())
