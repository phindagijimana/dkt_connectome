# Paper 3 — Deep Atropos vs HSVS 5TT (supplement, deprioritized)

**Status:** Deprioritized — treated as a supplement inside Paper 1, not a
standalone manuscript. Only escalate to its own paper if a full cohort
Deep Atropos branch (N ≥ 30 paired) is run.

**Target:** Paper 1 supplement (default); *NeuroImage: Reports* or
*Medical Image Analysis* only if standalone.

**Cross-refs:** [publication_strategy.md § Paper 3](publication_strategy.md#paper-3--deep-atropos-vs-hsvs-optional-deprioritized)
· [../deep_atropos_5tt.md](../deep_atropos_5tt.md)

---

## One-paragraph summary

A paired head-to-head of two five-tissue-type segmentation sources —
native-T1 Deep Atropos vs HSVS-on-mitigated-T1 — for pathology-informed
ACT in TBI. Under the current plan, this is a single sensitivity figure
inside Paper 1 using the `deep-atropos-pilot` arm on sub-TBI011011, not a
standalone manuscript. It would only escalate to its own paper if a full
cohort branch (N ≥ 30 paired subjects) is run and shows systematic,
non-noise 5TT or connectome differences at the lesion rim.

## Candidate titles

**Default (supplement section):**
- *Supplementary: sensitivity of tissue-segmentation source (HSVS vs native-T1 Deep Atropos) for pathology-informed ACT*

**If forced into standalone:**
- *Deep Atropos vs HSVS for pathology-informed tractography in focal brain lesions: a paired cohort comparison*
- *Native-T1 Deep Atropos five-tissue-type segmentation for lesion-aware connectome analysis: a head-to-head with HSVS in TBI*

## Research questions

| ID | Question |
|----|----------|
| RQ1 | Do Deep Atropos and HSVS differ in 5TT / tissue classification at the lesion and rim? |
| RQ2 | Do 5TT differences translate into systematic paired connectome differences? |
| RQ3 | Which source is more operationally viable (QA, empty nodes, failures, runtime)? |

## Gate for escalation to standalone

- Cohort Deep Atropos branch run on N ≥ 30 paired subjects
- Paired 5TT + connectome differences shown to be systematic and non-noise
- QA tradeoffs meaningful (not just runtime deltas)

## Related pipeline docs

- Deep Atropos branch: [../deep_atropos_5tt.md](../deep_atropos_5tt.md)
- Lesion-aware methods: [../lesion_aware.md](../lesion_aware.md)
- References: [../references.md](../references.md)
