# Factorial paper — manuscript skeleton

**Purpose:** section-by-section writing template with word-count budgets for
the factorial paper (Paper 1). Fill in as writing progresses.

**Related:** [index.md](index.md) · [analysis_plan.md](analysis_plan.md) ·
[../journal_tier.md](../journal_tier.md)

**Status:** BLANK skeleton (fill as writing progresses).

---

## Title

**Working title (HBM default):**
> Lesion-aware structural connectomics in traumatic brain injury: a factorial comparison of inpainting, virtual brain transplant, and pathology-informed tractography

**Working title (NeuroImage stretch — with synthetic-lesion validation):**
> A 3×2 factorial of anatomical mitigation and lesion-aware tractography for structural connectomics in traumatic brain injury, with synthetic-lesion validation

**Locked title:** ______________________________

---

## Abstract (~250 words)

**Structure:**

- Background (60–80 words): TBI-connectome problem; how anatomy handling and lesion-aware ACT are current knobs; LeAPP's stroke precedent
- Methods (50–70 words): cohort, six arms (2×3 factorial), primary numeric outcome, contrast set
- Results (60–80 words): completion rates by arm; effect sizes for primary and interaction contrasts
- Interpretation (40–60 words): which choices matter more, in what direction, and clinical / research implications

**Opening line (default HBM version):**
> Focal traumatic brain injury lesions distort the assumptions of standard connectome pipelines; two independent decisions — how to correct anatomy before recon (inpainting or virtual brain transplant) and whether to insert the lesion into the tractography pathology channel — can each change the resulting connectome, but their relative importance and their interaction in TBI are unknown.

**Opening line (NeuroImage stretch version):**
> ...same as above + "We evaluate a six-arm factorial across ~100 TrackTBI lesion subjects and validate with synthetic lesions injected on healthy controls (LeAPP-style)."

---

## Introduction (word budget: ~1200)

**Prior work map (fill from):** [prior_work_novelty.md](prior_work_novelty.md) §2–§6.

**Suggested paragraph structure:**

1. Clinical framing — TBI burden, focal-lesion subset (~2M TBIs/yr US, focal-lesion subset with imaging characterizable)
2. Standard connectome pipelines and where they break for focal lesions — registration, segmentation, tractography priors
3. LeAPP framework (Bey et al. 2024) — two independent axes: anatomy mitigation (VBT) × lesion-aware ACT
4. Extending from stroke to TBI — why TBI's heterogeneous morphology matters (mass effect, oedema, bilateral)
5. Our contribution — first cohort-scale 3×2 factorial in TBI adding neuroLIT (Pollak et al. 2025) as a third anatomy backend
6. Predictions and organization

**Anchor citations by paragraph:**

- Paragraph 1: Palacios 2022 (TBI cohort scale), general TBI epidemiology
- Paragraph 2: Warren 2015 (TBI connectome issues), general connectome methodology
- Paragraph 3: **Bey 2024** (LeAPP), Radwan 2020 (VBG lineage)
- Paragraph 4: Radwan 2023 (TBI + VBG + ACT small-N precedent)
- Paragraph 5: Pollak 2025 (neuroLIT), Smith 2012 (ACT foundation), Cieslak 2021 (QSIPrep)
- Paragraph 6: (self-referential)

**Length:** _____________ (fill as written)

---

## Methods (word budget: ~2500)

Sections in order:

1. **Cohort** (~300 words) — TrackTBI subset with lesion masks, inclusion / exclusion, N, demographics
2. **Imaging acquisition** (~200 words) — T1w, DWI (b-value, directions, TR/TE), site distribution if multisite
3. **Preprocessing** (~200 words) — QSIPrep, FastSurfer + FreeSurfer, ACPC registration workflow
4. **Anatomy mitigation** (~350 words) — Step 1.1 for neuroLIT (DDPM-based Pollak 2025) and VBT (Bey 2024 port, `run_vbt.py`); orig baseline
5. **Tractography** (~400 words) — QSIRecon MRtrix3, HSVS 5TT, `5ttedit -path` for `*-lesion` arms, iFOD2 + SIFT2 weighting
6. **Connectome construction** (~250 words) — DKT parcellation, SIFT2-weighted matrices per arm, per-arm output isolation
7. **Statistical framework** (~500 words) — primary numeric outcome definition, pre-specified contrasts, within-subject paired tests, interaction ANOVA, multiple-comparison correction
8. **QC and completion tracking** (~150 words) — per-subject-arm QC gate, completion matrix
9. **Software and reproducibility** (~200 words) — containers, DAG, provenance JSON, code and container URLs
10. **Synthetic-lesion validation** (if NeuroImage stretch, ~200 words) — CIDUR controls, lesion injection protocol, recovery metric

**Length:** _____________ (fill as written)

---

## Results (word budget: ~2000)

### Figures and tables

