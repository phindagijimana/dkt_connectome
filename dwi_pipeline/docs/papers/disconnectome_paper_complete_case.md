# Disconnectome paper — complete-case tracking

**Purpose:** subject-level data-tracking template for Paper 2. Populate as
the TrackTBI clinical export arrives and as cohort processing completes.
Determines complete-case N, which drives the venue-decision rule per
[disconnectome_paper_analysis_plan.md § 8](disconnectome_paper_analysis_plan.md#8-complete-case-n-threshold).

**Related:** [disconnectome_paper.md](disconnectome_paper.md) ·
[disconnectome_paper_analysis_plan.md](disconnectome_paper_analysis_plan.md)

**Status:** template — populate with actual cohort as data becomes available.

---

## Assembly diagram (CONSORT-style — to be filled)

```
TrackTBI-Sub subjects with lesion masks  ────────────────  N = ______
                       │
                       │ has T1w + DWI + ses-2WK
                       ▼
       Subjects passing DWI + anat QC       ────────────  N = ______
                       │
                       │ ran neurolit-lesion arm to completion
                       ▼
       Subjects with completed connectome    ───────────  N = ______
                       │
                       │ has disconnection_matrix.csv (D > 0 confirmed)
                       ▼
       Subjects with computed disconnectome  ───────────  N = ______
                       │
                       │ has rs-fMRI at ses-2WK passing motion QC
                       ▼
       Subjects with usable rs-fMRI          ───────────  N = ______
                       │
                       │ has 6-month GOSE from clinical export
                       ▼
       Subjects with GOSE at 6mo             ───────────  N = ______
                       │
                       │ has neuropsych battery at 6mo
                       ▼
       Complete-case N for full-chain analyses  ────────  N = ______   ← primary N
                                                         (Brain / Neurology stretch tier gate)

Sub-cohort: GOSE + covariates only (no fMRI/neuropsych required)  N = ______
                                                         (J Neurotrauma / HBM tier gate)
```

---

## Complete-case spreadsheet (populate)

Columns for the working tracker. Rows added as data materializes.

| sub | ses | lesion_mask | neurolit_lesion_done | disc_matrix_valid | rs_fMRI_2WK | rs_fMRI_QC_pass | GOSE_2WK | GOSE_3MO | GOSE_6MO | RPQ_6MO | trailmaking_A | trailmaking_B | WAIS_PSI | CVLT_II | BVMT_R | COWA | age | sex | education | GCS_admission | lesion_vol_mm3 | site | mechanism |
|-----|-----|-------------|----------------------|-------------------|-------------|-----------------|----------|----------|----------|---------|---------------|---------------|----------|---------|--------|------|-----|-----|-----------|---------------|----------------|------|-----------|
| TBI011011 | 2WK | ✅ | 6-arm done | ✅ | ✅ | pending | ? | ? | ? | ? | ? | ? | ? | ? | ? | ? | ? | ? | ? | ? | ~18000 | URMC | ? |
| TBI011204 | 2WK | ? | pending | pending | ✅ | pending | ? | ? | ? | ? | ? | ? | ? | ? | ? | ? | ? | ? | ? | ? | ? | ? | ? | ? |
| ... | | | | | | | | | | | | | | | | | | | | | | | | |

**Column definitions:**

- **lesion_mask** — presence of clinician-traced `_label-lesion_roi.nii.gz` in BIDS
- **neurolit_lesion_done** — completed `neurolit-lesion` arm processing (marker files present at Steps 1.1 → 4.1)
- **disc_matrix_valid** — `disconnection_matrix.csv` exists and passes integrity QC (Options A/B/C consistent, D > 0 in expected regions)
- **rs_fMRI_2WK** — presence of `_task-rest_bold.nii.gz` in `func/`
- **rs_fMRI_QC_pass** — passed fMRIPrep + XCP-D QC (mean FD, spike censoring criteria)
- **GOSE_2WK / _3MO / _6MO** — Glasgow Outcome Scale-Extended at each visit
- **RPQ_6MO** — Rivermead Post-Concussion Questionnaire at 6mo
- **trailmaking_A / _B, WAIS_PSI, CVLT_II, BVMT_R, COWA** — individual neuropsych test scores (raw or standardized — decide in analysis plan)
- **age, sex, education, GCS_admission** — mandatory covariates per analysis plan § 4
- **lesion_vol_mm3** — from `lesion_roi_metrics.csv`
- **site** — TrackTBI-Sub site (for multisite harmonization)
- **mechanism** — MVA / fall / assault / sports / other (descriptive)

---

## Suggested CSV file (populate as data arrives)

For programmatic use, mirror this template to `paper2_complete_case.csv` in
the same folder (git-ignore if it contains PHI) or in the analysis-code repo
under `paper2/data/`.

CSV columns (identical to table above):

```
sub,ses,lesion_mask,neurolit_lesion_done,disc_matrix_valid,rs_fMRI_2WK,rs_fMRI_QC_pass,GOSE_2WK,GOSE_3MO,GOSE_6MO,RPQ_6MO,trailmaking_A,trailmaking_B,WAIS_PSI,CVLT_II,BVMT_R,COWA,age,sex,education,GCS_admission,lesion_vol_mm3,site,mechanism
```

---

## Complete-case decision rule

Once the spreadsheet is populated:

| Complete-case N (has all: lesion, DWI, disc_matrix, rs-fMRI, GOSE, neuropsych, covariates) | Action |
|------|--------|
| ≥ 60 | Full Griffis SC → FC → behavior chain feasible → **Brain / Neurology stretch tier** |
| ≥ 50 | Domain-specific network story feasible → **Brain / HBM in play** |
| ≥ 45 | Proceed with Paper 2 as designed → un-pause and lock analysis plan |
| 30–44 | Proceed with limitations framing (smaller-cohort caveats) |
| < 30 | Fold disconnectome results into Paper 1 as one supplementary figure; do not submit Paper 2 as standalone |

**Parallel decision — methods-lead sub-cohort (LQT/BCB head-to-head only):**

| Complete-case N (has lesion mask + DWI + disc_matrix + LQT run + BCB run) | Action |
|------|--------|
| ≥ 40 | Methods head-to-head feasible → NeuroImage tier gate open |
| < 40 | Fold methods comparison into biology-lead paper as supplement |

---

## Governance

- **PHI:** if this spreadsheet contains actual subject IDs and outcomes, git-ignore it and store in secure institutional storage.
- **Sharing:** aggregate statistics can be reported in the paper (Table 1 demographics) and in the CONSORT diagram; individual rows are not shared.
- **Data provenance:** for each cell, document the source (BIDS / clinical export CSV / pipeline output JSON) in a companion `provenance.md` if needed.
