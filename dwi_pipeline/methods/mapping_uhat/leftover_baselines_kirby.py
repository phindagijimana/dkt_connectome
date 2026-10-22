#!/usr/bin/env python3
"""Leftover ranking baselines on Kirby mini (L vs U/F/FA/length). Not hat{U}."""

from __future__ import annotations

import json
import sys
from pathlib import Path

import numpy as np

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
sys.path.insert(0, "/mnt/nfs/home/urmc-sh.rochester.edu/pndagiji/Documents/edgeuq/src")

from c2_soft import auroc  # noqa: E402
from leftover import COUNT_FLOOR, moved_mask  # noqa: E402
from retest_pack import session_paths  # noqa: E402
from edgeuq.instability import score_neg_log_count  # noqa: E402

R = HERE / "work" / "R"
SD = HERE.parents[1] / "sample_data" / "kirby21"
OUT = R / "paper2" / "within_site_kirby"
IU = np.triu_indices(78, 1)
SIDS = ["KKI849", "KKI113", "KKI127", "KKI142", "KKI239"]


def _mat(path: Path) -> np.ndarray:
    a = np.loadtxt(path, delimiter=",")
    if a.ndim != 2:
        a = np.loadtxt(path)
    return np.asarray(a, dtype=np.float64)


def main() -> int:
    rows = []
    for sid in SIDS:
        pk = R / f"kirby21_{sid}_ses-1"
        cout = SD / "freeze" / f"sub-{sid}" / "connectomes" / f"sub-{sid}" / "ses-1"
        b2 = session_paths("kirby21", sid, 2)
        c0 = np.load(pk / "C0.npy") if (pk / "C0.npy").is_file() else _mat(cout / "dkt_connectome_count.csv")
        c1 = _mat(Path(b2["count"]))
        elig = np.maximum(c0, c1)[IU] >= COUNT_FLOOR
        y = moved_mask(c0, c1)[IU][elig].astype(float)
        scores = {"L": score_neg_log_count(c0)[IU][elig]}
        # higher = more unstable
        if (cout / "connectome_meanfa.csv").is_file():
            scores["neg_FA"] = -_mat(cout / "connectome_meanfa.csv")[IU][elig]
        if (cout / "connectome_meanlength.csv").is_file():
            scores["neg_length"] = -_mat(cout / "connectome_meanlength.csv")[IU][elig]
        if (pk / "U.csv").is_file():
            scores["U"] = _mat(pk / "U.csv")[IU][elig]
        elif (pk / "U.npy").is_file():
            scores["U"] = np.load(pk / "U.npy")[IU][elig]
        if (pk / "F.npy").is_file():
            scores["F"] = np.load(pk / "F.npy")[IU][elig]
        elif (pk / "F.csv").is_file():
            scores["F"] = _mat(pk / "F.csv")[IU][elig]
        rng = np.random.default_rng(0)
        scores["random"] = rng.random(y.size)
        rec = {"sid": sid, "n": int(elig.sum()), "y_rate": float(y.mean()), "auroc": {}}
        for k, s in scores.items():
            if y.min() < y.max() and np.isfinite(s).all():
                rec["auroc"][k] = float(auroc(s, y))
            else:
                rec["auroc"][k] = None
        rows.append(rec)

    # means over subjects that have each score
    keys = sorted({k for r in rows for k in r["auroc"]})
    means = {}
    for k in keys:
        vals = [r["auroc"][k] for r in rows if r["auroc"].get(k) is not None and r["sid"] != "KKI239"]
        means[k + "_n4"] = float(np.mean(vals)) if vals else None
        vals5 = [r["auroc"][k] for r in rows if r["auroc"].get(k) is not None]
        means[k + "_n5"] = float(np.mean(vals5)) if vals5 else None

    out = {
        "not_hatU": True,
        "note": "Higher score = predicted leftover move. neg_FA / neg_length = weak/short edges.",
        "subjects": rows,
        "mean_auroc": means,
    }
    path = OUT / "leftover_baselines_kirby.json"
    path.write_text(json.dumps(out, indent=2) + "\n")
    md = OUT / "leftover_baselines_kirby.md"
    lines = [
        "# Leftover ranking baselines (Kirby mini)",
        "",
        "Not \(\hat{U}\). AUROC vs leftover \(y\) (floor 10, relchange 0.25).",
        "",
        "| sid | y_rate | L | U | F | −FA | −length | random |",
        "|-----|-------:|--:|--:|--:|----:|--------:|-------:|",
    ]
    for r in rows:
        a = r["auroc"]
        def f(k):
            v = a.get(k)
            return f"{v:.3f}" if v is not None else "—"
        lines.append(
            f"| {r['sid']} | {r['y_rate']:.3f} | {f('L')} | {f('U')} | {f('F')} | {f('neg_FA')} | {f('neg_length')} | {f('random')} |"
        )
    lines += [
        "",
        f"**Mean n=4 (excl. 239):** L={means.get('L_n4'):.3f} U={means.get('U_n4')} F={means.get('F_n4')} "
        f"−FA={means.get('neg_FA_n4'):.3f} −length={means.get('neg_length_n4'):.3f} random={means.get('random_n4'):.3f}",
        "",
        f"Wrote `{path.name}`.",
    ]
    md.write_text("\n".join(lines) + "\n")
    print(md.read_text())
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
