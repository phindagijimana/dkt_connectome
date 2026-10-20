# Eight directions after retest exam fail

Pre-scale batch recomputed on both pilots. No frozen threshold retunes. **Dir 5 is code** (`edgeuq instability`).

| # | Direction | Result in one line | Artifacts |
|---|---|---|---|
| 1 | Claim split | Keep plant-UQ; leftover exam = negative boundary | `01_claim_split.md` |
| 2 | Threshold uncertainty | Uncertain edges enriched for crossings | `02_threshold_uncertainty.*` |
| 3 | Noise decomposition | Kirby leftover mostly above reseed floor; Boekel reseed when ready | `03_noise_decomposition.*` |
| 4 | Soft reframe | Soft helps moved-frac; invent fail = near-threshold blur | `04_soft_reframe.*` |
| 5 | Leftover score ≠ U | `edgeuq instability` L=−log1p(C0) AUROC ~0.70 | `05_leftover_score.*` + edgeuq |
| 6 | Strong edges only | Move rate drops with strength; U/F still ~0.58–0.61 | `06_strong_edges.*` |
| 7 | Reliability bands | Report count+Esoft+F+U+P10; ~1–2% uncertain flags | `07_reliability_bands.*` + CSVs |
| 8 | Scale descriptive | Plan only — awaiting **scale descriptive** | `08_scaling_plan.md` |

Runner: `run_prescale_directions.py`. Summary: `PRESCALE_SUMMARY.json`.
