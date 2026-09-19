# Factorial paper — what's missing to reach submission

**Purpose:** consolidated readiness checklist for the factorial paper (Paper 1).
Tracks what needs to happen between the current state (pipeline built,
pilot complete, planning docs mature) and a submitted manuscript.

**Related docs:** [index.md](index.md) · [analysis_plan.md](analysis_plan.md) ·
[completion_tracker.md](completion_tracker.md) · [manuscript_skeleton.md](manuscript_skeleton.md) ·
[differentiation_from_leapp.md](differentiation_from_leapp.md) ·
[neuroimage_prerequisites.md](neuroimage_prerequisites.md)

**Status as of 2026-09-18:** planning docs mature; N=1 pilot processed;
cohort scaling not started.

---

## Current readiness snapshot

| Category | Ready | Partial | Not started |
|----------|:-----:|:-------:|:-----------:|
| Pipeline (SC, all 6 arms) | ✅ | | |
| Reproducibility infrastructure (containers, provenance JSON) | ✅ | | |
| Planning docs (index, analysis plan, skeleton, tracker, LeAPP lineage) | ✅ | | |
| Pilot processing (sub-TBI011011 × 7 arms) | ✅ | | |
| Cohort BIDS + lesion masks | | ⚠️ (subject 2 in BIDS, none processed yet) | |
| Full-cohort processing | | | ❌ |
| Analysis plan sign-off | | ⚠️ (template ready, not signed) | |
| Analysis code | | | ❌ |
| Cohort completion / QC-by-arm table | | | ❌ |
| Figures + tables | | | ❌ |
| Manuscript draft | | | ❌ |
| Coauthor list + contributions | | | ❌ |
| Cover letter | | | ❌ |
| Data availability plan | | ⚠️ (concept) | |

---

## Blockers — must have before submission

### Data

- [ ] **Cohort identified** — ~100 TrackTBI subjects with clinician-traced lesion masks (currently N=2 in BIDS: TBI011011, TBI011204)
- [ ] **BIDS conversion completed** for the full lesion-mask cohort
- [ ] **Basic BIDS QC pass** per subject (T1w + DWI presence, orientation, geometry)
- [ ] **Lesion mask availability audit** — which subjects have clinician-traced masks vs need retracing / auto-segmentation

### Processing

- [ ] **Six-arm factorial processed on the cohort** — `orig-std`, `orig-lesion`, `neurolit-std`, `neurolit-lesion`, `vbt-std`, `vbt-lesion` with per-arm output isolation under `RESULTS_ROOT/arms/<arm>/`
- [ ] **Container digests recorded** per subject-arm for reproducibility supplement
- [ ] **Per-arm completion tracking** — populate [`completion_tracker.md`](completion_tracker.md) with real data
- [ ] **Per-arm QC pass criteria applied** per subject (empty-node fraction, SIFT2 mu, pathology QA, marker files)

### Analysis planning

- [ ] **`analysis_plan.md` locked** — all 13 sections signed off before opening group results
- [ ] **Primary numeric outcome chosen** (mean abs edge diff / global correlation / PC1)
- [ ] **Primary parcellation chosen** (DKT default; Schaefer 200 sensitivity if Tier 2 addition included)
- [ ] **Statistical framework locked** (within-subject test type, multiple-comparison correction)
- [ ] **Completion-N threshold locked** per arm (default: N ≥ 40)

### Analysis execution

- [ ] **Analysis code repo/dir** — `analysis/paper1/` with scripts for:
  - Pre-specified contrast tests (`*-std` vs `*-lesion` within anatomy)
  - Secondary anatomy contrasts (orig vs neuroLIT vs VBT)
  - Anatomy × ACT interaction 2×3 ANOVA
  - Per-arm QC aggregation
  - Failure-mode diagnosis (which subject-arm failed, why)
- [ ] **QC-by-arm table generated** — RQ4 primary result

### Manuscript

- [ ] **Section-by-section draft** — flesh out [`manuscript_skeleton.md`](manuscript_skeleton.md) template
- [ ] **Figure 1 — pipeline schematic** (6 arms + optional supplement branches)
- [ ] **Figure 2 — cohort QC by arm** (completion rates, streamline counts, empty nodes)
- [ ] **Figure 3 — factorial sensitivity distributions** (violin plots of connectome change per contrast)
- [ ] **Figure 4 — representative cases** (3 subjects: unilateral / bilateral / large lesion)
- [ ] **Figure 5 — anatomy × ACT interaction plot** (or forest plot of contrast effect sizes)
- [ ] **Table 1 — demographics** (age, sex, education, GCS, injury mechanism, lesion volume/location)
- [ ] **Table 2 — per-arm completion** (subject × arm matrix)
- [ ] **Table 3 — pre-specified contrasts** (effect sizes, p-values, adjusted)
- [ ] **Supplement figures** (Deep Atropos sensitivity, alternative parcellation, provenance schema, container digests)

### Administrative

- [ ] **Author list confirmed** — PI, analyst, coauthors, contributions per CRediT taxonomy
- [ ] **Data availability statement** — BIDS-Derivatives location + policy (Zenodo DOI target for release)
- [ ] **Code availability** — GitHub repo tagged for release; container digests
- [ ] **IRB / TRACK-TBI DUA compliance** verified for imaging data use
- [ ] **Cover letter** — highlights (TBI extension of LeAPP, neuroLIT third arm, cohort scale, reproducibility infra)
- [ ] **Reference list** — Zotero / Mendeley library assembled with all analog + methods citations

---

