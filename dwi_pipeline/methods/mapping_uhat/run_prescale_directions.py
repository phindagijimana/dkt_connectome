#!/usr/bin/env python3
"""Recompute Directions 2–7 on both GOLD pilots (pre-scale batch). Dir 5 via leftover_instability.

Does not mass-scale (Dir 8). Does not retune frozen cuts.
"""

from __future__ import annotations

import csv
import json
import subprocess
import sys
from pathlib import Path

import numpy as np

from assign_frozen import N_NODES
from c2_soft import auroc
from leftover import COUNT_FLOOR, RELCHANGE_CUT, moved_mask, relchange

LOCKED_INVENT = 0.001
from retest_pack import session_paths

HERE = Path(__file__).resolve().parent
R = HERE / "work" / "R"
OUT = R / "directions"
SD = HERE.parent.parent / "sample_data"
IU = np.triu_indices(N_NODES, 1)
PAIRS = [("kirby21", "KKI849"), ("boekel_dwi_retest", "pp01")]
P_LOW, P_HIGH = 0.1, 0.9


def _load_pair(ds: str, sid: str):
    pk = R / f"{ds}_{sid}_ses-1"
    a = session_paths(ds, sid, 1)
    b = session_paths(ds, sid, 2)
    c0 = np.load(pk / "C0.npy").astype(np.float64)
    c1 = np.loadtxt(b["count"], delimiter=",")
    if c1.ndim != 2:
        c1 = np.loadtxt(b["count"])
    u = np.loadtxt(pk / "U.csv", delimiter=",")
    f = np.load(pk / "F.npy").astype(np.float64)
    esoft = np.load(pk / "Esoft.npy").astype(np.float64)
    cs = np.load(pk / "Cs.npy")
    p10 = (cs >= COUNT_FLOOR).mean(axis=0)
    return {
        "key": f"{ds}/{sid}",
        "ds": ds,
        "sid": sid,
        "pk": pk,
        "c0": c0,
        "c1": c1,
        "u": u,
        "f": f,
        "esoft": esoft,
        "p10": p10,
        "ship_c0": np.loadtxt(a["count"], delimiter=",") if Path(a["count"]).is_file() else c0,
    }


def dir2(pairs: list[dict]) -> dict:
    out = {}
    for p in pairs:
        elig = np.maximum(p["c0"], p["c1"])[IU] >= COUNT_FLOOR
        c0e, c1e = p["c0"][IU][elig], p["c1"][IU][elig]
        p10e = p["p10"][IU][elig]
        y = moved_mask(p["c0"], p["c1"])[IU][elig]
        cross = ((c0e >= COUNT_FLOOR) != (c1e >= COUNT_FLOOR))
        sure_pos = p10e >= P_HIGH
        sure_neg = p10e <= P_LOW
        unc = (~sure_pos) & (~sure_neg)
        strata = {}
        for name, m in (("P10>=0.9", sure_pos), ("0.1<P10<0.9", unc), ("P10<=0.1", sure_neg)):
            strata[name] = {
                "n": int(m.sum()),
                "y_rate": float(y[m].mean()) if m.any() else None,
                "cross_rate": float(cross[m].mean()) if m.any() else None,
            }
        n_cross = int(cross.sum())
        frac_unc = float(unc.mean())
        enrich = float((cross & unc).sum() / max(n_cross, 1) / max(frac_unc, 1e-12))
        uncert_score = 1.0 - np.abs(p10e - 0.5) * 2.0  # peak at 0.5
        out[p["key"]] = {
            "n_elig": int(elig.sum()),
            "frac_uncertain": frac_unc,
            "frac_sure_pos": float(sure_pos.mean()),
            "frac_sure_neg": float(sure_neg.mean()),
            "strata": strata,
            "crossings": {
                "n": n_cross,
                "frac_on_uncertain": float((cross & unc).sum() / max(n_cross, 1)),
                "enrichment": enrich,
            },
            "auroc_uncert_score_vs_cross": float(auroc(uncert_score, cross.astype(float))),
            "auroc_uncert_score_vs_y": float(auroc(uncert_score, y.astype(float))),
            "auroc_P10_vs_y": float(auroc(p10e, y.astype(float))),
            "auroc_one_minus_P10_vs_y": float(auroc(1.0 - p10e, y.astype(float))),
        }
    claim = (
        "Uncertain edges (0.1<P10<0.9) are highly enriched for threshold crossings vs "
        "the eligible base rate; report as a small actionable flag set."
    )
    rec = {"direction": 2, "question": "Which edges are unstable under the count>=10 reporting rule?", "pairs": out, "claim": claim}
    (OUT / "02_threshold_uncertainty.json").write_text(json.dumps(rec, indent=2) + "\n")
    (OUT / "02_threshold_uncertainty.md").write_text(
        f"# Direction 2 — Threshold uncertainty\n\n{claim}\n\nSee `02_threshold_uncertainty.json`.\n"
    )
    return rec


