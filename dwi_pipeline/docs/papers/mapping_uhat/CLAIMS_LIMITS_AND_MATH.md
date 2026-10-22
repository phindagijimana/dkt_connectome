---
title: Claims, limits, and math (PI / lab brief)
date: 2026-10-22
status: LAB_BRIEF
companions: [PUBLICATION_PLAN.md, PAPER1_LOCK.md, PAPER2_LOCK.md, PAPER2_MATH.md, PAPER2_LITERATURE.md]
audience: lab / PI / onboarding (readable theory); manuscripts stay NeuroImage tone
---

# Claims, limitations, and math

Shared brief: **what we claim**, **what we do not**, the **math in plain language then symbols**, and the papers behind each piece.  
Manuscripts: [PAPER1_manuscript.md](PAPER1_manuscript.md), [PAPER2_manuscript.md](PAPER2_manuscript.md) (NeuroImage-level writing).  
Software: `edgeuq` v0.2.0. Core rule: \(P_L\neq\hat{U}\).

---

## 0. Start here (story in five minutes)

### The practical problem

Connectomes report how many streamlines link each pair of brain regions (**edge counts**). Those numbers look precise, but:

1. **Weak edges** (low counts) often jump a lot when you scan the same person again.  
2. How you **assign** streamline ends to parcels (e.g. MRtrix radial search) can move counts even when QC “passes.”  
3. A score that catches problem (2) under a **controlled fake error** need not predict problem (1) on real visit-to-visit change.

We treat (2) and (1) as **two different scientific targets**, not one “uncertainty score.”

### Two papers, two targets

| | Paper 1 | Paper 2 |
|---|---------|---------|
| **Everyday name** | Plant / assignment fragility | Leftover / scan–rescan change |
| **What we ask** | If I nudge endpoints by ~1 mm on purpose, which edges move? | Between visit 1 and visit 2, which edges move under frozen rules? |
| **Main scores** | \(U\), \(F\), plant-calibrated \(U_{\mathrm{cal}}\) | \(L\), then probability \(P_L=\phi(L)\) |
| **Must not say** | “\(U\) predicts retest change” | “\(P_L\) is \(\hat{U}\) / plant UQ” |

**Analogy.** Paper 1 is a **lab stress test** (shake the wiring). Paper 2 is **field reliability** (does the reading stay put next week?). Passing the stress test does not prove field reliability — and we measured that it doesn’t.

### One picture of the pipeline

```
ses-1 counts C⁽¹⁾ ──► L = −log(1 + C⁽¹⁾) ──► apply stratum map φ ──► P_L
                              ▲
                              │ fit φ only on OTHER subjects’ leftover labels y
ses-2 counts C⁽²⁾ ──► leftover event y (relchange > τ and max count ≥ f)
```

Plant path (Paper 1) never enters this diagram as a leftover probability.

### Tiny numeric example (leftover label)

Take \(\tau=0.25\), \(f=10\), \(\varepsilon=10^{-9}\).

| Edge | \(C^{(1)}\) | \(C^{(2)}\) | relchange \(\|a-b\|/\max(a,b,\varepsilon)\) | \(\max\ge 10\)? | \(y^{\mathrm{leftover}}\) |
|------|------------:|------------:|---------------------------------------------:|:---------------:|:-------------------------:|
| A | 100 | 95 | 0.05 | yes | **0** (stable) |
| B | 20 | 12 | 0.40 | yes | **1** (moved) |
| C | 8 | 3 | 0.625 | **no** | ignored for scoring (below floor) |

For edge B, ses-1 score \(L=-\log(1+20)\approx -3.04\) (weaker edges → larger \(L\) → higher leftover risk under our ranking).

---

## 1. Field limitations we are building methods for

### 1.1 Weak / low-count edges are unreliable on retest

**Limitation.** Streamline-count connectomes — especially weak edges — change between visits; global graph metrics can look stabler than edge weights.

**Why it matters.** Users still read edge counts as if they were stable biology.

**Literature (problem statement).** Buchanan et al., *NeuroImage* 2014 (TRT structural networks); Schumacher et al., *NeuroImage* 2018 (count reproducibility); Dimitriadis et al., *NeuroImage* 2019 (construction ↔ power); related weak/long-edge CV work (Bonilha-style TRT corpus).

