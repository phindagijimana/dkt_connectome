# DLSurfer claim boundary (v0.2 — identity frozen)

## Product identity

**Deep-learning FreeSurfer-suite methods:** FastSurferVINN morphometry + Synth* +
T1 specialty (HippUnfold, MARS, ScLimbic, …) + **multimodal DL specialty**
(TractSeg, PET-DL quant, DeepPrep, BrainQCNet). Not TBI-only. Lesion fill optional.

Credibility **A/B/C** (specialty allowed) · **D** classical gated — see
[CREDIBILITY.md](CREDIBILITY.md).

## We claim

- Orchestration of **validated** DL tools across morphometry and FS non-morphometry gaps.
- FreeSurfer-**shaped** `SUBJECTS_DIR` for T1 core (`dlsurfer recon-all` ≠ classical `recon-all`).
- Specialty modules callable alone (`dlsurfer tool` / `dlsurfer-*`), including multimodal.
- Optional lesion path via **standalone** neuroLIT when a mask is given.
- Transparent citations + documented alternatives per engine.
- **Isolation** from the DKT connectome codebase (this folder only).

## We do not claim

- Better anatomy than FastSurfer or FreeSurfer.
- Bit-identity with classical `recon-all` or TRACULA stats.
- That TractSeg/DeepPrep/PET-DL are drop-in clones of every FS flag.
- A DL replacement for interactive `-autorecon2-*` FreeView edit loops.
- Ownership of production DKT connectome / ACT pipelines.
- That **C**-tier or ops-incomplete **B** specialty is production-default everywhere.
- That “wired in DLSurfer” means “validated for every clinical cohort.”

## Boilerplate

> Products were generated with **DLSurfer**, a deep-learning FreeSurfer-suite
> orchestrator under `others_methods/preprocessing/DL/dlsurfer/` that calls published
> DL tools (FastSurfer / Synth* / specialty morphometry and multimodal modules).
> DLSurfer does not replace FreeSurfer or FastSurfer science and is not part of the
> DKT connectome pipeline; cite engines via `dlsurfer cite --profile <profile>`.
