# Disconnectome paper — analysis plan (pre-registration template)

**Purpose:** locked design decisions for the disconnectome paper (Paper 2).
Fill in and sign off *before* opening group-level results. Serves as an
internal pre-registration so post-hoc venue choice / model-shopping cannot
be mistaken for a priori strategy.

**Related docs:** [disconnectome_paper.md](index.md) ·
[paper2_disconnectome_outcomes.md](outcomes_planning.md) ·
[journal_tier.md](../journal_tier.md)

**Status:** DRAFT — not yet signed off.

---

## Sign-off block

Once every design decision below is locked, sign here. **No changes to
locked items after sign-off without documented amendment (below).**

| Person | Role | Date | Signature |
|--------|------|------|-----------|
| _____ | PI | ______ | ______ |
| _____ | Analyst | ______ | ______ |
| _____ | Second analyst | ______ | ______ |

**Amendments** (append entries below sign-off; document reason for each):

| Date | Section | Change | Reason |
|------|---------|--------|--------|
| | | | |

---

## 1. Fixed imaging arm

- **Default choice:** `neurolit-lesion` (neuroLIT anatomy mitigation + lesion-aware ACT)
- **Alternative under consideration:** `vbt-lesion` (VBT anatomy mitigation + lesion-aware ACT)
- **Decision rule for choosing:** whichever arm's pilot QC (on sub-TBI011011) shows higher completion rate + cleaner integrity QC
- **Locked choice:** ______ (fill after pilot QC review)

---

## 2. Fixed primary outcome

- **Default choice:** GOSE at 6 months post-injury
- **Rationale:** most widely-used TBI functional outcome; standard TRACK-TBI collection window; matches Palacios 2022 J Neurotrauma precedent
- **Locked choice:** ______

---

## 3. Fixed visit-timing rule

- **Default choice:** imaging at 2WK → outcome at 6mo
- **Rationale:** matches Griffis 2019 stroke design (acute imaging, subacute-chronic outcome); consistent with clinical decision-support use case
- **Locked choice:** ______ (imaging session) → ______ (outcome window)

---

## 4. Mandatory covariate set

Locked before opening any regression. All subsequent models include exactly
these covariates in the baseline; augmented models add SDC / FC on top.

- [ ] Age at injury
- [ ] Sex
- [ ] Education (years or categorical, decide below)
- [ ] GCS (field or admission — decide below)
- [ ] Lesion volume (mm³) — computed from lesion_roi_metrics.csv

**Additional decisions to lock:**

- Education encoding: ______ (years vs categorical)
- GCS: ______ (field vs admission)
- Handling missing education/GCS: ______ (exclude subject vs impute; if impute, method)

---

## 5. Primary imaging outcome variable

- **Default choice:** global disconnection score = sum of D over all edges with D > 0 (from `disconnection_matrix.csv` Option C spared connectome)
- **Alternative under consideration:** first principal component of the disconnection matrix
- **Locked choice:** ______

---

## 6. Network-to-domain mapping (for domain-specific analyses)

Pre-specify which network's SDC will be tested against which cognitive
composite. Locking this prevents domain-shopping.

| Cognitive domain | Network (parcellation choice) | SDC feature |
|------------------|-------------------------------|-------------|
| Attention / processing speed | ______ (default: Yeo7 dorsal attention or Schaefer 200 DAN) | Within-network + between-network SDC |
| Memory | ______ (default: medial temporal + default mode) | Within-network + between-network SDC |
| Executive function | ______ (default: Yeo7 fronto-parietal) | Within-network + between-network SDC |
| Language | ______ (default: Yeo7 left fronto-temporal) | Within-network + between-network SDC |
| Motor | ______ (default: sensorimotor) | Within-network + between-network SDC |

**Parcellation choice locked:** ______ (DKT / Schaefer 200 / 4S 156 / other)

---

## 7. Incremental-validity benchmark models

Nested regression models to be fit and compared. Cross-validation strategy
and permutation testing are pre-specified.

**Baseline model:**
```
outcome ~ age + sex + education + GCS + lesion_volume_mm3
```

