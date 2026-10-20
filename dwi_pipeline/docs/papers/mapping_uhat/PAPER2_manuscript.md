---
title: "Predicting and calibrating scan–rescan edge change in streamline-count connectomes"
short_title: "edgeuq Paper 2"
date: 2026-10-20
status: DESIGN_LOCKED_PILOT_DEMO
not: hat{U}; plant Ucal as leftover P; invent retune
venue_target: NeuroImage / MedIA (if held-out P_L closes after scale)
---

# Predicting and calibrating scan–rescan edge change in streamline-count connectomes

**Paper 2.** Dedicated leftover estimand. Symbols \(L\), \(P_L\) (optional \(R\)). **Never** \(\hat{U}\).

**Relation to Paper 1.** Paper 1 showed plant-trained \(U\)/\(F\) and plant \(U_{\mathrm{cal}}\) do **not** transfer to leftover \(y\) (AUROC ≈ 0.58–0.60; ECE ≈ 0.32). That domain-shift failure motivates a separate leftover model.

---

## Abstract (draft; finalize after scale)

Scan–rescan (“leftover”) changes in streamline-count connectomes concentrate on weak edges and are poorly ranked by endpoint plant-sensitivity scores. We formalize leftover edge move \(y^{\mathrm{leftover}}\) under frozen relative-change and count-floor rules, and introduce a ses-1 ranking score \(L=-\log(1+C^{(1)})\). On public pilots, \(L\) achieved leftover AUROC ≈ 0.70 versus ≈ 0.58–0.60 for plant scores. We then calibrate \(P_L=\phi(L)\) with isotonic regression using **subject-held-out** training on leftover labels only. With n=2 pilots, leave-one-subject-out preserves ranking but not calibration under cross-site base-rate shift (protocol demo). *[After scale: report held-out ECE/Brier and baseline comparisons.]* \(P_L\) is not plant-calibrated \(U\) and is not named \(\hat{U}\).

---

## 1. Introduction

- TRT literature: weak / low-count edges less reliable (Buchanan 2014; Schumacher 2018; …).  
- Paper 1: plant UQ works; leftover transfer fails — textbook wrong-label calibration.  
- Gap: a **leftover-native** ranker and probability with proper held-out design.  
- Contribution: estimand \(y^{\mathrm{leftover}}\), score \(L\), calibrated \(P_L\), optional class \(R\); software `edgeuq calibrate-leftover`.

## 2. Methods

See `PAPER2_MATH.md` and `PAPER2_LOCK.md`.

- Event: \(\tau=0.25\), \(f=10\), radial_4 counts from iFOD2.  
- \(L=-\log(1+C^{(1)})\).  
- \(\phi\): isotonic on train subjects’ leftover \(y\).  
- LOSO / k-fold by subject.  
- Baselines: random, FA, length, \(1-P_{10}\), \(U\), \(F\) (baselines only).

## 3. Results

### 3.1 Pilot ranking (n=2; also in Paper 1 Claim C)

| Pair | AUROC \(L\) | AUROC \(U\) | AUROC \(F\) |
|---|---:|---:|---:|
| Kirby KKI849 | 0.699 | 0.578 | 0.598 |
| Boekel pp01 | 0.704 | 0.605 | 0.592 |

### 3.2 Pilot LOSO \(P_L\) (protocol demo)

See `mapping_uhat/work/R/paper2/P_L_loso.json`. Expectation: AUROC≈L; ECE poor when train/test leftover base rates differ (0.54 vs 0.36). **Not a calibration win.**

### 3.3 Pending after `scale descriptive`

- Multi-subject LOSO/k-fold AUROC + ECE + Brier.  
- Strength-stratified performance.  
- Baseline table vs FA/length/bootstrap if available.  
- Optional \(R\) enrichment replication.

## 4. Discussion

- Why plant \(\phi\) failed (Paper 1 G) and how subject-held-out leftover \(\phi\) fixes the **design**.  
- \(L\) as count-aware score aligned with TRT lit.  
- Limits: n, atlas, iFOD2-only; strong-edge residual hard.  
- Naming discipline: \(P_L\neq\hat{U}\).

## 5. Conclusion

Leftover prediction/calibration is a separate problem from endpoint plant fragility. We lock the estimand, symbols, and held-out protocol; pilot LOSO validates the pipeline; scaled calibration is the submission gate for NeuroImage/MedIA.

---

## Code

- `edgeuq instability` → \(L\)  
- `edgeuq calibrate-leftover --loso-json …` → \(P_L\)  
- `mapping_uhat/run_paper2_PL.py` → pilot driver
