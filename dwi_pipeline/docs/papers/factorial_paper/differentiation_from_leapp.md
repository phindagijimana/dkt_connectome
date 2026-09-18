# Factorial paper — differentiation from LeAPP

**Purpose:** ranked menu of specific contributions we can add to enlarge our
distance from Bey et al. 2024 (LeAPP), the direct methodological precedent.
Answers the question: *"which additions materially shift the paper from
'TBI extension of LeAPP' to a substantively differentiated contribution?"*

**Related docs:** [index.md](index.md) · [leapp_lineage.md](leapp_lineage.md) ·
[neuroimage_prerequisites.md](neuroimage_prerequisites.md) ·
[analysis_plan.md](analysis_plan.md)

---

## Executive summary

Our paper as currently scoped is **framework-extension** (extends LeAPP's
methodological framework to TBI + adds neuroLIT as a 3rd anatomy arm +
containerized infrastructure). LeAPP itself was **framework-formation**
(created its named framework by combining pre-existing VBG + ACT into a
factorial and adding synthetic-lesion validation).

Reviewers apply different scrutiny to framework-extensions vs framework-
formations. Extensions need to demonstrate each extension is non-trivial;
formations get credit for the combination itself. Our closeness to LeAPP
therefore requires **deliberate additions** to reach a distance similar to
LeAPP-vs-VBG.

This document lists 20 candidate additions ranked by novelty-per-unit-effort.
Items 1–4 were identified first and are our "table stakes." Items 5–13 are
worth considering; items 14–20 are lower-leverage and mostly skip.

---

## Tier 0 — table-stakes additions (previously identified)

These are the four minimum additions that shift the paper from "TBI cohort
application of LeAPP" to "TBI-specific methodological extension."

| # | Addition | Novelty | Effort | Notes |
|---|----------|:-------:|:------:|-------|
| 1 | **Tier B synthetic-lesion validation** on CIDUR controls | ★★★★ | 4 wks | Matches LeAPP's N≈81 synthetic validation move; primary lever for HBM → NeuroImage upgrade |
| 2 | **Framework naming and branding** (name the pipeline as a citable framework, not just describe as "LeAPP extension") | ★★ | 1 day | Signals contribution-magnitude claim; changes long-term citation trajectory |
| 3 | **Foreground neuroLIT integration** as a first-class methodological choice (not just "3rd arm we added") | ★★ | Analysis-only | Turns Pollak 2025 integration from decoration to substantive contribution |
| 4 | **First-class bilateral-lesion handling** analysis (main-text figure/subgroup, not supplement) | ★★★ | Analysis-only | Stress-tests LeAPP's implicit unilateral assumption; TBI-specific finding LeAPP could not produce |

---

## Tier 1 — high leverage, worth adding

Each of these substantially enlarges distance from LeAPP with a favorable
effort-to-payoff ratio.

### 5. Uncertainty quantification per edge

LeAPP reported point estimates for edge weights per arm. Report **edge-weight
confidence intervals** via bootstrap resampling of tractography seeds (or
subject-level bootstrap of streamline weights).

- **What it delivers:** turns "the connectome is X" into "the connectome is X ± Y"
- **Effort:** ~2 weeks compute + analysis code
- **Payoff:** NeuroImage reviewers explicitly reward uncertainty reporting; genuine methodological advance over LeAPP
- **Novelty:** ★★★

### 6. Cross-parcellation robustness suite

LeAPP tested one parcellation. Report the six-arm factorial results in
**DKT + Schaefer 200 + 4S 156** (all already supported by QSIRecon).

- **What it delivers:** either robustness across parcellations (win) or parcellation-specific sensitivity (also publishable insight)
- **Effort:** rerun connectome step only, ~1 week compute
- **Payoff:** preempts the "what if you'd used Schaefer instead?" reviewer question
- **Novelty:** ★★★

### 7. Test-retest reliability on repeat scans

Check whether TRACK-TBI has any subjects with **repeat scans** (within-session,
or between-session at short interval where biology is unchanged). Compute
per-arm ICC per edge.

- **What it delivers:** if any arm has meaningfully higher ICC than others, that's a substantive reliability finding
- **Effort:** free if data exists; moderate analysis effort
- **Payoff:** reliability is a first-class methodological contribution NeuroImage rewards
- **Novelty:** ★★★
- **Dependency:** need to verify TRACK-TBI actually has repeat scans on the lesion-mask cohort

### 8. Lesion-topology → arm-recommendation decision tree

