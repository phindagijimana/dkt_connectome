# DLSurfer claim boundary (Phase 0 — frozen)

## We claim

- One-entry orchestration of **validated** DL tools from FreeSurfer and FastSurfer (plus selected Ready externals).
- FreeSurfer-**shaped** `SUBJECTS_DIR` outputs (atlas-flexible; **DKT default**, not exclusive).
- Device policy: GPU for fill/seg, CPU for recon-surf.
- First-class lesion path via **standalone** neuroLIT (HPC-split safe).
- Transparent citations + documented **runner-up alternatives** for every chosen engine.
- **Isolation** from the DKT connectome codebase (this folder only).
- Optional specialty modules (Mauri claustrum, SynthSeg-PC experimental, SynthSR preprocess, HippUnfold) that FS/FastSurfer core do not provide — see `STRUCTURE_MODULES.md`.

## We do not claim

- Better anatomy than FastSurfer or FreeSurfer.
- A reimplementation of VINN, Synth*, recon-surf, or FreeSurfer.
- Full FreeSurfer suite coverage (longitudinal, every subfield, TRACULA, …).
- Bit-identity with `recon-all`.
- Ownership of connectome / ACT / disconnectome (that is DKT or other consumers).
- That experimental `surf-dl-*` profiles are production-ready without TBI±LIT validation.

## Boilerplate

> Anatomical products were generated with **DLSurfer**, an orchestration layer under `others_methods/preprocessing/DL/dlsurfer/` that calls published deep-learning tools (primarily FastSurfer / neuroLIT / FreeSurfer Synth*). DLSurfer does not replace FreeSurfer or FastSurfer methods and is not part of the DKT connectome pipeline; cite engines via `dlsurfer cite --profile <profile>`.