**Our response.** Explicit leftover event \(y^{\mathrm{leftover}}\) and ses-1 score \(L\) aimed at that instability (Paper 2)—not a retune of plant scores.

### 1.2 Endpoint assignment is a major construction knob

**Limitation.** How streamlines are attached to parcels (radial search, etc.) moves counts even when QC “passes.”

**Literature.** Yeh et al., *NeuroImage* 2019; MRtrix `tck2connectome` / Smith radial search (operational `radial_4`).

**Our response.** Controlled plant/jitter exam (Paper 1 \(U\), \(F\)) that intervenes on endpoints and scores edges.

### 1.3 Plant fragility ≠ visit-to-visit change

**Limitation.** A score trained on *synthetic* endpoint error need not predict *natural* scan–rescan churn.

**In one sentence.** Doing well at ranking edges that break under a 1 mm plant does **not** mean those edges are the ones that break between real visits.

**Literature.** Same TRT corpus as §1.1 vs assignment literature (§1.2); calibration domain-shift (Zadrozny & Elkan; Niculescu-Mizil & Caruana; Naeini ECE).

**Our response.** Paper 1 Claim B: plant \(U\)/\(F\) / plant \(U_{\mathrm{cal}}\) fail on leftover \(y\) (AUROC ~0.58–0.60; ECE ~0.32). Never name leftover products \(\hat{U}\).

### 1.4 Calibration and maps do not silently transfer across sites/protocols

**Limitation.** Leftover base rates and \(L\!\to\!y\) curves differ by site/recon; pooling or ComBat-style harmonization does not automatically fix probabilities.

**In one sentence.** A probability map fit at Kirby need not be trustworthy at Boekel — so the product ships **stratum maps** and refuses silent mismatch.

**Literature.** Site/protocol effects implicit in multi-cohort TRT; calibration needs matched train/test events; our cross-site LOSO ECE ≈ 0.18 (Kirby↔Boekel).

**Our response.** Site/protocol \(\phi_L\); `apply-leftover-map` refuses stratum mismatch ([PREFIT_AND_SITE_MAPS.md](PREFIT_AND_SITE_MAPS.md)).

### 1.5 Scope limits of *our* evidence (honest)

| Limit | Meaning |
|-------|---------|
| Atlas / recon | Primary freezes: iFOD2 + DKT-78 + `radial_4` |
| n (current) | Plant exam + public leftover pilots; within-Kirby n=4 map / n=5 with QC outlier |
| Scale pending | Cohort CIs / descriptive tables—not a new estimand |
| Not claimed | Clinical TBI prediction; universal leftover probability; ICC replacement |

---

## 2. Claims (three outputs)

### Paper 1 — plant fragility + leftover boundary

**Lead claim.** Frozen edge scores \(U\)/\(F\) (and plant-calibrated \(U\)) quantify **controlled endpoint/assignment fragility**; the same scores **do not** transfer to scan–rescan leftover change.

| Piece | Plain language | Math / protocol | Cite |
|-------|----------------|-----------------|------|
| **A (positive)** | Planted 1 mm movers are ranked/calibrated well | Shift ±1 mm test; isotonic \(U\mapsto P_{\mathrm{cal}}\) on plant \(y\) only | Yeh 2019; MRtrix radial; our plant ECE |
| **B (boundary)** | Those scores fail leftover ranking/calibration | Same \(\tau,f\) event on retest pairs; AUROC/ECE on leftover \(y\) | Buchanan 2014; Schumacher 2018 |
| **C (secondary)** | \(L=-\log(1+C_0)\) is a *different* leftover ranker | Ses-1 only; not named \(U\) | Weak-edge TRT lit (§1.1) |

**Plain-language takeaway.** Paper 1 sells a **plant product** and an honest **no** on leftover transfer — not a leftover probability.

### Paper 2 — leftover \(L\) → site-specific \(P_L\)

**Lead claim.** Leftover edge change is its own estimand: \(L\) ranks it; subject-held-out \(P_L=\phi(L)\) is a **stratum-specific** probability—not plant \(U_{\mathrm{cal}}\) and never \(\hat{U}\).

