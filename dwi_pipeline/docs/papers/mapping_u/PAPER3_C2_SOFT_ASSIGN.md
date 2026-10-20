---
title: Paper 3 — C2, per-endpoint assignment probability under measured leftover (Yeh-style)
date: 20 October 2026
status: locked; development run in progress (planted y); leftover exam gated on Paper 2 data
not: Exp2 matrix mean; hat{U}; leftover calibration from planted y
---

# Paper 3 — C2 per-endpoint soft `radial_4`

**Why a new method.** Experiment 2 averaged six planted count matrices (+0.4 to +1.4 points stability; kept `radial_4`). That is a matrix smoother, not Yeh's per-endpoint assignment probability. C2 builds \(P(\text{node} \mid \text{endpoint}, \text{measured leftover})\).

**Method (locked, `methods/mapping_uhat/work/C2/LOCK.json`).**

- Jitter each endpoint \(\delta \sim N(0, \sigma_s^2 I_3)\), \(\sigma_s\) = session V1 voxel-median leftover / 1.5382 (median of a 3-D Maxwell length). Development \(\sigma\): 0.41–0.63 mm.
- \(S = 32\) jittered re-assignments with the same `radial_4`; fixed seeds.
- Per streamline: fraction of samples that stay on its hard edge. Per edge: leakage \(F_{ij} = 1 - \sum P(\text{stay}) / C^0_{ij}\). Soft connectome \(E[C]\).
- Assumptions stated: isotropic, constant \(\sigma\) per session; ends jitter independently (real \(\phi\) is smooth — the coherent case is the \(U\) plant).
- Retest amendment (20 Oct, before any retest number): Kirby/Boekel use pooled \(\sigma = 0.498\) mm.

## Exams

| Exam | \(y\) | Win rule (written first) | State |
|---|---|---|---|
| Development | Planted 1 mm (same as \(U\)) | Spearman\((F,e) > 0.5\) and AUROC \(> 0.7\) on ≥2/3 dev and ≥2/3 confirm | **Win, 3/3 + 3/3** (189577/189578). See below. |
| Leftover | Run-1 vs run-2 (Kirby, Boekel) | Primary: AUROC of \(F\) vs \(U\) vs calibrated \(U\). Soft connectome wins if its moved fraction is below hard on both pairs with invent_frac ≤ 0.001 | Gated on Paper 2 data; packs queued (189592, 189593) |

Fail on either → keep hard `radial_4` (Yeh 2019) and say so. A development pass is planted \(y\) only and is not leftover calibration.

### Development result (20 Oct 2026, planted \(y\) only)

| Session | Split | \(\sigma\) (mm) | Spearman\((F,e)\) | AUROC \(F\) | AUROC \(U\) | Spearman\((F,U)\) | Invented count≥10 edges in \(E[C]\) |
|---|---|---:|---:|---:|---:|---:|---:|
| IDEAS sub-1 | dev | 0.63 | 0.759 | 0.904 | 0.906 | 0.706 | 3 |
| IDEAS sub-6 | dev | 0.46 | 0.767 | 0.892 | 0.923 | 0.741 | 7 |
| BTC PAT20 | dev | 0.59 | 0.777 | 0.897 | 0.912 | 0.757 | 12 |
| TBI011011 | confirm | 0.52 | 0.787 | 0.910 | 0.923 | 0.746 | 6 |
| TBI011021 | confirm | 0.48 | 0.773 | 0.927 | 0.935 | 0.731 | 2 |
| TBI011204 | confirm | 0.41 | 0.787 | 0.931 | 0.945 | 0.754 | 5 |

- Leakage \(F\), built only from measured leftover \(\sigma\) and no planted shift, ranks the 1 mm movers almost as well as \(U\) (AUROC 0.89–0.93 vs 0.91–0.95). \(U\) remains slightly better on every session.
- \(F\) and \(U\) correlate 0.71–0.76, so they are related but not the same score.
- Mean streamline stay probability 0.95–0.96; 11–16% of endpoints have stay probability below 1.
- Recomputed hard \(C^0\) equals the frozen identity count exactly on all six sessions.
- The soft connectome \(E[C]\) crosses count 10 on 2–12 edges that are below 10 in \(C^0\) (up to 0.45% of eligible edges). That is above the 0.001 invent_frac used for the leftover soft-connectome rule, so the soft-connectome claim is at risk; the \(F\) ranking claim is not.

### Handling the invented edges (lock amendment 2026-10-20b, before any retest number)

The 0.001 rule is **not relaxed**. Three secondary, descriptive outputs were added:

1. **Invented-edge profile (development, done).** 33 of 35 invented edges were already at hard count 6–9 (mostly 9), so the soft average only nudged them over the count-10 threshold. Two were not: IDEAS sub-6, hard 0 → soft 35.5; PAT20, hard 2 → soft 14.8. Averaging also dropped 6–17 edges per session below 10, more than it added. `work/C2/invented_profile.json`.
2. **Hard crossing rate (retest).** Fraction of eligible edges that are ≥10 in one hard run and <10 in the other: what re-scanning alone does to the threshold. Context beside invent_frac; cannot overturn it.
3. **Threshold uncertainty.** Per edge \(P(\text{count} \ge 10)\) over the 32 jittered samples; \(0.1 < P < 0.9\) = threshold-uncertain. An uncertainty flag, not a replacement connectome. On retest: share of hard run-1 vs run-2 crossings that land on flagged edges. Per-sample matrices were rebuilt with the same seeds (Slurm 189597; leakage matched exactly on all 6 sessions). Result (189598): 46–74 threshold-uncertain edges per session (0.8–1.6% of eligible edges); 28 of the 35 invented edges are flagged threshold-uncertain. Retest packs save per-sample matrices directly.

Recommended use if the soft-connectome rule fails: report the hard connectome, flag threshold-uncertain edges, and use \(F\) as the per-edge fragility score.

## Files

`c2_soft.py`, `tests/test_c2_math.py`, `slurm/c2_array.sbatch`, `slurm/c2_exam.sbatch`, `retest_pack.py`, outputs in `work/C2/` and `work/R/`.

## Still to build

- Spatial \(\sigma\) (v2): V1 voxel maps were saved as flat vectors without a grid; needs re-saving with indices.
- Correlated jitter between the two ends (smooth \(\phi\)) — a second model, new lock.
- Compare against Exp2 and hard `radial_4` on the same leftover \(y\) (one table).
