# Factorial paper — completion tracker

**Purpose:** per-subject × per-arm completion tracker for the factorial paper
(Paper 1). Populate as cohort processing progresses. Determines cohort N per
arm, which drives the group-analysis go/no-go per
[analysis_plan.md § 6](analysis_plan.md#6-completion-threshold-n-per-arm).

**Related:** [index.md](index.md) · [analysis_plan.md](analysis_plan.md)

**Status:** template — populate as cohort scales.

---

## Assembly diagram (CONSORT-style — to be filled)

```
TrackTBI subjects with lesion masks     ──────────────  N = ______
                       │
                       │ has T1w + DWI at ses-2WK (or chosen session)
                       ▼
       Subjects passing initial QC       ──────────────  N = ______
                       │
                       │ processed through all six arms
                       ▼
         Per-arm completion:
           orig-std        ──────────────  N = ______
           orig-lesion     ──────────────  N = ______
           neurolit-std    ──────────────  N = ______
           neurolit-lesion ──────────────  N = ______
           vbt-std         ──────────────  N = ______
           vbt-lesion      ──────────────  N = ______
                       │
                       │ passing QC gate per arm (per analysis_plan § 7)
                       ▼
         Per-arm QC-clean N:
           orig-std        ──────────────  N = ______
           orig-lesion     ──────────────  N = ______
           neurolit-std    ──────────────  N = ______
           neurolit-lesion ──────────────  N = ______
           vbt-std         ──────────────  N = ______
           vbt-lesion      ──────────────  N = ______
                       │
                       │ minimum arm N (per analysis_plan § 6, default 40)
                       ▼
       Group-analysis go/no-go gate     ──────────────  min N = ______
```

---

## Per-subject × per-arm completion matrix (populate)

Track completion at the *arm level* per subject. Cells are `✅` (complete + QC-pass),
`⚠️` (complete but QC-fail), `❌` (failed processing), or `⏳` (pending).

| sub | ses | orig-std | orig-lesion | neurolit-std | neurolit-lesion | vbt-std | vbt-lesion | Deep Atropos pilot (Paper 1 supp) |
|-----|-----|:--------:|:-----------:|:------------:|:---------------:|:-------:|:----------:|:---------------------------------:|
| TBI011011 | 2WK | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| TBI011204 | 2WK | ⏳ | ⏳ | ⏳ | ⏳ | ⏳ | ⏳ | ⏳ |
| ... | | | | | | | | |

### Columns explained

- **orig-std, orig-lesion:** original T1w anatomy; standard vs lesion-aware ACT
- **neurolit-std, neurolit-lesion:** neuroLIT-inpainted T1w; standard vs lesion-aware ACT
- **vbt-std, vbt-lesion:** VBT-transplanted T1w; standard vs lesion-aware ACT
- **Deep Atropos pilot:** optional supplement arm — run only on subset for Paper 3 supplement figure

---

## Per-subject × per-arm QC metric dashboard (populate)

For subjects marked complete, capture the key QC metrics used in analysis_plan.md § 7.

| sub | arm | qsiprep.done | qsirecon.done | lesion_aware_act.done | connectome_shape | empty_node_frac | sift2_mu | pathology_QA | overall_QC |
|-----|-----|:------------:|:-------------:|:---------------------:|:----------------:|:---------------:|:--------:|:------------:|:----------:|
| TBI011011 | orig-lesion | ✅ | n/a | ✅ | 78×78 | 0.00 | 0.42 | pass | ✅ |
| TBI011011 | neurolit-lesion | ✅ | n/a | ✅ | 78×78 | 0.00 | 0.41 | pass | ✅ |
| TBI011011 | vbt-lesion | ✅ | n/a | ✅ | 78×78 | 0.00 | 0.41 | pass | ✅ |
| ... | | | | | | | | | |

### QC gate summary

- ✅ overall_QC pass = all of: qsiprep.done + qsirecon.done (or lesion_aware_act.done) + connectome shape correct + empty_node_frac ≤ 0.05 + sift2_mu in reasonable range + pathology QA pass (for `*-lesion` arms).
- ⚠️ overall_QC review = one of the above fails but the arm technically completed — reviewer flag for inclusion decision.
- ❌ overall_QC fail = arm did not complete or connectome is unusable.

---

## Suggested CSV file (populate)

For programmatic use, mirror the per-subject-arm completion matrix to
`paper1_completion_matrix.csv`. Columns:

```
sub,ses,orig_std,orig_lesion,neurolit_std,neurolit_lesion,vbt_std,vbt_lesion,deep_atropos_pilot
```

And a companion QC-metrics CSV `paper1_qc_dashboard.csv`:

```
sub,arm,qsiprep_done,qsirecon_done,lesion_aware_act_done,connectome_shape,empty_node_frac,sift2_mu,pathology_QA,overall_QC
```

Both should live in the analysis-code repo under `paper1/data/` (git-ignore if
containing PHI; store in secure institutional storage instead).

---

## Group-analysis decision rule

Per [analysis_plan.md § 6](analysis_plan.md#6-completion-threshold-n-per-arm):

| Min QC-clean N across all 6 arms | Action |
|----------------------------------|--------|
| ≥ 80 | **Ideal cohort** — full 3×2 factorial with strong power → HBM solid; NeuroImage stretch feasible if synthetic-lesion validation also runs |
| 40–79 | **Acceptable cohort** — proceed with group analysis + report per-arm completion honestly → HBM default |
| < 40 in any arm | **Reduced cohort** — report as failure-mode analysis in Discussion; consider dropping the low-N arm from primary contrast → HBM with limitations |
| < 20 in ≥ 2 arms | **Fold into a smaller manuscript** — cannot support the flagship factorial claim → HBM sensitivity paper only, or NeuroImage: Reports backup |

---

## Governance

- **PHI:** subject IDs and per-subject metrics may qualify as PHI depending on institutional policy — git-ignore the CSVs if so.
- **Sharing:** aggregate statistics (per-arm completion, per-arm QC pass rate) go in Table 2 of the manuscript.
- **Data provenance:** for each row, source is `RESULTS_ROOT/arms/<arm>/.snakemake_markers/sub-<ID>/` + `qc/sub-<ID>/subject_qc.json` from `collect_subject_qc.py`.
