# Paper 2B — working abstract (pre-results)

**Status:** DRAFT for PI review · **Target:** *NeuroImage* / *HBM*

**Related:** [planning.md](planning.md) · [index.md](index.md)

---

## Working title

*Patient-specific lesion-aware disconnectomes in traumatic brain injury: comparison with normative-atlas tools and coupling to resting-state functional disconnection*

---

## Abstract (~250 words)

**Background.** Structural disconnection (SDC) quantifies how focal lesions interrupt white-matter pathways. Clinical and computational studies often use **normative-atlas** tools (Lesion Quantification Toolkit, BCBtoolkit) that overlay lesions on healthy tractography templates. In **traumatic brain injury**, mass effect, oedema, and bilateral injury deform individual anatomy, potentially violating template assumptions. **Patient-specific** SDC from lesion-aware diffusion MRI tractography avoids template anatomy but is less often benchmarked against normative tools in the same cohort.

**Methods.** In [N] adults with clinician-traced TBI lesions ([visit]), we computed SDC using (1) our **patient-specific lesion-aware** pipeline (fixed `neurolit-lesion` arm, DKT-78) and (2) **LQT** normative-atlas SDC on registered lesion masks. Resting-state fMRI was processed with fMRIPrep and XCP-D; **empirical functional disconnection** (Arm B) was derived on the same DKT-78 graph with lesion-aware spared connectivity. We quantified edge-wise agreement between SDC methods, lesion-feature moderators of disagreement, and association strength between structural and functional disconnection (patient-specific vs LQT). fMRIStroke denoising was a pre-specified sensitivity stream.

**Results.** [Placeholder: distribution of patient-specific vs LQT correlations; fraction with substantial divergence; SC↔FC association comparison; representative cases.]

**Interpretation.** [Placeholder: when normative SDC is adequate vs when patient-specific DWI SDC is required in TBI; implications for connectome studies that do not report comparator choice. **No clinical outcome claims.**]

---

## Is / is-not

| This paper **is** | This paper **is not** |
|-------------------|------------------------|
| Methods head-to-head in TBI | GOSE / neuropsych prediction paper |
| SC ↔ empirical FC mechanism | Full Griffis behavior chain |
| Honest negative result if LQT ≈ patient-specific | Paper 1 factorial anatomy study |
