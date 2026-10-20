# Eight directions after retest exam fail

Worked **one at a time** on 2026-10-20. No frozen threshold retunes.

| # | Direction | Result in one line | Artifacts |
|---|---|---|---|
| 1 | Claim split | Keep plant-UQ; leftover exam = negative boundary | `01_claim_split.md` |
| 2 | Threshold uncertainty | Uncertain edges **9–14×** enriched for crossings | `02_threshold_uncertainty.*` |
| 3 | Noise decomposition | ~82% of Kirby leftover move rate is **above** reseed floor | `03_noise_decomposition.*` |
| 4 | Soft reframe | Soft slightly helps moved-frac; invent fail = near-threshold blur | `04_soft_reframe.*` |
| 5 | Leftover score ≠ U | Ses-1 `−log1p(C0)` AUROC **~0.70** vs U/F ~0.59 | `05_leftover_score.*` |
| 6 | Strong edges only | Move rate drops with strength; U/F still ~0.58–0.61 | `06_strong_edges.*` |
| 7 | Reliability bands | Report count+Esoft+F+U+P10; ~1–2% uncertain flags | `07_reliability_bands.*` + CSVs |
| 8 | Scale descriptive | Plan for cohort ICCs/enrichment — **awaiting “scale descriptive”** | `08_scaling_plan.md` |

## Recommended paper spine from this set

1. Plant-sensitivity UQ (shift + jitter) — positive.  
2. Retest negative control + Dirs 2–3 (threshold uncertainty, reseed decomposition).  
3. Edge report schema (Dir 7).  
4. Optional second method: count-based leftover instability (Dir 5).  
5. Scale (Dir 8) for descriptive replication only.
