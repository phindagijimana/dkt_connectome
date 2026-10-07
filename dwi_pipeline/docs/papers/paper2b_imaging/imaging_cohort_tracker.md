# Paper 2B — imaging cohort tracker

**Purpose:** complete-case assembly for **imaging-only** analyses (no GOSE columns).
Mirror to CSV: `analysis/paper2b/imaging_cohort.tsv` when populated.

**Related:** [analysis_plan.md](analysis_plan.md) §8

---

## Assembly diagram

```text
Subjects with BIDS lesion ROI          N = ______
        │
        │ DWI + T1w at ses-2WK
        ▼
neurolit-lesion disconnectome done     N = ______
        │
        │ rs-fMRI + fMRI pipeline Arm B
        ▼
Imaging complete (Arm A + Arm B)       N = ______
        │
        │ LQT (± BCB) on same visit
        ▼
Methods complete-case (2B primary)     N = ______
```

---

## Tracker table (populate)

| sub | ses | lesion_roi | disc_matrix | lqt_matrix | arm_b_xcp | arm_b_fms | mean_fd | lesion_vol_mm3 | ps_vs_lqt_r | sc_fc_r_ps | sc_fc_r_lqt | notes |
|-----|-----|------------|-------------|------------|-----------|-----------|---------|----------------|-------------|------------|-------------|-------|
| TBI011011 | 2WK | ✅ | ✅ | ⏳ | ✅ | ✅ | | ~18223 | | | | pilot |
| TBI011007 | 2WK | ✅ | ✅ | ⏳ | ✅ | ✅ | | | | | | pilot |
| TBI011021 | 2WK | ✅ | ✅ | ⏳ | ✅ | ✅ | | | | | | pilot |
| TBI011029 | 2WK | ✅ | ✅ | ⏳ | ✅ | ✅ | | | | | | pilot |
| TBI011140 | 2WK | ✅ | ✅ | ⏳ | ✅ | ✅ | | | | | | pilot |
| TBI011204 | 2WK | ✅ | ✅ | ⏳ | ✅ | ✅ | | | | | | pilot |
| TBI021030 | 2WK | ✅ | ✅ | ⏳ | ✅ | ✅ | | | | | | pilot |

**Column definitions:**

- **disc_matrix** — `disconnectome/disconnection_matrix.csv` passes integrity QC
- **lqt_matrix** — LQT output resampled/aligned to DKT-78
- **arm_b_xcp / arm_b_fms** — stage 5 / 5b CSV present
- **ps_vs_lqt_r** — from `compare_sdc_methods.py`
- **sc_fc_r_ps / sc_fc_r_lqt** — edge-vector Pearson vs Arm B (xcp stream)

---

## Pilot seed (2026-10-07)

Seven-subject neurolit-inpaint list matches `fMRI_pipeline/scripts/submit_pilot.slurm` (7 × 2WK).