| Piece | Plain language | Math | Cite |
|-------|----------------|------|------|
| Estimand | Which edges “move” between visits under frozen cuts | \(y^{\mathrm{leftover}}\) below | Buchanan; Schumacher |
| Ranking | Weaker ses-1 counts → higher leftover risk | \(L=-\log(1+C^{(1)})\) | Count TRT lit |
| Calibration | Fit \(\phi\) on leftover \(y\) of **train subjects**; test on held-out subjects | Isotonic \(P_L=\phi(L)\); ECE/Brier | Niculescu-Mizil; Naeini ECE |
| Site maps | Cross-site ECE fails; within-site improves when y-rates match | Within-Kirby vs Kirby↔Boekel LOSO | Our P2 results; PREFIT doc |
| Product | Apply shipped map only if stratum matches | `edgeuq apply-leftover-map` | PREFIT / software note |

**Plain-language takeaway.** Paper 2 sells **leftover ranking + per-site probabilities**, with held-out subjects and no silent cross-site apply.

### Software note — DKT + optional edgeuq

**Lead claim.** Reproducible DKT counts + optional trust-band hooks; **no new science**—cites P1/P2 for validation ([SOFTWARE_DKT_EDGEUQ.md](SOFTWARE_DKT_EDGEUQ.md)).

---

## 3. Math (shared cuts)

Read **intuition → formula → rule** in each subsection. Full protocol detail: [PAPER2_MATH.md](PAPER2_MATH.md).

### 3.1 Relative change and leftover label

**Intuition.** An edge “moved” if the count changed by more than 25% *and* at least one visit had a usable count (≥ 10). Tiny absolute wobbles on strong edges, and chaos on near-zero edges below the floor, are handled separately by that joint rule.

\[
\mathrm{relchange}(a,b)=\frac{|a-b|}{\max(a,b,\varepsilon)},\quad \varepsilon=10^{-9}.
\]

\[
y^{\mathrm{leftover}}_{ij}
=
\mathbf{1}\!\left\{
\mathrm{relchange}\big(C^{(1)}_{ij},C^{(2)}_{ij}\big)>\tau
\;\wedge\;
\max\big(C^{(1)}_{ij},C^{(2)}_{ij}\big)\ge f
\right\}
\]

with locked \(\tau=0.25\), \(f=10\). Eligible edges for AUROC/ECE: \(\max(C^{(1)},C^{(2)})\ge f\) on the upper triangle.  
**Not** the planted 1 mm label \(y^{\mathrm{plant}}\).

### 3.2 Plant scores (Paper 1; sketch)

**Intuition.** Move every endpoint a fixed amount (shift) or add random noise (jitter); rebuild the connectome; score how much each edge’s count reacted.

- **Shift:** translate all endpoints by a fixed mm along an axis; rebuild counts;  
  \(U_{ij}\) summarizes relative count change under the plant battery (test magnitude 1 mm).  
- **Jitter:** independent Gaussian endpoint noise → leakage \(F\), soft counts \(E_{\mathrm{soft}}\), \(P(C\ge 10)\).  
- **Plant calibration:** isotonic \(U\mapsto P_{\mathrm{cal}}\) fit on **plant** \(y\) development data only.

**Why isotonic?** It turns a ranking score into a probability that matches observed move rates while staying monotone (higher \(U\) → higher \(P\)). Fit on plant labels only — never on leftover \(y\).

### 3.3 Leftover score and map (Paper 2)

**Intuition.** Weak ses-1 edges are where TRT literature expects instability. \(L\) is a monotone transform of the ses-1 count (no second visit needed to *score*). To get a probability, learn \(\phi\) from other people’s leftover labels, then apply \(\phi(L)\) on a new person.

\[
L_{ij}=-\log\!\big(1+C^{(1)}_{ij}\big).
\]

On training subjects, pool eligible \((L,y^{\mathrm{leftover}})\) and fit monotone

\[
P_L=\phi(L)\qquad\text{(isotonic)}.
\]

Evaluate on **held-out subjects** (LOSO): AUROC\((L,y)\), ECE\((P_L,y)\), Brier.  
In-sample fit on the same subject’s edges is **invalid** for claiming ECE.

