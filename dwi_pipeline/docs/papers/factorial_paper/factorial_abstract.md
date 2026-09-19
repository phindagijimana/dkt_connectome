# Factorial paper — honest working abstract

**Purpose:** internal working abstract to share with PI and collaborators.
Written honestly — reflects what we plan to do, what's contingent on
execution, and what we deliberately are *not* claiming. This is not the
submission-ready abstract (that comes after results are in and results-
dependent language is possible).

**Related docs:** [index.md](index.md) · [factorial_missing.md](factorial_missing.md) ·
[analysis_plan.md](analysis_plan.md) · [leapp_lineage.md](leapp_lineage.md)

**Status:** DRAFT for PI/collaborator review, 2026-09-18.
Target: HBM default, NeuroImage stretch (with synthetic-lesion validation).

---

## Working title

*Lesion-aware structural connectomics in traumatic brain injury: a factorial
comparison of inpainting, virtual brain transplant, and pathology-informed
tractography.*

## Honest abstract (~300 words)

**Background.** Focal traumatic brain injury (TBI) breaks the assumptions
of standard structural connectome pipelines. Two independent decisions
each change the resulting connectome: (1) whether the T1w is corrected
before cortical reconstruction, and (2) whether tractography treats the
lesion mask as pathological tissue. For ischemic stroke, Bey et al. (2024,
*Human Brain Mapping*) evaluated these two axes factorially, introducing
the LeAPP framework (Lesion-Aware automated Processing Pipeline).
Whether the framework generalizes to TBI — where lesion morphology is
heterogeneous (contusion, oedema, hemorrhage, bilateral injury) — is
unknown.

**Question.** Does the LeAPP anatomy × ACT factorial framework generalize
to TBI at cohort scale, and does the addition of a third anatomy backend
(neuroLIT DDPM inpainting; Pollak et al. 2025) meaningfully differ from
the deterministic virtual-brain-transplant approach LeAPP uses?

**Approach.** We process ~100 TrackTBI subjects with clinician-traced
lesion masks through a 3 × 2 factorial (anatomy: original / neuroLIT / VBT;
ACT: standard / pathology-informed) with isolated per-arm outputs.
Pre-specified contrasts test main effects, interaction, and per-arm
completion / failure modes. Reproducibility infrastructure — containerized
pipeline, per-step provenance JSON, Snakemake DAG, BIDS-App wrapper — is
distributed openly.

**Anticipated findings (results-dependent).** We expect (a) lesion-aware
ACT to change connectomes within each anatomy backend by a measurable
amount, (b) neuroLIT and VBT to diverge in a subgroup where VBT's mirror
assumption strains (bilateral injury; ~30–40% of moderate-severe TBI),
and (c) per-arm completion rates to differ non-trivially — providing
the field with a calibrated map of when each preprocessing choice
matters.

**Interpretation caveats.** This is methods-sensitivity science, not
biological discovery. We do not claim which arm is "correct." Clinical-
outcome linkage is out of scope (that is our Paper 2). Results depend on
cohort N delivery and cohort heterogeneity; a small subset of arms may
require failure-mode framing rather than direct comparison.

---

## What this paper *is*

- A cohort-scale test of whether the LeAPP framework generalizes from stroke to TBI
- A three-way anatomy comparison (orig / neuroLIT / VBT) — first factorial evaluation of neuroLIT alongside VBT in real lesioned brains
- A calibrated methods-sensitivity result telling future TBI network studies which preprocessing knobs matter
- A distributable, containerized pipeline for future users
- Honest per-arm completion / QC reporting — pass and fail rates, not just success stories

## What this paper *is not*

- Not a discovery of new TBI biology
- Not a new tractography or inpainting technique (all algorithms adopted from cited prior work)
- Not a clinical outcome / prognostic paper (that's Paper 2)
- Not a claim about which arm is ground truth — no arm has that status
- Not a Nature-tier finding; realistically HBM by default, NeuroImage with additional synthetic-lesion validation

---

## Contingencies acknowledged for PI / collaborator review

1. **Cohort N delivery.** Target ~100 subjects with lesion masks; actual delivery depends on TrackTBI mask availability and processing success rate. If N < 40 per arm, framing shifts to failure-mode analysis; likely venue tier caps at HBM with limitations.
2. **VBT technical failures on bilateral cases.** Documented risk (midtrans SIGSEGV observed on pilot). Fold into first-class failure-mode result rather than dropping subjects.
3. **neuroLIT out-of-distribution behavior.** Pollak 2025 validated on healthy + simulated lesions; real TBI patterns may push the DDPM out of distribution. Sensitivity supplement recommended.
4. **Deep Atropos supplement scope.** Currently a pilot-only sensitivity figure; scaling to N ≥ 30 subjects is a decision point.
5. **Synthetic-lesion validation on CIDUR controls.** Optional but recommended for NeuroImage-tier submission (matches LeAPP's methodological completeness). Adds ~4 weeks of compute + analysis.

---

## Suggested citation of prior work in intro (for coauthor review)

- **Direct precedent:** Bey et al. 2024 *HBM* (LeAPP — the framework we extend)
- **Anatomy technique lineage:** Radwan et al. 2020 *HBM* (VBG — VBT's origin); Pollak et al. 2025 *Imaging Neuroscience* (neuroLIT DDPM)
- **ACT technique:** Smith et al. 2012 *NeuroImage* (foundation)
- **TBI precedent:** Radwan et al. 2023 *Network Neuroscience* (TBI + VBG + ACT, N=5)
- **TBI cohort scale:** Palacios et al. 2022 *Journal of Neurotrauma* (TRACK-TBI DTI, N≈391)
- **Pipeline infrastructure:** Cieslak et al. 2021 (QSIPrep); Tournier et al. 2019 (MRtrix3); Fischl 2012 (FreeSurfer); Henschel et al. 2020 (FastSurfer)

---

## What we ask coauthors to weigh in on

1. **Title framing** — is "factorial comparison" the right emphasis, or should we lead with "cohort-scale extension of LeAPP to TBI"?
2. **Deep Atropos supplement scope** — pilot only vs cohort-subset run?
3. **Synthetic-lesion validation decision** — pursue Tier B for NeuroImage-tier, or accept HBM default?
4. **Author list + CRediT contributions**
5. **Preferred initial submission venue** — HBM (safer) vs NeuroImage (higher tier if Tier B lands cleanly)

---

## See also

- [`index.md`](index.md) — full cover doc with cross-tier paper matrix
- [`factorial_missing.md`](factorial_missing.md) — submission-readiness checklist
- [`analysis_plan.md`](analysis_plan.md) — 13-section pre-registration template
- [`differentiation_from_leapp.md`](differentiation_from_leapp.md) — ranked menu of contribution additions
- [`../distance_novelty.md`](../distance_novelty.md) — contribution framework + per-paper contribution list
