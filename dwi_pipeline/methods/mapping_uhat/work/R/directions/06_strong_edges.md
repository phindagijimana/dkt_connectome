# Direction 6 — Strong-edge-only leftover evaluation

Eligible: `min(C1,C2) ≥ floor`.

## kirby21/KKI849

| min count | n | y_rate | AUROC U | AUROC F | AUROC −log C0 |
|---:|---:|---:|---:|---:|---:|
| 10 | 2102 | 0.508 | 0.610 | 0.585 | 0.665 |
| 20 | 1909 | 0.491 | 0.604 | 0.583 | 0.666 |
| 30 | 1783 | 0.477 | 0.596 | 0.579 | 0.662 |
| 50 | 1634 | 0.457 | 0.590 | 0.571 | 0.651 |
| 100 | 1458 | 0.433 | 0.587 | 0.570 | 0.640 |

## boekel_dwi_retest/pp01

| min count | n | y_rate | AUROC U | AUROC F | AUROC −log C0 |
|---:|---:|---:|---:|---:|---:|
| 10 | 2489 | 0.327 | 0.615 | 0.586 | 0.665 |
| 20 | 2290 | 0.306 | 0.601 | 0.584 | 0.653 |
| 30 | 2145 | 0.285 | 0.585 | 0.572 | 0.632 |
| 50 | 1952 | 0.268 | 0.584 | 0.578 | 0.626 |
| 100 | 1689 | 0.246 | 0.585 | 0.580 | 0.626 |

## Claim

Leftover move rate falls sharply as the min-count floor rises (weak-edge phenomenon). U/F AUROC stays ~0.5–0.6 even on stronger edges; count-based score also weakens. Strong-edge clinical reporting is more stable by base rate, but U/F still are not leftover rankers there.
