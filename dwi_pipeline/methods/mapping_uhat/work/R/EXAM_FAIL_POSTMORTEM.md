# Why the retest exam failed (read-only postmortem)

Not a retune. Frozen cuts unchanged (relchange 0.25, count≥10, invent≤0.001, ECE band ±0.15).
Full numbers: `exam_postmortem.json`.

## What failed vs what almost passed

| Gate | Kirby | Boekel | Verdict |
|---|---|---|---|
| Soft moved-frac < hard | 0.534 < 0.538 | 0.353 < 0.359 | Pass (tiny margin) |
| invent_frac ≤ 0.001 | **0.0062** (14 edges) | **0.0027** (7 edges) | **Fail** |
| Soft connectome win | — | — | **Fail** (invent only) |
| G occupied bins ±0.15 | 6/9 bins fail | 5/9 bins fail | **Fail** |
| G ECE | 0.37 | 0.27 | **Fail** (pooled 0.32) |
| AUROC U / F | 0.58 / 0.60 | 0.60 / 0.59 | Weak (near chance+ε) |

## 1) Invent fail — threshold blur, not wild phantoms

Invent = Esoft ≥ 10 while hard C0 < 10.

**Kirby (14 invents):** 12/14 had C0 in **[5, 10)** (mostly 8–9). Mean C0 ≈ 7.9, mean Esoft ≈ 13.1, mean P(count≥10) ≈ 0.80. 11/14 are “threshold-uncertain” (0.1 < P < 0.9). 10/14 are also ≥10 on run-2.

**Boekel (7 invents):** **all 7** had C0 in [5, 10). Mean C0 ≈ 7.9, Esoft ≈ 10.9, P10 ≈ 0.77.

So jittered assignment is pushing edges that already sit just under the count floor across 10 in the soft mean. That is exactly the locked invent definition, and it exceeds 0.001 even though the absolute counts are small (14 and 7).

Two Kirby outliers (C0=2–3 but Esoft=19–34) look like unstable far assignments; they are the minority. Dropping only those would not save invent_frac (still 12/2264 ≈ 0.005).

Soft moved-frac did beat hard slightly — the soft-connectome *stability* claim is nearly true; the *no-invention* claim is what kills the win.

## 2) G calibration fail — wrong probability scale for leftover y

Isotonic P was fit on **planted 1 mm** development data. On retest leftover:

- Observed move rates: Kirby **54%**, Boekel **36%**
- Mean predicted P: Kirby **0.22**, Boekel **0.17**
- Reseed tracking-only floor: **~9.5%**

So most leftover moves are **far above** tracking noise, but U still assigns most edges to the lowest probability bin:

- Kirby: **62%** of eligible edges in bin 1 with mean_p≈0.025 but mean_y≈0.49 (gap **+0.46**)
- Boekel: **71%** in bin 1, mean_p≈0.023 vs mean_y≈0.31 (gap **+0.29**)
- High bins overshoot the other way (P≈0.98 vs y≈0.47–0.77)

Spearman(P, y) pooled ≈ **0.17**. Calibration cannot hold when the map was trained for a rare planted event and tested on common scan–rescan churn.

## 3) Weak AUROC — sensitivity ≠ leftover movers

U/F separate movers only weakly (means U≈0.08 on stable vs ≈0.11 on movers). Spearman(U, y) ≈ 0.12–0.14.

A trivial **low-count** score (−min(C0,C1)) gets AUROC **~0.72** on both pairs — leftover moves concentrate on weak edges, not on the edges that are most sensitive to a 1 mm endpoint plant.

Also: only ~5–7% of eligible edges are hard threshold crossings; among edges present (≥10) in **both** runs, y_rate is still 51% / 33%. So this is mostly real count change between scans, not just 10-count flickering.

## Root-cause summary

1. **Invent:** soft expectation blurs the count≥10 knife-edge; near-threshold edges (C0=5–9) become “invented.” Rule is strict; behavior is expected near a hard threshold.
2. **G:** leftover y is a different phenomenon (high base rate, weakly related to U) than the planted-1 mm event the isotonic map was built for.
3. **AUROC:** shift/jitter scores answer “where would a 1 mm plant hurt?”; leftover y answers “what changed between two real scans?” — overlapping little.

## What this does *not* say

- Pipeline / packs are broken (C0 vs shipped still r≈1).
- Soft moved-frac is worse than hard (it is slightly better).
- We should retune 0.001 / 0.25 / isotonic without an explicit reopen (frozen).

## If you reopen later (options only — not done)

- Treat invent as a near-threshold diagnostic stratum rather than a hard win kill.
- Fit or evaluate calibration on leftover y (separate claim from planted-1 mm P).
- Score leftover with count-aware features; keep U/F as plant-sensitivity (their original job).
