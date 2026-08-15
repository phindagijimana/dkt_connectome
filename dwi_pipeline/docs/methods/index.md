# Methods overview

This section describes the **scientific theory and design rationale** behind each step of the DKT Connectome, with citations to the primary method papers. For operational details (CLI flags, file paths, troubleshooting), see [Pipeline steps](../pipeline_steps.md). For BibTeX and acknowledgment text, see [Citation](../citation.md).

The layout follows [QSIPrep](https://qsiprep.readthedocs.io/) — one methods page per major processing stage, each linking to [References by step](../references.md).

---

## End-to-end flow

Structural connectomics here means: preprocess diffusion MRI, reconstruct anatomy, trace white-matter pathways, assign streamlines to brain regions, and optionally quantify lesion-related disconnection.

```text
BIDS (T1w + DWI [+ fmap] [+ lesion mask])
        │
        ▼
Step 1    QSIPrep           Motion, denoising, SDC, T1w–DWI alignment
        │
        ▼ (optional)
Step 1.5  neuroLIT          DDPM inpainting when a BIDS lesion mask exists
        │
        ▼
Step 2    FreeSurfer /      Cortical surfaces + DKT parcellation (78 nodes)
          FastSurfer
        │
        ▼
Step 3    QSIRecon          SS3T-CSD, ACT-HSVS tractography, SIFT2 weights
        │
        ▼
Step 4    Connectome        Warp DKT labels → DWI grid; tck2connectome
        │
        ├─► (optional) Step 4.5 Disconnectome — lesion excision + D matrix
        │
        ▼
Step 5    Node strength     Graph metrics + ENIGMA-style clinical report
```

**Key principle:** tractography and connectome counting happen on a **common 3D grid** (`dwiref`, derived from QSIPrep's preprocessed T1w). FreeSurfer labels start in conformed surface space; Step 4 resamples them onto the tractography grid before counting streamlines.

---

## Methods by step

| Step | Page | Primary tools | What you cite |
|------|------|---------------|---------------|
| **1** | [QSIPrep preprocessing](step1_qsiprep.md) | QSIPrep, TOPUP/SyN | Cieslak et al. 2021 |
| **1.5** | [Lesion inpainting](step1_5_inpaint.md) | neuroLIT (DDPM) | Pollak et al. 2025 |
| **2** | [Cortical reconstruction](step2_recon.md) | FreeSurfer / FastSurfer | Fischl 2012; Klein & Tourville 2012 |
| **3** | [Tractography](step3_qsirecon.md) | QSIRecon, MRtrix3 SS3T-ACT-HSVS | Cieslak et al. 2024; Smith et al. 2012 |
| **4** | [DKT connectome](step4_connectome.md) | ANTs + MRtrix3 | Tournier et al. 2019; Klein & Tourville 2012 |
| **4.5** | [Disconnectome](step4_5_disconnectome.md) | Custom excision | Griffis et al. 2019 |
| **5** | [Node strength report](step5_node_strength.md) | nodestrength container | Rubinov & Sporns 2010; Piper et al. 2026 |

---

## Coordinate spaces (why registration matters)

| Space | Typical grid | Used for |
|-------|--------------|----------|
| BIDS native T1w | Scanner-native | Input anatomy, lesion masks |
| QSIPrep `desc-preproc_T1w` | ~1 mm isotropic | Registration reference after Step 1 |
| `dwiref` | ~2 mm (tractography grid) | Streamlines, `nodes.mif`, connectome matrix |
| FreeSurfer conformed | 256³ | `aparc.DKTatlas+aseg.mgz` before warping |

Step 4 performs a three-stage warp chain (FreeSurfer conformed → native T1w → preproc T1w → `dwiref`). See [DKT connectome](step4_connectome.md#spatial-alignment) for details.

---

## Default scientific choices

| Choice | Default | Rationale |
|--------|---------|-----------|
| DWI shell | b = 1000 (`dwi_select_b1000.json`) | Single-shell SS3T-CSD requires one non-zero b-value |
| Tractography spec | `mrtrix_singleshell_ss3t_ACT-hsvs` | ACT with hybrid surface/volume 5TT (needs Step 2 surfaces) |
| Parcellation | DKT, 78 nodes | Consistent across FreeSurfer and FastSurfer cohorts |
| Connectome weighting | Streamline **counts** | Simple, widely used; optional SIFT2 weighting |
| Disconnectome | Off (`--disconnection` to enable) | Method under validation |
| Inpainting | Auto when BIDS lesion mask present | Improves recon quality around lesions |

Alternatives and trade-offs: [Comparisons](../comparisons.md) · Developer deep-dive: [pipeline_science.md](https://github.com/phindagijimana/dkt_connectome/blob/main/dwi_pipeline/pipeline_science.md).

---

## Related pages

- [Pipeline steps](../pipeline_steps.md) — operational step reference
- [References by step](../references.md) — full citation tables
- [Preparing your data](../preparing_data.md) — BIDS inputs, SDC, lesion masks
- [Outputs](../outputs.md) — derivatives layout
- [Disconnectome](../disconnectome.md) — CLI defaults and QC for Step 4.5
