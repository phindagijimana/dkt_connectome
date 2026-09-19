# Factorial paper — NeuroImage-tier prerequisites

**Purpose:** the three open items that determine whether Paper 1 can defensibly target *NeuroImage* rather than *Human Brain Mapping* (default). Each item is a gap to close before committing to the higher venue. Update state as items are resolved.

**Related:** [index.md](index.md) · [analysis_plan.md](analysis_plan.md) · [completion_tracker.md](completion_tracker.md) · [leapp_lineage.md](leapp_lineage.md)

**Status:** OPEN — none resolved as of 2026-09-17.

**Framing:** *HBM is the safe target; NeuroImage is a stretch upgrade contingent on all three items below being cleanly delivered.* The default venue reverts to HBM if any one item is unresolved at submission time. See [index.md § Contribution summary](index.md#contribution-summary) for the venue-unlock argument.

---

## Item 1 — Synthetic-lesion validation on CIDUR

**State:** ⏳ Decision open (per [analysis_plan.md § 9](analysis_plan.md#9-synthetic-lesion-validation-tier-b))
**Controllability:** Fully controllable — CIDUR data exists on NAS (N ≈ 26 with connectomes per [`../publication_strategy.md`](../publication_strategy.md) line 615), pipeline is already built, injection protocol is standard.
**Owner:** ______

### What "done" looks like

Not just "we ran it." Reviewers need:

- [ ] Synthetic-lesion injection protocol documented (lesion library source, size/location distribution, placement rule)
- [ ] All six arms run on CIDUR subjects with injected lesions
- [ ] Ground-truth connectivity computed from the un-injected control connectome per subject
- [ ] Recovery metric defined a priori (candidates: fraction of expected edge-weight loss recovered; correlation of predicted vs. expected disconnection; Dice on lesion-affected edges above a threshold) — pick one, justify it, don't metric-shop later
- [ ] Recovered-vs-expected result reported per arm with confidence intervals
- [ ] Documented as Figure 6 in [manuscript_skeleton.md](manuscript_skeleton.md#figures-and-tables) (currently marked "optional, NeuroImage stretch only")

### Why this is the highest-leverage item

LeAPP earned its methodological credibility with N ≈ 81 synthetic lesions in healthy brains (per [leapp_lineage.md § 1](leapp_lineage.md#cohort-and-validation)). Matching that credibility at N ≈ 26 CIDUR is the single most defensible venue-tier lever we have — no other item on this list is as fully within our control.

### Blocker(s)

- No blocker. Awaiting decision commitment.

### Sub-tasks (once decided to run)

- [ ] Lock synthetic-lesion library — source, size/location distribution
- [ ] Lock recovery metric before running (pre-registration in [analysis_plan.md § 9](analysis_plan.md#9-synthetic-lesion-validation-tier-b))
- [ ] Add synthetic-lesion injection arm to Snakemake DAG
- [ ] Run six-arm factorial on 26 CIDUR subjects × injected lesions
- [ ] Compute recovery metric; ANOVA across arms
- [ ] Draft Figure 6 + Methods § 10 (per [manuscript_skeleton.md § 10](manuscript_skeleton.md#methods-word-budget-2500))

---

## Item 2 — Real-cohort N ≥ 80 per arm

**State:** ⏳ At N = 1 (pilot `sub-TBI011011` only, per [index.md § Cohort and data](index.md#cohort-and-data))
**Target:** ≥ 80 QC-clean subjects in every one of six arms (Scenario A per [completion_tracker.md § Group-analysis decision rule](completion_tracker.md#group-analysis-decision-rule))
**Controllability:** Partial — we control batch-submission and retry logic; we do NOT control how many TrackTBI subjects have clinician-traced lesion masks.
**Owner:** ______

### What "done" looks like

- [ ] Cohort delivered: ~100 TrackTBI subjects with clinician-traced lesion masks (per [index.md § Cohort and data](index.md#cohort-and-data))
- [ ] All six arms processed for each subject
- [ ] Per-arm QC-clean N ≥ 80 minimum across all six arms
- [ ] Completion matrix filled in [completion_tracker.md § Per-subject × per-arm completion matrix](completion_tracker.md#per-subject--per-arm-completion-matrix-populate)
- [ ] QC-metric dashboard filled in [completion_tracker.md § Per-subject × per-arm QC metric dashboard](completion_tracker.md#per-subject--per-arm-qc-metric-dashboard-populate)

### Calibration (own judgment, not documented forecast)

Scenario probabilities per [`../publication_strategy.md`](../publication_strategy.md) and my own calibration:

| Scenario | Description | Probability (my calibration) | Ceiling |
|---|---|---|---|
| A | N ≥ 80 per arm, no arm systematically fails | ~30 % | NeuroImage feasible (with Items 1 & 3) |
| B | N = 40–79 per arm, some arm-specific failures reported honestly | ~50 % | HBM (default) |
| C | N < 40 in one or more arms | ~20 % | HBM w/ limitations, or *NeuroImage: Reports* backup |

**Interpretation:** Scenario A alone doesn't unlock NeuroImage — it's the *precondition* that makes Items 1 and 3 payoff. Without N ≥ 80, Item 1 (synthetic validation) is stronger evidence than Item 2 (real cohort), which is an odd manuscript to defend.

### Blocker(s)

- **Absolute mask availability** — cannot manufacture masks that don't exist. Need TrackTBI clinician-traced-mask inventory before committing to venue.
- **Per-arm failure rates** — VBT SIGSEGV in pilot suggests real cohort will lose some subjects on VBT specifically; failure-rate estimate needed from small-batch pilot (~10 subjects) before extrapolating to N = 100.

### Sub-tasks

- [ ] Query TrackTBI subject-list for clinician-traced masks (target: confirm ≥ 100 available)
- [ ] Run small batch (~10 subjects) to estimate per-arm failure rate before full-cohort commitment
- [ ] Full-cohort batch submission
- [ ] Populate completion matrix incrementally
- [ ] Compute per-arm QC-clean N; re-classify Scenario A/B/C at N = 20, 40, 80

---

## Item 3 — TBI-specific complications characterized

**State:** ⏳ None delivered
**Controllability:** Partial — we control analytic transparency and pre-specified subgroup analyses; we do NOT control the actual lesion-topology distribution in the cohort.
**Owner:** ______

### Three sub-items (all needed)

#### 3a. Bilateral-TBI subgroup characterized

- [ ] Bilateral-lesion subjects identified in cohort (expected ~30–40 % of moderate-severe per [leapp_lineage.md § 1](leapp_lineage.md#what-our-paper-adds-vs-leapp))
- [ ] Per-arm performance on bilateral subgroup reported (supplement figure, per [manuscript_skeleton.md § Supplement](manuscript_skeleton.md#supplement) S5)
- [ ] VBT-specific bilateral failure characterized (VBT's mirror assumption breaks — this is our specific extension over LeAPP)
- [ ] Contrast with unilateral subgroup for anatomy-backend sensitivity

**Why reviewers will ask:** LeAPP was on stroke where bilateral is rare; TBI is where VBT's assumption stresses. This is the single most likely "what happens to your method in the harder case?" review comment.

#### 3b. VBT failure mode reported honestly

- [ ] Per-subject VBT completion status recorded in completion matrix
- [ ] Failure taxonomy: SIGSEGV vs. mask geometry vs. brain-extraction failure vs. other
- [ ] Report ALL failures, don't drop subjects — "if X% of cohort fails VBT while succeeding in orig and neuroLIT, that itself is a publishable finding about VBT's limits in TBI"
- [ ] Cross-link to [../lesion_aware.md](../lesion_aware.md) for VBT implementation notes

**Why reviewers will ask:** methods papers that only report success rates on subjects where the method didn't crash are cherry-picking. Honest failure reporting is a differentiator ([index.md § Contribution summary](index.md#contribution-summary) row 4).

#### 3c. neuroLIT OOD sensitivity supplement

- [ ] Characterize which TBI lesions are OOD for the neuroLIT DDPM (large, irregular, bilateral, non-cortical)
- [ ] Report per-subject inpainting quality metric (e.g., visual QC score or reconstruction fidelity on held-out patch)
- [ ] Sensitivity analysis: does neuroLIT-based connectome quality degrade for OOD lesions?
- [ ] Currently NOT a locked decision in [analysis_plan.md](analysis_plan.md) — add as sub-item to Item 3 or promote to § 11 (Deep Atropos sensitivity is § 10; this would be § 10a or a new locked item)

**Why reviewers will ask:** Pollak 2025 validated neuroLIT on healthy + simulated lesions per [leapp_lineage.md § 4](leapp_lineage.md#4-pollak-et-al-2025--neurolit-ddpm-inpainting); TBI is the OOD case. Reviewers know this and will flag it if unaddressed.

### Blocker(s)

- **Bilateral count** depends on Item 2 cohort delivery.
- **VBT failure rate** partially known from pilot but needs cohort-scale data.
- **neuroLIT OOD taxonomy** requires a lesion-morphology classification we haven't built.

---

## Overall decision gate

| Item | Resolved? | Notes |
|------|:---------:|-------|
| 1 — Synthetic-lesion validation | ⏳ | Decision open — commit or skip |
| 2 — N ≥ 80 per arm | ⏳ | At N = 1; scenario TBD after cohort processing |
| 3a — Bilateral subgroup | ⏳ | Depends on Item 2 |
| 3b — VBT failure reporting | ⏳ | Ongoing; incrementally populated |
| 3c — neuroLIT OOD sensitivity | ⏳ | Not yet a locked decision |

**Rule:** venue commitment happens at cohort-processing completion (or synthetic-validation completion, whichever is later), not now. Aiming for NeuroImage before these items resolve is speculation, not strategy.

**Fallback rule:** if any item is unresolved at submission time, submit to HBM directly — do not burn 2–4 months on a NeuroImage rejection cycle for a paper that was HBM-tier from the start.

---

## Decision log

Append entries as items resolve. Include date, item, resolution, and rationale.

| Date | Item | Resolution | Rationale |
|------|------|------------|-----------|
| 2026-09-17 | Doc created | Open — three items identified from ceiling analysis | Discussion between PN and Claude — three preconditions for NeuroImage venue tier |
| | | | |

---

## See also

- [index.md](index.md) — factorial paper cover doc + cross-tier citation matrix
- [analysis_plan.md](analysis_plan.md) — pre-registration template with locked decisions
- [completion_tracker.md](completion_tracker.md) — per-subject × per-arm completion matrix
- [leapp_lineage.md](leapp_lineage.md) — LeAPP + lineage papers (Radwan / Pollak / Smith)
- [../publication_strategy.md](../publication_strategy.md) — cross-paper strategy for all four papers