- **Figure 1** — pipeline schematic showing six arms + Deep Atropos supplement branch + ACPC lesion warp workflow
- **Figure 2** — cohort QC by arm: completion rate, pathology QA pass rate, streamline counts per arm (bar/violin)
- **Figure 3** — factorial sensitivity: distributions of connectome change across arms; heatmap of contrasts
- **Figure 4** — representative cases (3 subjects: unilateral / bilateral / large): lesion + pathology channel + tractography overlays across arms
- **Figure 5** — anatomy × ACT interaction plot (or forest plot of contrast effect sizes)
- **Figure 6** — optional: synthetic-lesion recovery on CIDUR (NeuroImage stretch only) — recovered vs expected connectivity loss
- **Table 1** — cohort demographics + clinical severity distribution
- **Table 2** — completion by arm (RQ4 primary result)
- **Table 3** — pre-specified contrasts with effect sizes, p-values, and multiple-comparison adjustments

### Suggested result narrative

- Cohort characteristics
- Completion by arm (RQ4)
- Primary contrast: `*-std` vs `*-lesion` within each anatomy (RQ1)
- Secondary contrast: anatomy comparisons (RQ2)
- Interaction contrast (RQ3)
- Synthetic-lesion validation if run (RQ5)

**Length:** _____________ (fill as written)

---

## Discussion (word budget: ~1800)

Suggested paragraph structure:

1. Restate primary findings with effect sizes
2. Interpret: which axis matters more (anatomy vs ACT); by how much; in which subgroups
3. Comparison with LeAPP stroke results — what generalizes, what differs, why TBI is different
4. Practical implications for future TBI connectome studies — which arm as default
5. Limitations: single cohort, no external replication, N constrained by lesion-mask availability, cohort heterogeneity
6. Future directions: longitudinal (Paper 4), disconnection-outcomes (Paper 2), Deep Atropos supplement (Paper 3 material)

**Length:** _____________ (fill as written)

---

## Data and code availability

- BIDS derivatives: ______
- Containers: GHCR — `ghcr.io/phindagijimana/dkt-connectome` (and dkt-lesion-act, dkt-vbt, dkt-neurolit); DockerHub — `phindagijimana/dkt-connectome`
- Code repo: [https://github.com/phindagijimana/dkt_connectome](https://github.com/phindagijimana/dkt_connectome) at tag ______
- Analysis code: repo `paper1/` subdir at tag ______

## Author contributions

| Author | Contribution |
|--------|--------------|
| Phind Ndagijimana | Pipeline development, cohort processing, analysis, drafting |
| PI | Study conception, cohort access, interpretation, revisions |
| ... | ... |

## Acknowledgements

Compute: URMC HPC. TrackTBI investigators. Data-contributing sites.

Funding: ______

## Supplement

- **S1** — per-subject / per-arm completion matrix
- **S2** — QC dashboards (sample screenshots)
- **S3** — sensitivity: Schaefer 200 alternative parcellation
- **S4** — sensitivity: Deep Atropos vs HSVS 5TT (Paper 3 supplement material)
- **S5** — sensitivity: bilateral-lesion subgroup
- **S6** — provenance JSON schema example + container digest table
- **S7** — analysis-plan pre-registration (from `analysis_plan.md` at sign-off)
- **S8** — synthetic-lesion validation details (if NeuroImage stretch)

**Figures: 5–6 main + 5–8 supplement.**
**Tables: 3 main + 2 supplement.**

---

## Reference list

Managed in Zotero / Mendeley / manual. Anchor references (see
[`index.md § Cross-tier paper-citation matrix`](index.md#cross-tier-paper-citation-matrix)):

- **Bey 2024** (LeAPP) — *Human Brain Mapping* [10.1002/hbm.26701](https://doi.org/10.1002/hbm.26701)
- **Radwan 2020** (Virtual Brain Grafting / VBG) — *Human Brain Mapping*
- **Radwan 2023** — TBI + VBG + ACT — *Network Neuroscience* [10.1162/netn_a_00277](https://doi.org/10.1162/netn_a_00277)
- **Smith 2012** — ACT foundation — *NeuroImage*
- **Pollak 2025** — neuroLIT DDPM inpainting — *Imaging Neuroscience* [10.1162/imag_a_00446](https://doi.org/10.1162/imag_a_00446)
- **Palacios 2022** — TRACK-TBI multisite DTI — *Journal of Neurotrauma* [10.1089/neu.2022.0070](https://doi.org/10.1089/neu.2022.0070)
- **Warren 2015** — TBI graph metrics → cognition — *Brain* [10.1093/brain/awv075](https://doi.org/10.1093/brain/awv075)
- **Cieslak 2021** — QSIPrep
- **Tournier 2019** — MRtrix3
- **Fischl 2012** — FreeSurfer
- **Henschel 2020** — FastSurfer
- **Andersson & Sotiropoulos 2016** — FSL EDDY
- **Yeh 2018** — HCP-842 tractogram (if using LQT as sensitivity)
