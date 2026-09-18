# Disconnectome paper — cover and navigation

**Purpose:** canonical entry point for the "disconnectome paper" (Paper 2 in
the portfolio). Consolidates planning artifacts, cross-links supporting docs,
and provides the cross-tier paper-citation matrix.

**Note on nomenclature:** "the disconnectome paper" and "Paper 2" refer to
the same manuscript. This doc is the cover; [paper2_disconnectome_outcomes.md](paper2_disconnectome_outcomes.md)
is the detailed planning artifact.

**As-of:** 2026-09-17. **Author:** Phind Ndagijimana (with Claude planning assist).

---

## What this paper is

A study asking whether **patient-specific lesion-aware structural disconnection
(SDC)** in traumatic brain injury (a) predicts functional connectivity
disruption and behavioral outcome beyond lesion volume alone, and (b) captures
clinically-relevant signal that widely-used normative-atlas SDC tools
(LQT, BCBtoolkit) miss because of TBI's heterogeneous lesion morphology.

The paper extends the **Griffis 2019 *Cell Reports* SDC → FC → behavior
framework** from ischemic stroke to TBI, adds a **methodological head-to-head
against normative-atlas SDC** that is specifically motivated by TBI's mass
effect / oedema / bilateral injury, and lands at one of three candidate
venues based on which contribution turns out quantitatively stronger:

- **NeuroImage** (methods-lead) — patient-specific vs normative-atlas SDC head-to-head
- **Brain** (biology-lead) — full SC → FC → behavior chain in TBI
- **Human Brain Mapping** (default) — coherent whole under either framing

## Status

**Conditional — un-pauses once complete-case N is confirmed.** PI has
indicated GOSE + other clinical outcomes are available for the TBI cohort;
rs-fMRI is present in TBI BIDS on both timepoints of the pilot (full cohort
assumed to mirror). Awaiting:

1. TRACK-TBI clinical data-dictionary export
2. Complete-case count (proceed at N ≥ 45; limitations at 30–44; fold into Paper 1 at < 30)
3. Analysis plan lock (see [disconnectome_paper_analysis_plan.md](disconnectome_paper_analysis_plan.md))

## Documentation cluster

The disconnectome paper is documented across the following files in this
folder, listed by role:

### Planning artifacts

| Doc | Purpose |
|-----|---------|
| **`disconnectome_paper.md`** (this file) | Cover + navigation + cross-tier paper matrix |
| [`paper2_disconnectome_outcomes.md`](paper2_disconnectome_outcomes.md) | Full detailed planning: RQs, data-level ceiling, Griffis-2019 contribution breakdown, design decisions, complete-case spreadsheet template |
| [`disconnectome_paper_analysis_plan.md`](disconnectome_paper_analysis_plan.md) | Pre-registration doc — locked design choices with sign-off dates |
| [`disconnectome_paper_manuscript_skeleton.md`](disconnectome_paper_manuscript_skeleton.md) | Section-by-section outline with word budgets |
| [`disconnectome_paper_complete_case.md`](disconnectome_paper_complete_case.md) | Subject-level data-tracking template (build as clinical export arrives) |
| [`journal_tier.md`](journal_tier.md) / [`.docx`](journal_tier.docx) | Full ten-venue landscape + per-venue framing + manuscript breakdowns |

### Prior-work reference

| Doc | Purpose |
|-----|---------|
| [`LQT.md`](LQT.md) / [`.docx`](LQT.docx) | Reference for LQT + normative-atlas SDC family (LQT / BCBtoolkit / NeMo) — our comparators |
| [`Griffis_later.md`](Griffis_later.md) / [`.docx`](Griffis_later.docx) | Follow-up literature (Salvalaggio, Talozzi, Kuceyeski, Boes, Fox) — our lineage + parallel lineage |
| [`publication_strategy.md`](publication_strategy.md) | Cross-paper strategy (all four papers), prior-work analog table |

### Pipeline methods (docs level up)

| Doc | Purpose |
|-----|---------|
| [`../lesion_aware.md`](../lesion_aware.md) | Lesion-aware ACT methodology + factorial design + LeAPP framework |
| [`../disconnectome.md`](../disconnectome.md) | Step 4.1 methods (Options A/B/C spared connectomes + integrity QC) |
| [`../methods/step3_1_lesion_act.md`](../methods/step3_1_lesion_act.md) | Step 3.1 lesion-aware tractography details |
| [`../references.md`](../references.md) | Full pipeline bibliography |

---

## Cross-tier paper-citation matrix

Papers that appear in multiple venue tiers — cite once, deploy at multiple
levels. Rows are papers; columns are tiers where each paper is a primary
citation. This answers the "papers that can be used for both tiers" question.

