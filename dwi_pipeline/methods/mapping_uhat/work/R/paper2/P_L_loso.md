# Paper 2 — pilot LOSO \(P_L\)

LOSO P_L on n=2 pilots is a design check: ranking of L transfers across sites, but ECE remains poor under base-rate shift. Not hat{U}. Scale required for calibration claims.

## Baselines (within-subject AUROC vs leftover y)

| Pair | L | U (baseline) | F (baseline) |
|---|---:|---:|---:|
| `kirby21/KKI849` | 0.699 | 0.578 | 0.598 |
| `boekel_dwi_retest/pp01` | 0.704 | 0.605 | 0.592 |

## LOSO folds

- test `kirby21/KKI849`: AUROC L=0.699, P_L=0.698, ECE=0.180, mean P=0.365 vs y=0.538
- test `boekel_dwi_retest/pp01`: AUROC L=0.704, P_L=0.704, ECE=0.180, mean P=0.539 vs y=0.359