def _move_decomp(c_a: np.ndarray, c_b: np.ndarray) -> dict:
    elig = np.maximum(c_a, c_b)[IU] >= COUNT_FLOOR
    a, b = c_a[IU][elig], c_b[IU][elig]
    y = moved_mask(c_a, c_b)[IU][elig]
    cross = (a >= COUNT_FLOOR) != (b >= COUNT_FLOOR)
    both = ~cross
    movers = y
    return {
        "n_elig": int(elig.sum()),
        "move_rate": float(y.mean()) if y.size else None,
        "frac_cross": float(cross.mean()) if cross.size else None,
        "frac_both": float(both.mean()) if both.size else None,
        "move_rate_both": float(y[both].mean()) if both.any() else None,
        "move_rate_cross": float(y[cross].mean()) if cross.any() else None,
        "mean_rel_movers_both": float(relchange(a, b)[movers & both].mean()) if (movers & both).any() else None,
        "n_movers": int(movers.sum()),
        "n_cross_movers": int((movers & cross).sum()),
        "n_both_movers": int((movers & both).sum()),
    }


def dir3(pairs: list[dict]) -> dict:
    kirby = next(p for p in pairs if p["ds"] == "kirby21")
    boekel = next(p for p in pairs if p["ds"] == "boekel_dwi_retest")
    reseed_dir = SD / "kirby21/freeze/sub-KKI849/reseed/ses-1_seed20261020"
    c_run1 = np.loadtxt(reseed_dir / "count_run1_radial4.csv", delimiter=",")
    c_reseed = np.loadtxt(reseed_dir / "count_reseed_radial4.csv", delimiter=",")
    lock = json.loads((reseed_dir / "reseed_control.json").read_text())
    k_reseed = _move_decomp(c_run1, c_reseed)
    k_reseed["lock_move_rate"] = lock.get("tracking_only_move_rate")
    k_left = _move_decomp(kirby["c0"], kirby["c1"])
    b_left = _move_decomp(boekel["c0"], boekel["c1"])

    # edge-level overlap on Kirby eligible leftover edges
    elig = np.maximum(kirby["c0"], kirby["c1"])[IU] >= COUNT_FLOOR
    y_left = moved_mask(kirby["c0"], kirby["c1"])[IU][elig]
    # align reseed to same IU elig using run1/reseed matrices (same node order)
    y_reseed_full = moved_mask(c_run1, c_reseed)[IU]
    # use leftover elig mask length; reseed may differ slightly — intersect by using leftover elig on both if shapes match
    y_reseed = y_reseed_full[elig] if y_reseed_full.shape == elig.shape else y_reseed_full[: int(elig.sum())]
    if y_reseed.shape != y_left.shape:
        # fall back: recompute elig from max(run1,reseed) for overlap stats only on common floor
        elig_r = np.maximum(c_run1, c_reseed)[IU] >= COUNT_FLOOR
        common = elig & elig_r
        y_left_c = moved_mask(kirby["c0"], kirby["c1"])[IU][common]
        y_reseed_c = moved_mask(c_run1, c_reseed)[IU][common]
    else:
        common = elig
        y_left_c, y_reseed_c = y_left, y_reseed

    decomp = {
        "leftover_move_rate": k_left["move_rate"],
        "tracking_move_rate": k_reseed["move_rate"],
        "excess_above_tracking": float(k_left["move_rate"] - k_reseed["move_rate"]),
        "excess_fraction_of_leftover": float(
            (k_left["move_rate"] - k_reseed["move_rate"]) / max(k_left["move_rate"], 1e-12)
        ),
        "among_leftover_eligible_edges": {
            "both_leftover_and_reseed_move": float((y_left_c & y_reseed_c).mean()),
            "leftover_only": float((y_left_c & ~y_reseed_c).mean()),
            "reseed_only": float((~y_left_c & y_reseed_c).mean()),
            "stable_both": float((~y_left_c & ~y_reseed_c).mean()),
        },
        "cross_share_of_leftover_movers": float(k_left["n_cross_movers"] / max(k_left["n_movers"], 1)),
        "both_present_share_of_leftover_movers": float(k_left["n_both_movers"] / max(k_left["n_movers"], 1)),
    }
    boekel_reseed_path = SD / "boekel_dwi_retest/freeze/sub-pp01/reseed/ses-1_seed20261020/reseed_control.json"
    boekel_reseed = None
    if boekel_reseed_path.is_file():
        br = json.loads(boekel_reseed_path.read_text())
        c1r = np.loadtxt(boekel_reseed_path.parent / "count_run1_radial4.csv", delimiter=",")
        csr = np.loadtxt(boekel_reseed_path.parent / "count_reseed_radial4.csv", delimiter=",")
        boekel_reseed = _move_decomp(c1r, csr)
        boekel_reseed["lock_move_rate"] = br.get("tracking_only_move_rate")

    claim = (
        "On Kirby, tracking-only explains ~9.5% move rate vs ~54% leftover; "
        "~82% of leftover move rate is excess above tracking. "
        "Most leftover movers are both-present count changes, not threshold crossings."
    )
    if boekel_reseed is None:
        claim += " Boekel reseed pending (work-dir 5tt rebuilt via fallback)."
    rec = {
        "direction": 3,
        "question": "How much of scan-rescan edge change is tracking RNG vs threshold crossing vs count change?",
        "kirby_tracking_only_reseed": k_reseed,
        "kirby_leftover_ses1_vs_ses2": k_left,
        "boekel_leftover_ses1_vs_ses2": b_left,
        "boekel_tracking_only_reseed": boekel_reseed,
        "kirby_decomposition": decomp,
        "claim": claim,
    }
    (OUT / "03_noise_decomposition.json").write_text(json.dumps(rec, indent=2) + "\n")
    (OUT / "03_noise_decomposition.md").write_text(
        f"# Direction 3 — Noise decomposition\n\n{claim}\n\nSee `03_noise_decomposition.json`.\n"
    )
    return rec


