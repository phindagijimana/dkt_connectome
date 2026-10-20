---
title: Paper 2 — Leftover connectome uncertainty (does the edge move under real leftover?)
date: 20 October 2026
status: rules locked; data in processing; no leftover numbers yet
not: hat{U} unless G wins; 2WK vs 6MO; planted mm called leftover
---

# Paper 2 — Leftover connectome uncertainty

**Question.** \(P(\text{this edge's count changes} \mid \text{measured leftover on this session})\). Voxel registration UQ exists (Simpson 2012; Hub 2009; Kybic 2010; Dalca 2019). The missing object is the push-through: leftover \(\phi\) → endpoint assignment → \(\Delta C\). A8 tried the cheap version (ANTs ensemble frequency) and failed calibration; that failure is reported in Paper 1, not hidden.

**Leftover \(y\).** Something we did not plant: two same-day acquisitions of the same subject, each processed by the same frozen pipeline. Moved = relchange\((C_{\text{run-1}}, C_{\text{run-2}}) > 0.25\) with \(\max \ge 10\). Not 2WK vs 6MO (time + recipe). Not the A5/A6 ensemble.

**Two routes (both publishable win or fail).**

1. **G — transport exam.** Frozen calibrated \(U\) (experiment C, no refit) tested on leftover \(y\). Win: every occupied bin (\(n\ge20\)) within 0.15 of observed rate. Rules: `GOLD_HATU_LOCK.md`, `methods/mapping_uhat/work/G/LOCK.json`. Win → may be named \(\hat U\). Fail → calibrated \(U\) stays a 1 mm phantom probability.
2. **\(\phi\) pushed through `radial_4`.** Per-endpoint jitter from measured leftover, same assigner (C2; see `PAPER3_C2_SOFT_ASSIGN.md`). Primary: AUROC of leakage \(F\) vs \(U\) vs calibrated \(U\) on leftover \(y\).

## Data

| Pair | Source | State (20 Oct 00:30) | Jobs |
|---|---|---|---|
| Kirby21 KKI849 ses-1/ses-2 | Same-day scan–rescan | QSIPrep done; FastSurfer done; tractography + DKT count ses-1 running, ses-2 next | 189574 (interactive), fallback 189589 (`general`) |
| Boekel pp01 ses-1/ses-2 | Same-day A/B, 4 runs each | Two data repairs: TRT from published bandwidth; Philips trace volume (b=1000, zero bvec) dropped from all 212 runs — it crashed eddy. **QSIPrep done (20 Oct 02:00), dwiref both sessions.** FastSurfer running. | 189586 ✓ → FastSurfer 189587 (interactive) → tractography 189588 (`general`) |
| Other-site 2WK (7) | Different site | FastSurfer array running; one DWI per subject, so not a leftover pair. For a later C transport check. | 189575 |

`work/sites_v1/LIST.json` stays `n = 0` until both sessions of a pair have `dkt_connectome_count.csv` with `empty_nodes = 0`.

## Run-1 pack (prepared, queued)

`methods/mapping_uhat/retest_pack.py` on ses-1 only:

- endpoints from the frozen iFOD2 tractogram; DKT nodes from the connectome output; `radial_4`;
- 18 planted maps with the U-paper rule (endpoints −t mm on one world axis; fit ±0.25/±0.5, test ±1), checked: re-running the rule on TBI011204 reproduced the stored `ty_m1mm` map exactly;
- \(U\), calibrated \(U\) (frozen isotonic), C2 leakage \(F\) and soft count \(E[C]\) with \(\sigma = 0.498\) mm (pooled V1 rule, written before any retest number).

Jobs: Kirby **189592** (after 189574_1), Boekel **189593** (after 189588_1).

## Exam (gated)

`retest_pack.py --exam` refuses to run until `LIST.json` has ≥2 pairs. G calibration runs only if `work/G/GOLD_LOCKED` exists (the user writes "GOLD locked"). Pre-specified outputs: AUROC(\(U\)), AUROC(calibrated \(U\)), AUROC(\(F\)); soft vs hard moved fraction with invent_frac ≤ 0.001; G ECE and occupied-bin check.

## Still to build

- **Tracking-only control.** Reseed run-1 tractography; the run-1 vs reseed move rate is the floor of \(y\) not due to registration. Needed to interpret \(y\). Locked in `RETEST_LOCK.json` (`tracking_only_control`): identical tckgen with `MRTRIX_RNG_SEED=20261020`, ses-1 nodes fixed, radial_4 counts; descriptive only. Queued for KKI849 (Slurm 189610, after the Kirby iFOD2 job). Output `freeze/sub-KKI849/reseed/ses-1_seed20261020/reseed_control.json`.
- **Per-session \(\sigma\).** A5/V1 on Kirby/Boekel run-1 needs the A5 driver rewritten (source lost). Secondary only.
- **More pairs.** Two pairs is the minimum for the gate. More Kirby21 subjects are the cheapest way to add power.

## Expected timing

Kirby pair + pack: Tuesday afternoon. Boekel pair + pack: Tuesday evening to Wednesday (shared `general` nodes). Exam: after both, and after the user decides on GOLD.
