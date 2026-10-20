#!/usr/bin/env python3
"""C2: per-endpoint soft radial_4 under measured V1 leftover sigma. Not hat{U}. Not Exp2."""

from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

import nibabel as nib
import numpy as np
from scipy.stats import spearmanr

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))

from assign_frozen import N_NODES, RADIAL_MM, assign_endpoints, connectome_from_assignments  # noqa: E402
from c_calib_u import FIT, SHIP, TEST, session_event  # noqa: E402
from leftover import COUNT_FLOOR  # noqa: E402

A6 = HERE / "work" / "a6"
V1 = HERE / "work" / "V"
OUT = HERE / "work" / "C2"
MAXWELL_MEDIAN = 1.5382
SEED0 = 20261019
SESSIONS = (*FIT, *TEST)
SPEARMAN_CUT = 0.5
AUROC_CUT = 0.7


def sigma_from_v1(median_mm: float) -> float:
    return float(median_mm) / MAXWELL_MEDIAN


def same_edge(a0: np.ndarray, b0: np.ndarray, a: np.ndarray, b: np.ndarray) -> np.ndarray:
    return ((a == a0) & (b == b0)) | ((a == b0) & (b == a0))


def valid_edge(a: np.ndarray, b: np.ndarray, n_nodes: int = N_NODES) -> np.ndarray:
    return (a > 0) & (b > 0) & (a != b) & (a <= n_nodes) & (b <= n_nodes)


def leakage(asg0: np.ndarray, stay: np.ndarray, n_samples: int, n_nodes: int = N_NODES) -> tuple[np.ndarray, np.ndarray]:
    """F_ij = 1 - sum P(stay) / C0_ij over streamlines hard-assigned to ij. Returns (F, C0)."""
    a0, b0 = asg0[:, 0], asg0[:, 1]
    ok = valid_edge(a0, b0, n_nodes)
    ia = np.minimum(a0[ok], b0[ok]) - 1
    ib = np.maximum(a0[ok], b0[ok]) - 1
    c0 = np.zeros((n_nodes, n_nodes), dtype=np.float64)
    kept = np.zeros((n_nodes, n_nodes), dtype=np.float64)
    np.add.at(c0, (ia, ib), 1.0)
    np.add.at(kept, (ia, ib), stay[ok].astype(np.float64) / float(n_samples))
    c0 = c0 + c0.T
    kept = kept + kept.T
    f = np.where(c0 > 0, 1.0 - kept / np.maximum(c0, 1.0), 0.0)
    return np.clip(f, 0.0, 1.0), c0


def run_session(sid: str, n_samples: int) -> dict:
    out = OUT / sid
    out.mkdir(parents=True, exist_ok=True)
    if (out / "F.npy").is_file() and (out / "session.json").is_file():
        return json.loads((out / "session.json").read_text())
    v1 = json.loads((V1 / sid / "session.json").read_text())
    med = float(v1["median_of_voxel_medians_mm"])
    sigma = sigma_from_v1(med)
    l0 = nib.load(str(A6 / sid / "L0_dkt.nii.gz"))
    nodes = np.rint(l0.get_fdata()).astype(np.int32)
    aff = np.asarray(l0.affine, dtype=np.float64)
    ends = np.load(A6 / sid / "ends_identity.npy").astype(np.float32)
    print(f"[C2] {sid} n={ends.shape[0]} V1 median={med:.4f} sigma={sigma:.4f} S={n_samples}", flush=True)
    asg0 = assign_endpoints(ends, nodes, aff, kind="radial", radius_mm=RADIAL_MM)
    a0, b0 = asg0[:, 0], asg0[:, 1]
    stay = np.zeros(ends.shape[0], dtype=np.uint16)
    end_stay = np.zeros((ends.shape[0], 2), dtype=np.uint16)
    esum = np.zeros((N_NODES, N_NODES), dtype=np.float64)
    rng = np.random.default_rng(SEED0 + SESSIONS.index(sid))
    for s in range(n_samples):
        jit = ends + rng.normal(0.0, sigma, size=ends.shape).astype(np.float32)
        asg = assign_endpoints(jit, nodes, aff, kind="radial", radius_mm=RADIAL_MM)
        del jit
        stay += same_edge(a0, b0, asg[:, 0], asg[:, 1]).astype(np.uint16)
        end_stay += (asg == asg0).astype(np.uint16)
        esum += connectome_from_assignments(asg)
        print(f"[C2] {sid} sample {s + 1}/{n_samples}", flush=True)
    f, c0 = leakage(asg0, stay, n_samples)
    esoft = esum / float(n_samples)
    np.save(out / "F.npy", f.astype(np.float32))
    np.save(out / "C0.npy", c0.astype(np.float32))
    np.save(out / "Esoft.npy", esoft.astype(np.float32))
    ok = valid_edge(a0, b0)
    p_end = end_stay[ok].astype(np.float64).ravel() / float(n_samples)
    hist, _ = np.histogram(p_end, bins=np.linspace(0.0, 1.0, 11))
    ident = np.load(SHIP.parents[0] / ("followup" if sid in FIT else "confirmation_uq") / sid / "identity_count.npy")
    iu = np.triu_indices(N_NODES, 1)
    rec = {
        "session_id": sid,
        "split": "dev" if sid in FIT else "confirm",
        "V1_median_mm": med,
        "sigma_mm": sigma,
        "S": n_samples,
        "seed": SEED0 + SESSIONS.index(sid),
        "n_streamlines": int(ends.shape[0]),
        "n_hard_edges_streamlines": int(ok.sum()),
        "C0_vs_identity_spearman": float(spearmanr(c0[iu], np.asarray(ident, dtype=np.float64)[iu]).statistic),
        "C0_vs_identity_max_abs": float(np.max(np.abs(c0 - ident))),
        "mean_streamline_stay": float(stay[ok].mean() / n_samples),
        "end_stay_hist_deciles": hist.tolist(),
        "end_stay_frac_lt_1": float((p_end < 1.0).mean()),
        "not_hatU": True,
        "planted_y_only": True,
    }
    (out / "session.json").write_text(json.dumps(rec, indent=2) + "\n")
    return rec


