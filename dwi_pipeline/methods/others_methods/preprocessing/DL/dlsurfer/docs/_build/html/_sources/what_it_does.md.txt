# What DLSurfer does

DLSurfer is a curated orchestrator that takes a subject's **T1-weighted MRI** (and optionally a lesion mask) and builds a **FreeSurfer-shaped `SUBJECTS_DIR`**: segmentation, surfaces, and thickness that downstream tools (including [DKT Connectome](https://dkt-connectome.readthedocs.io/)) already know how to read.

The workflow is **study-agnostic**. Any T1w cohort can run. Lesion-specific steps (neuroLIT inpainting, lesion profiles) stay off unless you pick a lesion profile and pass a mask. It wraps FastSurfer, FreeSurfer, and optional specialty engines — it does not replace those tools; it pins them and writes classical SUBJECTS_DIR layout.

---

## Each stage in a paragraph

**Fill (optional) — Inpaint the lesion on T1w.** With profile `core-lesion` and a lesion mask, neuroLIT fills the cavity on T1w *before* VINN / surfaces so cortical reconstruction sees contiguous anatomy. Diffusion is unchanged (DLSurfer is T1-only). Skip by using `core` or omitting the mask.

**Segment — Whole-brain labels.** FastSurfer VINN (`--seg_only --tal_reg`) writes DKT/aseg-style volumes plus optional CC, CerebNet, and HypVINN products into the SUBJECTS_DIR tree.

**Surfaces — White / pial / sphere / thickness.** `recon-surf --surf_only` (or FreeSurfer equivalents) builds the mesh stack that morphometry and atlas mapping need.

**Post (optional) — Pack LIT products.** lit-postprocessing can attach inpainting outputs to the FS tree for QC and provenance.

**Specialty (optional) — Profile-selected engines.** Claustrum, hippocampal/brainstem/thalamic modules, SynthSR, TopoFit, Schaefer, V2C-Flow, SUGAR, CortexMorph, and related tools stay gated until lab evidence clears — see [Gates](usage/gates.md) and [Surfaces (Phase 3)](workflows/surfaces.md).

---

## Stage table

| Stage | What happens | Default engine |
|-------|----------------|----------------|
| **Fill (optional)** | Inpaint lesion cavity on T1w so VINN/surfaces see contiguous anatomy | neuroLIT standalone (`core-lesion`) |
| **Segment** | Whole-brain DKT/aseg (+ CC, CerebNet, HypVINN) | FastSurfer VINN `--seg_only --tal_reg` |
| **Surfaces** | White/pial, sphere, thickness, aparc in SUBJECTS_DIR | recon-surf `--surf_only` |
| **Post (optional)** | Pack LIT products into the FS tree | lit-postprocessing |
| **Specialty** | Claustrum, HA/BS/thal, SynthSR, TopoFit, … | Profile-selected |

**Biological note (lesions):** Large lesions break cortical surface reconstruction because FastSurfer/FreeSurfer expect contiguous GM. Fill modifies T1w *before* segmentation/surfaces so labels can be estimated on a plausible whole-brain anatomy. That is **not** a claim that tissue inside the lesion is healthy.

**Not DWI / not DKT connectome:** Tractography, SIFT2, disconnectome, and QSIPrep live in [DKT Connectome](https://dkt-connectome.readthedocs.io/). DLSurfer only owns T1 morphometry orchestration; see [Isolation](reference/ISOLATION.md).

**Engine policy:** Wrap FastSurfer/FS for production SUBJECTS_DIR — [why](workflows/engine_policy.md).
