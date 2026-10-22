---
title: "Endpoint fragility scores for streamline-count connectomes, with an honest scan–rescan boundary"
short_title: "edgeuq Paper 1"
date: 2026-10-20
status: finalize_pre_scale
software: edgeuq (shift, jitter, instability, rescan)
not: hat{U}; leftover ECE win; invent soft-win
venue_target: NeuroImage / Human Brain Mapping
---

# Endpoint fragility scores for streamline-count connectomes, with an honest scan–rescan boundary

**Not \(\hat{U}\).** Calibrated \(U\) is a probability for a **planted 1 mm** endpoint event only. Leftover prediction/calibration is Paper 2.

**Product.** (i) Frozen shift sensitivity \(U\) and jitter leakage \(F\) for iFOD2 count connectomes under `radial_4`. (ii) Isotonic calibration of \(U\) to the planted 1 mm event. (iii) Public scan–rescan exam showing these scores do **not** transfer as leftover rankers/calibrators. (iv) Reporting schema and optional secondary score \(L=-\log(1+C_0)\). (v) Software: `edgeuq`.

---

## Abstract

Structural connectomes built from probabilistic tractography (iFOD2) assign streamline endpoints to parcels with a radial search. Small residual errors in endpoint placement can change edge counts even when session QC passes. We introduce frozen edge-level **fragility** scores: shift sensitivity \(U\) under controlled sub-millimetre endpoint translations, and jitter leakage \(F\) under Gaussian endpoint noise. On development and held-out TRACK-TBI sessions, \(U\) ranked planted 1 mm movers with AUROC ≈ 0.91–0.94; an isotonic map of \(U\), fit only on development data, was well calibrated for that **same planted event** (held-out ECE ≈ 0.009).

We then tested whether plant-trained scores predict **scan–rescan leftover** edge changes on public same-day pairs (Kirby21 KKI849; Boekel pp01). They do not: leftover AUROC for \(U\)/\(F\) ≈ 0.58–0.60; plant calibration fails on leftover \(y\) (ECE ≈ 0.32). Soft expectation slightly reduces moved fraction but fails a locked invent≤0.001 rule because near-threshold counts blur across the floor of 10. A tracking-only reseed explains only ~9.5% move rate versus 36–54% leftover. Threshold-uncertain edges (\(0.1<P(C\ge10)<0.9\)) are rare (~1–3%) but highly enriched for crossings. A separate ses-1 count score \(L=-\log(1+C_0)\) ranked leftover movers at AUROC ≈ 0.70 on both pilots and is released as a distinct method (`edgeuq instability`), not a retuned \(U\).

**Conclusion.** Endpoint fragility UQ is a validated product for planted assignment error; scan–rescan change is a different phenomenon and must not be named \(\hat{U}\). Cohort-scale descriptive replication is pending (`scale descriptive`); leftover calibration is Paper 2. Software: `edgeuq` v0.2.0.

---

## Figures (rendered)

- Honesty / Claim B–C: [`figures/fig_plant_neq_leftover`](figures/fig_plant_neq_leftover.pdf) (leftover ranking + N16 claim split).  
- Claim B bars: [`figures/fig_paper1_leftover_boundary`](figures/fig_paper1_leftover_boundary.pdf).  
- Source plan: [PAPER1_figures.md](PAPER1_figures.md).

---

## 1. Introduction

Streamline-count connectomes remain widely used despite known sensitivity of edge weights to tractography and node assignment (Buchanan et al., 2014; Yeh et al., 2019; Schumacher et al., 2018). MRtrix radial search (default 4 mm) is the usual bridge from endpoints to parcels. Prior work established that millimetre-scale residual anatomy–diffusion mismatch and assignment choices move connectivity; what has been missing is a **frozen, reusable edge map** that ranks *which* reported edges are fragile under a **controlled** endpoint plant, plus a checked probability for that plant — and an honest test of whether the same scores predict **natural** visit-to-visit change.

We separate three claims:

- **A.** \(U\)/\(F\) quantify plant / assignment fragility (positive).
- **B.** They do not transfer to leftover ranking or leftover calibration on public retest pilots (boundary result).
- **C.** Leftover instability needs a **different** score (\(L\)); calibration of leftover probabilities is out of scope here (Paper 2).

