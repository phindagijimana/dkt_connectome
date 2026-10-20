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
| Development | Planted 1 mm (same as \(U\)) | Spearman\((F,e) > 0.5\) and AUROC \(> 0.7\) on ≥2/3 dev and ≥2/3 confirm | Running: **189577** (6 sessions, ~01:30), exam **189578** |
| Leftover | Run-1 vs run-2 (Kirby, Boekel) | Primary: AUROC of \(F\) vs \(U\) vs calibrated \(U\). Soft connectome wins if its moved fraction is below hard on both pairs with invent_frac ≤ 0.001 | Gated on Paper 2 data; packs queued (189592, 189593) |

Fail on either → keep hard `radial_4` (Yeh 2019) and say so. A development pass is planted \(y\) only and is not leftover calibration.

## Files

`c2_soft.py`, `tests/test_c2_math.py`, `slurm/c2_array.sbatch`, `slurm/c2_exam.sbatch`, `retest_pack.py`, outputs in `work/C2/` and `work/R/`.

## Still to build

- Spatial \(\sigma\) (v2): V1 voxel maps were saved as flat vectors without a grid; needs re-saving with indices.
- Correlated jitter between the two ends (smooth \(\phi\)) — a second model, new lock.
- Compare against Exp2 and hard `radial_4` on the same leftover \(y\) (one table).