**Why subject holdout?** Edges within one brain are dependent. Fitting and testing on the same subject’s edges overstates calibration. Hold out **people**, not random edges.

### 3.4 Metrics in one line each

| Metric | Asks | Good when… |
|--------|------|------------|
| **AUROC** | Do higher scores put movers above stayers? | Ranking works (closer to 1) |
| **ECE** | Do reported probabilities match observed move rates in bins? | Calibration works (closer to 0) |
| **Brier** | Mean squared error of \(P\) vs \(y\) | Lower is better |

Plant Claim A: high AUROC + low ECE on **plant** \(y\).  
Plant Claim B: AUROC near chance / high ECE on **leftover** \(y\).  
Paper 2: AUROC of \(L\) on leftover; ECE of \(P_L\) **within stratum**.

### 3.5 What the symbols must not mean

| Symbol | Means | Must not mean |
|--------|--------|----------------|
| \(U\), \(U_{\mathrm{cal}}\) | Plant / assignment fragility | \(P(\text{visit change})\) |
| \(L\) | Leftover instability ranker | Shift sensitivity \(U\) |
| \(P_L\) | \(P(y^{\mathrm{leftover}}=1\mid L)\) under a stratum map | \(\hat{U}\) or plant \(U_{\mathrm{cal}}\) |
| \(\phi_L\) | Frozen map score→probability for one stratum | A universal leftover map across sites |

Full protocol: [PAPER2_MATH.md](PAPER2_MATH.md), [PAPER1_LOCK.md](PAPER1_LOCK.md), [PAPER2_LOCK.md](PAPER2_LOCK.md).

---

## 4. Theory in short (why two estimands)

**Generative sketch (not a proof — intuition for the split).**

- **Count / leftover world:** visit-2 counts behave like noisy draws around visit-1 (e.g. Poisson-like). Weak edges then dominate relative change → expect \(L\) to rank leftover movers better than plant \(U\).  
- **Plant world:** apply a 1 mm endpoint operator. Edges that are *assignment-fragile* move → expect \(U\) to dominate.

We measured both worlds empirically (Paper 1 Claim A vs B; Paper 2 \(L\)). The sketch explains *why* one score cannot honestly wear both hats.

**Calibration theory (one idea).** A probability is only meaningful for the **event it was fit to**. Plant \(U_{\mathrm{cal}}\) is \(P(\text{planted 1 mm move})\). Using it as \(P(\text{visit change})\) is wrong-label calibration — ECE ≈ 0.32 on leftover \(y\) is that failure, not a bug in isotonic regression.

---

## 5. Potential critiques and how we account for them

Anticipated NeuroImage-tier / lab red-team pushbacks. Detail tracker: [NEUROIMAGE_REVIEWER_RESPONSE.md](NEUROIMAGE_REVIEWER_RESPONSE.md).

### Shared

| Critique | Why it hurts | How we account |
|----------|--------------|----------------|
| “This is UQ for real visit change / \(\hat{U}\)” | Oversell; wrong estimand | Locked non-claims; abstracts and symbol table forbid leftover as plant \(U\); \(P_L\neq\hat{U}\) |
| “n=2 pilots are not enough” | Underpowered generalization | Do not submit calibration as NI-scale on n=2; within-Kirby mini + **scale descriptive** for CIs; ranking claims stay provisional until scale |
| “Two papers rehash the same story” | Desk-reject / confusion | [PUBLICATION_PLAN.md](PUBLICATION_PLAN.md): P1 plant+boundary; P2 leftover; software cites both |
| “No runnable software” | Irreproducible methods | `edgeuq` v0.2.0 CLIs + tests; DOI after public GH Release |
| “Just ComBat / harmonize and pool \(\phi\)” | Hides site clash | Product default = **site/protocol maps**; refuse silent cross-site apply; harmonization optional research only ([PREFIT_AND_SITE_MAPS.md](PREFIT_AND_SITE_MAPS.md)) |

### Paper 1

