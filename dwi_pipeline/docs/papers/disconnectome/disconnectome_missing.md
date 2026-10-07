# Disconnectome paper — what's missing to reach submission

**Purpose:** consolidated readiness checklist for the disconnectome paper
(Paper 2). Tracks what's needed between current state (pipeline built for SC,
fMRI pipeline just built and being tested, planning docs mature, waiting on
external clinical data) and a submitted manuscript.

**Related docs:** [index.md](index.md) · [outcomes_planning.md](outcomes_planning.md) ·
[analysis_plan.md](analysis_plan.md) · [complete_case.md](complete_case.md) ·
[manuscript_skeleton.md](manuscript_skeleton.md) ·
[../journal_tier.md](../journal_tier.md) · [../LQT.md](../LQT.md) ·
[../Griffis_later.md](../Griffis_later.md)

**Status as of 2026-10-07:** SC pipeline mature; **fMRI neurolit-inpaint pilot
complete (7 × 2WK)** — dual stream, Arm A/B matrices, exploratory
`run_pilot_fc_analysis.sh`. Prior work map:
[prior_work_novelty.md](prior_work_novelty.md). **Primary blockers:**
TRACK-TBI clinical export + complete-case N + prespecified group analysis code.

---

## Current readiness snapshot

| Category | Ready | Partial | Not started / blocked |
|----------|:-----:|:-------:|:--------------------:|
| SC pipeline (patient-specific lesion-aware) | ✅ | | |
| fMRI pipeline (fMRIPrep + XCP-D + DKT + Arm B + fMRIStroke) | ✅ | ⚠️ (DKT BOLD: XCP-D T1w denoised missing on pilot — fallback documented) | |
| fMRI pilot (7-subject neurolit-inpaint) | ✅ | | |
| Prior work / novelty map | ✅ | | |
| Reproducibility infrastructure | ✅ | | |
| Planning docs (index, outcomes_planning, analysis_plan, skeleton, tracker) | ✅ | | |
| Prior-work reference docs (LQT, Griffis_later, journal_tier) | ✅ | | |
| **TRACK-TBI clinical export** (GOSE + neuropsych + covariates) | | | ❌ external gate |
| Paper 2 subject subset finalized | | | ❌ blocks on clinical export |
| SC pipeline scaled on Paper 2 subset | | | ❌ blocks on subset |
| fMRI pipeline scaled on Paper 2 subset | | | ❌ blocks on subset + pilot success |
| LQT installed + run (comparator) | | | ❌ MATLAB dependency |
| BCBtoolkit installed + run (comparator) | | | ❌ |
| Analysis plan sign-off | | ⚠️ (template ready) | |
| Analysis code | | | ❌ |
| Figures + tables | | | ❌ |
| Manuscript draft | | | ❌ |

---

## External blockers (out of our direct control)

**These block downstream execution but not planning. Ask the TRACK-TBI data
core / PI network for the data-dictionary export.**

- [ ] **TRACK-TBI clinical data-dictionary export** — GOSE at all visits, RPQ, neuropsych battery (Trail Making A/B, WAIS PSI, SDMT, CVLT-II, BVMT-R, COWA), GCS, age, sex, education, mechanism, visit dates
- [ ] **DUA compliance verified** for TRACK-TBI outcome data use in the URMC analysis
- [ ] **Complete-case N confirmation** — how many subjects have all of: lesion mask + DWI + rs-fMRI + GOSE + covariates
- [ ] **Neuropsych composite construction method** — either adopt TRACK-TBI's published composites OR run factor analysis on individual test scores (Corbetta-style)

### Decision gate on complete-case N

