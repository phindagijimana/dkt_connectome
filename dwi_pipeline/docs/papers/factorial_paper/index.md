# Factorial paper — cover and navigation

**Purpose:** canonical entry point for the "factorial paper" (Paper 1 in the
portfolio). Consolidates planning artifacts, cross-links supporting docs,
and provides the cross-tier paper-citation matrix.

**Note on nomenclature:** "the factorial paper," "Paper 1," and "the flagship
paper" all refer to the same manuscript.

**As-of:** 2026-09-17. **Author:** Phind Ndagijimana (with Claude planning assist).

**Status:** Active — submit first. **Target:** *Human Brain Mapping* (default);
*NeuroImage* stretch with synthetic-lesion validation.

---

## What this paper is

A 3×2 factorial evaluation of **anatomy mitigation** (original T1w vs neuroLIT
inpainting vs virtual brain transplant) crossed with **lesion-aware ACT**
(standard vs pathology-informed) for structural connectomes in traumatic
brain injury. Extending the LeAPP framework (Bey et al. 2024, HBM) from
ischemic stroke to TBI's more heterogeneous lesion morphology, we run all
six arms with isolated per-arm outputs across ~100 TrackTBI subjects with
clinician-traced lesion masks.

Pre-specified contrasts test whether lesion-aware ACT changes connectomes
within each anatomy backend, how much anatomy mitigation matters holding ACT
fixed, and whether the two interact. Primary deliverables are cohort
completion rates by arm, quantitative matrix/edge sensitivity, and honest
QC-by-arm reporting.

## Candidate titles

- *Lesion-aware structural connectomics in traumatic brain injury: a factorial comparison of inpainting, virtual brain transplant, and pathology-informed tractography* (working title)
- *A 3×2 factorial of anatomical mitigation and lesion-aware tractography for structural connectomics in traumatic brain injury*
- *From stroke to traumatic brain injury: extending lesion-aware connectome processing with neuroLIT and virtual brain transplant*
- *How much do preprocessing choices change the connectome in focal TBI? A cohort-scale factorial of inpainting and pathology-informed ACT*
- *Inpaint, transplant, or ignore? A factorial evaluation of lesion handling for structural connectomes in traumatic brain injury*

## Documentation cluster

The factorial paper is documented across the following files in this folder:

### Planning artifacts

| Doc | Purpose |
|-----|---------|
| **`index.md`** (this file) | Cover + navigation + cross-tier paper matrix |
| [`analysis_plan.md`](analysis_plan.md) | Pre-registration doc — locked design choices with sign-off block |
| [`manuscript_skeleton.md`](manuscript_skeleton.md) | Section-by-section outline with word budgets |
| [`completion_tracker.md`](completion_tracker.md) | Per-arm × per-subject completion tracker with assembly diagram |
| [`neuroimage_prerequisites.md`](neuroimage_prerequisites.md) | Three open items that gate NeuroImage-tier submission (synthetic validation, N ≥ 80, TBI-specific complications) |
| [`contribution_strategy.md`](contribution_strategy.md) | Distance-from-LeAPP analysis + ranked enhancement menu (framework-extension vs framework-formation framing) |
| [`differentiation_from_leapp.md`](differentiation_from_leapp.md) | Ranked menu of 20 candidate additions that enlarge our distance from LeAPP (Tier 0 table-stakes + Tier 1 high-leverage + Tier 2 medium + Tier 3 skip); marginal-value analysis and reviewer-defense mapping |
| [`factorial_missing.md`](factorial_missing.md) | ★ Submission-readiness checklist: blockers (must-have), should-have (HBM tier), stretch (NeuroImage tier), timeline placeholder, dependencies flowchart, risk register |
| [`factorial_abstract.md`](factorial_abstract.md) | ★ Honest working abstract for PI/coauthor review (contingencies acknowledged, is/is-not framing, questions for coauthors) |
| [`vbt_orientation_finding.md`](vbt_orientation_finding.md) | ★ TBI-specific finding: LeAPP VBT crashes on negative-determinant sform T1w (common in radiological-convention DICOMs); fixed with `fslreorient2std` preprocessing. Real Paper 1 methods contribution (RQ4 failure mode + supplement). |
| [`sidecar_repair_finding.md`](sidecar_repair_finding.md) | ★ Cohort-scale BIDS repair for Case-2 phasediff fmaps (EchoTime1/2, magnitude1/2, IntendedFor, PE block) — code walkthrough of `repair_bids_sidecars.py`, per-subject applicability table, methods paragraph draft. |

### Prior-work reference