**+SDC model:**
```
outcome ~ [baseline covariates] + SDC_summary
```

**+SDC+FC model (only if rs-fMRI available):**
```
outcome ~ [baseline covariates] + SDC_summary + FC_abnormality_summary
```

**Comparison metric:**
- For GOSE (ordinal): cross-validated ΔAUC (5-fold or leave-one-out)
- For continuous cognitive composites: cross-validated ΔR²
- Statistical test: permutation p-value from 10,000 label-shuffles

**Cross-validation method locked:** ______ (5-fold / LOO / other)
**Number of permutations locked:** ______ (default 10,000)
**Multiple-comparison correction locked:** ______ (Bonferroni across domains / FDR / none if single primary test)

---

## 8. Complete-case N threshold

Pre-specify what happens at each N range so the decision is not made after
seeing results.

- **N ≥ 45:** un-pause and execute Paper 2 as planned; primary analyses run.
- **N = 30–44:** execute with explicit "small-cohort limitations" framing; report all analyses but discuss cautiously.
- **N < 30:** fold disconnectome results into Paper 1 as one supplementary figure; do not submit as standalone Paper 2.

**Locked threshold acceptance:** ______

---

## 9. Head-to-head SDC comparison (methods contribution)

Pre-specify what defines a "meaningful divergence" between patient-specific
SDC and normative-atlas SDC.

- **Metric:** edge-wise Pearson correlation between patient-specific SDC matrix and LQT SDC matrix, per subject.
- **Interpretation thresholds:**
  - r ≥ 0.9 across cohort → methods agree; methods contribution weak; write Brain/HBM biology-lead.
  - 0.7 ≤ r < 0.9 → moderate agreement; methods contribution modest.
  - r < 0.7 across ≥ 25% of cohort → substantial divergence; methods contribution strong; write NeuroImage methods-lead.
- **Downstream confirmation:** divergence must translate into cross-validated ΔAUC or ΔR² improvement (patient-specific SDC ≥ 0.02 ΔAUC above LQT SDC on either FC prediction or GOSE prediction) for NeuroImage submission.
- **Locked thresholds:** ______

---

## 10. Venue decision rule

After primary analyses complete, apply this rule:

1. If head-to-head shows substantial divergence (§ 9) with downstream confirmation → **NeuroImage** (methods-lead)
2. Else if SC→FC coupling is clean (CCA first-component r ≥ 0.4 with permutation p < 0.05) AND domain-specific network → deficit mapping holds for ≥ 3/5 domains → **Brain** (biology-lead)
3. Else if the whole is coherent (≥ 1 primary analysis significant with defensible interpretation) → **HBM** (default)
4. Else fold disconnectome into Paper 1 supplement

**Locked rule:** ______

---

## 11. Timeline

Locked calendar dates for each milestone:

- Analysis plan sign-off by: ______
- fMRI preprocessing arm complete: ______
- LQT / BCB batch runs complete: ______
- Group results opened: ______ (**this is the firewall — no design changes after this date**)
- Manuscript draft complete: ______
- Coauthor rounds complete: ______
- Submission: ______

---

## 12. What is NOT locked (allowed to change)

Everything not listed above is fair game to iterate on during analysis:

- Figure design and specific plots
- Supplementary analyses and robustness checks
- Introduction / discussion narrative choices
- Software version updates (unless they change results)
- Wording of the primary claim (as long as the underlying finding is unchanged)

---

## 13. What TRIGGERS an amendment (documented above)

- Any change to §§ 1–10 after sign-off requires a documented amendment with reason.
- Any addition of a new "primary" analysis not on the original list requires demoting it to "exploratory" or opening the firewall (a red flag).

---

## Reviewer defense value

At submission, this pre-registration doc travels as a supplement or is
referenced in Methods. Its purpose:

- Demonstrates the analysis was pre-specified, not p-hacked
- Anchors the venue-choice decision to a rule, not to post-hoc ambition
- Documents amendments transparently if any occurred
- Supports the "not shopping venues after seeing results" claim

This is the sort of internal pre-registration that HBM / Brain / NeuroImage
increasingly expect for prognostic-model papers even without formal OSF
registration.