Per [`analysis_plan.md § 8`](analysis_plan.md#8-complete-case-n-threshold):

- **N ≥ 45** — proceed with Paper 2 as designed → un-pause + lock analysis plan → J Neurotrauma/HBM realistic, Brain stretch achievable
- **N = 30–44** — proceed with limitations framing → HBM/NI:Clinical realistic; not Brain
- **N < 30** — fold disconnectome findings into Paper 1 as one supplementary figure; do not submit as standalone Paper 2

---

## Internal blockers — must have before submission

### Pilot execution

- [x] **fMRI neurolit-inpaint pilot — 7 × 2WK** (SLURM 172440 / 173003; Arm B both streams)
- [x] **DKT Arm B + DWI disconnectome** on same DKT-78 order (pilot)
- [x] **Exploratory QC** — `bash fMRI_pipeline/scripts/run_pilot_fc_analysis.sh`
- [ ] **Primary DKT BOLD = XCP-D denoised T1w** — pilot used fMRIPrep fallback; fix or document in methods
- [ ] **XCP-D network atlases** for domain analyses (Schaefer/4S) — available from XCP-D run; not yet in Paper 2 analysis
- [ ] **Motion QC table cohort-wide** — extract mean FD from confounds TSV per subject

### Data — after external gate clears

- [ ] **Paper 2 subject subset finalized** — subset of Paper 1 cohort with complete clinical variables + rs-fMRI + lesion mask
- [ ] **rs-fMRI coverage verified** cohort-wide (pilot has it; full cohort assumed to mirror — needs empirical audit)
- [ ] **Complete-case tracker populated** — [`complete_case.md`](complete_case.md) with real data
- [ ] **Assembly diagram completed** (CONSORT-style flow through inclusion criteria)

### Cohort processing

- [ ] **SC pipeline scaled** — `neurolit-lesion` (fixed arm per analysis plan) on Paper 2 subset; likely re-uses Paper 1's cohort outputs
- [ ] **fMRI pipeline scaled** — full Paper 2 subset through fMRIPrep + XCP-D + DKT post-hoc
- [ ] **Container digests recorded** per subject
- [ ] **Cross-site harmonization** applied if TRACK-TBI multisite structure applies

### Head-to-head comparators (methods contribution)

- [ ] **LQT installed** — MATLAB required (or MATLAB compiler runtime + compiled LQT, or Python port)
- [ ] **BCBtoolkit installed** — MATLAB + FSL wrapper
- [ ] **Lesion masks normalized to MNI** for LQT/BCB input (extending existing pipeline registration)
- [ ] **LQT + BCB run per subject** on Paper 2 subset — batch execution
- [ ] **Parcellation alignment** — LQT with DKT atlas OR our SC pipeline with Schaefer 200

### Analysis planning + execution

- [ ] **[`analysis_plan.md`](analysis_plan.md) locked** — 13 sections signed off before opening group results
- [ ] **Fixed imaging arm decided** (default `neurolit-lesion`)
- [ ] **Primary outcome locked** (default GOSE at 6mo)
- [ ] **Visit-timing rule locked** (default: 2WK imaging → 6mo outcome)
- [ ] **Covariate set locked** (age + sex + education + GCS + lesion volume)
- [ ] **Network-to-domain mapping locked** (which parcellation → which composite)
- [ ] **Analysis code** — `analysis/paper2/` scripts for:
  - CCA (SC ↔ FC) — Griffis Fig 2 replication in TBI
  - Ridge regression (SDC + FC → cognitive composites) — Salvalaggio-style
  - GOSE ordinal regression with incremental validity nested models
  - Head-to-head SDC divergence (patient-specific vs LQT vs BCB per subject)
  - Downstream ΔAUC / ΔR² attributable to each SDC method
  - Permutation testing (10,000 shuffles default)
  - Multiple-comparison correction

### Manuscript

- [ ] **Section-by-section draft** — flesh out [`manuscript_skeleton.md`](manuscript_skeleton.md)
- [ ] **Framing decision** — methods-lead (NeuroImage) vs biology-lead (Brain) vs default (HBM) based on results
- [ ] **Figure 1 — face-validity group disconnectome** in MNI space
- [ ] **Figure 2 — CCA first component** (SDC loadings + FC loadings + subject scores)
- [ ] **Figure 3 — domain-specific network-behavior grid** (5 panels: attention/memory/executive/language/motor)
- [ ] **Figure 4 — GOSE prediction ROC** (baseline vs +SDC vs +SDC+FC)
- [ ] **Figure 5 — representative cases** (mild/moderate/severe)
- [ ] **Figure 6 (methods-lead only) — head-to-head SDC divergence** vs LQT/BCB
- [ ] **Table 1 — demographics + clinical severity**
- [ ] **Table 2 — nested model comparison** (cross-validated ΔAUC + permutation p)
- [ ] **Table 3 — domain-network mapping table**
- [ ] **Supplement figures** (rs-fMRI motion QC, alternative parcellation, alternative arm, provenance schema)

### Administrative

- [ ] **Author list confirmed** — PI, analyst, coauthors, contributions per CRediT
- [ ] **TRACK-TBI collaborators acknowledged** if data core provides support
- [ ] **Data availability statement** — imaging BIDS-Derivatives + code repo tag; clinical data likely requires DUA-mediated access, not open
- [ ] **Code availability** — analysis scripts + containers + provenance JSON schema
- [ ] **IRB compliance** for TRACK-TBI imaging + clinical merge
- [ ] **Cover letter** — highlights (TBI extension of Griffis, patient-specific vs normative SDC head-to-head, full SC→FC→behavior chain)
- [ ] **Reference list** — Griffis 2019, Griffis 2021 LQT, Foulon 2018 BCB, Salvalaggio 2020, Talozzi 2023, Corbetta 2015, Palacios 2022, Bey 2024 LeAPP (methods citation for SC pipeline), fMRIPrep + XCP-D + MRtrix + FSL etc.

---

## Should have (for J Neurotrauma / HBM tier)

- [ ] **Automated lesion-segmentation sensitivity supplement** — comparison against clinician-traced masks (nnU-Net / MELD)
- [ ] **Cross-site harmonization** (ComBat or site-fixed-effects) — TRACK-TBI is multisite
- [ ] **Analysis pre-registration** on OSF or AsPredicted (1 day; free)
- [ ] **Prospective coauthor statistical review**
- [ ] **Face-validity qualitative discussion** — expert clinical inspection of case series

---

## Stretch (for Brain / NeuroImage tier)

Each item raises the ceiling if delivered cleanly.

- [ ] **Cross-atlas robustness** — repeat primary analyses in DKT vs Schaefer 200 vs 4S 156 for both SC and FC
- [ ] **Latent-space disconnectome** (Talozzi 2023-style dimensionality reduction) — needs N ≥ 60
- [ ] **Cohort-wide test-retest** if any subjects have repeat scans within-session
- [ ] **rs-fMRI motion-strict subgroup analysis** — exclude high-FD subjects, confirm findings robust
- [ ] **Comparison against Che 2026 CT + GAN-MRI baseline** — establish "black-box CNN" comparator for the interpretability argument
- [ ] **Multi-atlas FC + multi-parcellation SC full grid** — 3 SC atlases × 5 FC atlases = 15 pairings, robust to any single choice

---

## Timeline placeholder

Fill in as milestones are reached. Note: external gate can be reached in
parallel with pilot work but blocks cohort execution.

| Milestone | Target date | Actual date | Owner |
|-----------|-------------|-------------|-------|
| TRACK-TBI clinical export received | | | (external) |
| Complete-case N confirmed | | | |
| Paper 2 subset finalized | | | |
| Pilot fMRI pipeline succeeds | | | (in progress: job 72700) |
| Full pilot (3 subject-sessions) succeeds | | | |
| Cohort SC processing complete (fixed arm) | | | |
| Cohort fMRI processing complete | | | |
| LQT + BCB installed + cohort-run | | | |
| Analysis plan sign-off | | | (firewall #1) |
| Group results opened | | | (firewall #2 — no plan changes after) |
| Venue decision (NI / Brain / HBM) | | | (based on results) |
| First manuscript draft | | | |
| Coauthor rounds | | | |
| Submission | | | |

---

## Dependencies flowchart

```
External gate:
  TRACK-TBI clinical export ──────────────────────────┐
                                                       │
Internal pilot:                                        │
  fMRI pipeline test on TBI011011 ses-2WK ──► pilot success
                                                │
                                                ▼
                                        Full pilot (3 SES)
                                                │
                                                ▼
                                        Complete-case audit ◄─────┐
                                                │                  │
                                                ▼                  │ requires
                                        Paper 2 subset             │ clinical
                                                │                  │ export
                                                ├──► Cohort SC (neurolit-lesion arm)
                                                │
                                                ├──► Cohort fMRI (fMRIPrep + XCP-D + DKT)
                                                │
                                                └──► LQT + BCB per subject
                                                │
                                                ▼
                                        Analysis plan sign-off ───► FIREWALL 1
                                                │
                                                ▼
                                        Group-level analyses
                                                │
                                                ├──► CCA (SC↔FC)
                                                ├──► Ridge / GOSE ordinal
                                                ├──► Head-to-head SDC divergence
                                                ├──► Incremental-validity nested models
                                                │
                                                ▼
                                        Effect sizes + significance ─► FIREWALL 2
                                                │                       (venue decision)
                                                ▼
                                        Framing choice (methods-lead / biology-lead / default)
                                                │
                                                ▼
                                        Figures + tables
                                                │
                                                ▼
                                        First manuscript draft
                                                │
                                                ▼
                                        Coauthor rounds
                                                │
                                                ▼
                                        Submission
```

---

## Risk register

| Risk | Mitigation |
|------|-----------|
| **TRACK-TBI clinical export never arrives** | Fold disconnectome-only imaging results into Paper 1 as one figure; do not submit Paper 2 standalone |
| **Complete-case N < 30** | Same as above |
| **Complete-case N = 30–44** | Submit with explicit limitations framing → NI:Clinical or HBM (not Brain) |
| **rs-fMRI not cohort-wide** | Fall back to SC → behavior only (no FC middle layer); ceiling drops from Brain to HBM |
| **LQT / BCB not installable** (MATLAB unavailable) | Use Python ports; if unavailable, cite as limitation, run head-to-head against a Python-based normative-atlas alternative |
| **Patient-specific SDC ≈ LQT SDC** (methods head-to-head shows no divergence) | Publishable negative result; write as biology-lead (Brain default) rather than methods-lead |
| **SC → FC coupling weak in TBI** | Publish SC → behavior direct pathway; discuss weak FC coupling as TBI-specific difference from stroke |
| **Multisite variance masks effects** | ComBat harmonization + site-fixed-effects sensitivity |
| **Motion-QC failures reduce N further** | Report per-subject motion metrics transparently; exclusion criteria pre-specified |
| **Reviewer perceives closeness to Griffis / Salvalaggio** | Foreground patient-specific-SDC methods contribution + TBI-specific findings in introduction |

---

## See also

- [`index.md`](index.md) — cover doc + cross-tier paper matrix
- [`outcomes_planning.md`](outcomes_planning.md) — full detailed planning, Griffis-2019 contribution breakdown
- [`analysis_plan.md`](analysis_plan.md) — 13-section pre-registration template
- [`complete_case.md`](complete_case.md) — subject-level tracking template
- [`manuscript_skeleton.md`](manuscript_skeleton.md) — writing template
- [`../journal_tier.md`](../journal_tier.md) — ten-venue landscape
- [`../LQT.md`](../LQT.md) — normative-atlas SDC family reference
- [`../Griffis_later.md`](../Griffis_later.md) — Salvalaggio 2020 + Talozzi 2023 + Kuceyeski lineage
- [`../distance_novelty.md`](../distance_novelty.md) — contribution framework + consolidated per-paper contribution list
