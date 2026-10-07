# Paper 2B — analysis plan (pre-registration template)

**Purpose:** locked imaging-only design. **No clinical outcomes.** Sign before
opening cohort-level tests on RQ1–RQ3.

**Related:** [planning.md](planning.md) · [../disconnectome/analysis_plan.md](../disconnectome/analysis_plan.md) (Paper 2 — do not mix GOSE sections)

**Status:** DRAFT — not yet signed off.

---

## Sign-off block

| Person | Role | Date | Signature |
|--------|------|------|-----------|
| _____ | PI | ______ | ______ |
| _____ | Analyst | ______ | ______ |

**Amendments:**

| Date | Section | Change | Reason |
|------|---------|--------|--------|
| | | | |

---

## 1. Fixed DWI arm

- **Default:** `neurolit-lesion` under `validation_v030/arms/neurolit-lesion/connectomes/`
- **Locked:** ______

---

## 2. Fixed imaging visit

- **Default:** `ses-2WK` (DWI + rs-fMRI)
- **Locked:** ______

---

## 3. Structural disconnection (Arm A)

- **Source:** `sub-*/disconnectome/disconnection_matrix.csv` (78 × 78, comma-separated)
- **Document:** `disconnectome.json` → `disconnection_spared` option
- **Locked:** ______

---

## 4. Functional disconnection (Arm B)

- **Primary stream:** `xcp_d` → `.../arm-B_empirical_fc_disconnection/desc-empirical_fc_disconnection.csv`
- **Sensitivity stream:** `fmristroke` (same path under fmristroke tree)
- **Method:** D_ij = 1 − |FC_spare|/|FC_primary| on DKT-78 ([`fc_dkt78_align.py`](../../../../fMRI_pipeline/scripts/fc_dkt78_align.py))
- **BOLD provenance:** report `atlas-DKT_provenance.json` `bold_source_class` per subject
- **Locked:** ______

---

## 5. Normative comparators

| Tool | Output | Status |
|------|--------|--------|
| **LQT** | Parcel SDC matrix aligned to DKT-78 | Not run on cohort |
| **BCBtoolkit** | Voxel probability map → parcel aggregate (optional) | Not run |

- **MNI lesion prep:** document registration pipeline for LQT input
- **Locked comparator set:** ______ (LQT only / LQT+BCB)

---

## 6. Primary endpoints (no clinical)

### 6.1 RQ1 — SDC method agreement

- **Metric:** Pearson r on strict upper triangle between patient-specific D and LQT D (per subject)
- **Cohort summaries:** mean/median r, fraction with r < 0.7, r < 0.5
- **Locked thresholds:** same as Paper 2 [§9](../disconnectome/analysis_plan.md#9-head-to-head-sdc-comparison-methods-contribution) unless amended here: ______

### 6.2 RQ3 — SC ↔ FC coupling

- **Primary:** compare association strength **patient-specific SDC ↔ Arm B** vs **LQT SDC ↔ Arm B**
- **Methods (choose one primary, one sensitivity):**
  - **A:** Pearson r on paired upper-triangle edge vectors (per subject + Fisher-z average)
  - **B:** CCA first canonical correlation (subject-level stacked edges or summary features)
  - **C:** Cross-validated prediction R² (SC edges → FC edges), permutation test
- **Locked primary:** ______ (default: **A** for pilot; **C** for cohort)

### 6.3 Excluded endpoints

- GOSE, RPQ, neuropsych composites, ordinal outcome models

---

## 7. Covariates (imaging QC only)

Not regression covariates on behavior — used for **stratification / sensitivity**:

- Mean FD (fMRIPrep/XCP-D confounds)
- Lesion volume mm³ (`lesion_roi_metrics.csv`)
- Lesion labels (core/oedema)

---

## 8. Imaging complete-case N

| Rule | Action |
|------|--------|
| N ≥ 40 with LQT + Arm A + Arm B | Primary manuscript inference |
| N = 15–39 | Report with bootstrap / limitations |
| N < 15 | Pilot / methods note only |

**Locked:** ______

---

## 9. fMRI dual-stream policy

- **Primary inference:** XCP-D Arm B only
- **Sensitivity:** fMRIStroke Arm B; report agreement ([`compare_fc_streams.py`](../../../../fMRI_pipeline/scripts/compare_fc_streams.py))
- **Locked:** ______

---

## 10. Software outputs

All group summaries written to:

```text
$OUT_ROOT/analysis/paper2b/
```

Scripts: [`dwi_pipeline/analysis/paper2b/`](../../../analysis/paper2b/).

---

## 11. Venue rule (2B-specific)

1. **H1 supported** (meaningful LQT divergence in ≥25% subjects) **and H3 supported** (patient-specific SC↔FC > LQT) → lead *NeuroImage*
2. **H1 supported**, H3 weak → methods paper with honest SC↔FC null; *HBM* / *NI:Clinical*
3. **H1 null** (high LQT agreement) → publishable **negative methods**; emphasize when normative tools fail in subsets
4. Do **not** upgrade to Paper 2 outcome claims without new analysis plan sign-off

**Locked:** ______
