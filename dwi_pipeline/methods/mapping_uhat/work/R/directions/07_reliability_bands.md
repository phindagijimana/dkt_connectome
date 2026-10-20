# Direction 7 — F as reliability band (edge report)

For each counted edge (C≥10), report:

- `count` (hard)
- `Esoft` (jitter expectation) and band [min,max]
- `F_leakage` (assignment instability)
- `U_shift` (1 mm plant sensitivity)
- `P_count_ge10` + `threshold_uncertain` flag

## kirby21/KKI849

- Reported edges: 2149
- Threshold-uncertain: 33 (0.015)
- Median F: 0.082
- Median |Esoft−count|: 4.22
- Files: `07_edge_bands_KKI849_top30.csv`, `..._uncertain.csv`

## boekel_dwi_retest/pp01

- Reported edges: 2572
- Threshold-uncertain: 28 (0.011)
- Median F: 0.064
- Median |Esoft−count|: 3.25
- Files: `07_edge_bands_pp01_top30.csv`, `..._uncertain.csv`

## Claim

Report each edge as count with a soft band (Esoft), assignment leakage F, shift sensitivity U, and P(count>=10). On pilots, only ~1–3% of reported edges are threshold-uncertain — a small, actionable flag set.