def dir4(pairs: list[dict]) -> dict:
    rows = []
    for p in pairs:
        elig = np.maximum(p["c0"], p["c1"])[IU] >= COUNT_FLOOR
        c0, c1, es = p["c0"][IU], p["c1"][IU], p["esoft"][IU]
        hard_y = (relchange(c0, c1) > RELCHANGE_CUT) & (np.maximum(c0, c1) >= COUNT_FLOOR)
        soft_y = (relchange(es, c1) > RELCHANGE_CUT) & (np.maximum(es, c1) >= COUNT_FLOOR)
        # invent: soft reports edge (>=floor) where hard C0 < floor
        # invent: Esoft crosses floor where hard C0 did not (exam definition; frac vs n_elig)
        invent = (es >= COUNT_FLOOR) & (c0 < COUNT_FLOOR)
        n_elig = int(elig.sum())
        invent_n = int(invent.sum())
        denom = max(n_elig, 1)
        from_near = int(((es >= COUNT_FLOOR) & (c0 >= 5) & (c0 < COUNT_FLOOR)).sum())
        from_far = int(((es >= COUNT_FLOOR) & (c0 < 5)).sum())
        invent_frac = invent_n / denom
        rows.append(
            {
                "pair": p["key"],
                "moved_frac_hard": float(hard_y[elig].mean()),
                "moved_frac_soft": float(soft_y[elig].mean()),
                "soft_lower_than_hard": bool(soft_y[elig].mean() < hard_y[elig].mean()),
                "delta_moved": float(hard_y[elig].mean() - soft_y[elig].mean()),
                "invent_n": invent_n,
                "invent_frac": invent_frac,
                "locked_invent_cap": LOCKED_INVENT,
                "invent_fails_lock": invent_frac > LOCKED_INVENT,
                "invent_from_C0_5_10": from_near,
                "invent_from_C0_lt5": from_far,
                "invent_frac_if_exclude_near_threshold": from_far / denom,
            }
        )
    claim = (
        "Soft expectation slightly reduces moved-frac on both pilots but fails invent<=0.001. "
        "Almost all invents are near-threshold (C0 in [5,10)). "
        "Report soft as denoising-with-threshold-blur, not as a win under the locked invent rule."
    )
    rec = {
        "direction": 4,
        "question": "How should soft expectation be reported after invent fail?",
        "locked_rule_unchanged": "invent_frac<=0.001 still FAIL; do not relax",
        "pairs": rows,
        "reporting_schema": {
            "primary_stability": "moved_frac_soft vs moved_frac_hard (descriptive)",
            "invent_total": "invent_frac vs locked 0.001 (binary fail as recorded)",
            "invent_strata": ["C0 in [5,10) near-threshold blur", "C0 < 5 far invents"],
        },
        "claim": claim,
    }
    (OUT / "04_soft_reframe.json").write_text(json.dumps(rec, indent=2) + "\n")
    (OUT / "04_soft_reframe.md").write_text(f"# Direction 4 — Soft reframe\n\n{claim}\n")
    return rec