Turn the factorial results into an **actionable clinical decision aid**:
*"given this lesion location + volume + bilaterality, use arm X."* Published
as a supplement + accessible via the pipeline (JSON lookup or Python function).

- **What it delivers:** shifts the paper's function from methods-sensitivity characterization to actionable practice guidance
- **Effort:** post-hoc analysis on cohort results, 1–2 weeks
- **Payoff:** paper gets cited by clinical / downstream users, not just methods peers
- **Novelty:** ★★★★
- **Highest marginal value** among all Tier 1 items — this alone rewrites the paper's function

---

## Tier 2 — medium leverage, worth if timeline permits

### 9. Automated lesion segmentation comparison

Compare arm behavior when lesion mask is clinician-traced vs auto-segmented
(nnU-Net / MELD). Rerun subset of subjects with both mask sources.

- **What it delivers:** sensitivity to mask source + enables fully-automated pipeline use without expert tracers
- **Effort:** 2× compute for a subset
- **Payoff:** enables scaling beyond expert-traced cohorts
- **Novelty:** ★★

### 10. Multi-measure connectome consistency

The pipeline already produces multiple edge measures from one tractogram:
streamline count, SIFT2-weighted, mean length, mean FA, mean MD. Report
whether the six-arm factorial effects are **consistent across measures**.

- **What it delivers:** robustness if consistent; insight into measure sensitivity if not
- **Effort:** analysis-only, no additional compute
- **Payoff:** turns an underused pipeline capability into a robustness figure
- **Novelty:** ★★
- **Best per-unit-effort** in Tier 2

### 11. Cross-site harmonization analysis

TRACK-TBI is multi-site. Test whether per-arm effects survive **ComBat or
site-fixed-effects** harmonization.

- **What it delivers:** LeAPP was single-site; cross-site is what a real-world TBI processing pipeline needs
- **Effort:** analysis-only
- **Payoff:** cross-site generalizability strengthening beyond LeAPP
- **Novelty:** ★★★

### 12. Prospective preregistration

Post the analysis plan (already drafted in [`analysis_plan.md`](analysis_plan.md))
to OSF or AsPredicted **before opening group results**.

- **What it delivers:** LeAPP wasn't prospectively registered
- **Effort:** 1 day
- **Payoff:** reviewer trust in the primary contrasts; explicit anti-p-hacking signal
- **Novelty:** ★★
- **Highest per-day-of-effort** payoff of any item on this list

### 13. Deep Atropos as full third arm dimension

Currently Deep Atropos is a supplement figure only. If we run the full
factorial as **3 anatomy × 2 ACT × 2 5TT source** = 12 arms (adding Deep
Atropos vs HSVS as a third axis), we get a **3×2×2 factorial** —
meaningfully more than LeAPP's 2×2.

- **What it delivers:** turns a supplement into a first-class contribution; makes the factorial genuinely more complex than LeAPP's
- **Effort:** 2× cohort processing compute
- **Payoff:** biggest structural expansion of the factorial design
- **Novelty:** ★★★★
- **Trade-off:** scope-expanding — may require slower cohort processing

---

## Tier 3 — nice-to-have, mostly skip

These are either niche, cannibalize other papers, or add marginal value.

| # | Addition | Reason to skip |
|---|----------|----------------|
| 14 | Multi-shell DWI robustness | Depends on cohort having multi-shell subjects; probably too niche |
| 15 | Publish BIDS-Derivatives on Zenodo with DOI | Standard practice, not a novelty differentiator |
| 16 | LQT/BCB SDC cross-check | That's Paper 2 territory; cannibalizes Paper 2's methods contribution |
| 17 | Full FC integration as robustness | That's Paper 2's Griffis chain; leave it there |
| 18 | Effect of MRI acquisition parameters | Interesting but requires acquisition-heterogeneity data specifically |
| 19 | Data-augmented training / validation | ML-adjacent; expands scope beyond factorial paper |
| 20 | Lesion age (acute / subacute / chronic) stratification | Depends on TRACK-TBI having enough spread in visit timing |

---

## Compound-effect table