def auroc(score: np.ndarray, y: np.ndarray) -> float:
    s = np.asarray(score, dtype=np.float64).ravel()
    yy = np.asarray(y, dtype=np.float64).ravel()
    pos = s[yy > 0.5]
    neg = np.sort(s[yy <= 0.5])
    if pos.size == 0 or neg.size == 0:
        return float("nan")
    lt = np.searchsorted(neg, pos, side="left")
    le = np.searchsorted(neg, pos, side="right")
    return float((lt + 0.5 * (le - lt)).mean() / neg.size)


def exam() -> dict:
    lock = json.loads((OUT / "LOCK.json").read_text())
    if not lock.get("locked"):
        raise SystemExit("C2 LOCK not locked")
    iu = np.triu_indices(N_NODES, 1)
    rows = []
    for sid in SESSIONS:
        d = OUT / sid
        f = np.load(d / "F.npy").astype(np.float64)
        es = np.load(d / "Esoft.npy").astype(np.float64)
        c0 = np.load(d / "C0.npy").astype(np.float64)
        e, y, mx = session_event(sid)
        u = np.loadtxt(SHIP / sid / "dkt_connectome_U.csv", delimiter=",")
        m = mx[iu] >= COUNT_FLOOR
        fe, ee, ye, ue = f[iu][m], e[iu][m], y[iu][m], u[iu][m]
        invented = int(((es[iu] >= COUNT_FLOOR) & (c0[iu] < COUNT_FLOOR)).sum())
        rho_f = float(spearmanr(fe, ee).statistic)
        auc_f = auroc(fe, ye)
        rows.append(
            {
                "session_id": sid,
                "split": "dev" if sid in FIT else "confirm",
                "n": int(m.sum()),
                "y_rate": float(ye.mean()),
                "spearman_F_e": rho_f,
                "auroc_F": auc_f,
                "spearman_U_e": float(spearmanr(ue, ee).statistic),
                "auroc_U": auroc(ue, ye),
                "spearman_F_U": float(spearmanr(fe, ue).statistic),
                "invented_count_ge10": invented,
                "pass": bool(rho_f > SPEARMAN_CUT and auc_f > AUROC_CUT),
            }
        )
    dev_pass = sum(r["pass"] for r in rows if r["split"] == "dev")
    conf_pass = sum(r["pass"] for r in rows if r["split"] == "confirm")
    win = bool(dev_pass >= 2 and conf_pass >= 2)
    summary = {
        "experiment": "C2",
        "y": "planted 1 mm (development only; not leftover y)",
        "win": win,
        "dev_pass": dev_pass,
        "confirm_pass": conf_pass,
        "sessions": rows,
        "claim": (
            "C2 dev win: per-endpoint soft radial_4 under measured leftover sigma ranks 1 mm movers. Planted y only."
            if win
            else "C2 dev fail: keep U as the ranker; soft radial_4 stays a description. Planted y only."
        ),
        "leftover_exam": "blocked until Kirby and Boekel run-pair counts exist",
        "not_hatU": True,
    }
    (OUT / "c2_summary.json").write_text(json.dumps(summary, indent=2) + "\n")
    return summary


def main() -> int:
    ap = argparse.ArgumentParser(description="C2 per-endpoint soft radial_4. Not hat{U}.")
    ap.add_argument("--session-id")
    ap.add_argument("--samples", type=int, default=32)
    ap.add_argument("--exam", action="store_true")
    args = ap.parse_args()
    lock = json.loads((OUT / "LOCK.json").read_text())
    if args.samples != int(lock["model"]["S"]):
        raise SystemExit("S differs from LOCK")
    if args.exam:
        print(json.dumps(exam(), indent=2))
        return 0
    if args.session_id not in SESSIONS:
        raise SystemExit(f"unknown session {args.session_id}")
    print(json.dumps(run_session(args.session_id, args.samples), indent=2))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
