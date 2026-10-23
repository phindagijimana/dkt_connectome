---
title: Classical (non-DL) FreeSurfer / FastSurfer stages → DL alternatives
subtitle: Master table — many alternatives per method; readiness + sources
date: 23 October 2026
status: living inventory
related:
  - CATALOG.md
  - DL_ALTERNATIVES.md
  - LITERATURE_MAP.md
---

# Classical methods → credible DL alternatives

**Readiness legend**

| Tag | Meaning |
|-----|---------|
| **Production** | Ships in FreeSurfer or FastSurfer today; lab-usable without new training |
| **Ready** | Public code + pretrained weights; integration work only |
| **Research** | Peer-reviewed + code; not a SUBJECTS_DIR drop-in |
| **Early** | Credible paper (code weak/missing); watch list |
| **None** | No credible DL replacement found; classical remains |

**Scope.** Rows are **non-deep-learning** algorithms still used in FreeSurfer and/or FastSurfer. Where FS 8 / FastSurfer already swapped in DL, the classical method is listed as “legacy / optional” and the in-tree DL is noted under alternatives.

Canvas: [Classical → DL table](/mnt/nfs/home/urmc-sh.rochester.edu/pndagiji/.cursor/projects/mnt-nfs-home-urmc-sh-rochester-edu-pndagiji-Documents-TrackTBI-Sub/canvases/classical-to-dl-table.canvas.tsx)

---

## A. Volume preprocessing & intensity

