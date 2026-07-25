# Pipeline Science Reference

**DWI connectivity pipeline — physics, biology, mathematics, geometry, and software**

This document explains the scientific concepts behind the four-stage workflow implemented in `subject.sh`:

1. **QSIPrep** — diffusion MRI preprocessing  
2. **FreeSurfer / FastSurfer** — anatomical reconstruction and parcellation  
3. **QSIRecon** (`mrtrix_singleshell_ss3t_ACT-hsvs`) — constrained tractography  
4. **DK connectome** — Desikan–Killiany region-to-region connectivity from FreeSurfer labels  

Default recon spec: **`mrtrix_singleshell_ss3t_ACT-hsvs`**. Alternative without Step 2: **`mrtrix_singleshell_ss3t_ACT-fast`** (FSL FAST 5TT).

---

## Table of contents

1. [End-to-end data flow](#1-end-to-end-data-flow)  
2. [Biology: brain tissues and parcellations](#2-biology-brain-tissues-and-parcellations)  
3. [Physics: diffusion MRI](#3-physics-diffusion-mri)  
4. [Mathematics: models, transforms, and connectivity](#4-mathematics-models-transforms-and-connectivity)  
5. [Geometry: coordinate spaces and surfaces](#5-geometry-coordinate-spaces-and-surfaces)  
6. [Five-tissue-type (5TT) images](#6-five-tissue-type-5tt-images)  
7. [FSL FAST segmentation](#7-fsl-fast-segmentation)  
8. [HSVS: Hybrid Surface–Volume Segmentation](#8-hsvs-hybrid-surfacevolume-segmentation)  
9. [Anatomically Constrained Tractography (ACT)](#9-anatomically-constrained-tractography-act)  
10. [CSD and SS3T response estimation](#10-csd-and-ss3t-response-estimation)  
11. [Tractography, SIFT2, and connectomes](#11-tractography-sift2-and-connectomes)  
12. [FreeSurfer / FastSurfer outputs used by the pipeline](#12-freesurfer--fastsurfer-outputs-used-by-the-pipeline)  
13. [DK connectome: label warping and matrix generation](#13-dk-connectome-label-warping-and-matrix-generation)  
14. [Software stack summary](#14-software-stack-summary)  
15. [Design choices and alternatives](#15-design-choices-and-alternatives)  
16. [References](#16-references)  

---

## 1. End-to-end data flow

```
BIDS (T1w + DWI [+ fieldmaps])
        │
        ├──────────────────────────────┐
        ▼                              ▼
   QSIPrep (Step 1)              FreeSurfer / FastSurfer (Step 2)
   • denoise, SDC, eddy          • cortical surfaces + aseg
   • DWI → T1w registration      • aparc+aseg.mgz, rawavg.mgz
   • desc-preproc_T1w, dwiref    • white/pial surfaces (HSVS input)
        │                              │
        └──────────────┬───────────────┘
                       ▼
              QSIRecon ACT-HSVS (Step 3)
              • build 5TT (HSVS) from FS surfaces + volumes
              • SS3T CSD → FODs → ACT tractography
              • optional atlas connectome (e.g. 4S156)
                       │
                       ▼
              DK connectome (Step 4)
              • warp aparc+aseg → dwiref grid
              • tck2connectome → 84×84 DK matrix
```

**Key principle:** Tractography and connectome counting happen on a **common 3D grid** (`dwiref`, ~2 mm in QSIPrep T1w space). Anatomical labels from FreeSurfer start in a **different space** (conformed 256³); Step 4 resamples them onto the tractography grid before counting streamlines.

---

## 2. Biology: brain tissues and parcellations

### 2.1 Gray matter (GM)

**Gray matter** is the neuronal cell-body–rich tissue of the cerebral cortex and deep nuclei. In MRI it appears **intermediate** in T1-weighted intensity (brighter than CSF, darker than fat; cortical GM is slightly darker than WM on T1).

**Roles in this pipeline:**

| Role | Mechanism |
|------|-----------|
| **ACT termination** | Streamlines may **end** when entering GM (axons synapse in cortex / subcortical targets). |
| **5TT volume 0** | Cortical GM probability map for tissue classification. |
| **Parcellation nodes** | Cortical regions in `aparc+aseg.mgz` (Desikan–Killiany or DKT atlas) define connectome rows/columns. |

Cortex is **folded** (gyri and sulci). Volume-only segmentations struggle at thin sulcal CSF; **surface-based** methods (FreeSurfer) follow the cortical sheet more accurately — a motivation for HSVS.

### 2.2 White matter (WM)

**White matter** consists largely of **myelinated axon bundles** connecting brain regions. On T1w MRI it is **hyperintense** relative to cortical GM.

**Roles in this pipeline:**

| Role | Mechanism |
|------|-----------|
| **Tractography substrate** | FOD peaks align with local fiber orientations inside WM. |
| **ACT propagation** | Streamlines **propagate** inside WM; invalid paths cut when leaving WM incorrectly. |
| **5TT volume 2** | WM probability / mask for ACT and response-function estimation. |
| **Subcortical WM pathways** | Thalamocortical, commissural, and association fibers tracked between GM nodes. |

Diffusion anisotropy is **high** in coherent WM (e.g. corpus callosum) and **low** in GM and CSF.

### 2.3 Cerebrospinal fluid (CSF)

**CSF** fills ventricles and subarachnoid space. On T1w it is **dark** (low signal).

**Roles in this pipeline:**

| Role | Mechanism |
|------|-----------|
| **ACT exclusion** | Streamlines should **not** propagate through CSF (no coherent fiber structure). |
| **Partial volume** | Voxels at GM–CSF or WM–CSF borders contaminate DWI signal; multi-tissue models (SS3T) mitigate this. |
| **5TT volume 3** | CSF probability map. |

Misclassified CSF at the cortical surface causes **false continuations** of streamlines into sulci — ACT uses accurate GM/CSF boundaries to prevent this.

### 2.4 Subcortical gray matter (subcortical GM)

**Subcortical GM** includes deep nuclei segmented in FreeSurfer’s **`aseg`** (automatic subcortical segmentation): thalamus, caudate, putamen, pallidum, hippocampus, amygdala, accumbens, brain stem, etc.

**Roles in this pipeline:**

| Role | Mechanism |
|------|-----------|
| **5TT volume 1** | Subcortical GM tissue class (separate from cortical GM in the 5TT format). |
| **ACT** | Streamlines may **terminate** entering subcortical GM (similar biological rule as cortex). |
| **DK connectome** | Subcortical structures appear as **nodes** in `aparc+aseg.mgz` (e.g. Left-Thalamus, Left-Caudate). |

Separating **cortical GM** and **subcortical GM** in the 5TT image lets ACT apply appropriate rules at the cortex vs. deep nuclei.

### 2.5 Pathological / other tissue (5TT volume 4)

The **fifth 5TT volume** captures **pathological or unclassified** tissue (e.g. lesions, resection cavities). In healthy controls it is often near zero. In TBI cohorts it can absorb **non-brain** or **abnormal** voxels so ACT does not treat them as normal WM.

### 2.6 Desikan–Killiany (DK) and DKT parcellations

The **DK atlas** defines **34 cortical regions per hemisphere** (68 cortical labels) plus subcortical labels from `aseg`. Step 4 maps FreeSurfer labels to MRtrix’s **`fs_default.txt`** lookup table and builds a **symmetric 84×84** connectivity matrix (zero diagonal).

The **DKT** protocol refines those boundaries for reproducibility and, in doing so, **removes three DK regions**: **bankssts**, the **frontal pole** and the **temporal pole**. DKT therefore has **31 cortical regions per hemisphere**, and a DKT connectome built on the same subcortical set has **78 nodes**.

**This distinction is operational, not academic, because it interacts with the recon tool.** FastSurfer writes DKT labels into **`aparc.DKTatlas+aseg.mapped.mgz`**, usually symlinked to **`aparc+aseg.mgz`**, and produces **no DK atlas at all** — there is no `lh.aparc.annot` and no DK volume in the tree. `recon-all`, by contrast, writes **both**: `aparc+aseg.mgz` (DK) and `aparc.DKTatlas+aseg.mgz` (DKT).

**DKT is therefore the only parcellation both tools can produce, and the pipeline standardises on it.** Step 4 outputs a 78-node DKT connectome by default whichever tool ran, reading the DKT image appropriate to the tree:

| Step 2 recon | `CONNECTOME_PARCELLATION` | Segmentation read | LUT | Matrix | Output file |
|---|---|---|---|---|---|
| `recon-all` (default) | `dkt` (default) | `aparc.DKTatlas+aseg.mgz` | `fs_dkt.txt` | 78×78 | `dkt_connectome.csv` |
| `--fastsurfer` | `dkt` (default) | `aparc+aseg.mgz` (is DKT) | `fs_dkt.txt` | 78×78 | `dkt_connectome.csv` |
| `recon-all` | `dk` | `aparc+aseg.mgz` | `fs_default.txt` | 84×84 | `dk_connectome.csv` |
| `--fastsurfer` | `dk` | `aparc+aseg.mgz` (is DKT) | `fs_default.txt` | 84×84, **6 empty nodes** | `dk_connectome.csv` |

The practical consequence is that **`--fastsurfer` changes how long Step 2 takes, not the node set**. A cohort in which some subjects ran `recon-all` and others FastSurfer still pools into one 78-node array, and no analysis has to branch on which tool a subject used. That is the reason for the default: had it followed the recon tool, a mixed cohort would produce a mixture of 84- and 78-node matrices that cannot be stacked.

The last row is the one combination to avoid: the DK table asks for labels a DKT image does not contain, leaving **6 structurally empty nodes** (indices 1, 31, 32, 50, 80, 81). Step 4 warns when it happens. Set `CONNECTOME_PARCELLATION=auto` to follow the recon tool instead, or `dk` to force the 84-node atlas where `recon-all` makes it genuinely available.

**Requesting DKT must switch the input image, not just the LUT.** Because `labelconvert` matches by name, applying `fs_dkt.txt` to a DK image does not produce DKT: bankssts and the poles are absent from the target table, so those voxels map to 0 and are *discarded*, whereas real DKT reassigns that territory to the neighbouring gyri. Measured on one `recon-all` subject:

| Segmentation read | LUT | Nodes | Cortical voxels retained |
|---|---|---|---|
| `aparc+aseg.mgz` (DK) | `fs_default.txt` | 84 | 682,932 |
| `aparc+aseg.mgz` (DK) | `fs_dkt.txt` | 78 | 670,820 — **12,112 voxels silently lost** |
| `aparc.DKTatlas+aseg.mgz` | `fs_dkt.txt` | 78 | 682,932 |

The middle row yields a plausible-looking 78-node matrix with no empty nodes and no warning, which is precisely what makes it dangerous. Step 4 therefore selects the DKT *image* on a `recon-all` tree rather than only swapping the table, passes it to the container as `--segmentation`, and records the file it read in `parcellation.json` along with whether the parcellation came from the default or an explicit `CONNECTOME_PARCELLATION`.

The `--segmentation` argument is what makes this real rather than nominal. The container defaults to `aparc+aseg.mgz` and cannot infer the caller's intent, so a version that chose the DKT image in the driver but never passed it through would read the DK image, apply the DKT table, and lose those 12,112 voxels while reporting the DKT filename in its provenance — the failure looks exactly like success. That is not hypothetical: it is the state this pipeline was in for one revision, and the numbers below are the difference it made.

**The difference is not cosmetic.** Measured on `sub-SUBJ01` (`recon-all`, deterministic mode), comparing a true DKT run against what the DK-image-plus-DKT-table path produced:

| Matrix | Nodes | Assigned streamlines |
|---|---|---|
| DK (`aparc+aseg.mgz` + `fs_default.txt`) | 84 | 7,736,752 |
| **True DKT** (`aparc.DKTatlas+aseg.mgz` + `fs_dkt.txt`) | 78 | **7,691,076** |
| DK image + DKT table (the silent failure) | 78 | 7,425,289 |

The last row loses **265,787 streamlines — 3.4 % of the total** — and differs from the true DKT matrix in **5,548 of 6,084 cells (91 %)**. The reason true DKT retains nearly all of the DK streamline count is that DKT does not delete bankssts and the poles, it *merges* them into adjoining gyri; only the small residue that fell outside any DKT region is lost. Deleting the rows instead throws away every connection those three regions had.

`fs_dkt.txt` is generated from `fs_default.txt` by `dwi_pipeline/scripts/make_dkt_lut.py`, which drops those 6 regions and renumbers the remainder contiguously. It is generated rather than hand-written because `fs_default.txt` maps **two names to one node** for the thalamus (`Left-Thalamus` and `Left-Thalamus-Proper`, spanning FreeSurfer 6 and 7 naming), and that aliasing must survive renumbering.

The swap changes no tractography — the same streamlines are counted against a different set of regions — but it is **not** simply the DK matrix with six rows removed, as the table above shows. **Do not pool DK and DKT connectomes**: the node sets and dimensions differ. Each subject records its atlas, node count, LUT, the segmentation actually read and its empty-node count in **`parcellation.json`**.

---

## 3. Physics: diffusion MRI

### 3.1 What DWI measures

Diffusion-weighted imaging sensitize the MR signal to **Brownian motion** of water molecules. A **diffusion-encoding gradient** of strength **b** (s/mm²) is applied along direction **g** (unit vector). Signal attenuation follows (Stejskal–Tanner):

\[
S(\mathbf{g}, b) = S_0 \exp\left(-b\,\mathbf{g}^\top \mathbf{D}\,\mathbf{g}\right)
\]

where **D** is the **symmetric 3×3 diffusion tensor** (in mm²/s) and **S₀** is the baseline (b ≈ 0) signal.

### 3.2 Anisotropy and fiber orientation

In **white matter**, mobility is **restricted perpendicular** to axons (myelin hindrance) and **easier parallel** to them. **D** has one large eigenvalue (primary eigenvector ≈ local fiber direction). Scalar maps derived from **D**:

| Map | Meaning |
|-----|---------|
| **FA** (fractional anisotropy) | 0 = isotropic, 1 = single direction |
| **MD** (mean diffusivity) | Average eigenvalue |
| **AD / RD** | Axial / radial diffusivity |

The pipeline’s default spec uses **single-shell** data (e.g. **b = 1000 s/mm²**) selected via `dwi_select_b1000.json` — one non-zero b-value shell plus b₀ volumes.

### 3.3 q-space and the diffusion signal vector

Each voxel’s DWI signal can be written as samples on the **sphere** of gradient directions. High angular resolution enables resolving **crossing fibers** (multiple orientations per voxel). **CSD** (Section 10) models the **orientation distribution function (ODF)** or **fiber orientation distribution (FOD)** on the sphere rather than a single tensor.

### 3.4 Preprocessing effects relevant to science

**QSIPrep** applies steps that preserve interpretability of **D** and FODs:

| Step | Physical / statistical purpose |
|------|----------------------------------|
| **Denoising** (e.g. MP-PCA) | Removes Rician noise bias in low-SNR voxels |
| **Gibbs ringing removal** | Reduces truncation artifacts from finite k-space |
| **Eddy current + motion** (`eddy`) | Corrects distortion and misalignment across volumes |
| **SDC** (TOPUP / SyN) | Unwarp EPI susceptibility-induced geometric distortion |
| **Brain mask / B0→T1w** | Aligns DWI to anatomical space for ACT and connectomes |

Distortion correction is **critical**: misaligned WM masks cause ACT to **cut valid streamlines** or **allow invalid ones**.

---

## 4. Mathematics: models, transforms, and connectivity

### 4.1 Spherical harmonics and FODs

MRtrix represents FODs as **real symmetric spherical harmonic (SH) coefficients** up to order **l_max** (often 8). The FOD **f(û)** for unit direction **û** is:

\[
f(\hat{\mathbf{u}}) = \sum_{\ell=0}^{\ell_{\max}} \sum_{m=-\ell}^{\ell} c_{\ell m}\, Y_{\ell m}(\hat{\mathbf{u}})
\]

**CSD** estimates **c_ℓm** from the DWI signal under sparsity / non-negativity constraints.

### 4.2 Registration as coordinate maps

Moving image **I_m** to fixed **I_f** finds transform **T** such that **I_m ∘ T ≈ I_f**.

| Transform type | Degrees of freedom | Use in pipeline |
|----------------|-------------------|-----------------|
| **Rigid** (6 DOF) | Rotation + translation | FS conformed ↔ native header |
| **Affine** (12 DOF) | Rigid + scale + shear | BIDS T1w → QSIPrep `desc-preproc_T1w` |
| **Nonlinear** | Dense displacement field | SyN SDC, optional atlas registration |

**GenericLabel** interpolation (ANTs) assigns each output voxel the label of the **nearest neighbor** in source space — required for **integer parcellations** (no fractional labels).

### 4.3 Connectome as a weighted graph

Given **N** regions (nodes) and streamlines **s**, the connectome **C** is:

\[
C_{ij} = \sum_{s \in \mathcal{S}_{ij}} w(s)
\]

where **𝒮_ij** are streamlines connecting regions **i** and **j**, and **w(s)** is unity or a **SIFT2** weight. The pipeline uses **symmetric** matrices (**C_ij = C_ji**) and **zero diagonal** (no self-connections).

---

## 5. Geometry: coordinate spaces and surfaces

### 5.1 Scanner / native space

Raw T1w and DWI live in **scanner coordinates** (LPS/RAS depending on DICOM). FreeSurfer writes **`rawavg.mgz`** — the T1w on its **original voxel grid** (after reorientation for processing).

### 5.2 FreeSurfer conformed space

FreeSurfer **conforms** volumes to **256 × 256 × 256**, **1 mm isotropic**, **LIA** orientation centered on the brain. **`orig.mgz`** and default **`aparc+aseg.mgz`** use this grid.

**Problem:** QSIRecon tractograms are **not** in conformed space — they live on **`dwiref`** (~2 mm, QSIPrep T1w space).

### 5.3 QSIPrep T1w / ACPC space

**`desc-preproc_T1w`** (~1 mm) is the anatomical reference after bias correction, skull stripping, and ACPC alignment. **`dwiref`** is the **DWI reference grid** in the same world coordinate frame (~2 mm).

### 5.4 Cortical surfaces (2-manifolds in 3D)

FreeSurfer reconstructs **inner (white)** and **outer (pial)** cortical surfaces — triangular meshes (**~160k vertices per hemisphere**) embedded in 3D. HSVS **rasterizes** the **volume between** these surfaces as **cortical GM**, giving **sub-millimeter** fidelity at the cortical ribbon — something pure volume clustering (FAST) cannot match at 1–2 mm resolution.

### 5.5 Streamline geometry

Each streamline is a **polyline** **{p_k}** in 3D, integrated in steps of length **Δℓ** (e.g. 0.5–1 mm). ACT checks **tissue labels** at each point **p_k**. Connectome assignment tests which **parcellation label** each endpoint (or segment) intersects.

---

## 6. Five-tissue-type (5TT) images

A **5TT** image is a **4D NIfTI** (X × Y × Z × **5**) of **partial volume fractions** or **binary tissue maps**, one volume per tissue class:

| Index | Tissue | Typical use in ACT |
|-------|--------|-------------------|
| 0 | Cortical gray matter | Valid termination |
| 1 | Subcortical gray matter | Valid termination |
| 2 | White matter | Allowed propagation |
| 3 | CSF | Forbidden propagation |
| 4 | Pathological / other | Custom handling |

This ordering is the MRtrix3 `5ttgen` convention and was verified against this
project's own output (`sub-*_space-ACPC_seg-hsvs_probseg.nii.gz`), where volumes
0–4 contain cortical GM, subcortical GM, WM, CSF, and pathological tissue
respectively.

**ACT** reads the **dominant tissue** or **thresholded probabilities** at each step to decide **continue**, **terminate**, or **discard** the streamline.

In QSIRecon, the node **`create_5tt_hsvs`** (`GenerateMasked5tt`) builds the 5TT from FreeSurfer inputs, then registers it to the QSIRecon T1w grid (`register_fs_to_qsiprep_wf`).

---

## 7. FSL FAST segmentation

**FAST** (FMRIB’s Automated Segmentation Tool) is a **hidden Markov random field (MRF)** classifier on T1w (or multi-contrast) intensities.

### 7.1 Statistical model

FAST assumes each voxel intensity **y** comes from one of **K** tissue classes (typically **K = 3**: CSF, GM, WM) with class-conditional Gaussians:

\[
p(y \mid c=k) = \mathcal{N}(y; \mu_k, \sigma_k^2)
\]

Spatial **MRF priors** encourage neighboring voxels to share classes — smoothing segmentation.

### 7.2 FAST in the pipeline (`ACT-fast`)

When **Step 2 (FreeSurfer/FastSurfer) is skipped**, the pipeline switches to:

**`mrtrix_singleshell_ss3t_ACT-fast`**

QSIRecon uses **FSL FAST** (or equivalent workflow) on QSIPrep’s T1w to build a **3-tissue** segmentation, then derives a **5TT-compatible** image **without cortical surfaces**.

| Aspect | FAST (ACT-fast) | HSVS (ACT-hsvs) |
|--------|-----------------|-----------------|
| Input | T1w volume only | FS surfaces + aseg + volumes |
| Cortical GM | Intensity-based blob | Surface ribbon between white/pial |
| Surfaces required | **No** | **Yes** |
| Typical use | Quick / no FS license path | Production ACT accuracy |

FAST is **fast and robust** but **less accurate** at the GM–WM–CSF interface in cortex — exactly where ACT needs precision.

---

## 8. HSVS: Hybrid Surface–Volume Segmentation

**HSVS** = **Hybrid Surface–Volume Segmentation** (Smith et al., *NeuroImage* 2020; implemented in MRtrix3 / QSIRecon as **`5ttgen hsvs`**).

### 8.1 Concept

HSVS **combines**:

1. **Surface geometry** — FreeSurfer **white** and **pial** meshes define the **cortical gray matter ribbon**.  
2. **Volume segmentation** — FreeSurfer **`aseg`** provides **subcortical GM**, ventricles, brainstem.  
3. **Intensity / topology** — WM is inferred from **surfaces + aseg** (WM = interior to white surface, excluding subcortical GM).

The “**hybrid**” name reflects **surfaces for cortex** + **volume labels for deep structures**.

### 8.2 Why surfaces matter

At 1–2 mm resolution, **partial volume** blurs cortex and sulcal CSF in a single voxel. A **volume-only** label may classify sulcal CSF as GM or WM. Surfaces **explicitly** place the cortical sheet between white and pial surfaces, reducing **leakage** of tractography into CSF-filled sulci.

### 8.3 Required FreeSurfer files

HSVS / `5ttgen hsvs` typically requires:

| File | Content |
|------|---------|
| `surf/lh.white`, `surf/rh.white` | WM–GM boundary |
| `surf/lh.pial`, `surf/rh.pial` | GM–CSF boundary |
| `mri/aseg.mgz` | Subcortical labels |
| `mri/brain.mgz` or T1 | Brain mask context |

**`--seg_only` FastSurfer** (without `recon-surf`) produces **volume labels only** — **no surfaces** — so **`create_5tt_hsvs` cannot run**. Full FastSurfer or `recon-all` is required for ACT-HSVS.

### 8.4 Registration to DWI space

After HSVS builds 5TT in FreeSurfer space, QSIRecon:

1. Converts / registers FS anatomy to **QSIPrep T1w** (ANTs affine + transforms).  
2. Resamples 5TT to the **tracking grid** (`dwiref` or recon workflow grid).  

Log message: *“HSVS 5tt image will be registered to the QSIRecon T1w image.”*

---

## 9. Anatomically Constrained Tractography (ACT)

**ACT** (Smith et al., *NeuroImage* 2012) embeds **anatomical priors** in probabilistic tractography (`tckgen`).

### 9.1 Biological rules encoded

At each integration step:

| Tissue transition | Action |
|-------------------|--------|
| WM → WM | Continue |
| WM → cortical GM | **Terminate** (valid endpoint) |
| WM → subcortical GM | **Terminate** |
| WM → CSF | **Discard** (invalid) |
| GM → WM (reverse) | Typically **not seeded** / discarded depending on config |
| Any → pathological | Configurable |

This reduces **false positives** (streamlines floating in CSF or jumping between gyri across sulci).

### 9.2 Seeding

ACT commonly seeds streamlines **within WM** (or WM–GM interface voxels). Seeds outside WM or inside CSF are rejected.

### 9.3 Relation to 5TT

ACT consumes the **5TT** image at each step. **HSVS 5TT** improves **GM boundary** definition → cleaner termination → more plausible connectomes.

---

## 10. CSD and SS3T response estimation

### 10.1 Constrained Spherical Deconvolution (CSD)

**CSD** deconvolves the DWI signal with a **single-fiber response function** to estimate the **FOD**. It resolves **crossing fibers** better than DTI (single tensor).

### 10.2 SS3T (single-shell 3-tissue)

**SS3T** extends response estimation to **single-shell** data with **three tissue types** (WM, GM, CSF) — appropriate when only one non-zero b-value is available (e.g. **b1000**).

Each tissue has its own **isotropic/anisotropic response**. Fitting separates **WM anisotropic** contribution from **GM/CSF isotropic** partial volume — critical in voxels near cortex and ventricles.

Spec name breakdown: **`mrtrix_singleshell_ss3t_ACT-hsvs`**

| Token | Meaning |
|-------|---------|
| `mrtrix` | MRtrix3 backend |
| `singleshell` | One b-value shell |
| `ss3t` | Single-shell 3-tissue CSD |
| `ACT-hsvs` | ACT using HSVS 5TT |

---

## 11. Tractography, SIFT2, and connectomes

### 11.1 Probabilistic tractography (`tckgen`)

Integration follows FOD peaks (iFOD2 algorithm in MRtrix). Step size, maximum angle, and cutoff FOD amplitude control **curvature** and **sensitivity**.

**Output:** streamlines file **`.tck`** (or `.tck.gz`) — millions of 3D curves in **world coordinates** aligned to `dwiref`.

### 11.2 SIFT2

**SIFT2** (Smith et al., 2015) assigns **non-negative weights** **w(s)** to streamlines so weighted density matches **FOD-derived fiber density**. Optional in connectome summation; improves quantitative interpretation vs. raw streamline counts.

### 11.3 Atlas connectomes (inside QSIRecon)

If **`QSIRECON_ATLASES`** is set (e.g. **`4S156Parcels`**), QSIRecon runs **`tck2connectome`** against **template atlases** registered to subject space — independent of Step 4.

### 11.4 Anatomical connectome (Step 4)

Step 4 uses the **subject-native FreeSurfer parcellation** warped to **`dwiref`**, producing the anatomical graph for this subject: **`dkt_connectome.csv`** (DKT, 78 nodes) by default from either recon tool, or **`dk_connectome.csv`** (Desikan–Killiany, 84 nodes) with `CONNECTOME_PARCELLATION=dk` on a `recon-all` tree. See §2.6.

---

## 12. FreeSurfer / FastSurfer outputs used by the pipeline

| Output | Space | Consumer |
|--------|-------|----------|
| `mri/aparc+aseg.mgz` | Conformed 256³ | DK Step 4, parcellation |
| `mri/rawavg.mgz` | Native T1w grid | `mri_label2vol` target for DK warp |
| `mri/aseg.mgz` | Conformed | HSVS subcortical component |
| `surf/*.white`, `surf/*.pial` | Surface mesh | HSVS cortical ribbon |
| `mri/brain.mgz` | Conformed | Masking |

**FastSurfer** mimics FreeSurfer folder layout. Full pipeline runs **`recon-surf`** (not **`--seg_only`**) so surfaces exist for HSVS.

---

## 13. DK connectome: label warping and matrix generation

Step 4 (`run_connectome.sh`) performs a **three-stage spatial alignment**:

```
aparc+aseg.mgz (FS conformed)
        │  mri_label2vol --temp rawavg.mgz
        ▼
aparc+aseg in native T1w (rawavg grid)
        │  ANTs affine: BIDS T1w → desc-preproc_T1w
        ▼
aparc+aseg in QSIPrep T1w space
        │  ANTs GenericLabel resample → dwiref
        ▼
aparc+aseg on tractography grid
        │  labelconvert (FS LUT → fs_default.txt for DK, fs_dkt.txt for DKT)
        ▼
nodes.mif  +  tractogram.tck  →  tck2connectome  →  dkt_connectome.csv  (DKT, 78 nodes)
                                                       dkt_connectome.csv  (DKT, 78 nodes)
```

**Why not use QSIPrep’s `from-orig_to-T1w` transform alone?**  
QSIPrep’s packaged FS-native transform may target a **reoriented T1wNative** frame that does not match **`rawavg.mgz`**. Step 4 uses an **empirical affine** between **BIDS T1w** and **`desc-preproc_T1w`** after **`mri_label2vol`**, which empirically aligns labels with tractography on real data.

**`labelconvert`** maps FreeSurfer integer labels to MRtrix’s compact index set — **84-node** DK via `fs_default.txt`, or **78-node** DKT via `fs_dkt.txt`. The mapping is **by region name, not by integer**: each input label is resolved to a name through `FreeSurferColorLUT.txt`, and that name is looked up in the target table. Names absent from the target table become 0 and are excluded from the graph.

Because the matrix dimension now depends on the recon tool, Step 4 counts nodes that received no streamlines and warns, since an empty node usually means the table does not match the segmentation. `CONNECTOME_FAIL_ON_EMPTY_NODES=1` escalates that to a hard failure; it warns by default because empty nodes can be genuine after a resection or a large lesion.

**`tck2connectome`** options in the pipeline:

- **`-symmetric`** — undirected graph  
- **`-zero_diagonal`** — no self-loops  
- **`-out_assignments`** — per-streamline node IDs for QC  

### 13.1 Numerical reproducibility of Step 4

Step 4 is **not bitwise reproducible by default**, and the reason is worth understanding before archiving results.

ITK accumulates the registration metric across CPU threads, and floating-point addition is **not associative**, so the thread scheduling of a given run changes the summation order and hence the last bits of the result. Two identical runs of the Step 4b affine differ by roughly **1e-10**. Nearest-neighbour (`GenericLabel`) resampling normally absorbs this completely, but a voxel sitting almost exactly on a label boundary can flip, which reassigns the streamlines ending there.

Measured on one subject: two runs that differed only in thread scheduling produced matrices differing in **482 of 6,084 cells** and **134 of 15.4 M streamlines (0.0009 %)**; two other pairs were identical.

The magnitude is far below scan–rescan variability and will not change a statistical result. What it does affect is **verifiability**: re-running an archived subject may not reproduce the archived matrix exactly. Setting **`CONNECTOME_DETERMINISTIC=1`** pins ITK to a single thread, after which repeat runs produce a **bitwise identical** affine and connectome. The cost is roughly **3.6× on Step 4** (about 3:20 → 12:20 for one subject), which is near **3 %** of a full four-step run.

---

## 14. Software stack summary

| Layer | Package | Role |
|-------|---------|------|
| Preprocessing | **QSIPrep** | BIDS DWI/T1w preprocessing, SDC, eddy |
| Anatomy | **FreeSurfer** / **FastSurfer** | Surfaces, `aparc+aseg`, `aseg` |
| Reconstruction | **QSIRecon** | Workflow orchestration, HSVS 5TT, tractography |
| Diffusion modeling | **MRtrix3** | CSD, ACT, `tckgen`, SIFT2, connectomes |
| Tissue seg (alt.) | **FSL FAST** | ACT-fast 5TT without surfaces |
| Registration | **ANTs** | Affine / SyN, `antsApplyTransforms` |
| Connectome step | **dkt_connectome.sif** | FreeSurfer `mri_label2vol` + ANTs + MRtrix |
| Orchestration | **`subject.sh`**, Slurm | Four-step batch processing |
| Containers | Apptainer/Singularity | Reproducible HPC execution |

### 14.1 Runtime libraries in `dkt_connectome.sif`

`dkt_connectome.sif` is assembled rather than built from source: a minimal `ubuntu:22.04` base with the FreeSurfer, ANTs and MRtrix3 trees **copied in from `qsirecon.sif`**. This keeps the image small (~150 MB against several GB) and guarantees Step 4 uses the *same binaries* as Step 3, so no version skew can appear between the tractogram and the parcellation that indexes it.

The cost of copying binaries instead of installing packages is that **no package manager records their dependencies**. Each binary still needs its shared libraries at run time, and the base image must supply them explicitly:

| Package | Provides | Needed by | Used for |
|---------|----------|-----------|----------|
| `libtiff5` | `libtiff.so.5` | 110 binaries, incl. `labelconvert`, `tck2connectome` | TIFF codec in MRtrix's image-IO layer |
| `libpng16-16` | `libpng16.so.16` | 110 binaries, incl. `labelconvert`, `tck2connectome` | PNG codec in the same layer |
| `libfftw3-double3` | `libfftw3.so.3` | 2 binaries (`mrdegibbs`, `mrfilter`) | FFT for Gibbs-ringing removal and filtering |
| `zlib1g` | `libz.so.1` | 112 binaries | gzip for `.nii.gz` and `.mgz` |
| `libgomp1` | `libgomp.so.1` | `mri_label2vol`, `mri_convert` | OpenMP thread pool |
| `bc`, `ca-certificates` | — | wrapper script | Arithmetic, TLS roots |

**Why this was a real failure and not a theoretical one.** A missing shared library does not break the image build; it breaks every later *run*. The dynamic loader aborts before `main()`, the shell reports **exit 127**, and MRtrix prints nothing — so the pipeline appeared to skip Step 4 rather than fail it. This is what silently produced no `dk_connectome.csv` for an otherwise successful job. The build therefore ends with an assertion that runs `ldd` over every staged binary and **fails the build** if any report `not found`, so a broken image can never be shipped again.

**These libraries cannot change any result.** They are format codecs, a compressor and a thread pool, not numerical kernels, and the distinction matters for three separate reasons:

- `libtiff` and `libpng` are **never exercised** by this pipeline. MRtrix links one image-IO layer into every command, so every command declares the codecs whether or not the format is used; the pipeline's data are `.mgz`, `.nii.gz`, `.mif`, `.tck` and `.csv`. The libraries are loaded and then not called.
- `libz` is used constantly but is **lossless** by construction.
- `libfftw3` *is* a numerical library, but it is required only by `mrdegibbs` and `mrfilter`, **neither of which Step 4 invokes**. It is installed to satisfy the whole-image `ldd` assertion, so that the two commands are not latent traps for anyone who later reaches for them.

There is also no version of the pipeline in which these libraries alter a number rather than an outcome: without them the binary cannot start at all. The comparison is between a run and a crash, not between two answers.

---

## 15. Design choices and alternatives

| Choice | Rationale |
|--------|-----------|
| **ACT-HSVS default** | Best cortical tissue boundaries for ACT when FS/FastSurfer surfaces exist |
| **Separate Step 2** | QSIPrep alone does not run full `recon-all`; HSVS needs FS subject dir |
| **b1000 single-shell** | Matches typical clinical acquisitions; SS3T is tailored to a single shell |
| **DK as Step 4** | QSIRecon atlases ≠ DK; explicit warp ensures label–tract alignment |
| **ACT-fast fallback** | Enables tractography without FS when `--no-recon` |
| **FastSurfer vs recon-all** | ~10× faster; GPU option; compatible outputs if `recon-surf` completes |
| **DKT for both recon tools** | The only parcellation both can produce, so `--fastsurfer` changes runtime rather than the node set and a mixed cohort still pools (§2.6) |
| **Deterministic Step 4 by default** | Bitwise-reproducible matrices; ~3.6× on Step 4 but only ~3% of a full per-subject run (§13.1) |
| **Binaries staged from `qsirecon.sif`** | Step 4 uses the same MRtrix/ANTs as Step 3, removing version skew; the price is declaring runtime libraries by hand (§14.1) |

**Not recommended without validation:** `--seg_only` FastSurfer + ACT-HSVS (missing surfaces); DK connectome without **`mri_label2vol` + dwiref resample** (space mismatch silently corrupts matrices).

---

## 16. References

1. Smith RE, Tournier JD, Calamante F, Connelly A. **Anatomically-constrained tractography: Improved diffusion MRI streamlines tractography through effective use of anatomical information.** *NeuroImage* 2012.  
2. Smith RE, Tournier JD, Calamante F, Connelly A. **Hybrid surface/volume segmentation for improved cortical gray matter classification in single voxel diffusion analysis.** *NeuroImage* 2020. (**HSVS**)  
3. Tournier JD, Calamante F, Connelly A. **MRtrix3: A fast, flexible and open software framework for analysing medical MR diffusion imaging data.** *NeuroImage* 2019.  
4. Smith RE, Tournier JD, Calamante F, Connelly A. **SIFT2: Enabling dense quantitative assessment of brain white matter connectivity using streamlines tractography.** *NeuroImage* 2015.  
5. Zhang Y, Brady M, Smith S. **Segmentation of brain MR images through a hidden Markov random field model and the expectation-maximization algorithm.** *IEEE TMI* 2001. (**FAST**)  
6. Desikan RS et al. **An automated labeling system for subdividing the human cerebral cortex on MRI scans into gyral based regions of interest.** *NeuroImage* 2006. (**DK atlas**)  
7. PennLINC **QSIPrep** / **QSIRecon** documentation — recon specs, `--fs-subjects-dir`, ACT workflows.  
8. Henschel L, et al. **FastSurfer** — fast deep-learning cortical segmentation and surface reconstruction.

---

*Document version: 2026-06-11 — aligned with `subject.sh` on branch `lab-pipeline` and QSIRecon spec `mrtrix_singleshell_ss3t_ACT-hsvs`.*