| Doc | Purpose |
|-----|---------|
| [`leapp_lineage.md`](leapp_lineage.md) | LeAPP (Bey 2024) deep summary + lineage papers (Radwan VBG, Pollak neuroLIT, Smith ACT) — establishes what we extend and where the field sits |
| [`../publication_strategy.md`](../publication_strategy.md) | Cross-paper strategy for all four papers |

### Pipeline methods (docs level up — used but not moved)

| Doc | Purpose |
|-----|---------|
| [`../../TBI_Experimental_Arms.md`](../../TBI_Experimental_Arms.md) | Factorial spec, arm definitions, pilot tree, pre-specified contrasts |
| [`../../lesion_aware.md`](../../lesion_aware.md) | Lesion-aware ACT methodology + LeAPP framework overview |
| [`../../deep_atropos_5tt.md`](../../deep_atropos_5tt.md) | Deep Atropos branch (Paper 3 supplement, factorial-adjacent) |
| [`../../methods/step1_1_inpaint.md`](../../methods/step1_1_inpaint.md) | Step 1.1 anatomy mitigation implementation |
| [`../../methods/step3_1_lesion_act.md`](../../methods/step3_1_lesion_act.md) | Step 3.1 lesion-aware tractography |
| [`../../validation.md`](../../validation.md) | Validation cohort context |
| [`../../references.md`](../../references.md) | Full pipeline bibliography |

---

## Research questions

| ID | Question | Contrast |
|----|----------|----------|
| RQ1 (primary) | Does lesion-aware ACT produce systematically different connectomes than standard ACT within each anatomy backend? | `*-std` vs `*-lesion` within each anatomy |
| RQ2 (secondary) | How much does anatomy mitigation (orig vs neuroLIT vs VBT) change connectomes, holding ACT fixed? | `orig-*` vs `neurolit-*` vs `vbt-*` |
| RQ3 (interaction) | Is ACT benefit larger after inpainting (anatomy × ACT interaction)? | Nested 2×3 ANOVA interaction term |
| RQ4 (operations) | What are completion rates, QC pass rates, and failure modes across six arms? | Cohort completion table |
| RQ5 (optional) | On synthetic lesions in healthy controls, does the pipeline recover expected connectivity loss (LeAPP-style)? | Synthetic-lesion recovery on CIDUR |