| # | Classical method | Where used | Credible DL alternatives | Source | Ready? |
|---|------------------|------------|--------------------------|--------|--------|
| A1 | Motion correction / multi-frame average | FS `recon-all` (if multi) | (usually keep classical) · learning-based motion (fMRI/DWI-centric, not T1 morphometry standard) | — | **None** for T1 recon core |
| A2 | Conform (orientation, 1 mm isotropic grid) | FS + FastSurfer input prep | Keep classical (`mri_convert` / FastSurfer conform). SynthSeg/SynthSR tolerate odd geometry instead of conforming first | FreeSurfer; Billot SynthSeg | Classical **Production**; Synth* path **Production** |
| A3 | NU / N3 / N4-style bias-field correction | FS intensity stages; FastSurfer biasfield stats | **DeepN4** (learn N4) · Implicit CNN bias correction (Simkó MIDL 2022) · Log-Gabor CNN bias nets | Kanakaraj et al. DeepN4 (PMC10680935); [MASILab/DeepN4](https://github.com/MASILab/DeepN4); also in DIPY `BiasFieldCorrectionFlow(method="n4")`; Simkó 2022 | DeepN4 **Ready**; Simkó **Research** |
| A4 | Intensity normalization (WM=110 style) | FS autorecon | Often absorbed by SynthSeg / FastSurferVINN training domains; no separate “norm net” needed | SynthSeg; Henschel FastSurfer | Absorbed in **Production** DL segs |
| A5 | Skull stripping (watershed / hybrid) | FS ≤7 classical; FastSurfer skips (seg-driven) | **SynthStrip** · HD-BET · ROBEX (classic ML) · MONAI / nnU-Net brain extractors | Hoopes SynthStrip (FS ≥7.3; synthstrip.io); Isensee HD-BET | SynthStrip **Production**; HD-BET **Ready** |
| A6 | Neck removal | FS CA stream | Often unnecessary after SynthStrip / SynthSeg; no dedicated DL neck tool required | — | Absorbed |

---

## B. Volumetric registration & labeling

| # | Classical method | Where used | Credible DL alternatives | Source | Ready? |
|---|------------------|------------|--------------------------|--------|--------|
| B1 | Talairach / affine to atlas (mincost) | FS | **SynthMorph** (affine) · **EasyReg** (affine+nonlinear, symmetric) · SynthSeg centroid affine | Hoffmann SynthMorph (TMI 2022; Imaging Neurosci 2024); Iglesias EasyReg (Sci Rep 2023); in FS | **Production** (FS) |
| B2 | EM / GCA linear register | FS CA stream | SynthMorph · EasyReg · ANTs (classical) · VoxelMorph family | Same; Balakrishnan VoxelMorph | SynthMorph/EasyReg **Production** |
| B3 | CA nonlinear volumetric registration | FS CA stream | **SynthMorph** deformable · **EasyReg** · VoxelMorph / TransMorph / LapIRN (research) | Same; Chen TransMorph etc. | SynthMorph/EasyReg **Production**; others **Research** |
| B4 | CA Label / classical aseg (GCA) | FS ≤7 core | **SynthSeg** · **FastSurferVINN** · QuickNAT · DeepSCAN · AssemblyNet · SLANT | Billot SynthSeg; Henschel FastSurferVINN 2022; Roy QuickNAT; McKinley DeepSCAN | SynthSeg + VINN **Production** |
| B5 | Cortical ribbon / tissue classes (WM/GM/CSF volumetric) | FS WM seg helpers | Same DL segs as B4; FastSurfer aseg → surfaces | — | **Production** |
| B6 | Corpus callosum (classical post) | Older FS | **FastSurfer-CC** | Pollak et al. Imaging Neurosci 2026 | **Production** (FastSurfer) |
| B7 | Cerebellum substructure (classical/limited) | FS add-ons | **CerebNet** | Faber et al. NeuroImage 2022 | **Production** (FastSurfer) |
| B8 | Hypothalamus / limbic subunits | FS ScLimbic (DL) vs classical sparse | **HypVINN** · **mri_sclimbic_seg** | Estrada HypVINN 2023; FS ScLimbic | **Production** |
| B9 | Hippocampal / amygdala / brainstem / thalamus subfields | FS `segmentHA_*` (Bayesian classical + some DL paths) · `segment_subregions` | FS DL subregions · HippUnfold · Hippodeep · e2dhipseg · SynthSeg subfields modes | Iglesias HA papers; DeKraker HippUnfold; FS wiki SubregionSegmentation | Mixed **Production** / **Ready** |
| B10 | Lesion-aware labeling (classical CFM only) | Not native FS | **FastSurfer-LIT / neuroLIT** · VBG · LeAPP VBT · enantiomorphic fill (pre-classical) | Pollak LIT 2025; Radwan VBG 2021; Bey LeAPP 2024; Nachev 2008 | LIT **Production**; VBG/LeAPP **Ready**/ops caveats |

---

## C. White-matter mask, fill, tessellation, topology (pre-surface)

| # | Classical method | Where used | Credible DL alternatives | Source | Ready? |
|---|------------------|------------|--------------------------|--------|--------|
| C1 | WM segmentation / edit-with-aseg | FS autorecon2 | DL aseg (B4) + derived WM; TopoFit bypasses fragile WM edits for white surface | FastSurfer; TopoFit | **Production** / TopoFit **Production** |
| C2 | Fill (ensure hemispheric connectivity) | FS | Absorbed by template-deformation CSR (TopoFit, Vox2Cortex, V2C-Flow) — no separate fill net | Hoopes; Bongratz | Covered by surface DL **Ready**/Production |
| C3 | Tessellation (marching cubes / FS tessellate) | FS; FastSurfer recon-surf uses MC variant | Explicit mesh DL (Vox2Cortex, V2C-Flow, TopoFit, CorticalFlow) **avoids** MC · Implicit DL (DeepCSR, FastCSR, CortexODE init) still extract isosurface | Bongratz CVPR 2022; Cruz DeepCSR WACV 2021; Ren FastCSR Brain Inform 2022 | Explicit **Ready**/Research; FastCSR **Research** |
| C4 | Mesh smoothing (Smooth1/2) | FS / recon-surf | Learned deformation nets produce smooth meshes; classical smooth still OK | Surface DL family | Absorbed |
| C5 | Automatic topology fixer (manifold surgery) | FS (major time sink) | **TopoFit** (genus-0 template) · **Vox2Cortex / V2C-Flow** · **CorticalFlow** diffeomorphic · CortexODE + fast topology correction | Hoopes MIDL 2022; Bongratz; Lebrat CorticalFlow 2022; Ma CortexODE TMI 2022 | TopoFit **Production**; V2C-Flow **Ready**; others **Research** |
| C6 | QSphere / initial spherical embedding | FS | Spectral embedding in FastSurfer recon-surf (classical math, not DL) · Template-correspondence CSR skips QSphere | Henschel FastSurfer 2020; V2C-Flow | Spectral = classical; skip via **Ready** CSR |

---

## D. Cortical surfaces (white / pial / inflate)

| # | Classical method | Where used | Credible DL alternatives | Source | Ready? |
|---|------------------|------------|--------------------------|--------|--------|
| D1 | White surface placement (Final Surfs WM) | FS; FastSurfer recon-surf | **TopoFit** · **V2C-Flow** · **Vox2Cortex** · **CortexODE** · **CorticalFlow** · **SurfNN** · **SurfNet** · **DeepCSR** · **FastCSR** · SynthDist path in `recon-all-clinical` | Hoopes 2022; Bongratz 2022/2024; Ma 2022; Lebrat 2022; Zheng SurfNN 2023; Cruz 2021; Ren 2022; FS clinical | TopoFit **Production**; V2C-Flow **Ready**; rest **Research**/Early |
| D2 | Pial surface placement | FS; recon-surf | **V2C-Flow** · **Vox2Cortex** · **PialNN** (needs WM) · **CortexODE** · **SurfNN** · **DeepCSR** · **CorticalFlow** · SynthDist clinical | Ma PialNN 2021; same CSR family | V2C-Flow **Ready**; PialNN **Research**; FS clinical **Production** |
| D3 | Joint WM+pial (intersection-aware) | Classical separate | **V2C-Flow** (joint) · **SurfNN** (midthickness+half-thickness) · **Vox2Cortex** | Bongratz 2024; Zheng 2023 | **Ready**/Research |
| D4 | Surface inflation (metric) | FS Inflate1/2 | Often unnecessary if template IDs exist (V2C-Flow); else classical inflate remains | V2C-Flow paper | Partial **Ready** |
| D5 | High-res / sub-mm surface mode | FS `-cm`; FastSurfer hires recon-surf | FastSurferVINN native hi-res seg + classical/hires recon-surf; CSR nets mostly 1 mm-trained | Henschel VINN 2022 | Seg **Production**; DL surf hi-res **Early** |

---

## E. Spherical mapping, registration, parcellation, thickness

| # | Classical method | Where used | Credible DL alternatives | Source | Ready? |
|---|------------------|------------|--------------------------|--------|--------|
| E1 | Spherical mapping (minimize distortion) | FS; FastSurfer (spectral shortcut still classical) | Template-deformation CSR with fsaverage topology · SUGAR/S3Reg assume sphere already | V2C-Flow; TopoFit icosphere | Partial **Ready** |
| E2 | Spherical registration to fsaverage (`sphere.reg`) | FS; FastSurfer (+~30 min optional) | **SUGAR** · **S3Reg** · V2C-Flow native correspondences · emerging uncertainty-aware CSR+sphere (2026) | Ren SUGAR 2023 ([pBFSLab/SUGAR](https://github.com/pBFSLab/SUGAR)); Zhao S3Reg TMI 2021 ([BRAIN-Lab-UNC/S3Reg](https://github.com/BRAIN-Lab-UNC/S3Reg)); Bongratz V2C-Flow | SUGAR/S3Reg **Ready**; V2C bake-in **Ready** |
| E3 | Contralateral spherical registration | FS | Same as E2 / often unused in FastSurfer path | — | **Ready** if E2 used |
| E4 | Map average curvature / sulc to subject | FS | Follows E2; or predict morphometrics directly (weak FS replacement) | — | Tied to E2 |
| E5 | Cortical parcellation on surface (DK/DKT/Destrieux) | FS `mris_ca_label`; FastSurfer maps volume DKT→surface | Volume DL parc (VINN/SynthSeg `--parc`) · mesh GNN parc (research) · template label propagation via V2C IDs | FastSurfer; SynthSeg; V2C-Flow | Volume→surf **Production**; pure mesh parc **Research** |
| E6 | Cortical parcellation statistics / ribbon / aseg remap | FS autorecon3; FastSurfer post-surf refine | Keep classical bookkeeping on DL meshes, or use volume stats only | FastSurfer; FS | Classical **Production** (thin glue) |
| E7 | Cortical thickness (white–pial distance) | FS; recon-surf | Surface DL thickness from predicted meshes · **DL+DiReCT** · **CortexMorph** · **DL-CTE** · direct CNN thickness maps | Rebsamen HBM 2020; CortexMorph arXiv:2307.11567; Wu DL-CTE 2025 ([DL-CTE](https://github.com/wujiong-hub/DL-CTE)) | DiReCT family **Ready**/Research; mesh thickness needs D1–D2 |
| E8 | Point-wise curvature / area / volume morphometrics | FS | Derived from DL meshes if topology OK; else classical | — | Depends on D1–D2 |

---

## F. Longitudinal & specialty classical streams

| # | Classical method | Where used | Credible DL alternatives | Source | Ready? |
|---|------------------|------------|--------------------------|--------|--------|
| F1 | Longitudinal base template + `-long` | FS | Limited; FS8 long uses SynthSeg per TP (not fully longitudinal aseg). **V2C-Long** research line | FS release notes; ai-med V2C-Long repo | **Early** / partial **Production** (FS8 caveat) |
| F2 | Longitudinal hippocampal subfields | FS `segmentHA_T1_long` | Mostly classical Bayesian; some DL subregion tools cross-sectional only | Iglesias 2017 long HA | **None** strong DL long replacement |
| F3 | Manual-edit re-entry (`-autorecon2-wm/cp/pial`) | FS | No DL replacement — QC workflow. DL robustness (TopoFit, SynthStrip) reduces edit rate | — | Classical remains |
| F4 | TRACULA / PET / fMRI FS helpers | FS suite | Out of morphometry scope; separate DL ecosystems | — | Out of scope |

---

## G. FastSurfer-specific classical pieces

| # | Classical method | Where used | Credible DL alternatives | Source | Ready? |
|---|------------------|------------|--------------------------|--------|--------|
| G1 | **recon-surf** (entire surface pipeline) | FastSurfer after VINN | Whole CSR stacks in D1–E2 (TopoFit+PialNN, V2C-Flow, CortexODE, FastCSR, …) | See D–E | **Ready**/Research — not Production drop-in |
| G2 | Spectral spherical embedding (Laplace–Beltrami) | FastSurfer recon-surf | Not DL (spectral geometry). Alternatives: skip via template CSR · SUGAR after sphere | Henschel 2020; V2C-Flow; SUGAR | Classical math OK; skip **Ready** |
| G3 | FreeSurfer binary calls inside recon-surf | FastSurfer | Replacing recon-surf replaces these; cannot “DL” the binaries piecemeal | FastSurfer docs | — |
| G4 | Marching-cubes init in recon-surf | FastSurfer | Explicit CSR (C3/D1) | Bongratz; Hoopes | **Ready** |

---

## Compact “many alternatives” cheat sheet (by pain point)

| Pain point | Alternatives (readiness) |
|------------|--------------------------|
| Skull-strip | SynthStrip (**Production**), HD-BET (**Ready**) |
| Aseg / DKT volume | SynthSeg, FastSurferVINN (**Production**); QuickNAT, DeepSCAN (**Ready**/Research) |
| Bias field | DeepN4 (**Ready**); Simkó implicit CNN (**Research**) |
| Affine / nonlinear volume reg | SynthMorph, EasyReg (**Production**); VoxelMorph family (**Research**) |
| Topology + white surface | TopoFit (**Production**); V2C-Flow, Vox2Cortex, CorticalFlow, CortexODE (**Ready**/Research) |
| Pial surface | V2C-Flow (**Ready**); PialNN, CortexODE, SurfNN, DeepCSR (**Research**) |
| Full CSR end-to-end | V2C-Flow (**Ready**); CortexODE pipeline (**Research**); FastCSR (**Research**); recon-all-clinical (**Production**, hybrid) |
| sphere.reg | SUGAR, S3Reg (**Ready**); V2C-Flow correspondences (**Ready**) |
| Thickness w/o surfaces | DL+DiReCT, CortexMorph, DL-CTE (**Ready**/Research) |
| Lesion | neuroLIT/LIT (**Production**); VBG, LeAPP VBT, enantiomorphic (**Ready** w/ caveats) |
| Longitudinal surfaces | No strong full DL replacement (**Early**/None) |

---

## Suggested use of this table

1. **Phase 1 product** — only **Production** rows (already in FS/FastSurfer).  
2. **Phase 2 pilots** — **Ready** surface/reg tools (TopoFit → V2C-Flow → SUGAR).  
3. **Watch** — **Research**/**Early**; require lab validation (especially TBI + LIT) before catalog admission.

Do **not** treat “credible paper” as “replace FastSurfer recon-surf in TRACK-TBI tomorrow.”