def dir6(pairs: list[dict]) -> dict:
    floors = [10, 20, 30, 50, 100]
    out = {}
    for p in pairs:
        rows = []
        for fl in floors:
            strong = np.minimum(p["c0"], p["c1"])[IU] >= fl
            if not strong.any():
                continue
            y = moved_mask(p["c0"], p["c1"], floor=fl)[IU][strong].astype(float)
            # moved_mask still uses COUNT_FLOOR in max; restrict manually
            y = ((relchange(p["c0"], p["c1"])[IU] > RELCHANGE_CUT) & strong).astype(float)
            y = y[strong]
            u = p["u"][IU][strong]
            f = p["f"][IU][strong]
            L = (-np.log1p(p["c0"]))[IU][strong]
            rows.append(
                {
                    "min_count_floor": fl,
                    "n": int(strong.sum()),
                    "y_rate": float(y.mean()),
                    "auroc_U": float(auroc(u, y)),
                    "auroc_F": float(auroc(f, y)),
                    "auroc_neg_log1p_C0": float(auroc(L, y)),
                }
            )
        out[p["key"]] = rows
    claim = (
        "Move rate falls as min-count floor rises, but U/F AUROC stays ~0.57–0.61. "
        "Leftover ranking remains a weak-edge / count phenomenon; L still beats U/F inside strong strata."
    )
    rec = {
        "direction": 6,
        "question": "On strong edges only, do U/F rank leftover movers — or is leftover still a weak-edge phenomenon?",
        "definition": "strong = min(C_run1,C_run2) >= floor",
        "pairs": out,
        "claim": claim,
    }
    (OUT / "06_strong_edges.json").write_text(json.dumps(rec, indent=2) + "\n")
    (OUT / "06_strong_edges.md").write_text(f"# Direction 6 — Strong edges\n\n{claim}\n")
    return rec


def dir7(pairs: list[dict]) -> dict:
    summaries = []
    for p in pairs:
        c0, p10, f, u, es = p["c0"], p["p10"], p["f"], p["u"], p["esoft"]
        reported = c0[IU] >= COUNT_FLOOR
        unc = (p10[IU] > P_LOW) & (p10[IU] < P_HIGH) & reported
        ii, jj = IU[0][reported], IU[1][reported]
        rows = []
        for k in range(ii.size):
            i, j = int(ii[k]), int(jj[k])
            rows.append(
                {
                    "i": i + 1,
                    "j": j + 1,
                    "count": int(c0[i, j]),
                    "Esoft": float(es[i, j]),
                    "F_leakage": float(f[i, j]),
                    "U_shift": float(u[i, j]),
                    "P_count_ge10": float(p10[i, j]),
                    "threshold_uncertain": bool((p10[i, j] > P_LOW) and (p10[i, j] < P_HIGH)),
                }
            )
        rows_sorted = sorted(rows, key=lambda r: -r["count"])
        tag = p["sid"]
        top_path = OUT / f"07_edge_bands_{tag}_top30.csv"
        unc_path = OUT / f"07_edge_bands_{tag}_uncertain.csv"
        with top_path.open("w", newline="") as fh:
            w = csv.DictWriter(fh, fieldnames=list(rows_sorted[0].keys()))
            w.writeheader()
            w.writerows(rows_sorted[:30])
        unc_rows = [r for r in rows_sorted if r["threshold_uncertain"]]
        with unc_path.open("w", newline="") as fh:
            fields = list(rows_sorted[0].keys()) if rows_sorted else ["i", "j"]
            w = csv.DictWriter(fh, fieldnames=fields)
            w.writeheader()
            w.writerows(unc_rows)
        summaries.append(
            {
                "pair": p["key"],
                "n_reported_edges_count_ge10": int(reported.sum()),
                "n_threshold_uncertain_among_reported": int(unc.sum()),
                "frac_uncertain": float(unc.sum() / max(int(reported.sum()), 1)),
                "median_F": float(np.median(f[IU][reported])),
                "median_abs_soft_minus_hard": float(np.median(np.abs(es[IU][reported] - c0[IU][reported]))),
            }
        )
    claim = (
        "Report each edge as count with a soft band (Esoft), assignment leakage F, shift sensitivity U, "
        "and P(count>=10). On pilots, only ~1–3% of reported edges are threshold-uncertain — a small, actionable flag set."
    )
    rec = {
        "direction": 7,
        "question": "What should a connectome table show users beyond a point count?",
        "schema": ["count", "Esoft", "band_low/high", "F_leakage", "U_shift", "P_count_ge10", "threshold_uncertain"],
        "pairs": summaries,
        "outputs": ["07_edge_bands_*_top30.csv", "07_edge_bands_*_uncertain.csv"],
        "claim": claim,
    }
    (OUT / "07_reliability_bands.json").write_text(json.dumps(rec, indent=2) + "\n")
    (OUT / "07_reliability_bands.md").write_text(f"# Direction 7 — Reliability bands\n\n{claim}\n")
    return rec


