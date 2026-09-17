# Paper 1 — Factorial anatomy × lesion-aware ACT in TBI (flagship)

**Status:** Active — submit first.
**Target:** *Human Brain Mapping* (default); *NeuroImage* stretch with synthetic-lesion validation.

**Cross-refs:** [publication_strategy.md § Paper 1](publication_strategy.md#paper-1--flagship-submit-first)
· [../lesion_aware.md](../lesion_aware.md) · [../TBI_Experimental_Arms.md](../TBI_Experimental_Arms.md)

---

## One-paragraph summary

A 3×2 factorial evaluation of anatomy mitigation (original T1w vs neuroLIT
inpainting vs virtual brain transplant) crossed with lesion-aware ACT
(standard vs pathology-informed) for structural connectomes in traumatic
brain injury. Extending the LeAPP framework (Bey et al. 2024, HBM) from
ischemic stroke to TBI's more heterogeneous lesion morphology, we run all
six arms with isolated per-arm outputs across ~100 TrackTBI subjects with
clinician-traced lesion masks. Pre-specified contrasts test whether
lesion-aware ACT changes connectomes within each anatomy backend, how much
anatomy mitigation matters holding ACT fixed, and whether the two interact.
Primary deliverables are cohort completion rates by arm, quantitative
matrix/edge sensitivity, and honest QC.

## Candidate titles

- *Lesion-aware structural connectomics in traumatic brain injury: a factorial comparison of inpainting, virtual brain transplant, and pathology-informed tractography* (working title)
- *A 3×2 factorial of anatomical mitigation and lesion-aware tractography for structural connectomics in traumatic brain injury*
- *From stroke to traumatic brain injury: extending lesion-aware connectome processing with neuroLIT and virtual brain transplant*
- *How much do preprocessing choices change the connectome in focal TBI? A cohort-scale factorial of inpainting and pathology-informed ACT*
- *Inpaint, transplant, or ignore? A factorial evaluation of lesion handling for structural connectomes in traumatic brain injury*

## Research questions

| ID | Question |
|----|----------|
| RQ1 (primary) | Does lesion-aware ACT produce systematically different connectomes than standard ACT within each anatomy backend? |
| RQ2 (secondary) | How much does anatomy mitigation (orig vs neuroLIT vs VBT) change connectomes, holding ACT fixed? |
| RQ3 (interaction) | Is ACT benefit larger after inpainting (anatomy × ACT interaction)? |
| RQ4 (operations) | What are completion rates, QC pass rates, and failure modes across six arms? |
| RQ5 (optional) | On synthetic lesions in healthy controls, does the pipeline recover expected connectivity loss (LeAPP-style)? |

## What's not asked

- Which arm is ground truth
- Whether disconnection predicts clinical recovery (that's Paper 2)

## Cohort and data

- Pilot: `sub-TBI011011` — 6-arm factorial complete on NAS (engineering gate)
- Flagship: ~100 TrackTBI subjects with lesion masks × 6 arms
- Synthetic-lesion validation (optional Tier B): CIDUR controls with injected lesions

## Analysis registry (fill before opening group results)

- [ ] Primary numeric outcome: **[choose one]** global matrix correlation | mean absolute edge difference
- [ ] Primary parcellation: DKT (78 regions) — SIFT2-weighted
- [ ] Contrast set: pre-specified in `TBI_Experimental_Arms.md § Pre-specified contrasts`
- [ ] Completion threshold: N ≥ __ per arm before group analysis opens

## Deliverables

- Six-arm QC-by-arm table
- Cohort completion CSV
- Matrix/edge sensitivity figures per contrast
- Representative case tractography renders
- Data availability: BIDS derivatives, Zenodo software DOI at manuscript tag

## Related pipeline docs

- Factorial spec: [../TBI_Experimental_Arms.md](../TBI_Experimental_Arms.md)
- Lesion-aware methods: [../lesion_aware.md](../lesion_aware.md)
- Step 3.1: [../methods/step3_1_lesion_act.md](../methods/step3_1_lesion_act.md)
- Validation: [../validation.md](../validation.md)
- References: [../references.md](../references.md)
