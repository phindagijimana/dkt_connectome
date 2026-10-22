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

Scan–rescan (“leftover”) changes in streamline-count connectomes concentrate on weak edges and are poorly ranked by endpoint plant-sensitivity scores. We formalize leftover edge move \(y^{\mathrm{leftover}}\) under frozen relative-change and count-floor rules, and introduce a ses-1 ranking score \(L=-\log(1+C^{(1)})\). On public pilots, \(L\) achieved leftover AUROC ≈ 0.70 versus ≈ 0.58–0.60 for plant scores. We then calibrate \(P_L=\phi(L)\) with isotonic regression using **subject-held-out** training on leftover labels only. Cross-site leave-one-subject-out (Kirby↔Boekel) preserves ranking but not calibration (ECE ≈ 0.18) when leftover base rates clash (~0.54 vs ~0.36). **Within-site** Kirby LOSO (interim n=4) yields mean ECE ≈ 0.043 with matched y-rates (~0.52–0.60), supporting **site- or protocol-specific** \(\phi_L\) rather than a universal map or silent harmonization. *[After scale + KKI239: held-out ECE/Brier CIs and FA/length baselines.]* \(P_L\) is not plant-calibrated \(U\) and is not named \(\hat{U}\).

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

### 3.2 Pilot LOSO \(P_L\) — cross-site (protocol demo)

See `mapping_uhat/work/R/paper2/P_L_loso.json`. AUROC≈L; ECE ≈ 0.18 when train/test leftover base rates differ (0.54 vs 0.36). **Not a universal calibration win** — treated as a hard negative for pooled \(\phi\).

### 3.3 Within-site Kirby LOSO (n=5; hinge)

| Test | y_rate | AUROC \(L\) | ECE \(P_L\) |
|------|-------:|------------:|-----------:|
| KKI849 | 0.538 | 0.699 | 0.107 |
| KKI113 | 0.522 | 0.737 | 0.119 |
| KKI127 | 0.584 | 0.753 | 0.054 |
| KKI142 | 0.600 | 0.682 | 0.026 |
| KKI239† | 0.834 | 0.553 | 0.285 |
| **Mean n=5** | **0.616** | — | **0.118** |
| Mean n=4 (excl. 239) | 0.561 | — | **0.043** |

†Ses-2 tracked from **raw WM FOD** after `mtnormalise` CSF balance failure (documented rescue).  
Source: `work/R/paper2/within_site_kirby/P_L_loso_within_kirby.json`.  

Interpretation: without 239, within-site ECE ≈ 0.04 vs cross-site ≈ 0.18 supports **site/protocol maps**. KKI239 is a **within-site outlier** (y-rate and ranking), consistent with a processing stratum — not silent peer evidence. Product rule unchanged: per-site \(\phi_L\); refuse silent cross-site apply; flag QC/recon exceptions ([PREFIT_AND_SITE_MAPS.md](PREFIT_AND_SITE_MAPS.md)).

### 3.4 Pending after `scale descriptive`

- Multi-subject LOSO/k-fold AUROC + ECE + Brier with CIs.  
- Strength-stratified performance.  
- Baseline table vs FA/length/bootstrap if available.  
- Optional \(R\) enrichment replication.  
- Freeze versioned `isotonic_leftover_<stratum>.json`.

## 4. Discussion

- Why plant \(\phi\) failed (Paper 1 G) and how subject-held-out leftover \(\phi\) fixes the **design**.  
- Cross-site ECE failure is a **finding** (site maps), not a reason to drop \(P_L\).  
- Harmonization is not the default substitute for stratum-specific \(\phi\) without an ECE test.  
- \(L\) as count-aware score aligned with TRT lit.  
- Limits: n, atlas, iFOD2-only; strong-edge residual hard; n=4 interim exploratory.  
- Naming discipline: \(P_L\neq\hat{U}\). Contingency: if ECE fails within-site at scale, publish as ranking / instability prediction.

## 5. Conclusion

Leftover prediction/calibration is a separate problem from endpoint plant fragility. We lock the estimand, symbols, held-out protocol, and **site-specific map** rule; within-site interim supports calibration under matched base rates; scaled within-site ECE is the NeuroImage/MedIA submission gate.

---

## Code

- `edgeuq instability` → \(L\)  
- `edgeuq calibrate-leftover --loso-json …` → \(P_L\)  
- `edgeuq apply-leftover-map --map … --stratum …` → single-scan \(P_L\) (refuses stratum mismatch)  
- `mapping_uhat/run_paper2_PL.py` → pilot driver  
- `mapping_uhat/run_within_site_PL.py` → within-Kirby LOSO hinge  

Reviewer checklist: [NEUROIMAGE_REVIEWER_RESPONSE.md](NEUROIMAGE_REVIEWER_RESPONSE.md).
