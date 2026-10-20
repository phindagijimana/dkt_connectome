#!/usr/bin/env python3
"""Retest pairs: U, calibrated U and C2 leakage on run-1; leftover y from run-1 vs run-2. Not hat{U}."""

from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

import nibabel as nib
import numpy as np

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))

from ants_ensemble import mrconvert  # noqa: E402
from assign_frozen import N_NODES, RADIAL_MM, assign_endpoints, connectome_from_assignments, extract_endpoints  # noqa: E402
from c2_soft import SEED0, auroc, leakage, same_edge  # noqa: E402
from leftover import COUNT_FLOOR, RELCHANGE_CUT, apply_isotonic, moved_mask, relchange  # noqa: E402
from p1_baselines import u_e_mask  # noqa: E402

SD = HERE.parents[1] / "sample_data"
OUT = HERE / "work" / "R"
C2_LOCK = HERE / "work" / "C2" / "LOCK.json"
ISO = HERE / "work" / "C" / "isotonic.json"
FIT_MM = (-0.5, -0.25, 0.25, 0.5)
TEST_MM = (-1.0, 1.0)
PAIRS = (("kirby21", "KKI849"), ("boekel_dwi_retest", "pp01"))
INVENT_FRAC = 0.001


def shift_name(axis: str, t: float) -> str:
    return f"{axis}_{'p' if t > 0 else 'm'}{abs(t):g}mm"


def shift_endpoints(ends: np.ndarray, axis: str, t: float) -> np.ndarray:
    """Same rule as the U paper: endpoints move by -t mm on one world axis."""
    out = np.asarray(ends, dtype=np.float32).copy()
    out[..., "xyz".index(axis[1])] -= np.float32(t)
    return out


def session_paths(ds: str, sid: str, ses: int) -> dict[str, Path]:
    freeze = SD / ds / "freeze" / f"sub-{sid}"
    cout = freeze / "connectomes" / f"sub-{sid}" / f"ses-{ses}"
    qout = freeze / "qsirecon_single_run_output"
    tcks = sorted(
        p
        for p in qout.rglob("*model-ifod2_streamlines.tck*")
        if f"sub-{sid}" in str(p) and f"ses-{ses}" in str(p)
    )
    return {
        "tck": tcks[0] if tcks else qout / "MISSING.tck",
        "count": cout / "dkt_connectome_count.csv",
        "parc": cout / "parcellation.json",
        "nodes_mif": cout / "dkt_nodes.mif",
    }


def pack(ds: str, sid: str, ses: int = 1) -> dict:
    lock = json.loads(C2_LOCK.read_text())
    amend = lock["leftover_exam"]["amendment_2026-10-20"]
    sigma = float(amend["retest_sigma_mm"])
    n_samples = int(lock["model"]["S"])
    p = session_paths(ds, sid, ses)
    for k in ("tck", "count", "nodes_mif"):
        if not p[k].is_file():
            raise SystemExit(f"missing {k}: {p[k]}")
    out = OUT / f"{ds}_{sid}_ses-{ses}"
    (out / "u_shifts").mkdir(parents=True, exist_ok=True)
    l0_path = out / "L0_dkt.nii.gz"
    if not l0_path.is_file():
        mrconvert(p["nodes_mif"], l0_path)
    l0 = nib.load(str(l0_path))
    nodes = np.rint(l0.get_fdata()).astype(np.int32)
    aff = np.asarray(l0.affine, dtype=np.float64)
    ends_path = out / "ends.npy"
    if not ends_path.is_file():
        np.save(ends_path, extract_endpoints(p["tck"]))
    ends = np.load(ends_path).astype(np.float32)
    print(f"[R] {ds} {sid} ses-{ses} n={ends.shape[0]} sigma={sigma}", flush=True)
    asg0 = assign_endpoints(ends, nodes, aff, kind="radial", radius_mm=RADIAL_MM)
    c0 = connectome_from_assignments(asg0)
    np.save(out / "C0.npy", c0.astype(np.float32))
    shipped = np.loadtxt(p["count"], delimiter=",")
    iu = np.triu_indices(N_NODES, 1)
    agree = float(np.corrcoef(c0[iu], shipped[iu])[0, 1]) if shipped.shape == c0.shape else None

    maps: dict[str, np.ndarray] = {}
    for axis in ("tx", "ty", "tz"):
        for t in (*FIT_MM, *TEST_MM):
            name = shift_name(axis, t)
            f = out / "u_shifts" / f"{name}_count.npy"
            if f.is_file():
                maps[name] = np.load(f).astype(np.float64)
                continue
            asg = assign_endpoints(shift_endpoints(ends, axis, t), nodes, aff, kind="radial", radius_mm=RADIAL_MM)
            maps[name] = connectome_from_assignments(asg)
            np.save(f, maps[name].astype(np.float32))
            print(f"[R] shift {name}", flush=True)
    fit = [maps[shift_name(a, t)] for a in ("tx", "ty", "tz") for t in FIT_MM]
    test = [maps[shift_name(a, t)] for a in ("tx", "ty", "tz") for t in TEST_MM]
    u, _e, _m = u_e_mask(c0, fit, test, float(COUNT_FLOOR))
    iso = json.loads(ISO.read_text())
    ucal = apply_isotonic(u, np.asarray(iso["X_thresholds"]), np.asarray(iso["y_thresholds"]))
    ucal = 0.5 * (ucal + ucal.T)
    np.fill_diagonal(ucal, 0.0)
    np.savetxt(out / "U.csv", u, delimiter=",", fmt="%.8f")
    np.savetxt(out / "Ucal.csv", ucal, delimiter=",", fmt="%.8f")

    if not (out / "F.npy").is_file():
        a0, b0 = asg0[:, 0], asg0[:, 1]
        stay = np.zeros(ends.shape[0], dtype=np.uint16)
        esum = np.zeros((N_NODES, N_NODES), dtype=np.float64)
        rng = np.random.default_rng(SEED0 + 100 + PAIRS.index((ds, sid)))
        for s in range(n_samples):
            jit = ends + rng.normal(0.0, sigma, size=ends.shape).astype(np.float32)
            asg = assign_endpoints(jit, nodes, aff, kind="radial", radius_mm=RADIAL_MM)
            del jit
            stay += same_edge(a0, b0, asg[:, 0], asg[:, 1]).astype(np.uint16)
            esum += connectome_from_assignments(asg)
            print(f"[R] C2 sample {s + 1}/{n_samples}", flush=True)
        f_mat, _ = leakage(asg0, stay, n_samples)
        np.save(out / "F.npy", f_mat.astype(np.float32))
        np.save(out / "Esoft.npy", (esum / n_samples).astype(np.float32))
    rec = {
        "dataset": ds,
        "subject": sid,
        "session": ses,
        "tck": str(p["tck"]),
        "n_streamlines": int(ends.shape[0]),
        "C0_vs_shipped_count_pearson": agree,
        "sigma_mm": sigma,
        "S": n_samples,
        "planted_rule": "endpoints -= t on one world axis; fit +-0.25/+-0.5, test +-1; radial_4",
        "not_hatU": True,
    }
    (out / "pack.json").write_text(json.dumps(rec, indent=2) + "\n")
    return rec


