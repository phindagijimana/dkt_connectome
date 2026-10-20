# Paper 1 — tables (camera-ready numbers from locks)

Source artifacts: `mapping_uhat/work/R/retest_exam.json`, plant confirmation tables in `docs/papers/mapping_u/manuscript.md` §§3.1–3.4, `work/R/strengthen/N/`, `work/R/directions/`.

## Table 1 — Plant validation of \(U\) (Claim A)

| Split | Session | \(n\) eligible | 1 mm moved | Spearman\((U,e)\) | AUROC |
|---|---|---:|---:|---:|---:|
| Dev | IDEAS sub-1 | 2742 | 389 | 0.861 | 0.906 |
| Dev | IDEAS sub-6 | 2703 | 464 | 0.883 | 0.923 |
| Dev | BTC PAT20 | 2667 | 389 | 0.867 | 0.912 |
| Confirm | TBI011011 | 2604 | 439 | 0.886 | 0.923 |
| Confirm | TBI011021 | 2791 | 426 | 0.887 | 0.935 |
| Confirm | TBI011204 | 2841 | 474 | 0.899 | 0.945 |

Plant calibration (pooled confirm): ECE(\(P_{\mathrm{cal}}\)) ≈ 0.009 vs ECE(raw \(U\)) ≈ 0.121.

## Table 2 — Scan–rescan leftover exam (Claim B)

| Pair | \(n\) | \(y\)-rate | AUROC \(U\) | AUROC \(U_{\mathrm{cal}}\) | AUROC \(F\) | invent_frac | Soft win? | G win? |
|---|---:|---:|---:|---:|---:|---:|---|---|
| Kirby KKI849 | 2264 | 0.538 | 0.578 | 0.589 | 0.598 | 0.0062 | No | No |
| Boekel pp01 | 2628 | 0.359 | 0.605 | 0.599 | 0.592 | 0.0027 | No | No |

Pooled G ECE ≈ 0.318. Kirby reseed move rate ≈ 0.095.

## Table 3 — Secondary \(L\) and controls (Claim C; pilots)

| Pair | AUROC \(L\) | AUROC \(U\) | AUROC \(F\) | AUROC random | AUROC neg-FA |
|---|---:|---:|---:|---:|---:|
| Kirby | 0.699 | 0.578 | 0.598 | ~0.49 | ~0.52 |
| Boekel | 0.704 | 0.605 | 0.592 | ~0.51 | ~0.48 |

## Table 4 — Reporting / uncertainty (pilots)

| Pair | Uncertain frac (elig) | Crossing enrichment | Soft Δ moved-frac (hard−soft) |
|---|---:|---:|---:|
| Kirby | 0.027 | ~9.5× | ~0.005–0.008 |
| Boekel | 0.016 | ~14× | ~0.006–0.007 |

## Table 5 — Frozen protocol

| Parameter | Value |
|---|---|
| Tractography | iFOD2 + ACT (probabilistic) |
| Parcellation | DKT-78 |
| Assignment | radial 4 mm |
| Relchange / floor | 0.25 / 10 |
| Invent cap | 0.001 |
| Plant fit / test | ±0.25,±0.5 / ±1 mm |
| Jitter samples | 32 |
