# Direction 5 — Separate leftover-instability score

U/F unchanged. New candidates evaluated on leftover y.

| Score | Kirby AUROC | Boekel AUROC | Uses |
|---|---:|---:|---|
| `U` (plant sensitivity (frozen)) | 0.578 | 0.605 | |
| `F` (jitter leakage (frozen)) | 0.598 | 0.592 | |
| `neg_log1p_C0_only` (ses-1 count only) | 0.699 | 0.704 | |
| `one_minus_P10` (ses-1 jitter P10) | 0.553 | 0.538 | |
| `hybrid_C0_P10` (ses-1 count + P10) | 0.699 | 0.704 | |
| `neg_min_C0_C1` (oracle min(C0,C1)) | 0.716 | 0.735 | |
| `abs_dcount_oracle` (oracle |ΔC|) | 0.515 | 0.504 | |

## Claim

Ses-1-only low-count (-log1p C0) AUROC ~0.71–0.73 beats U/F (~0.58–0.60) for leftover y on both pilots. P10 adds little alone. A dedicated leftover-instability score should be count-aware and kept separate from plant-sensitivity U.

## Implication

Build leftover UQ as a **second method** (count / threshold instability), not by retuning U.