## Should have (for the HBM default target tier)

- [ ] **Bilateral-lesion subgroup analysis** as first-class result (not buried in supplement) — TBI-specific finding LeAPP could not produce
- [ ] **Deep Atropos vs HSVS 5TT sensitivity** on cohort subset (N ≥ 30 if feasible; falls back to pilot-only)
- [ ] **Container digest table** in supplement (SHA per SIF at cohort-processing time)
- [ ] **Failure-mode analysis** — per-arm failure characterization if any arm underperforms (VBT-bilateral, midtrans crashes, neuroLIT out-of-distribution)
- [ ] **Two coauthor rounds** internally before submission
- [ ] **Statistical review** — someone independent to verify statistical framework choices

---

## Stretch (for NeuroImage tier)

Each item raises the ceiling from HBM → NeuroImage. Costs vary; see
[`differentiation_from_leapp.md`](differentiation_from_leapp.md) for detailed
effort estimates and marginal-value analysis.

- [ ] **Synthetic-lesion validation on CIDUR controls** (Tier B — LeAPP-parity) — 4 wks; single biggest ceiling-lift
- [ ] **Cross-parcellation robustness suite** (Schaefer 200 + 4S 156 alongside DKT) — 1 wk compute
- [ ] **Edge-level uncertainty quantification** via bootstrap tractography seeds — 2 wks
- [ ] **Test-retest reliability** on repeat-scan subjects if any — free if data exists
- [ ] **Lesion-topology → arm-recommendation decision tree** — 1-2 wks post-hoc; high marginal value
- [ ] **Multi-measure connectome consistency** (count + SIFT2 + length + FA + MD) — analysis-only
- [ ] **Cross-site harmonization** (ComBat or site regressors) — analysis-only
- [ ] **Prospective preregistration** on OSF / AsPredicted — 1 day
- [ ] **Deep Atropos as full third factorial axis** (3×2×2 = 12 arms) — 2× compute, scope-expanding

---

## Timeline placeholder

Fill in dates as milestones are reached. Firewall = "group results opened"
per analysis plan § 11.

| Milestone | Target date | Actual date | Owner |
|-----------|-------------|-------------|-------|
| Cohort BIDS conversion complete | | | |
| Lesion mask availability audit | | | |
| Cohort processing begins | | | |
| Cohort processing complete | | | |
| Completion/QC-by-arm table complete | | | |
| Analysis plan sign-off | | | (firewall #1) |
| Group results opened | | | (firewall #2 — no plan changes after) |
| First manuscript draft | | | |
| Coauthor round 1 | | | |
| Coauthor round 2 | | | |
| Submission (HBM default) | | | |

---

## Dependencies flowchart

```
Cohort BIDS + lesion masks
    │
    ▼
Per-subject 6-arm processing
    │
    ├─► Container digests recorded ──────────────┐
    │                                            │
    ▼                                            │
Per-arm QC pass                                  │
    │                                            │
    ▼                                            │
Cohort completion / QC-by-arm table              │
    │                                            │
    ▼                                            │
Analysis plan sign-off ────────► FIREWALL 1     │
    │                                            │
    ▼                                            │
Group-level factorial analyses                   │
    │                                            │
    ▼                                            │
Effect sizes + significance ──► FIREWALL 2      │
                                (venue decision)  │
    │                                            │
    ▼                                            │
Figures + tables ◄───────────────────────────────┘
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
| Cohort N < 40 per arm | Report as failure-mode analysis; consider dropping low-N arm from primary; fall back to NeuroImage: Reports |
| VBT systematic failures on bilateral cases | Document as first-class finding; validate as TBI-specific limitation of LeAPP's method |
| **VBT `midtrans` SIGSEGV on radiological-convention T1w** | ✅ **Fixed and validated end-to-end** (2026-09-19) — `fslreorient2std` preprocessing added to `run_vbt.py`; full 14-step Snakemake DAG completed on TBI011011 ses-2WK for both `vbt-lesion` (job 76167, 6h 47m) and `vbt-std` (job 76168, 5h 05m), each producing a 78×78 DKT connectome with 0 empty nodes and `subject_qc.json: PASS`. Deployed via `VBT_BIND_DEV=1` bind-mount pending container rebuild. See [`vbt_orientation_finding.md`](vbt_orientation_finding.md) for the finding, fix, validation table, and suggested manuscript treatment |
| neuroLIT out-of-distribution behavior | Sensitivity analysis in supplement; may motivate future retraining |
| Deep Atropos supplement N insufficient | Fold into pilot-only qualitative supplement |
| Reviewer perceives paper as "just LeAPP re-run on TBI" | Foreground bilateral handling + neuroLIT + reproducibility infrastructure in intro |
| Cross-site heterogeneity confounds arm effects | Cross-site harmonization (Tier 2 addition) |

---

## See also

- [`index.md`](index.md) — cover doc + cross-tier paper matrix
- [`analysis_plan.md`](analysis_plan.md) — 13-section pre-registration template
- [`completion_tracker.md`](completion_tracker.md) — per-subject × per-arm tracker
- [`manuscript_skeleton.md`](manuscript_skeleton.md) — writing template
- [`differentiation_from_leapp.md`](differentiation_from_leapp.md) — ranked additions menu
- [`leapp_lineage.md`](leapp_lineage.md) — LeAPP + lineage deep summary
- [`neuroimage_prerequisites.md`](neuroimage_prerequisites.md) — three gates for NeuroImage tier
- [`../distance_novelty.md`](../distance_novelty.md) — contribution framework and consolidated list