**What's not asked:** which arm is ground truth; whether disconnection
predicts clinical recovery (that's [the disconnectome paper](../disconnectome/index.md)); whether Deep Atropos vs HSVS 5TT matters
at cohort scale (that's Paper 3 supplement).

---

## Cohort and data

| Cohort | Role | Status |
|--------|------|--------|
| **`sub-TBI011011`** — 6-arm factorial pilot | Engineering gate | ✅ Complete on NAS (6 arms + Deep Atropos pilot arm all pass) |
| **~100 TrackTBI subjects with lesion masks** | Flagship cohort × 6 arms | ⏳ Pending — depends on TrackTBI lesion-mask availability + pipeline processing |
| **CIDUR controls with synthetic-lesion injection** | Optional Tier B validation | ⏳ Planned — LeAPP-style synthetic validation |

---

## Cross-tier paper-citation matrix

Papers that appear in multiple venue tiers — cite once, deploy at multiple
levels. Rows are papers; columns are tiers where each paper is a primary
citation.

| Paper | *HBM* default tier | *NeuroImage* stretch tier | Supplement / general | *NeuroImage: Reports* backup |
|-------|:------------------:|:-------------------------:|:--------------------:|:----------------------------:|
| **Bey 2024** (LeAPP) *HBM* — factorial anatomy × ACT in stroke | ✅ **Direct precedent** | ✅ Methodological ancestor | | ✅ |
| **Radwan 2020** *HBM* — Virtual Brain Grafting (VBG) | ✅ VBT technique lineage | | ✅ Methods reference | |
| **Radwan 2023** *NetNeuro* — TBI + VBG + ACT N=5 | ✅ TBI precedent (small N) | ✅ Patient-specific TBI tractography | | ✅ |
| **Smith 2012** *NeuroImage* — SIFT/ACT foundational | | ✅ Methods foundation | ✅ Methods foundation | |
| **Pollak 2025** *Imaging Neuroscience* — neuroLIT DDPM inpainting | ✅ Inpainting method citation | | ✅ Methods reference | |
| **Yeh 2018** *NeuroImage* — HCP-842 tractogram | | | ✅ Reference atlas (if validation via LQT) | |
| **Cieslak 2021** — QSIPrep | | | ✅ Preprocessing citation | |
| **Andersson & Sotiropoulos 2016** — FSL EDDY | | | ✅ Preprocessing citation | |
| **Tournier 2019** — MRtrix3 | | | ✅ Tractography citation | |
| **Palacios 2022** *J Neurotrauma* — TRACK-TBI multisite DTI | ✅ Cohort scale precedent | | ✅ | |

**Interpretation:**

- **Cross-tier workhorses** (cited across 2+ primary tiers): Bey 2024, Radwan 2020, Radwan 2023 — anchor multiple parts of any Paper 1 submission.
- **Tier-specific anchors:** Smith 2012 for methods (NeuroImage stretch), Pollak 2025 for the neuroLIT arm, Palacios 2022 for cohort scale.
- **General methods references** (always cited): QSIPrep (Cieslak 2021), FSL EDDY (Andersson & Sotiropoulos 2016), MRtrix3 (Tournier 2019), FastSurfer (Henschel 2020), FreeSurfer (Fischl 2012).

Full LeAPP lineage detail in [`leapp_lineage.md`](leapp_lineage.md).

---

## Contribution summary

Five contributions ranked by novelty and venue-unlock potential:

| Contribution | Novelty | Reviewer defense | Venue tier it unlocks |
|--------------|---------|------------------|-----------------------|
| Six-arm factorial in TBI (extends LeAPP stroke → TBI) | Direct extension | Cohort completion table; pre-specified contrasts significant | HBM |
| neuroLIT inpainting as third anatomy backend (beyond LeAPP's VBT) | Novel combination | Pollak 2025 neuroLIT + our factorial evaluation | HBM |
| ACPC / HSVS registration workflow for pathology ACT | Methods refinement | `lesion_warp_method.txt` QA + registration success rates | HBM |
| Cohort-scale QC-by-arm reporting (pass/fail, not success stories) | Genuine transparency | Completion CSV as primary result | HBM (a differentiator, not novelty per se) |
| Synthetic-lesion validation on healthy anatomy (LeAPP-style RQ5) | LeAPP parity | Recovery of expected connectivity loss | **NeuroImage stretch** |

The synthetic-lesion validation (RQ5) is the specific analysis that could
elevate Paper 1 from HBM (default) to NeuroImage (stretch) — LeAPP had this
component (N≈81 synthetic lesions in healthy brains) and NeuroImage
reviewers may expect equivalent evidence at that tier.

---

## What stays inside Paper 1 (not separate manuscripts)

Per [publication_strategy.md § What stays inside paper 1](../publication_strategy.md#what-stays-inside-paper-1-not-separate-manuscripts):

| Topic | Treatment |
|-------|-----------|
| ACPC-first lesion → 5TT warp (HSVS path) | Methods subsection + supplement |
| neuroLIT vs VBT only | Part of factorial — not its own paper |
| Registration / pathology QA metrics | Supplementary tables |
| Pipeline / Snakemake / containers | Methods + data availability — not a standalone software paper |
| Deep Atropos vs HSVS sensitivity | Supplementary figure (Paper 3 material folded here) |
| A/B/C disconnectome excision integrity QC | Supplementary (contribution to disconnectome paper) |

---

## Design decisions to lock

Full pre-registration in [`analysis_plan.md`](analysis_plan.md). Key items:

- [ ] Primary numeric outcome: global matrix correlation | mean absolute edge difference | first-PC of connectome delta
- [ ] Primary parcellation: DKT (78 regions) — SIFT2-weighted (default) vs Schaefer 200 (sensitivity)
- [ ] Contrast set: pre-specified per [../../TBI_Experimental_Arms.md § Pre-specified contrasts](../../TBI_Experimental_Arms.md#pre-specified-contrasts-paper-1)
- [ ] Completion-threshold N per arm before group analysis opens
- [ ] Synthetic-lesion inclusion decision (Tier B) — determines HBM default vs NeuroImage stretch

---

## Immediate next steps

1. **Finalize cohort:** TrackTBI subject list with clinician-traced lesion masks (target ~100)
2. **Complete pilot QC:** confirm all six arms clean on `sub-TBI011011` — engineering gate (see [`completion_tracker.md`](completion_tracker.md))
3. **Lock analysis plan:** [`analysis_plan.md`](analysis_plan.md) sign-off before batch submission
4. **Batch process cohort:** six arms × ~100 subjects with per-arm result trees
5. **Assemble QC-by-arm table:** feeds RQ4 (operations) and paper Table 1
6. **Decide on synthetic-lesion validation:** run on CIDUR controls if pursuing NeuroImage stretch

---

## See also

- [`../index.md`](../index.md) — papers workspace landing page
- [`../publication_strategy.md`](../publication_strategy.md) — full four-paper portfolio
- [`../disconnectome/index.md`](../disconnectome/index.md) — the disconnectome paper (Paper 2)
- [`../paper3_deep_atropos.md`](../paper3_deep_atropos.md) — Deep Atropos supplement (folded into Paper 1)
- [`../paper4_longitudinal.md`](../paper4_longitudinal.md) — longitudinal resource (Paper 4)
