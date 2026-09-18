# Factorial paper — analysis plan (pre-registration template)

**Purpose:** locked design decisions for the factorial paper (Paper 1). Fill
in and sign off *before* opening group-level results. Serves as an internal
pre-registration so post-hoc contrast-shopping / metric-shopping cannot be
mistaken for a priori strategy.

**Related docs:** [index.md](index.md) ·
[manuscript_skeleton.md](manuscript_skeleton.md) ·
[../../TBI_Experimental_Arms.md](../../TBI_Experimental_Arms.md)

**Status:** DRAFT — not yet signed off.

---

## Sign-off block

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

## 1. Six arms (locked from pipeline design)

Per [../../TBI_Experimental_Arms.md](../../TBI_Experimental_Arms.md), the
factorial arms are fixed:

| Arm | Anatomy | ACT | `--experiment-arm` preset |
|-----|---------|-----|---------------------------|
| `orig-std` | Original T1w | Standard | `orig-std` |
| `orig-lesion` | Original T1w | Lesion-aware | `orig-lesion` |
| `neurolit-std` | neuroLIT | Standard | `neurolit-std` |
| `neurolit-lesion` | neuroLIT | Lesion-aware | `neurolit-lesion` |
| `vbt-std` | VBT | Standard | `vbt-std` |
| `vbt-lesion` | VBT | Lesion-aware | `vbt-lesion` |

Seventh sensitivity arm `deep-atropos-pilot` runs on pilot only (Paper 3 supplement material).

---

## 2. Primary numeric outcome

- **Default choice:** mean absolute edge difference on the upper triangle of the DKT connectome, per subject-arm-pair
- **Alternative under consideration:** global Pearson correlation between paired arms per subject
- **Alternative under consideration:** first principal component of the connectome delta
- **Locked choice:** ______

---

## 3. Primary parcellation

- **Default choice:** DKT (78 regions), SIFT2-weighted, from `dkt_connectome.csv`
- **Sensitivity parcellation:** Schaefer 200 (already supported by QSIRecon) — reported in supplement
- **Locked choice:** ______

---

## 4. Pre-specified contrasts (locked)

Per [../../TBI_Experimental_Arms.md § Pre-specified contrasts](../../TBI_Experimental_Arms.md#pre-specified-contrasts-paper-1):

| Level | Contrast | Question |
|-------|----------|----------|
| Primary | `*-std` vs `*-lesion` within each anatomy | Does pathology ACT change connectomes? |
| Secondary | `orig-*` vs `neurolit-*` vs `vbt-*` within std / lesion | How much does inpainting matter? |
| Interaction | Anatomy × ACT | Is ACT benefit larger after inpainting? |

**Locked:** these three contrasts. No post-hoc addition of contrasts without amendment.

---

## 5. Statistical framework

- **Within-subject paired comparisons:** paired Wilcoxon signed-rank test or paired t-test (choose one; decision below)
- **Cross-arm distribution comparison:** Friedman test across three anatomy backends, followed by pairwise post-hoc
- **Interaction test:** repeated-measures 2×3 ANOVA on the primary numeric outcome
- **Multiple-comparison correction:** Bonferroni across the three primary contrasts (or FDR — decision below)

**Locked choices:**
- Within-subject test: ______
- Multiple-comparison correction: ______

---

## 6. Completion-threshold N per arm

- **Default rule:** proceed with group analysis only when each arm has N ≥ 40 subjects with clean end-to-end processing
- **Fallback:** if any arm drops below N=40, report as failure-mode analysis with per-arm success rate rather than pool
- **Locked N threshold:** ______

---

## 7. QC pass criteria per subject-arm

Locked criteria before opening group results. A subject is "clean" for a given arm if all of:

- [ ] `qsiprep.done` marker present
- [ ] `qsirecon.done` marker present (or `lesion_aware_act.done` for `*-lesion` arms)
- [ ] Connectome CSV present with 78×78 shape
- [ ] Empty-node fraction ≤ [threshold — default 5%]
- [ ] SIFT2 mu > 0 and < [reasonable upper bound]
- [ ] For `*-lesion` arms: lesion warp method (ACPC or MNI) recorded in `lesion_aware_act.json`; pathology QA pass

**Locked QC gate:** ______

---

## 8. Handling failed arms per subject

If a subject completes some but not all six arms:

- **Default rule:** include in the arms where they succeeded; report a "completion matrix" showing subject × arm success
- **Alternative rule:** require all six arms to be complete for a subject to be included in any group analysis
- **Locked rule:** ______

---

## 9. Synthetic-lesion validation (Tier B)

Determines whether Paper 1 aims at HBM (default) or NeuroImage (stretch).

- **Include:** run synthetic lesions on CIDUR controls (N=~26) with the full six-arm factorial + measure recovery of expected connectivity loss
- **Not include:** submit at HBM default without this validation
- **Locked decision:** ______

---

## 10. Deep Atropos sensitivity figure (in-supplement)

Per publication strategy, Deep Atropos vs HSVS is a Paper 1 supplement, not Paper 3 standalone.

- **Include:** run `deep-atropos-pilot` on cohort subset (N ≥ 30 if feasible) as one supplementary figure
- **Alternative:** run on pilot only (`sub-TBI011011`) as illustrative sensitivity — cheaper
- **Locked decision:** ______

---

## 11. Timeline

- Analysis plan sign-off by: ______
- Cohort processing complete: ______
- QC-by-arm table complete: ______
- Group results opened: ______ (**this is the firewall**)
- Manuscript draft complete: ______
- Coauthor rounds complete: ______
- Submission: ______

---

## 12. What is NOT locked (allowed to change)

- Figure design and specific plots (as long as they show the locked contrasts on the locked outcome)
- Supplementary analyses and robustness checks
- Introduction / discussion narrative choices
- Software version updates (unless they change results)
- Wording of the primary claim (as long as the underlying finding is unchanged)

---

## 13. What TRIGGERS an amendment

- Any change to §§ 1–10 after sign-off requires a documented amendment with reason.
- Any addition of a new "primary" analysis not on the original list requires demoting it to "exploratory" or opening the firewall (a red flag).

---

## Reviewer defense value

This pre-registration doc travels as supplement material or is referenced in
Methods at submission. Purpose:

- Demonstrates the analysis was pre-specified, not p-hacked
- Anchors contrast choices to a rule, not to post-hoc pattern-finding
- Documents amendments transparently if any occurred
- Supports the "not gaming the factorial" claim expected by HBM/NeuroImage reviewers