| Paper | J Neurotrauma tier | Brain / HBM domain-specific | Brain / Neurology stretch (full chain) | NeuroImage methods-lead |
|-------|:------------------:|:---------------------------:|:--------------------------------------:|:-----------------------:|
| **Griffis 2019** *Cell Rep* — SC→FC→behavior in stroke | | ✅ **The template** | ✅ **The template** | |
| **Corbetta 2015** *Neuron* — WashU behavioral factor analysis | | ✅ Behavioral framework | ✅ Behavioral framework | |
| **Salvalaggio 2020** *Brain* — multi-domain outcome + indirect FC | | ✅ Multi-domain framework | ✅ Combined SC+FC modeling | |
| **Talozzi 2023** *Brain* — latent disconnectome | | | ✅ Methodological frontier | |
| **Boes 2015** *Brain* — lesion network mapping (rs-fMRI-based) | | | ✅ Parallel lineage | |
| **Fox 2018** *NEJM* — LNM paradigm review | | | ✅ High-visibility positioning | |
| **Bey 2024** (LeAPP) *HBM* — factorial anatomy × ACT in stroke | | ✅ HBM precedent for our family | | ✅ Methodological ancestor |
| **Palacios 2022** *J Neurotrauma* — TRACK-TBI multisite DTI + GOSE | ✅ **Direct precedent** | | | |
| **Warren 2015** *Brain* — TBI graph metrics → cognition | ✅ TBI classic | ✅ TBI precedent for connectome-cognition | | |
| **Kuceyeski 2020** *HBM* — mTBI longitudinal | ✅ Small-cohort TBI connectome | | | |
| **Kuceyeski 2013** *Brain Connect* (NeMo tool) | | | | ✅ Older normative-atlas tool; sensitivity comparator |
| **Griffis 2021** *NI:Clinical* (LQT release) | | | | ✅ **Primary comparator** |
| **Foulon 2018** *GigaScience* (BCBtoolkit) | | | | ✅ **Second comparator** |
| **Radwan 2023** *NetNeuro* — TBI + VBG + ACT N=5 | | | | ✅ TBI patient-specific tractography precedent |
| **Osmanlıoğlu 2022** *HBM* — TBI longitudinal + cognition | ✅ Backup TBI precedent | ✅ Normative-score analog | | |
| **Yeh 2018** *NeuroImage* — HCP-842 tractogram | | | | ✅ Methods (underpins LQT / NeMo) |

**Interpretation:**

- **Cross-tier workhorses** (cited across 2+ primary tiers): Griffis 2019, Salvalaggio 2020, Corbetta 2015, Bey 2024, Warren 2015, Osmanlıoğlu 2022. These are the papers most worth deep familiarity — they anchor multiple parts of any Paper 2 submission.
- **Tier-specific anchors:** Palacios 2022 (J Neurotrauma only), LQT/BCB/NeMo (NeuroImage methods only), Boes/Fox (stretch tier only).
- **Contribution to novelty defense:** at any tier, the reviewer question is "how does this differ from [tier-appropriate anchor]?" The cross-tier matrix tells you which anchor to name for which submission.

---

## Contribution summary

Five contributions ranked by novelty and venue-unlock potential:

| Contribution | Novelty | Reviewer defense | Venue tier it unlocks |
|--------------|---------|------------------|-----------------------|
| SDC → FC coupling in TBI | Incremental (Griffis stroke → TBI extension) | CCA replicates in TBI | HBM |
| SDC → behavior domain-specific in TBI | Incremental (Griffis stroke → TBI extension) | Domain-network mapping holds | HBM / Brain |
| Incremental validity vs lesion volume in TBI | Incremental | ΔAUC / ΔR² above baseline | HBM / Brain |
| **Patient-specific vs normative-atlas SDC head-to-head in TBI** | **Genuinely new** | Divergence + clinical consequence | **NeuroImage** |
| Combined biology + methods story | Combined | Both cleanly delivered | Nature Comm (stretch, needs replication) |

Full contribution reasoning in [paper2_disconnectome_outcomes.md § Our contribution relative to Griffis 2019](paper2_disconnectome_outcomes.md#our-contribution-relative-to-griffis-2019--expanded).

---

## Immediate next steps

1. **Request TRACK-TBI clinical data dictionary** (see [Appendix D in journal_tier.md](journal_tier.md#appendix-d--what-track-tbi-clinical-export-should-include))
2. **Build complete-case tracker** (populate [disconnectome_paper_complete_case.md](disconnectome_paper_complete_case.md) as data arrives)
3. **Confirm rs-fMRI coverage** cohort-wide (pilot has it; verify full cohort mirrors)
4. **Lock analysis plan** ([disconnectome_paper_analysis_plan.md](disconnectome_paper_analysis_plan.md)) before opening any group results
5. **Build fMRI preprocessing arm** (fMRIPrep + XCP-D) into pipeline
6. **Install LQT + BCBtoolkit** and prepare per-subject batch scripts
7. **Add Schaefer / 4S parcellation** to Paper 2 subset for network-native analyses

## See also

- [`../papers/index.md`](index.md) — papers workspace landing page
- [`publication_strategy.md`](publication_strategy.md) — full four-paper portfolio
- [`../TBI_Experimental_Arms.md`](../TBI_Experimental_Arms.md) — factorial design (Paper 1 context)
