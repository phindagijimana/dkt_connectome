# Direction 5 — Separate leftover-instability score (code)

Implemented as `edgeuq instability` → `L = -log1p(C0)`. Not hat{U}.

| Pair | L AUROC | U | F | n |
|---|---:|---:|---:|---:|
| `kirby21/KKI849` | 0.699 | 0.578 | 0.598 | 2264 |
| `boekel_dwi_retest/pp01` | 0.704 | 0.605 | 0.592 | 2628 |

## Claim

Ses-1-only low-count (-log1p C0) AUROC ~0.70 beats U/F (~0.58–0.60) for leftover y on both pilots. Implemented as edgeuq instability (L).