Related work on test–retest reliability typically targets graph metrics or edge ICCs (Buchanan 2014; Owen et al.; Dimitriadis 2019). We are deliberately **edge-mechanistic**: we intervene on endpoints and score edges, not modularity.

---

## 2. Methods

### 2.1 Freeze

- Tractography: **iFOD2** + ACT (QSIRecon), probabilistic.
- Nodes: 78-region DKT in DWI/T1w space; empty_nodes = 0.
- Assignment: `radial_4` (4 mm).
- Event: relative change \(>0.25\) with \(\max(C)\ge 10\).

Software: `edgeuq` (Python; NumPy/NiBabel).

### 2.2 Shift sensitivity \(U\)

Fit plants: \(\{\pm0.25,\pm0.5\}\) mm on \(x,y,z\) (12 maps). Test plants: \(\{\pm1\}\) mm (6 maps). For eligible edges,

\[
U_{ij}=\max_{s\in\mathrm{fit}}\frac{|C^s_{ij}-C^0_{ij}|}{\max(C^s_{ij},C^0_{ij},\varepsilon)}.
\]

Moved under plant: test relative change \(>0.25\) and floor 10. Metrics: Spearman\((U,e)\), AUROC. Review footnote: \(U>0.25\).

### 2.3 Calibrated \(U\) (plant only)

Isotonic regression of \(U\to P_{\mathrm{cal}}\) fit on three development sessions only; frozen before confirmation ECE. **Not** fit on leftover \(y\). Win criteria as locked in experiment C (ECE improvement + high-bin band).

### 2.4 Jitter leakage \(F\) and soft expectation

Independent Gaussian endpoint jitter (\(\sigma\) from protocol / leftover-median rule; retest packs used locked \(\sigma\approx0.5\) mm), \(S=32\) samples. \(F\): fraction of streamlines that leave their ses-1 edge. \(E_{\mathrm{soft}}\): mean sample counts. \(P_{10}=P(C\ge10)\). Soft invent: \(E_{\mathrm{soft}}\ge10\) while \(C_0<10\); locked invent_frac ≤ 0.001 for a soft “win.”

### 2.5 Scan–rescan (leftover) exam

Public pairs: Kirby21 `KKI849`, Boekel `pp01` (same-day). Leftover \(y\) from ses-1 vs ses-2 DKT counts under the same cuts. Primary: AUROC of ses-1 \(U\), \(U_{\mathrm{cal}}\), \(F\) vs leftover \(y\). G: ECE of plant-trained \(P_{\mathrm{cal}}\) on leftover \(y\) (expected fail under Claim B). Tracking-only control: reseed iFOD2 with new RNG, ses-1 nodes fixed (descriptive floor).

### 2.6 Secondary score \(L\) (Claim C)

\[
L_{ij}=-\log(1+C^{(1)}_{ij}).
\]

Distinct method (`edgeuq instability`). Not \(\hat{U}\). Pilot AUROC vs leftover \(y\) reported; population claims await **scale descriptive**.

### 2.7 Reporting schema

Per reported edge (\(C_0\ge10\)): count, \(E_{\mathrm{soft}}\), \(F\), \(U\), \(P_{10}\), threshold_uncertain \((0.1<P_{10}<0.9)\).

---

## 3. Results

### 3.1 Plant validation (Claim A) — development and confirmation

| Split | Sessions | Spearman\((U,e)\) | AUROC \(U\) |
|---|---|---|---|
| Development (IDEAS×2, BTC) | 3 | 0.86–0.88 | 0.91–0.92 |
| Confirmation (TRACK-TBI 2WK×3) | 3 | 0.89–0.90 | 0.92–0.94 |

Ordinary QC flagged 0 edges; \(U>0.25\) flagged 78–138 count≥10 edges/session at precision 0.97–0.99 vs 1 mm movers (recall 0.20–0.29; conservative footnote).

**Calibration (plant event):** held-out ECE(\(P_{\mathrm{cal}}\)) ≈ 0.009 vs ≈ 0.121 for raw \(U\); high bin mean \(P\) ≈ 0.978 vs moved ≈ 0.970 (\(n=462\)).

**Multi-magnitude (pilots):** \(U\) AUROC for OR-ed plants remains high at 0.25 / 0.5 / 1.0 mm (Kirby/Boekel packs), supporting a sensitivity surface rather than a single-cut artifact.