| Addition | Novelty gain | Effort | Marginal ROI |
|----------|:------------:|:------:|:------------:|
| **Tier 0** | | | |
| 1 — Tier B synthetic validation | ★★★★ | 4 wks | Best (single biggest lever) |
| 2 — Framework naming | ★★ | 1 day | Best (highest per-day) |
| 3 — Foreground neuroLIT | ★★ | Analysis-only | Best |
| 4 — First-class bilateral handling | ★★★ | Analysis-only | Best |
| **Tier 1** | | | |
| 5 — Edge uncertainty quantification | ★★★ | 2 wks | High |
| 6 — Cross-parcellation robustness | ★★★ | 1 wk | High |
| 7 — Test-retest reliability | ★★★ | Free if data | Depends on data availability |
| 8 — Decision-tree recommendation | ★★★★ | 1-2 wks | Very high |
| **Tier 2** | | | |
| 9 — Auto-segmentation comparison | ★★ | 2× compute | Medium |
| 10 — Multi-measure consistency | ★★ | Analysis-only | High per unit effort |
| 11 — Cross-site harmonization | ★★★ | Analysis-only | High |
| 12 — Preregistration | ★★ | 1 day | Highest per-day |
| 13 — Deep Atropos as full arm | ★★★★ | 2× compute | High but scope-expanding |

---

## Realistic combined packages

### Minimal package (Tier 0 only)

Add items 1–4. Distance from LeAPP: modest. Landing zone: HBM default,
NeuroImage stretch achievable if Tier B validation lands cleanly.

### Recommended package (Tier 0 + selected Tier 1 + selected Tier 2)

Add items 1, 2, 3, 4, 5, 6, 8, 10, 11, 12.

- Skip 7 (contingent on repeat-scan data availability)
- Skip 9 (moderate value, high compute)
- Skip 13 (scope-expanding — 12 arms may exceed cohort processing capacity)

Distance from LeAPP: **substantial**. Landing zone: NeuroImage main
submission (not just stretch); potential *Human Brain Mapping* editorial
preview / recommendation.

### Maximum package (all Tier 0 + all Tier 1 + all Tier 2)

Add items 1–13. Distance from LeAPP: **large**. Landing zone: NeuroImage
main + potential *Brain* or *Nature Human Behaviour* consideration if
biology insights emerge (unlikely for a pure methods paper).

Effort estimate: 3–5 months of additional analysis / compute beyond the
minimal-package Paper 1 timeline.

---

## Priority-ordered highest-marginal-value picks

If you can add only one item beyond Tier 0: **#8 (decision-tree recommendation)** —
shifts the paper's function from methods characterization to actionable
practice guidance.

If two: **#8 + #6 (cross-parcellation robustness)** — adds actionability +
preempts the most common reviewer question.

If three: **#8 + #6 + #5 (edge uncertainty)** — genuinely rewrites the
story from "we ran LeAPP on TBI" to "we made LeAPP's outputs quantitatively
defensible and actionable in TBI."

If four: **#8 + #6 + #5 + #12 (preregistration)** — one-day rigor signal on
top of the three substantive additions.

---

## Decision framework

For each candidate addition, ask three questions:

1. **Does it produce something LeAPP structurally could not?** (e.g. bilateral handling, uncertainty per edge, decision tree)
2. **Does it require data we don't have?** (e.g. test-retest scans, auto-segmentation, multi-shell)
3. **Does it cannibalize another paper's contribution?** (e.g. LQT cross-check → Paper 2; full FC → Paper 2)

Add if 1 = yes, 2 = no, 3 = no. Skip otherwise.

---

## Reviewer-defense value

Each addition provides a specific answer to a specific anticipated critique:

| Anticipated critique | Which addition answers it |
|---------------------|---------------------------|
| "How does this differ from LeAPP?" | Tier 0 items 1–4; item 5 |
| "Why should I trust these connectomes as ground truth?" | Item 5 (uncertainty), item 7 (test-retest) |
| "What if you'd used Schaefer / another atlas?" | Item 6 (cross-parcellation) |
| "How should a clinician actually use these results?" | Item 8 (decision tree) |
| "Does this only work with clinician-traced masks?" | Item 9 (auto-seg comparison) |
| "Are the effects robust to edge measure choice?" | Item 10 (multi-measure) |
| "Does this survive multi-site heterogeneity?" | Item 11 (harmonization) |
| "Was this p-hacked?" | Item 12 (preregistration) |
| "Why not test Deep Atropos as a first-class arm?" | Item 13 (3×2×2 factorial) |

Missing an answer for any critique = potential reject-and-resubmit request
from a rigorous reviewer.

---

## See also

- [`index.md`](index.md) — cover doc, cross-tier paper matrix, contribution summary
- [`leapp_lineage.md`](leapp_lineage.md) — Bey 2024 deep summary + what our paper adopts vs differentiates
- [`neuroimage_prerequisites.md`](neuroimage_prerequisites.md) — the three gating items for NeuroImage-tier submission
- [`analysis_plan.md`](analysis_plan.md) — pre-registration template
