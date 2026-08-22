# Methods overview

Per-step **theory, biology, and citations** for the DKT Connectome.

| Audience | Start here |
|----------|------------|
| **Why** the pipeline exists (lesions, SDC, disconnectome) | **[Science overview](../science_overview.md)** |
| **How to run** each step (paths, flags, outputs) | **[Pipeline steps](../pipeline_steps.md)** |
| **Citations** (BibTeX tables) | **[References by step](../references.md)** |

This section follows [QSIPrep](https://qsiprep.readthedocs.io/) — one methods page per processing stage.

---

## Methods by step

| Step | Page | Primary tools | What you cite |
|------|------|---------------|---------------|
| **1** | [QSIPrep preprocessing](step1_qsiprep.md) | QSIPrep, TOPUP/SyN | Cieslak et al. 2021 |
| **1.5** | [Lesion inpainting & VBT](step1_5_inpaint.md) | neuroLIT (DDPM); optional VBT | Pollak et al. 2025; Bey et al. 2024 (VBT) |
| **2** | [Cortical reconstruction](step2_recon.md) | FreeSurfer / FastSurfer | Fischl 2012; Klein & Tourville 2012 |
| **3** | [Tractography](step3_qsirecon.md) | QSIRecon, MRtrix3 SS3T-ACT-HSVS | Cieslak et al. 2024; Smith et al. 2012 |
| **3.5** | [Lesion-aware ACT](step3_5_lesion_act.md) | MRtrix3 `5ttedit -path` + iFOD2/SIFT2 | Bey et al. 2024; Smith et al. 2012 |
| **4** | [DKT connectome](step4_connectome.md) | ANTs + MRtrix3 (multi-measure) | Tournier et al. 2019; Jones et al. 2013 |
| **4.5** | [Disconnectome](step4_5_disconnectome.md) | Custom excision | Griffis et al. 2019 |
| **5** | [Node strength report](step5_node_strength.md) | nodestrength container | Rubinov & Sporns 2010; Piper et al. 2026 |

---

## Related pages

- [Science overview](../science_overview.md) — end-to-end flow, physics summary, default choices
- [Pipeline steps](../pipeline_steps.md) — operational reference
- [Disconnectome](../disconnectome.md) — CLI defaults and QC (Step 4.5 user guide)
- [Comparisons](../comparisons.md) — vs other pipelines
- Developer deep-dive: [pipeline_science.md on GitHub](https://github.com/phindagijimana/dkt_connectome/blob/main/dwi_pipeline/pipeline_science.md)