| Critique | Why it hurts | How we account |
|----------|--------------|----------------|
| “Only a negative TRT result” | No positive use case | Same paper: Claim A plant win **and** Claim B leftover fail |
| “Soft invent / G quietly abandoned” | Selective reporting | Locked invent≤0.001 and G fail reported as fails, not retuned |
| “Only DKT / iFOD2 / two sites” | Narrow generality | Stated freeze; scale + optional HCP stratum for descriptive panels; coarse DKT-39 smoke done; full Schaefer optional |
| “No figure for plant≠leftover” | Hard to see claim split | Rendered: `figures/fig_plant_neq_leftover` (+ N16 claim-split panel) |
| “Implies clinical TBI utility” | Unwarranted leap | Non-claim: TRACK-TBI used for plant held-out only; no clinical leftover claim |

### Paper 2

| Critique | Why it hurts | How we account |
|----------|--------------|----------------|
| “ECE≈0.18 means leftover maps don’t work” | Misreads cross-site fail | Frame as **site dependence** (finding); within-Kirby n=4 ECE≈0.043 with matched y-rates |
| “n=5 with KKI239 kills the within-site story” | Outlier pulls mean ECE | Document 239 as skip-mtnorm processing stratum; primary map = n=4 peers; report both means |
| “No baselines vs FA / length / random / \(U\)” | \(L\) could be trivial | Kirby mini baseline table (`leftover_baselines_kirby`); \(L\) beats those |
| “In-sample isotonic on one subject” | Invalid ECE | Train/test unit = **subject**; LOSO; refuse same-subject fit-as-validation |
| “How do I use this on one scan?” | Product gap | Shipped interim \(\phi_L\) + `apply-leftover-map` with stratum check |
| “ECE may never pass at scale” | Venue risk | Contingency locked: publish as ranking / instability prediction + site-map protocol, not universal \(P_L\) |
| “Atlas dependence” | Protocol brittleness | Coarse DKT-39 smoke (ΔAUROC small); Schaefer when nodes exist—not a silent claim of atlas-invariance |

### What we still leave open (do not bluff)

- **Scale CIs** for ECE/AUROC and cohort move-rate tables (compute gate).  
- **Zenodo DOI** (tag `v0.2.0` pushed; public Release needs auth).  
- **True multi-atlas N3** beyond coarse DKT pairing.  

### Venue posture if critiques land

| Evidence after scale | Honest posture |
|----------------------|----------------|
| Within-site ECE holds + CIs | NI/MedIA **calibration** + site maps |
| Ranking holds; ECE mainly within-site | NI-tier **methods**; cross-site as hard negative |
| Ranking only | Imaging Neuroscience / NI:Reports — no probability product claim |

---

## 6. Citation anchors (quick list)

**TRT / weak edges:** Buchanan et al. 2014; Schumacher et al. 2018; Dimitriadis et al. 2019.  
**Assignment:** Yeh et al. 2019; MRtrix / Smith radial search.  
**Calibration design:** Zadrozny & Elkan; Niculescu-Mizil & Caruana; Naeini ECE.  
**Our locks / evidence:** [PAPER1_manuscript.md](PAPER1_manuscript.md), [PAPER2_manuscript.md](PAPER2_manuscript.md), [PAPER2_LITERATURE.md](PAPER2_LITERATURE.md), [NEUROIMAGE_REVIEWER_RESPONSE.md](NEUROIMAGE_REVIEWER_RESPONSE.md).

---

## 7. One-sentence for a PI

We separate **planted assignment fragility** (Paper 1) from **scan–rescan leftover prediction/calibration** (Paper 2), with math that freezes the leftover event and forbids calling leftover probabilities \(\hat{U}\); the methods sit on the known TRT and assignment limits in Buchanan, Schumacher, Yeh, and related work, treat site-specific maps as the product default, and answer standard oversell / n / baseline / cross-site critiques with locked non-claims, held-out design, and an explicit ranking-only contingency if calibration does not close at scale.

---

## 8. Where to read next

| Need | Doc |
|------|-----|
| Formal leftover math + LOSO rules | [PAPER2_MATH.md](PAPER2_MATH.md) |
| Single-scan use / site maps | [PREFIT_AND_SITE_MAPS.md](PREFIT_AND_SITE_MAPS.md) |
| Reviewer checklist | [NEUROIMAGE_REVIEWER_RESPONSE.md](NEUROIMAGE_REVIEWER_RESPONSE.md) |
| Submission prose (keep NI tone) | P1 / P2 manuscripts |
