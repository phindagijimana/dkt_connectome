#!/usr/bin/env python3
"""A7 proxyUhat from A6 count matrices. Not hat{U}. Not A8."""

from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

import numpy as np

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))

from leftover import COUNT_FLOOR, RELCHANGE_CUT, proxyuhat  # noqa: E402

K = 50


def load_session_matrices(a6_dir: Path) -> tuple[np.ndarray, list[np.ndarray]]:
    c0_p = a6_dir / "C000_identity.npy"
    if not c0_p.is_file():
        raise FileNotFoundError(c0_p)
    c0 = np.load(c0_p).astype(np.float64)
    cks: list[np.ndarray] = []
    missing: list[int] = []
    for k in range(1, K + 1):
        p = a6_dir / f"C{k:03d}.npy"
        if not p.is_file():
            missing.append(k)
            continue
        cks.append(np.load(p).astype(np.float64))
    if missing:
        raise FileNotFoundError(f"{a6_dir} missing C_k {missing}")
    if c0.shape != (78, 78):
        raise ValueError(f"C0 shape {c0.shape} != (78, 78)")
    return c0, cks


def session_row(sid: str, p: np.ndarray) -> dict:
    iu = np.triu_indices(p.shape[0], k=1)
    vals = p[iu]
    return {
        "session_id": sid,
        "K": K,
        "relchange_cut": RELCHANGE_CUT,
        "count_floor": COUNT_FLOOR,
        "n_undirected_edges": int(vals.size),
        "n_positive": int(np.sum(vals > 0)),
        "mean_proxyUhat": float(np.mean(vals)),
        "median_proxyUhat": float(np.median(vals)),
        "max_proxyUhat": float(np.max(vals)),
        "gold_leftover": False,
        "name": "A7 proxyUhat frequency. Not hat{U}. Not A8.",
    }


def run_session(sid: str, a6_root: Path, a7_root: Path) -> dict:
    c0, cks = load_session_matrices(a6_root / sid)
    p = proxyuhat(c0, cks)
    out = a7_root / sid
    out.mkdir(parents=True, exist_ok=True)
    np.save(out / "dkt_connectome_proxyUhat.npy", p.astype(np.float32))
    csv = out / "dkt_connectome_proxyUhat.csv"
    np.savetxt(csv, p, delimiter=",", fmt="%.8f")
    row = session_row(sid, p)
    row["csv"] = str(csv)
    (out / "a7_session.json").write_text(json.dumps(row, indent=2) + "\n")
    return row


def main() -> int:
    ap = argparse.ArgumentParser(description="A7 proxyUhat. Not hat{U}.")
    ap.add_argument("--inventory", type=Path, default=HERE / "work" / "inventory.json")
    ap.add_argument("--a6", type=Path, default=HERE / "work" / "a6")
    ap.add_argument("--work", type=Path, default=HERE / "work" / "a7")
    ap.add_argument("--session-id", default=None)
    args = ap.parse_args()
    inv = json.loads(args.inventory.read_text())
    sessions = inv["sessions"]
    if args.session_id:
        sessions = [s for s in sessions if s["session_id"] == args.session_id]
        if not sessions:
            raise SystemExit(f"unknown session {args.session_id}")
    args.work.mkdir(parents=True, exist_ok=True)
    rows = []
    for s in sessions:
        sid = s["session_id"]
        print(f"[A7] {sid}", flush=True)
        rows.append(run_session(sid, args.a6, args.work))
    summary = {
        "item": "A7",
        "a5_fail": False,
        "n_sessions": len(rows),
        "relchange_cut": RELCHANGE_CUT,
        "count_floor": COUNT_FLOOR,
        "K": K,
        "sessions": rows,
        "claim": "A7 proxyUhat written. Still not hat{U}. A8 not started.",
        "not_leftover": "stored .mat unused; Extra A unused",
    }
    (args.work / "a7_summary.json").write_text(json.dumps(summary, indent=2) + "\n")
    print(json.dumps({s["session_id"]: s["mean_proxyUhat"] for s in rows}, indent=2))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
