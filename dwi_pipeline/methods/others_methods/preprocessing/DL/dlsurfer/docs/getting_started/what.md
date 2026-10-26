# What DLSurfer does

One paragraph per stage (same spirit as DKT Connectome’s step pages).

| Stage | What happens | Default engine |
|-------|----------------|----------------|
| **Fill (optional)** | Inpaint lesion cavity on T1w so VINN/surfaces see contiguous anatomy | neuroLIT standalone (`core-lesion`) |
| **Segment** | Whole-brain DKT/aseg (+ CC, CerebNet, HypVINN) | FastSurfer VINN `--seg_only --tal_reg` |
| **Surfaces** | White/pial, sphere, thickness, aparc in SUBJECTS_DIR | recon-surf `--surf_only` |
| **Post (optional)** | Pack LIT products into the FS tree | lit-postprocessing |
| **Specialty** | Claustrum, HA/BS/thal, SynthSR, TopoFit, … | Profile-selected |

**Biological note (lesions):** Large lesions break cortical surface reconstruction because FastSurfer/FreeSurfer expect contiguous GM. Fill modifies T1w *before* segmentation/surfaces so labels can be estimated on a plausible whole-brain anatomy. That is **not** a claim that tissue inside the lesion is healthy.

**Not DWI / not DKT connectome:** Tractography, SIFT2, disconnectome, and QSIPrep live in [DKT Connectome](https://dkt-connectome.readthedocs.io/). DLSurfer only owns T1 morphometry orchestration; see [Isolation](../reference/ISOLATION.md).

**Engine policy:** Wrap FastSurfer/FS for production SUBJECTS_DIR — [why](../workflows/engine_policy.md).