### 3.2 Scan–rescan boundary (Claim B)

| Pair | \(n\) | leftover \(y\)-rate | AUROC \(U\) | AUROC \(F\) | invent_frac | uncertain frac |
|---|---:|---:|---:|---:|---:|---:|
| Kirby KKI849 | 2264 | 0.538 | 0.578 | 0.598 | 0.0062 | 0.027 |
| Boekel pp01 | 2628 | 0.359 | 0.605 | 0.592 | 0.0027 | 0.016 |

- Soft moved-frac slightly **below** hard on both; **invent FAIL** (locked 0.001). Almost all invents have \(C_0\in[5,10)\).
- G on leftover: ECE ≈ 0.32; bin band fail. Keep \(P_{\mathrm{cal}}\) as **1 mm only**.
- Kirby reseed move rate ≈ **0.095** vs leftover **0.54** (~82% of leftover move rate above tracking floor).
- Among leftover movers: ~87% both-present large \(\Delta C\); ~12–14% threshold crosses; Kirby ~10% also reseed-movers.

**Threshold uncertainty:** uncertain edges ~9–14× enriched for crossings (pilots).

### 3.3 Secondary leftover score \(L\) (Claim C; pilots)

| Pair | AUROC \(L\) | AUROC \(U\) | AUROC \(F\) |
|---|---:|---:|---:|
| Kirby | 0.699 | 0.578 | 0.598 |
| Boekel | 0.704 | 0.605 | 0.592 |

Hybrid \(L+\alpha U\) does not beat \(L\) alone. Simulation: Poisson count churn → \(L\gg U\); real 1 mm plant map → \(U\gg L\) (supports claim split). Strong-edge strata: y-rate falls; AUROCs shrink — residual leftover on strong edges remains open.

### 3.4 Negative controls (pilots)

Random ~0.5; FA weak; length/degree moderate; \(L\) best among tested ses-1 scores for leftover \(y\).

---

## 4. Discussion

**What P1 solves.** A protocol and software for ranking edges by fragility to controlled endpoint error, with a calibrated probability for that plant, after QC PASS.

**What P1 deliberately does not solve.** Calibrated \(P(\text{edge moves between visits})\). Literature already shows weak/count edges are less reliable on retest (Buchanan et al.; Schumacher et al.). Our exam shows plant-trained \(U\)/\(F\) are the wrong instrument for that estimand. Naming plant-calibrated scores \(\hat{U}\) would be incorrect.

**Reporting value after FAIL.** Rare threshold-uncertain flags, soft bands with invent strata, and \(L\) as a separate instability score give users actions without pretending invent/G won.

**Generalizability (limits).** Validated on iFOD2 + DKT-78; public leftover exam on two pilots. Alternate atlases, deterministic tractography, and multi-shell HCP strata are future generality tests (improve tier; not required to state Claim A/B on current freezes). Cohort **scale descriptive** will populate population panels without retuning cuts.

**Paper 2.** Leftover prediction/calibration with symbols \(L\), \(P_L\) (never \(\hat{U}\)), held-out ECE, lit baselines (ICC, bootstrap reliability).

---

## 5. Conclusion

Endpoint fragility scores \(U\)/\(F\) are validated for planted assignment error and released in `edgeuq`. Scan–rescan leftover change is mostly not tracking RNG and is not ranked by \(U\)/\(F\); we report that boundary, plus practical flags and a separate count instability score \(L\). Leftover calibration remains Paper 2.

---

## Data and code

- Software: `edgeuq` (shift, jitter, instability, rescan); protocol docs under `docs/`.
- Public pilots: Kirby21, Boekel retest (processed derivatives under project freeze; not redistributing raw where licenses forbid).
- Locks: `PAPER1_LOCK.md`; `work/R/strengthen/`; `work/sites_v1/RETEST_LOCK.json`.

## Acknowledgements / funding

*[to fill]*

## References (key)

Buchanan et al., NeuroImage 2014 (TRT structural networks).  
Yeh et al., NeuroImage 2019 (assignment consequential).  
Schumacher et al., NeuroImage 2018 (streamline-count reproducibility).  
Smith / MRtrix docs (radial search).  
Zadrozny & Elkan (isotonic calibration).  
Qi; Greene; related planted-shift / sensitivity literature as cited in project locks.