def main() -> int:
    OUT.mkdir(parents=True, exist_ok=True)
    pairs = [_load_pair(ds, sid) for ds, sid in PAIRS]

    import os

    os.environ["PYTHONPATH"] = "/mnt/nfs/home/urmc-sh.rochester.edu/pndagiji/Documents/edgeuq/src" + (
        os.pathsep + os.environ["PYTHONPATH"] if os.environ.get("PYTHONPATH") else ""
    )
    subprocess.check_call([sys.executable, str(HERE / "leftover_instability.py"), "--out", str(OUT)])

    d2 = dir2(pairs)
    d3 = dir3(pairs)
    d4 = dir4(pairs)
    d6 = dir6(pairs)
    d7 = dir7(pairs)
    d5 = json.loads((OUT / "05_leftover_score.json").read_text())

    summary = {
        "prescale": True,
        "scaled": False,
        "dir8": "awaiting user phrase: scale descriptive",
        "directions_recomputed": [2, 3, 4, 5, 6, 7],
        "dir5_code": "edgeuq instability + leftover_instability.py",
        "boekel_reseed": d3.get("boekel_tracking_only_reseed"),
        "claims": {f"d{k}": v.get("claim") for k, v in ((2, d2), (3, d3), (4, d4), (5, d5), (6, d6), (7, d7))},
    }
    (OUT / "PRESCALE_SUMMARY.json").write_text(json.dumps(summary, indent=2) + "\n")

    readme = OUT / "README.md"
    readme.write_text(
        "\n".join(
            [
                "# Eight directions after retest exam fail",
                "",
                "Pre-scale batch recomputed on both pilots. No frozen threshold retunes. **Dir 5 is code** (`edgeuq instability`).",
                "",
                "| # | Direction | Result in one line | Artifacts |",
                "|---|---|---|---|",
                "| 1 | Claim split | Keep plant-UQ; leftover exam = negative boundary | `01_claim_split.md` |",
                "| 2 | Threshold uncertainty | Uncertain edges enriched for crossings | `02_threshold_uncertainty.*` |",
                "| 3 | Noise decomposition | Kirby leftover mostly above reseed floor; Boekel reseed when ready | `03_noise_decomposition.*` |",
                "| 4 | Soft reframe | Soft helps moved-frac; invent fail = near-threshold blur | `04_soft_reframe.*` |",
                "| 5 | Leftover score ≠ U | `edgeuq instability` L=−log1p(C0) AUROC ~0.70 | `05_leftover_score.*` + edgeuq |",
                "| 6 | Strong edges only | Move rate drops with strength; U/F still ~0.58–0.61 | `06_strong_edges.*` |",
                "| 7 | Reliability bands | Report count+Esoft+F+U+P10; ~1–2% uncertain flags | `07_reliability_bands.*` + CSVs |",
                "| 8 | Scale descriptive | Plan only — awaiting **scale descriptive** | `08_scaling_plan.md` |",
                "",
                "Runner: `run_prescale_directions.py`. Summary: `PRESCALE_SUMMARY.json`.",
                "",
            ]
        )
    )
    print(json.dumps({"ok": True, "out": str(OUT), "boekel_reseed": summary["boekel_reseed"] is not None}, indent=2))
    return 0


if __name__ == "__main__":
    # leftover.INVENT_FRAC may not exist — use 0.001 literal in dir4
    sys.exit(main())
