# Paper 2B — readiness checklist

**As-of:** 2026-10-07

**Related:** [index.md](index.md) · [../disconnectome/disconnectome_missing.md](../disconnectome/disconnectome_missing.md)

---

## Snapshot

| Category | Ready | Partial | Missing |
|----------|:-----:|:-------:|:---------:|
| Patient-specific SDC pipeline | ✅ | | |
| fMRI Arm B (dual stream) | ✅ | ⚠️ DKT BOLD fallback | |
| 7-subject pilot | ✅ | | |
| Analysis scripts (`analysis/paper2b/`) | ✅ | | |
| **LQT batch** | | | ❌ |
| BCB (optional) | | | ❌ |
| Imaging cohort N ≥ 40 | | | ❌ |
| Analysis plan sign-off | | ⚠️ | |
| Manuscript draft | | | ❌ |

**No external clinical export required** for 2B primary analyses.

---

## Must have before submission

### Imaging & comparators

- [ ] **LQT installed** and run per imaging complete-case subject
- [ ] **LQT → DKT-78 alignment** documented (same node order as patient-specific)
- [ ] **Cohort N** ≥ locked threshold in [analysis_plan.md](analysis_plan.md) §8
- [ ] **Primary SC↔FC metric** locked (§6.2)
- [ ] **BOLD provenance** table in supplement (XCP-D T1w denoised vs fallback)

### Analysis

- [ ] [analysis_plan.md](analysis_plan.md) signed
- [ ] `run_paper2b_analysis.sh` run on full imaging cohort
- [ ] [imaging_cohort_tracker.md](imaging_cohort_tracker.md) filled

### Manuscript

- [ ] [manuscript_skeleton.md](manuscript_skeleton.md) drafted
- [ ] Figures 1–5 per skeleton
- [ ] Code + container availability statement

---

## Pilot done (2026-10-07)

- [x] 7 × 2WK neurolit DWI disconnectome
- [x] 7 × 2WK fMRI Arm B (xcp + fmristroke)
- [x] Exploratory coupling (`run_pilot_fc_analysis.sh` → can mirror under `analysis/paper2b/`)

---

## Risks

| Risk | Mitigation |
|------|------------|
| LQT ≈ patient-specific everywhere | Publish negative methods; subset where they differ |
| SC↔FC weak at edge level | Emphasize RQ1; frame RQ3 as exploratory until N grows |
| Overlap with Paper 2 | 2B = no outcomes; Paper 2 adds GOSE as separate sign-off |
