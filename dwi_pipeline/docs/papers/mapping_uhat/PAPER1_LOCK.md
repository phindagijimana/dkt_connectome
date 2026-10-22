---
title: Paper 1 lock — endpoint fragility UQ for streamline-count connectomes
date: 2026-10-20
status: FINALIZE_PRE_SCALE
venue_target: NeuroImage / Imaging Neuroscience / HBM (methods)
publication_plan: PUBLICATION_PLAN.md (P1 separate from P2 and DKT software note)
---

# PAPER1_LOCK

> **Publication:** methods paper alone. DKT-Connectome may ship `edgeuq` as an optional hook and cite this paper; it does not absorb Claims A–C.

## One-line product

Frozen edge scores for **fragility of streamline-count connectomes under controlled endpoint / assignment perturbation**, plus an honest **scan–rescan transfer boundary**, software (`edgeuq`), and reporting flags. Optional secondary: count instability \(L\).

## In scope (P1)

1. **Claim A (positive):** shift sensitivity \(U\), jitter leakage \(F\), calibrated \(U\) = P(move under **planted 1 mm**).
2. **Claim B (boundary result):** on public retest pilots, \(U\)/\(F\) do **not** rank leftover movers well; plant calibration does **not** transfer (G fail). Soft invent fails locked rule — report as near-threshold blur, not a soft win.
3. **Claim C (secondary):** \(L=-\log(1+C_0)\) as a **separate** leftover-instability score (pilot evidence; scale pending).
4. **Reporting:** threshold-uncertain flags, edge schema, soft as band + invent strata, reseed floor (descriptive).
5. **Software:** `edgeuq` (`shift`, `jitter`, `instability`, `rescan`).

## Out of scope (→ Paper 2)

- Leftover **calibration** win / naming \(\hat{U}\) or \(P_L\) as primary product.
- Mass-cohort prediction optimization.
- Retuning invent / relchange / floor / ECE band after seeing retest.

## Frozen protocol (do not change in P1)

| Item | Value |
|---|---|
| Tractography | iFOD2 + ACT (QSIRecon), probabilistic |
| Assignment | radial search 4 mm |
| Relchange cut | 0.25 |
| Count floor | 10 |
| Invent cap (soft win) | 0.001 |
| Plant fit / test | ±0.25/±0.5 fit; ±1 mm test |
| Jitter | σ from leftover-median rule or locked retest σ |

## Awaiting scale descriptive (insert before submission if available)

- Cohort distributions: leftover move rate, uncertain enrichment, \(L\) AUROC across Kirby21 / Boekel / HCP.
- Does **not** block finishing Methods/Results/Discussion text below; mark figures “pilot + pending scale panel.”

## Split from older docs

- Supersedes treating leftover G/\(\hat{U}\) as Paper 1 win criterion (`GOLD_HATU_LOCK` stay as historical lock of the *attempt*).
- Old `docs/papers/mapping_u/PAPER2_LEFTOVER_UQ.md` → content migrates to **Paper 2** (prediction/calibration with new symbols).
- Old `manuscript.md` plant numbers remain the Claim A backbone of this Paper 1.
