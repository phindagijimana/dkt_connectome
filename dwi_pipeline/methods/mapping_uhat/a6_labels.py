#!/usr/bin/env python3
"""A6: warp DKT labels only; tractogram frozen. Not hat{U}. Not A7."""

from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

import nibabel as nib
import numpy as np

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))

from ants_ensemble import (  # noqa: E402
    SIF_DEFAULT,
    apply_labels,
    default_binds,
    existing_ants_file,
    locate_ants_outputs,
    mrconvert,
)
from assign_frozen import (  # noqa: E402
    N_NODES,
    RADIAL_MM,
    assign_endpoints,
    connectome_from_assignments,
    extract_endpoints,
)

BIND_DEFAULT = default_binds()
ASSIGN_CHECK_N = 2000
ASSIGN_CHECK_MIN = 0.90


def _load_nodes(path: Path) -> tuple[np.ndarray, np.ndarray]:
    img = nib.load(str(path))
    data = np.rint(img.get_fdata()).astype(np.int32)
    return data, np.asarray(img.affine, dtype=np.float64)


def _transforms_for_k(a5_dir: Path, rec: dict) -> list[Path]:
    tlist: list[Path] = []
    if rec.get("warp"):
        found = existing_ants_file(Path(rec["warp"]))
        if found is not None:
            tlist.append(found)
    if rec.get("affine"):
        found = existing_ants_file(Path(rec["affine"]))
        if found is not None:
            tlist.append(found)
    if tlist:
        return tlist
    found = locate_ants_outputs(a5_dir / f"k{int(rec['k']):03d}")
    if found["warp"]:
        tlist.append(Path(found["warp"]))
    if found["affine"]:
        tlist.append(Path(found["affine"]))
    if not tlist:
        raise FileNotFoundError(f"no ANTs output for k={rec.get('k')} in {a5_dir}")
    return tlist


def _ensure_l0(session: dict, out: Path, sif: str) -> Path:
    dest = out / "L0_dkt.nii.gz"
    if dest.is_file():
        return dest
    dkt = Path(session["dkt_nodes"])
    if dkt.suffixes[-2:] == [".nii", ".gz"] or dkt.suffix == ".nii":
        return dkt
    return mrconvert(dkt, dest, sif=sif, bind=BIND_DEFAULT)


def _ensure_ends(session: dict, out: Path) -> np.ndarray:
    cache = out / "ends_identity.npy"
    if cache.is_file():
        return np.load(cache)
    print(f"[A6] extract endpoints {session['session_id']}", flush=True)
    ends = extract_endpoints(Path(session["tck"]))
    np.save(cache, ends)
    return ends


def _identity_count(session: dict, out: Path, ends: np.ndarray, l0: Path) -> np.ndarray:
    dest = out / "C000_identity.npy"
    if dest.is_file():
        return np.load(dest)
    nodes, aff = _load_nodes(l0)
    asg = assign_endpoints(ends, nodes, aff, kind="radial", radius_mm=RADIAL_MM)
    mat = connectome_from_assignments(asg)
    np.save(dest, mat.astype(np.float32))
    freeze = Path(session["count"])
    if freeze.is_file():
        frozen = np.loadtxt(freeze, delimiter=",")
        if frozen.shape == mat.shape:
            denom = np.maximum(frozen, 1.0)
            rel = np.abs(mat - frozen) / denom
            print(
                f"[A6] identity vs freeze median relchange={float(np.median(rel)):.4f}",
                flush=True,
            )
    return mat


def _assign_check(session: dict, ends: np.ndarray, l0: Path) -> dict:
    asg_path = Path(session["assignments"])
    n = min(ASSIGN_CHECK_N, ends.shape[0])
    nodes, aff = _load_nodes(l0)
    got = assign_endpoints(ends[:n], nodes, aff, kind="radial", radius_mm=RADIAL_MM)
    rec = {"n_check": n, "ok": None, "note": "vs freeze assignments.csv; not P"}
    if not asg_path.is_file():
        rec["ok"] = None
        rec["note"] = "no assignments.csv"
        return rec
    frozen = np.loadtxt(asg_path, comments="#")  # MRtrix assignments: "a b" per line
    if frozen.ndim == 1:
        frozen = frozen.reshape(-1, 2)
    frozen = frozen[:n, :2]
    agree = float(np.mean(np.sort(got, axis=1) == np.sort(frozen.astype(np.int32), axis=1)))
    rec["pair_agree"] = agree
    rec["min"] = ASSIGN_CHECK_MIN
    rec["ok"] = agree >= ASSIGN_CHECK_MIN
    return rec


