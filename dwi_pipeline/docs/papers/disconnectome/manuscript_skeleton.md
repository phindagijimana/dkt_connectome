# Disconnectome paper — manuscript skeleton

**Purpose:** section-by-section writing template with word-count budgets. Fill
in as writing progresses. Choose the appropriate framing (methods-lead /
biology-lead / default) based on the venue-decision rule in
[disconnectome_paper_analysis_plan.md § 10](analysis_plan.md#10-venue-decision-rule).

**Related:** [disconnectome_paper.md](index.md) ·
[journal_tier.md — per-venue detailed breakdowns](../journal_tier.md)

**Status:** BLANK skeleton (fill as writing progresses).

---

## Title

**Working title (methods-lead / NeuroImage):**
> Patient-specific lesion-aware disconnectomes in traumatic brain injury: a head-to-head comparison with normative-atlas approaches and consequences for network-level outcome prediction.

**Working title (biology-lead / Brain):**
> Structural disconnection mediates functional network dysfunction and predicts cognitive recovery after traumatic brain injury.

**Working title (HBM default):**
> Lesion-aware structural disconnection and outcome after traumatic brain injury: a disconnectome study.

**Locked title:** ______________________________

---

## Abstract (~250 words)

**Structure (all three framings):**

- Background (60–80 words): what problem, what's the current state (Griffis 2019 in stroke; LQT/BCB normative approach; TBI gap)
- Methods (50–70 words): cohort, imaging arms, SDC computation, FC/behavior outcomes
- Results (60–80 words): quantitative primary finding(s) with effect sizes and cross-validated statistics
- Interpretation (40–60 words): what this changes about the field / clinical practice

**Framing-specific opening line:**

- NeuroImage: "Structural disconnection (SDC) is central to modeling network dysfunction after focal brain lesions, but the two dominant SDC pipelines — LQT and BCBtoolkit — assume patient anatomy conforms to a healthy normative template, an assumption strained in traumatic brain injury."
- Brain: "Focal traumatic brain injury (TBI) produces cognitive and functional deficits that often exceed local damage; whether the Griffis-2019 structural-disconnection framework, which explained widespread network dysfunction in stroke, generalizes to TBI is unknown."
- HBM: "Structural disconnection has emerged as a key mediator between focal brain lesions and network-level dysfunction; we characterize its prognostic and mechanistic value in a moderate-cohort traumatic brain injury sample."

---

## Introduction (word budget: 1000 methods / 1200 biology / 800 HBM)

**Prior work map (fill from):** [prior_work_novelty.md](prior_work_novelty.md) §2–§8.

**Suggested paragraph structure:**

1. **Clinical framing** — TBI burden, focal-lesion subset, network-dysfunction problem
2. **Griffis 2019 SDC → FC → behavior chain** — one paragraph summary, citing Corbetta 2015 for behavior
3. **Current tools and their limits** — LQT / BCBtoolkit / NeMo overview; anatomy-template assumption
4. **TBI vs stroke** — why the anatomy-template assumption is strained in TBI (mass effect, oedema, bilateral)
5. **Our contribution** — one-sentence core claim (framing-dependent) + list of specific advances
6. **Predictions and organization** — what we test, in what order

**Anchor citations by paragraph:**

- Paragraph 1: Palacios 2022, general TBI burden refs
- Paragraph 2: **Griffis 2019** (primary), Corbetta 2015 (behavior), Salvalaggio 2020 (extension)
- Paragraph 3: Griffis 2021 (LQT), Foulon 2018 (BCBtoolkit), Kuceyeski 2013 (NeMo)
- Paragraph 4: Warren 2015 (TBI graph metrics), general TBI heterogeneity refs
- Paragraph 5: (framing-dependent) Radwan 2023 (patient-specific TBI precedent), Bey 2024 (LeAPP ancestor)
- Paragraph 6: (self-referential)

**Length:** _____________ (fill as written)

---

## Methods (word budget: ~2500)

Sections in order:

1. **Cohort** (~300 words) — TrackTBI subset, inclusion / exclusion, N, demographics summary
2. **Imaging acquisition** (~250 words) — T1w, DWI (b-value, directions), rs-fMRI (TR, TE, duration, sessions)
3. **Preprocessing** (~350 words) — QSIPrep for DWI; FastSurfer + FreeSurfer for anatomy; lesion mask registration; SDC pipeline (5ttedit -path, iFOD2, SIFT2, DKT parcellation); disconnection Options A/B/C
4. **Normative-atlas SDC comparators** (~300 words) — LQT (Griffis 2021) parameter choices; BCBtoolkit (Foulon 2018) parameter choices; MNI normalization procedure
5. **rs-fMRI processing** (~300 words, if applicable) — fMRIPrep + XCP-D, atlas parcellation, connectivity matrix construction, motion QC
6. **Behavioral outcomes** (~200 words) — GOSE administration, neuropsych battery, factor construction, missing-data handling
7. **Statistical models** (~500 words) — baseline regression, incremental-validity nested comparison, CCA (if biology framing), cross-validation, permutation testing, multiple-comparison correction
8. **Software and reproducibility** (~200 words) — containers, DAG, provenance JSON, code repo URL

**Length:** _____________ (fill as written)

---

## Results (word budget: 2000 methods / 2000 biology / 1600 HBM)

Figures and tables (framing-specific — pick per venue decision):

### Methods-lead (NeuroImage)

- **Figure 1** — pipeline schematic (patient-specific vs LQT vs BCB)
- **Figure 2** — representative subject: lesion + patient-specific SDC + LQT SDC + BCB disconnection map side by side
- **Figure 3** — cohort-wide SDC concordance distribution (violin per method-pair) + scatter vs lesion volume / mass-effect
- **Figure 4** — FC-prediction ΔR² per SDC method + per network
- **Figure 5** — GOSE-prediction ROC / AUC per SDC method with lesion-volume baseline
- **Table 1** — SDC divergence stratified by lesion location (frontal / temporal / parietal / occipital / bilateral)
- **Table 2** — nested model comparison (baseline / +SDC / +SDC+FC) with cross-validated statistics

### Biology-lead (Brain)

- **Figure 1** — group-average disconnectome in MNI space (face validity)
- **Figure 2** — CCA first component: SDC loadings + FC loadings + subject-score scatter
- **Figure 3** — domain-specific network → cognitive-composite scatter grid (5 panels)
- **Figure 4** — GOSE prediction: baseline vs +SDC vs +SDC+FC ROC curves
- **Figure 5** — representative case series (mild / moderate / severe) with lesion + SDC + FC-abnormality + outcome
- **Table 1** — cohort demographics + clinical severity
- **Table 2** — nested model comparison
- **Table 3** — domain-network mapping table

### HBM default

- **Figure 1** — group-average disconnectome (from biology) or pipeline schematic (from methods)
- **Figure 2** — SC → outcome scatter or head-to-head divergence
- **Figure 3** — domain-specific or by-arm robustness
- **Figure 4** — representative case
- **Table 1** — demographics
- **Table 2** — model comparison

**Length:** _____________ (fill as written)

---

## Discussion (word budget: 1500 methods / 1800 biology / 1200 HBM)

Suggested paragraph structure:

1. **Restate primary finding** with effect size
2. **Comparison with Griffis 2019** — where the pattern generalizes from stroke to TBI; where it differs
3. **Comparison with Salvalaggio 2020** — SC + FC combined modeling replication or contrast
4. **Comparison with LQT / BCB normative-atlas approach** — where they agree, where they diverge, when to use each
5. **Clinical implications** — prognostic biomarker use case; who benefits most from patient-specific processing
6. **Limitations** — single-cohort, single-site (unless multisite), N, no external replication
7. **Future directions** — replication cohort; expansion to Deep Atropos; longitudinal; synthetic-MRI for CT-only

**Length:** _____________ (fill as written)

---

## Data and code availability

- BIDS derivatives: ______ (Zenodo / OSF / institutional repo)
- Containers: GHCR — `ghcr.io/phindagijimana/dkt-connectome`; DockerHub — `phindagijimana/dkt-connectome`; digest table in supplement
- Code repo: [https://github.com/phindagijimana/dkt_connectome](https://github.com/phindagijimana/dkt_connectome) at tag ______
- Analysis code (regression, CCA): repo `paper2/` subdir at tag ______

## Author contributions

| Author | Contribution |
|--------|--------------|
| Phind Ndagijimana | Pipeline development, data processing, analysis, drafting |
| PI | Study conception, cohort access, clinical interpretation, revisions |
| ... | ... |

## Acknowledgements

Compute: URMC HPC (smdodwork01–05); TrackTBI investigators; data-contributing sites.

Funding: ______

## Supplement

- **S1** — fMRI preprocessing details (fMRIPrep version, XCP-D pipeline, motion QC per subject)
- **S2** — LQT and BCBtoolkit parameter tables
- **S3** — Alternative-parcellation robustness (DKT vs Schaefer 200 vs 4S 156)
- **S4** — Alternative fixed-arm robustness (`vbt-lesion`)
- **S5** — Provenance JSON schema example + container digest table
- **S6** — Complete-case cohort assembly diagram (CONSORT-style)
- **S7** — Analysis plan pre-registration doc (from `disconnectome_paper_analysis_plan.md` at sign-off)

---

## Reference list

Managed in Zotero / Mendeley / manual. Anchor references (see
[disconnectome_paper.md § Cross-tier paper-citation matrix](index.md#cross-tier-paper-citation-matrix)):

- Griffis 2019 *Cell Reports*
- Griffis 2021 *NeuroImage: Clinical*
- Salvalaggio 2020 *Brain*
- Talozzi 2023 *Brain*
- Foulon 2018 *GigaScience*
- Kuceyeski 2013 *Brain Connectivity*
- Kuceyeski 2020 *Human Brain Mapping*
- Corbetta 2015 *Neuron*
- Palacios 2022 *Journal of Neurotrauma*
- Warren 2015 *Brain*
- Bey 2024 *Human Brain Mapping*
- Boes 2015 *Brain* (if biology / stretch)
- Fox 2018 *NEJM* (if biology / stretch)
- Osmanlıoğlu 2022 *Human Brain Mapping* (backup)
- Radwan 2023 *Network Neuroscience* (methods lineage)
- Yeh 2018 *NeuroImage* (methods, HCP-842)
- Pipeline citations: MRtrix, QSIPrep, QSIRecon, FastSurfer, FreeSurfer (see `../references.md`)
