# DLSurfer claim boundary (Phase 0 — frozen)

## We claim

- One-entry orchestration of **validated** DL tools from FreeSurfer and FastSurfer (plus selected Ready externals).
- FreeSurfer-**shaped** `SUBJECTS_DIR` for DKT / QSIRecon handoff.
- Device policy: GPU for fill/seg, CPU for recon-surf.
- First-class lesion path via **standalone** neuroLIT (HPC-split safe).
- Transparent citations for every engine actually run.

## We do not claim

- Better anatomy than FastSurfer or FreeSurfer.
- A reimplementation of VINN, Synth*, recon-surf, or FreeSurfer.
- Full FreeSurfer suite coverage (longitudinal, every subfield, TRACULA, …).
- Bit-identity with `recon-all`.
- That experimental `surf-dl-*` profiles are production-ready without TBI±LIT validation.

## Boilerplate (paste into papers / README)

> Anatomical products were generated with **DLSurfer**, an orchestration layer that calls published deep-learning tools (primarily FastSurfer / neuroLIT / FreeSurfer Synth*). DLSurfer does not replace FreeSurfer or FastSurfer methods; cite the engines listed by `dlsurfer cite --profile <profile>`.