def run_session(session: dict, work: Path, *, sif: str) -> dict:
    sid = session["session_id"]
    out = work / sid
    out.mkdir(parents=True, exist_ok=True)
    a5_dir = HERE / "work" / "a5" / sid
    leftover = a5_dir / "leftover.json"
    if not leftover.is_file():
        raise FileNotFoundError(f"A6 needs A5 leftover.json: {leftover}")
    l0 = _ensure_l0(session, out, sif)
    ends = _ensure_ends(session, out)
    check_p = out / "assign_check.json"
    if not check_p.is_file():
        check = _assign_check(session, ends, l0)
        check_p.write_text(json.dumps(check, indent=2) + "\n")
        print(f"[A6] assign_check {check}", flush=True)
    _identity_count(session, out, ends, l0)
    ks = sorted(a5_dir.glob("k*.json"))
    n_done = 0
    for jp in ks:
        rec = json.loads(jp.read_text())
        k = int(rec["k"])
        dest = out / f"C{k:03d}.npy"
        if dest.is_file():
            n_done += 1
            continue
        print(f"[A6] {sid} k={k:03d}", flush=True)
        tlist = _transforms_for_k(a5_dir, rec)
        lk = out / f"L{k:03d}.nii.gz"
        apply_labels(labels=l0, reference=l0, transforms=tlist, out_labels=lk, sif=sif, bind=BIND_DEFAULT)
        nodes, aff = _load_nodes(lk)
        asg = assign_endpoints(ends, nodes, aff, kind="radial", radius_mm=RADIAL_MM)
        mat = connectome_from_assignments(asg)
        np.save(dest, mat.astype(np.float32))
        try:
            lk.unlink()
        except OSError:
            pass
        n_done += 1
    summary = {
        "session_id": sid,
        "item": "A6",
        "n_streamlines": int(ends.shape[0]),
        "n_count_matrices": n_done,
        "n_expected": 50,
        "n_nodes": N_NODES,
        "assigner": "radial_4",
        "gold_leftover": False,
        "name": "A6 labels-only count matrices. Not hat{U}. Not A7.",
    }
    if n_done >= 50 and (out / "C000_identity.npy").is_file():
        (out / "a6_session.json").write_text(json.dumps(summary, indent=2) + "\n")
    else:
        print(f"[A6] incomplete {sid} n_count={n_done}/50", flush=True)
    return summary


def main() -> int:
    ap = argparse.ArgumentParser(description="A6 labels only. Not hat{U}.")
    ap.add_argument("--inventory", type=Path, default=HERE / "work" / "inventory.json")
    ap.add_argument("--work", type=Path, default=HERE / "work" / "a6")
    ap.add_argument("--session-id", default=None)
    ap.add_argument("--sif", default=SIF_DEFAULT)
    ap.add_argument("--skip-if-done", action="store_true")
    args = ap.parse_args()
    inv = json.loads(args.inventory.read_text())
    sessions = inv["sessions"]
    if args.session_id:
        sessions = [s for s in sessions if s["session_id"] == args.session_id]
        if not sessions:
            raise SystemExit(f"unknown session {args.session_id}")
    args.work.mkdir(parents=True, exist_ok=True)
    for s in sessions:
        done = args.work / s["session_id"] / "a6_session.json"
        if args.skip_if_done and done.is_file():
            npy = list((args.work / s["session_id"]).glob("C*.npy"))
            if len(npy) >= 51:
                print(f"[A6] skip {s['session_id']} a6_session.json exists", flush=True)
                continue
        print(f"[A6] {s['session_id']}", flush=True)
        run_session(s, args.work, sif=args.sif)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
