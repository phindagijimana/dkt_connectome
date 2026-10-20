# Retest / rescan exam (GOLD locked 2026-10-20)

Inputs: Kirby KKI849 + Boekel pp01, both sessions empty_nodes=0, packs on ses-1.

## Soft connectome (locked rule)
**FAIL** (`c2_soft_connectome_win=false`). Soft moved-frac was slightly below hard on both pairs, but `invent_frac` exceeded 0.001 on both (Kirby 0.0062, Boekel 0.0027). Per C2 lock: report; keep radial_4; do not relax the rule.

## Ranking (AUROC on leftover y)
| Pair | n | y_rate | AUROC U | AUROC Ucal | AUROC F |
|---|---:|---:|---:|---:|---:|
| Kirby KKI849 | 2264 | 0.538 | 0.578 | 0.589 | 0.598 |
| Boekel pp01 | 2628 | 0.359 | 0.605 | 0.599 | 0.592 |

## G calibration (isotonic U vs leftover y)
**FAIL** (`win=false`). ECE=0.318; occupied bins within ±0.15: false. Claim: keep calibrated U as a 1 mm probability; **not** hat{U}.

## Tracking-only control (descriptive)
Reseed move rate ≈ 0.095 (9.5% of scored edges), vs hard leftover move rates 54% / 36%. Tracking noise is a minority of observed moves.

## Scaling
Not auto-queued after FAIL. HCP FastSurfer/iFOD2 released separately.
