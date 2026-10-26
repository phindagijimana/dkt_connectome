# What DLSurfer does

DLSurfer orchestrates **deep-learning FreeSurfer-suite methods**: T1 morphometry
(any T1w → FreeSurfer-shaped `SUBJECTS_DIR`) plus multimodal specialty that covers
former FS non-morphometry gaps — TractSeg, PET-DL, DeepPrep, BrainQCNet.

**Specialty DL is first-class** (structure *and* multimodal), callable alone
(`dlsurfer tool …`). Lesion inpainting is optional. Trust ranks **A/B/C/D** —
[Credibility](reference/CREDIBILITY.md). Classical FS gated (`--allow-classical`).

---

## Each stage in a paragraph

**Fill (optional) — Inpaint the lesion on T1w.** With profile `core-lesion` and a lesion mask, neuroLIT fills the cavity on T1w *before* VINN / surfaces so cortical reconstruction sees contiguous anatomy. Diffusion is unchanged (DLSurfer is T1-only). Skip by using `core` or omitting the mask.

**Segment — Whole-brain labels.** FastSurfer VINN (`--seg_only --tal_reg`) writes DKT/aseg-style volumes plus optional CC, CerebNet, and HypVINN products into the SUBJECTS_DIR tree.

**Surfaces — White / pial / sphere / thickness.** `recon-surf --surf_only` (or FreeSurfer equivalents) builds the mesh stack that morphometry and atlas mapping need.

**Post (optional) — Pack LIT products.** lit-postprocessing can attach inpainting outputs to the FS tree for QC and provenance.

**Specialty (first-class) — Structure & surface DL.** Claustrum, HippUnfold, MARS,
ScLimbic, thalamic CNN, SynthSR, TopoFit, V2C-Flow, SUGAR, CortexMorph, etc. —
see [Structure modules](reference/STRUCTURE_MODULES.md), `dlsurfer tools`, and
[Credibility](reference/CREDIBILITY.md). Experimental (C) specialty stays
callable; some profiles need open [gates](usage/gates.md) before `--execute`.

---

## Stage table

| Stage | What happens | Default engine |
|-------|----------------|----------------|
| **Fill (optional)** | Inpaint lesion cavity on T1w so VINN/surfaces see contiguous anatomy | neuroLIT standalone (`core-lesion`) |
| **Segment** | Whole-brain DKT/aseg (+ CC, CerebNet, HypVINN) | FastSurfer VINN `--seg_only --tal_reg` |
| **Surfaces** | White/pial, sphere, thickness, aparc in SUBJECTS_DIR | recon-surf `--surf_only` |
| **Post (optional)** | Pack LIT products into the FS tree | lit-postprocessing |
| **Specialty** | Claustrum, HippUnfold, MARS, ScLimbic, SynthSR, TopoFit, … (A/B/C) | `dlsurfer tool` / profile |

**Biological note (lesions):** Large lesions break cortical surface reconstruction because FastSurfer/FreeSurfer expect contiguous GM. Fill modifies T1w *before* segmentation/surfaces so labels can be estimated on a plausible whole-brain anatomy. That is **not** a claim that tissue inside the lesion is healthy.

**Not DWI / not DKT connectome:** Tractography, SIFT2, disconnectome, and QSIPrep live in [DKT Connectome](https://dkt-connectome.readthedocs.io/). DLSurfer only owns T1 morphometry orchestration; see [Isolation](reference/ISOLATION.md).

**Engine policy:** Wrap FastSurfer/FS for production SUBJECTS_DIR — [why](workflows/engine_policy.md).