def pair_scores(ds: str, sid: str) -> dict:
    a = session_paths(ds, sid, 1)
    b = session_paths(ds, sid, 2)
    pk = OUT / f"{ds}_{sid}_ses-1"
    ca = np.loadtxt(a["count"], delimiter=",")
    cb = np.loadtxt(b["count"], delimiter=",")
    u = np.loadtxt(pk / "U.csv", delimiter=",")
    ucal = np.loadtxt(pk / "Ucal.csv", delimiter=",")
    f = np.load(pk / "F.npy").astype(np.float64)
    es = np.load(pk / "Esoft.npy").astype(np.float64)
    iu = np.triu_indices(N_NODES, 1)
    m = np.maximum(ca, cb)[iu] >= COUNT_FLOOR
    y = moved_mask(ca, cb)[iu][m].astype(np.float64)
    hard_move = float(y.mean())
    m_soft = np.maximum(es, cb)[iu] >= COUNT_FLOOR
    soft_rel = relchange(es, cb)[iu][m_soft]
    invented = int(((es[iu] >= COUNT_FLOOR) & (ca[iu] < COUNT_FLOOR)).sum())
    return {
        "pair": f"{ds}/{sid}",
        "n": int(m.sum()),
        "y_rate": hard_move,
        "auroc_U": auroc(u[iu][m], y),
        "auroc_Ucal": auroc(ucal[iu][m], y),
        "auroc_F": auroc(f[iu][m], y),
        "moved_frac_hard": hard_move,
        "moved_frac_soft": float((soft_rel > RELCHANGE_CUT).mean()),
        "invented_count_ge10": invented,
        "invent_frac": invented / float(max(int(m.sum()), 1)),
        "_Ca": ca,
        "_Cb": cb,
        "_Uful": u,
    }


def exam() -> dict:
    lst = json.loads((HERE / "work" / "sites_v1" / "LIST.json").read_text())
    if int(lst.get("n") or 0) < 2:
        raise SystemExit("blocked: LIST.json has <2 leftover pairs (no leftover numbers yet)")
    rows = [pair_scores(ds, sid) for ds, sid in PAIRS]
    soft_win = all(r["moved_frac_soft"] < r["moved_frac_hard"] and r["invent_frac"] <= INVENT_FRAC for r in rows)
    from g_exam import GOLD_FLAG, exam_from_pairs  # noqa: E402

    g = exam_from_pairs([(r["_Uful"], r["_Ca"], r["_Cb"]) for r in rows]) if GOLD_FLAG.is_file() else {"status": "blocked: GOLD_LOCKED absent"}
    clean = [{k: v for k, v in r.items() if not k.startswith("_")} for r in rows]
    rec = {
        "experiment": "retest leftover exam (C2 primary AUROC + soft connectome; G calibration if GOLD locked)",
        "pairs": clean,
        "c2_soft_connectome_win": soft_win,
        "G": g,
        "tracking_only_control": "not run yet (reseeded run-1 tractography)",
        "not_hatU_unless_G_win": True,
    }
    (OUT / "retest_exam.json").write_text(json.dumps(rec, indent=2, default=float) + "\n")
    return rec


def main() -> int:
    ap = argparse.ArgumentParser(description="Retest leftover pack/exam. Not hat{U}.")
    ap.add_argument("--dataset")
    ap.add_argument("--subject")
    ap.add_argument("--session", type=int, default=1)
    ap.add_argument("--exam", action="store_true")
    args = ap.parse_args()
    if args.exam:
        rec = exam()
        print(json.dumps({k: rec[k] for k in ("pairs", "c2_soft_connectome_win")}, indent=2, default=float))
        return 0
    if (args.dataset, args.subject) not in PAIRS:
        raise SystemExit(f"pair not registered: {args.dataset}/{args.subject}")
    print(json.dumps(pack(args.dataset, args.subject, args.session), indent=2))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
