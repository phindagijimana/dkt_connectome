# Paper 2B — imaging-only disconnectome (no clinical outcomes)

**Purpose:** canonical entry for the **imaging-mechanism / methods** manuscript
that does **not** require GOSE, neuropsych, or TRACK-TBI clinical export.

**Sibling papers:**

| Paper | Question | Clinical data |
|-------|----------|---------------|
| [**Paper 2 (full)**](../disconnectome/index.md) | SDC → FC → **behavior**; incremental validity | **Required** |
| **Paper 2B (this folder)** | Patient-specific vs **normative SDC**; **SC ↔ FC** alignment | **Not used** |

**As-of:** 2026-10-07 · **Status:** Active — pilot imaging complete (7 × 2WK); LQT/BCB + cohort N pending.

---

## Thesis

In focal TBI, **normative-atlas structural disconnection** (LQT, BCBtoolkit) and
**patient-specific lesion-aware SDC** (DWI tractography) are **not interchangeable**;
disagreement is **structured by lesion anatomy**, and **patient-specific SDC aligns
better with empirical resting-state functional disconnection** (DKT-78 Arm B) than
normative SDC — **without** claiming prognostic value on clinical outcomes.

---

## Documentation cluster

Each markdown file has a matching `.docx` (regenerate: `bash dwi_pipeline/analysis/paper2b/export_paper2b_docx.sh`).

| Doc | Role |
|-----|------|
| **[index.md](index.md)** / [index.docx](index.docx) | Cover + navigation |
| [planning.md](planning.md) | RQs, hypotheses, scope, venue targets |
| [analysis_plan.md](analysis_plan.md) | Pre-registration (imaging-only; sign-off block) |
| [prior_work_novelty.md](prior_work_novelty.md) | Prior-work map + evidence checklist |
| [manuscript_skeleton.md](manuscript_skeleton.md) | Section outline + figures/tables |
| [paper2b_abstract.md](paper2b_abstract.md) | Working abstract (honest, pre-results) |
| [imaging_cohort_tracker.md](imaging_cohort_tracker.md) | Per-subject imaging QC (no GOSE columns) |
| [readiness_missing.md](readiness_missing.md) | Submission checklist |
| [lqt_batch_notes.md](lqt_batch_notes.md) | LQT output convention + SLURM (RQ1 blocker) |

**Analysis code:** [`../../../analysis/paper2b/`](../../../analysis/paper2b/) (README + scripts).

**Pipeline ops:** DWI [`../../methods/step4_1_disconnectome.md`](../../methods/step4_1_disconnectome.md) · fMRI [`../../../../fMRI_pipeline/fmri_pipeline.md`](../../../../fMRI_pipeline/fmri_pipeline.md) · pilot QC [`../../../../fMRI_pipeline/scripts/run_pilot_fc_analysis.sh`](../../../../fMRI_pipeline/scripts/run_pilot_fc_analysis.sh).

---

## Target venues

| Venue | Fit |
|-------|-----|
| ***NeuroImage*** | Primary — methods head-to-head + quantitative FC downstream |
| ***Human Brain Mapping*** | Solid if N modest but methods + SC↔FC clear |
| ***NeuroImage: Clinical*** | TBI imaging focus; backup |

Not targeting *Brain* / outcome-led *J Neurotrauma* with this manuscript (see Paper 2).

---

## Cross-tier citations (methods-heavy)

| Paper | Role in 2B |
|-------|------------|
| Griffis 2021 LQT | **Comparator** |
| Foulon 2018 BCB | Second comparator |
| Griffis 2019 | SC↔FC template (Fig 2 analog — **no behavior arm**) |
| Bey 2024 LeAPP | Patient-specific SC pipeline precedent |
| Lamouroux 2024/25 fMRIStroke | fMRI sensitivity stream citation |
| Radwan 2023 TBI VBG+ACT | Small-N TBI patient-specific precedent |

Full maps: [prior_work_novelty.md](prior_work_novelty.md) · [../LQT.md](../LQT.md) · [../Griffis_later.md](../Griffis_later.md).

---

## Immediate next steps

1. Run **LQT** (± BCB) on pilot + cohort subset → [`analysis/paper2b/compare_sdc_methods.py`](../../../analysis/paper2b/compare_sdc_methods.py).
2. Scale **imaging cohort** (same lesion-mask inclusion as Paper 1 / 2).
3. **Lock** [analysis_plan.md](analysis_plan.md) before group-level inference.
4. Populate [imaging_cohort_tracker.md](imaging_cohort_tracker.md).
5. Execute [`run_paper2b_analysis.sh`](../../../analysis/paper2b/run_paper2b_analysis.sh) → `$OUT_ROOT/analysis/paper2b/`.

---

## See also

- [../index.md](../index.md) — papers workspace
- [../disconnectome/index.md](../disconnectome/index.md) — Paper 2 (full)
- [../publication_strategy.md](../publication_strategy.md) — portfolio
