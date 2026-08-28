# How it works — science and theory

This page explains **why** the DKT Connectome pipeline exists and **what each step does scientifically**. For CLI flags and file paths, see [Pipeline steps](pipeline_steps.md). For step-by-step methods with citations, see [Methods overview](methods/index.md).

---

## Scientific goal

**Structural connectomics** maps white-matter pathways between brain regions as a graph: nodes (parcels) and edges (streamline counts or weights between them). After **traumatic brain injury (TBI)** or other focal lesions, standard pipelines still build connectomes on **lesioned anatomy** — but cortical segmentation, registration, and tractography were largely designed for **healthy** brains.

The DKT Connectome is a **lesion-aware** BIDS workflow that:

1. Preprocesses diffusion MRI with explicit **susceptibility-distortion** choices for every subject  
2. Optionally **inpaints** lesioned T1w before reconstruction when you supply a manual mask  
3. Builds a **Desikan–Killiany–Tourville (DKT, 78-node)** connectome on a tractography grid aligned to QSIPrep  
4. Optionally quantifies **structural disconnection** when you pass `--disconnection`

It is **study-agnostic**: any BIDS DWI + T1w dataset can run; lesion-specific steps activate only when masks are present.

---

## The problem with “standard” connectomes on injured brains

| Issue | What goes wrong | This pipeline’s response |
|-------|-----------------|-------------------------|
| Lesion in T1w | FreeSurfer/FastSurfer expect healthy GM/WM/CSF; large cavities break segmentation and **global registration** | **Step 1.5:** neuroLIT DDPM inpainting fills the lesion on T1w before recon |
| Lesion in registration | T1w–DWI alignment can be dominated by the cavity | **Step 1:** QSIPrep cost-function masking when a BIDS lesion mask exists |
| Lesion ignored after Step 1 | Mask used only once, then discarded | Mask carried through to **Step 4.5** disconnectome |
| Implicit SDC | Mixed vendors / missing fieldmaps → inconsistent distortion correction | **Explicit SDC mode** per subject (fmap TOPUP, SyN, or documented `--no-sdc`) |

Inpainting changes **only the T1w that feeds reconstruction and label warping** — it does **not** alter preprocessed DWI. Diffusion signal and tractography (Steps 1 and 3) remain physically consistent with the acquired data.

---

## End-to-end flow (conceptual)

```{figure} img/pipeline_overview.svg
:alt: DKT Connectome pipeline overview
:align: center
:width: 100%

BIDS inputs (T1w, DWI, optional fieldmaps and lesion mask) through QSIPrep, optional neuroLIT inpainting, reconstruction, QSIRecon ACT tractography, DKT connectome, optional disconnectome, and node-strength reporting.
```

**Key geometric principle:** streamlines live on a shared **tractography grid** (`dwiref`, ~2 mm, from QSIPrep). FreeSurfer labels start in **conformed surface space**; Step 4 warps them onto `dwiref` before counting streamlines. See [Step 4 — spatial alignment](methods/step4_connectome.md#spatial-alignment).

---

## Physics and mathematics (at a glance)

### Diffusion MRI (Step 1)

Water diffusion is anisotropic in white matter. DWI measures signal along gradient directions; preprocessing must correct **motion**, **eddy currents**, and **EPI susceptibility distortion** before modeling. QSIPrep standardizes this in BIDS form ([Cieslak et al. 2021](methods/step1_qsiprep.md)).

### FODs and tractography (Step 3)

**Constrained spherical deconvolution (CSD)** estimates fiber orientation distributions (FODs) per voxel. **Single-shell three-tissue (SS3T)** CSD fits single-shell data (typical b ≈ 1000 s/mm²). **Anatomically constrained tractography (ACT)** uses a **five-tissue-type (5TT)** image so streamlines terminate at GM/CSF boundaries rather than crossing them arbitrarily ([Smith et al. 2012](methods/step3_qsirecon.md)). **HSVS** builds 5TT from FreeSurfer surfaces + volumes for better cortical priors than volume-only FAST.

### Connectome (Step 4)

Streamlines are assigned to **DKT parcels** (78 nodes: cortical + subcortical). **MRtrix3 `tck2connectome`** counts streamlines connecting each pair (default) or applies **SIFT2** weights. Output: symmetric `dkt_connectome.csv` ([Klein & Tourville 2012](methods/step4_connectome.md)).

### Disconnectome (Step 4.5, optional)

Three complementary models ([Griffis et al. 2019](methods/step4_5_disconnectome.md)):

- **Option A** — remove lesion voxels from the parcellation  
- **Option B** — discard streamlines intersecting the lesion  
- **Option C** — both  

A **disconnection matrix** compares spared connectivity to the intact Step 4 graph. **Off by default** while methods are validated at scale — enable with `--disconnection`.

---

## Default scientific choices

| Choice | Default | Why |
|--------|---------|-----|
| DWI shell | b = 1000 | Single-shell SS3T-CSD needs one non-zero shell |
| Tractography | `mrtrix_singleshell_ss3t_ACT-hsvs` | ACT + hybrid surface/volume 5TT (needs Step 2) |
| Parcellation | DKT, 78 nodes | Stable across FreeSurfer and FastSurfer |
| Edge weight | Streamline **counts** | Simple, widely reported; SIFT2 optional |
| Inpainting | Auto if BIDS lesion mask | Improves recon near lesions |
| Disconnectome | Off | Pass `--disconnection` to opt in |

---

## Methods deep-dive (by step)

| Step | Read next | Primary citation |
|------|-----------|------------------|
| 1 — QSIPrep | [step1_qsiprep.md](methods/step1_qsiprep.md) | Cieslak et al. 2021 |
| 1.5 — Inpainting | [step1_5_inpaint.md](methods/step1_5_inpaint.md) | Pollak et al. 2025 |
| 2 — Recon | [step2_recon.md](methods/step2_recon.md) | Fischl 2012; Klein & Tourville 2012 |
| 3 — Tractography | [step3_qsirecon.md](methods/step3_qsirecon.md) | Cieslak et al. 2024; Tournier et al. 2019 |
| 4 — Connectome | [step4_connectome.md](methods/step4_connectome.md) | MRtrix3 connectome tools |
| 4.5 — Disconnectome | [step4_5_disconnectome.md](methods/step4_5_disconnectome.md) | Griffis et al. 2019 |
| 5 — Node strength | [step5_node_strength.md](methods/step5_node_strength.md) | Rubinov & Sporns 2010 |

BibTeX and acknowledgment text: [Citation](citation.md) · [References by step](references.md).

---

## Validation and scope

- **Integrity checks** and benchmark notes: [Validation](validation.md)  
- **Manuscript planning** (TrackTBI ~100 lesion cohort, factorial arms, journal targets): [Publication strategy](publication_strategy.md)  
- **Compared to QSIPrep-only, MRtrix3_connectome, micapipe:** [Comparisons](comparisons.md)  
- **Developer reference** (~800 lines, registration math, alternatives): [pipeline_science.md on GitHub](https://github.com/phindagijimana/dkt_connectome/blob/main/dwi_pipeline/pipeline_science.md)

---

## Ready to run?

1. [Installation](installation.md) — containers + **your** FreeSurfer license  
2. [Tutorial](tutorial.md) — first dry-run and real subject  
3. [Preparing your data](preparing_data.md) — BIDS, fieldmaps, lesion masks
