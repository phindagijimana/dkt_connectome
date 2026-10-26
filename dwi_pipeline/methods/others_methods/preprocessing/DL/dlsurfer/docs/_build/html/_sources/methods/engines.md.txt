# Methods — resources & citations

Auto-generated from `dlsurfer/engines.yaml` (`python scripts/gen_methods_docs.py`).
Cite **these engines**, not DLSurfer as morphometry science.

## Pinned stack

| Pin | Value |
|-----|-------|
| `fastsurfer_image` | `deepmi/fastsurfer:cu132-v2.6.0` |
| `fastsurfer_sif_lab` | `Documents/others/containers/fastsurfer_cu126_v2.6.0.sif` |
| `freesurfer_min` | `8.0.0` |
| `freesurfer_sif_lab` | `Documents/others/containers/freesurfer_7.4.1.sif` |
| `neurolit_min` | `0.6.0` |
| `neurolit_sif_lab` | `Documents/others/containers/lit_0.6.0.sif` |

## Chosen engines

| Engine | CLI / resource | Paper / docs |
|--------|----------------|--------------|
| **SynthStrip** (`synthstrip`) · production | `mri_synthstrip` | Hoopes A, et al. SynthStrip: skull-stripping for any brain image. NeuroImage 2022.<br>https://synthstrip.io |
| **DeepN4** (`deepn4`) · ready | `deepn4 / dipy_bias_field_correction --method n4` | Kanakaraj S, et al. DeepN4: Learning N4ITK Bias Field Correction for T1-weighted Images. 2024. PMC10680935.<br>https://github.com/MASILab/DeepN4 |
| **FastSurferVINN (asegdkt)** (`fastsurfer_vinn`) · production | `run_fastsurfer.sh (asegdkt module)` | Henschel L, et al. FastSurfer. NeuroImage 2020;219:117012.<br>Henschel L, Kuegler D, Reuter M. FastSurferVINN. NeuroImage 2022;251:118933. |
| **SynthSeg** (`synthseg`) · production | `mri_synthseg` | Billot B, et al. SynthSeg. Medical Image Analysis / FreeSurfer wiki SynthSeg.<br>https://surfer.nmr.mgh.harvard.edu/fswiki/SynthSeg |
| **FastSurfer-CC** (`fastsurfer_cc`) · production | `run_fastsurfer.sh (cc; disable with --no_cc)` | Pollak C, et al. FastSurfer-CC. Imaging Neuroscience 2026. doi:10.1162/IMAG.a.1221 |
| **CerebNet** (`cerebnet`) · production | `run_fastsurfer.sh (cereb; --no_cereb to disable)` | Faber J, et al. CerebNet. NeuroImage 2022;264:119703. |
| **HypVINN** (`hypvinn`) · production | `run_fastsurfer.sh (hypothal; optional --t2)` | Estrada S, et al. FastSurfer-HypVINN. Imaging Neuroscience 2023. |
| **neuroLIT / FastSurfer-LIT** (`neurolit`) · production | `lit-inpainting ; lit-postprocessing ; or run_fastsurfer.sh --lesion_mask` | Pollak C, et al. FastSurfer-LIT. Imaging Neuroscience 2025. doi:10.1162/imag_a_00446<br>https://github.com/Deep-MI/neurolit<br>FastSurfer LIT docs: https://deep-mi.org/FastSurfer/stable/overview/modules/LIT.html |
| **FastSurfer recon-surf (classical geometry)** (`recon_surf`) · classical | `run_fastsurfer.sh (surf) / recon-surf.sh` | Henschel L, et al. FastSurfer. NeuroImage 2020 (recon-surf description).<br>Fischl B. FreeSurfer. NeuroImage 2012 (underlying surface methods). |
| **SynthMorph** (`synthmorph`) · production | `mri_synthmorph` | Hoffmann M, et al. SynthMorph. IEEE TMI 2022; Imaging Neuroscience 2024.<br>https://synthmorph.io |
| **EasyReg** (`easyreg`) · production | `mri_easyreg` | Iglesias JE, et al. EasyReg. Scientific Reports 2023. doi:10.1038/s41598-023-33781-0<br>https://surfer.nmr.mgh.harvard.edu/fswiki/EasyReg |
| **FreeSurfer 8 recon-all** (`freesurfer8`) · production | `recon-all` | FreeSurfer 8.0.0 release notes (SynthSeg, SynthStrip, SynthMorph in recon-all).<br>Fischl B. FreeSurfer. NeuroImage 2012. |
| **TopoFit** (`topofit`) · production | `mris_estimate_wm` | Hoopes A, et al. TopoFit. MIDL 2022.<br>https://github.com/ahoopes/topofit |
| **V2C-Flow (Vox2Cortex-Flow)** (`v2c_flow`) · ready | `vox2organ / V2C-Flow pretrained` | Bongratz F, et al. Vox2Cortex. CVPR 2022.<br>Bongratz F, et al. V2C-Flow. arXiv:2401.12938 (2024).<br>https://github.com/ai-med/Vox2Cortex |
| **SUGAR** (`sugar`) · ready | `SUGAR (see upstream README)` | Ren J, et al. SUGAR. arXiv:2307.00511 (2023).<br>https://github.com/pBFSLab/SUGAR |
| **DL-CTE / CortexMorph family** (`dl_cte`) · ready | `dl-cte / cortexmorph` | Rebsamen M, et al. DL+DiReCT. Hum Brain Mapp 2020.<br>CortexMorph arXiv:2307.11567 (2023).<br>Wu et al. DL-CTE 2025. https://github.com/wujiong-hub/DL-CTE |
| **FreeSurfer longitudinal (-base / -long)** (`freesurfer_long`) · production | `recon-all -base … ; recon-all -long …` | Reuter et al. NeuroImage 2012 (longitudinal FreeSurfer)<br>FreeSurfer Longitudinal Processing docs |
| **FreeSurfer hippocampal/amygdala subfields (HA)** (`segment_ha`) · production | `segmentHA_T1.sh <sid> <SUBJECTS_DIR>` | Iglesias et al. NeuroImage 2015 (hippocampal subfields)<br>Saygin et al. NeuroImage 2017 (amygdala) |
| **FreeSurfer brainstem structures** (`segment_bs`) · production | `segmentBS.sh <sid> <SUBJECTS_DIR>` | Iglesias et al. NeuroImage 2015 (brainstem) |
| **FreeSurfer thalamic nuclei** (`segment_thalamic`) · production | `segmentThalamicNuclei.sh <sid> <SUBJECTS_DIR>` | Iglesias et al. NeuroImage 2018 (thalamic nuclei) |
| **recon-all-clinical (SynthSeg/SynthDist clinical)** (`recon_all_clinical`) · production | `recon-all-clinical.sh …` | Billot SynthSeg; FreeSurfer recon-all-clinical docs |
| **Destrieux (a2009s) parcellation** (`atlas_destrieux`) · production | `recon-all -s <sid> -sd <SUBJECTS_DIR> -a2009s` | Destrieux et al. NeuroImage 2010<br>FreeSurfer aparc.a2009s docs |
| **Schaefer surface projection** (`atlas_schaefer`) · ready | `mri_surf2surf --srcsubject fsaverage --trgsubject <sid> --sval-annot …` | Schaefer et al. Cerebral Cortex 2018<br>FreeSurfer mri_surf2surf / label projection docs |
| **FastSurfer srun / brun HPC wrap** (`srun_fastsurfer`) · production | `srun_fastsurfer.sh …  OR  brun_fastsurfer.sh …` | FastSurfer HPC docs (brun_fastsurfer / srun_fastsurfer) |
| **Mauri claustrum (mri_claustrum_seg)** (`mauri_claustrum`) · production | `mri_claustrum_seg --i <T1w> --o <outdir> --threads N --topo-correct` | Mauri C, et al. Hum Brain Mapp. 2025;46:e70303. doi:10.1002/hbm.70303<br>https://github.com/chiara-mauri/claustrum_segmentation |
| **SynthSeg-PC (Billot GMM → U-Net piriform)** (`synthseg_pc`) · research | `python Documents/piriform/synthseg_pc/predict_ideas_one.py --images … --model …` | Billot B, et al. Nat Commun. 2023 (SynthSeg / GMM training)<br>Steinbart D, et al. Hum Brain Mapp. 2023 (PC labels 125/126)<br>Mauri et al. 2025 (dense FoV / real-T1 epoch pattern — not claustrum weights)<br>Hammers A, et al. Hum Brain Mapp. 2003 |
| **SynthSR (mri_synthsr)** (`synthsr`) · production | `mri_synthsr --i <in> --o <out>` | Billot B, et al. SynthSR (FreeSurfer mri_synthsr)<br>Iglesias / Billot Synth* family docs |
| **HippUnfold** (`hippunfold`) · ready | `hippunfold <bids> <out> participant …` | DeKraker J, et al. eLife 2022;11:e77945 |

## Per-engine detail

### SynthStrip {#synthstrip}

- **Replaces (classical):** FS watershed / hybrid skull-strip
- **CLI / resource:** `mri_synthstrip`
- **Why chosen:** Best Production skull-strip already in FreeSurfer (≥7.3). Contrast- and resolution-robust via synthetic training; removes a common classical failure mode without a separate container. Prefer over HD-BET inside DLSurfer so the strip utility stays license/tooling-aligned with FS8.
- **Cite:**
  - Hoopes A, et al. SynthStrip: skull-stripping for any brain image. NeuroImage 2022.
  - https://synthstrip.io
- **Alternatives:** `hdbet` (ready), `robex` (research), `monai_brain_extract` (research)

### DeepN4 {#deepn4}

- **Replaces (classical):** N3/N4 / NU bias-field correction
- **CLI / resource:** `deepn4 / dipy_bias_field_correction --method n4`
- **Why chosen:** Best Ready learned approximation of N4ITK for T1w (public weights; also in DIPY). Optional pre-step when FastSurfer/FS bias handling is insufficient or when a differentiable/portable N4 stand-in is needed outside FS. Not required for core FastSurfer profiles (VINN path has its own biasfield stats).
- **Cite:**
  - Kanakaraj S, et al. DeepN4: Learning N4ITK Bias Field Correction for T1-weighted Images. 2024. PMC10680935.
  - https://github.com/MASILab/DeepN4
- **Alternatives:** `simko_implicit_bias` (research), `n4itk` (classical)

### FastSurferVINN (asegdkt) {#fastsurfer_vinn}

- **Replaces (classical):** CA aseg / classical volumetric labeling + DK-style cortex labels
- **CLI / resource:** `run_fastsurfer.sh (asegdkt module)`
- **Why chosen:** Primary whole-brain morphometry engine for DLSurfer. Resolution-independent (0.7–1.0 mm) DL segmentation into FreeSurfer-compatible DKT/aseg products in minutes on GPU. This is the core reason DLSurfer defaults to FastSurfer rather than classical recon-all for 'core' profiles. Atlas default = DKT; other atlases are orthogonal (see docs/ATLASES.md) — DLSurfer is not DKT-connectome.
- **Cite:**
  - Henschel L, et al. FastSurfer. NeuroImage 2020;219:117012.
  - Henschel L, Kuegler D, Reuter M. FastSurferVINN. NeuroImage 2022;251:118933.
- **Alternatives:** `synthseg` (production), `quicknat` (research), `deepscan` (research), `assemblynet` (research), `slant` (research)

### SynthSeg {#synthseg}

- **Replaces (classical):** CA aseg; clinical / odd-contrast labeling
- **CLI / resource:** `mri_synthseg`
- **Why chosen:** Best Production alternative when T1 quality/contrast/resolution is non-standard, or when using profile fs8 / seg-quick-synthseg. Domain-randomized; ships in FreeSurfer. Not the default for research-grade isotropic T1 (VINN preferred).
- **Cite:**
  - Billot B, et al. SynthSeg. Medical Image Analysis / FreeSurfer wiki SynthSeg.
  - https://surfer.nmr.mgh.harvard.edu/fswiki/SynthSeg
- **Alternatives:** `fastsurfer_vinn` (production)

### FastSurfer-CC {#fastsurfer_cc}

- **Replaces (classical):** Classical / limited CC post-processing
- **CLI / resource:** `run_fastsurfer.sh (cc; disable with --no_cc)`
- **Why chosen:** Validated CC morphometry module in the default FastSurfer stack; included in 'core' so DLSurfer matches upstream FastSurfer defaults rather than stripping modules.
- **Cite:**
  - Pollak C, et al. FastSurfer-CC. Imaging Neuroscience 2026. doi:10.1162/IMAG.a.1221
- **Alternatives:** `classical_cc` (classical), `skip_cc` (production)

### CerebNet {#cerebnet}

- **Replaces (classical):** Limited classical cerebellum sub-segmentation
- **CLI / resource:** `run_fastsurfer.sh (cereb; --no_cereb to disable)`
- **Why chosen:** Production cerebellum sub-segmentation in FastSurfer; kept on in 'core' for parity with upstream morphometry defaults.
- **Cite:**
  - Faber J, et al. CerebNet. NeuroImage 2022;264:119703.
- **Alternatives:** `classical_cereb` (classical), `skip_cereb` (production)

### HypVINN {#hypvinn}

- **Replaces (classical):** Sparse classical hypothalamic labeling
- **CLI / resource:** `run_fastsurfer.sh (hypothal; optional --t2)`
- **Why chosen:** Production hypothalamus + adjacent structure module. Preferred over ScLimbic when the FastSurfer engine is selected (XOR with FS-only ScLimbic path).
- **Cite:**
  - Estrada S, et al. FastSurfer-HypVINN. Imaging Neuroscience 2023.
- **Alternatives:** `sclimbic` (production), `skip_hypothal` (production)

### neuroLIT / FastSurfer-LIT {#neurolit}

- **Replaces (classical):** No native classical lesion fill in FS/FastSurfer
- **CLI / resource:** `lit-inpainting ; lit-postprocessing ; or run_fastsurfer.sh --lesion_mask`
- **Why chosen:** Best Production lesion inpainting (DDPM). Standalone lit-inpainting is the DEFAULT lesion path in DLSurfer because native --lesion_mask cannot use FastSurfer --seg_only/--surf_only (breaks GPU/CPU HPC split). lit-postprocessing restores LIT packaging after ordinary recon. Native --lesion_mask remains an explicit opt-in profile.
- **Cite:**
  - Pollak C, et al. FastSurfer-LIT. Imaging Neuroscience 2025. doi:10.1162/imag_a_00446
  - https://github.com/Deep-MI/neurolit
  - FastSurfer LIT docs: https://deep-mi.org/FastSurfer/stable/overview/modules/LIT.html
- **Alternatives:** `neurolit_native_flag` (production), `vbg` (ready), `leapp_vbt` (ready), `enantiomorphic` (ready)

### FastSurfer recon-surf (classical geometry) {#recon_surf}

- **Replaces (classical):** FS surface stages (tessellate→topology→white/pial→sphere→thickness)
- **CLI / resource:** `run_fastsurfer.sh (surf) / recon-surf.sh`
- **Why chosen:** Still the Production surface path for SUBJECTS_DIR / QSIRecon compatibility. Not deep learning (spectral embedding + FreeSurfer binaries). Kept as default surfaces backend until Phase-3 surf-dl backends pass the TBI±LIT gate. This is intentional: DLSurfer does not fake a DL surface drop-in before validation.
- **Cite:**
  - Henschel L, et al. FastSurfer. NeuroImage 2020 (recon-surf description).
  - Fischl B. FreeSurfer. NeuroImage 2012 (underlying surface methods).
- **Alternatives:** `topofit` (production), `v2c_flow` (ready), `cortexode` (research), `pialnn` (research), `corticalflow` (research), `surfnn` (research), `deepcsr` (research), `fastcsr` (research), `recon_all_clinical` (production)

### SynthMorph {#synthmorph}

- **Replaces (classical):** Talairach / CA linear+nonlinear volumetric registration
- **CLI / resource:** `mri_synthmorph`
- **Why chosen:** Best Production acquisition-agnostic DL registration in FreeSurfer. Used as a utility profile for multimodal alignment / MNI mapping — not required inside FastSurfer 'core' (VINN path), but exposed so classical CA register is not reintroduced by lab scripts.
- **Cite:**
  - Hoffmann M, et al. SynthMorph. IEEE TMI 2022; Imaging Neuroscience 2024.
  - https://synthmorph.io
- **Alternatives:** `easyreg` (production), `voxelmorph` (research), `ants` (classical)

### EasyReg {#easyreg}

- **Replaces (classical):** Classical symmetric diffeomorphic volume registration
- **CLI / resource:** `mri_easyreg`
- **Why chosen:** Best Production symmetric, invertible, modality-agnostic registration CLI in FreeSurfer 7.4+. Prefer when directionality/symmetry matters; companion to SynthMorph for utility registration tasks.
- **Cite:**
  - Iglesias JE, et al. EasyReg. Scientific Reports 2023. doi:10.1038/s41598-023-33781-0
  - https://surfer.nmr.mgh.harvard.edu/fswiki/EasyReg
- **Alternatives:** `synthmorph` (production), `voxelmorph` (research)

### FreeSurfer 8 recon-all {#freesurfer8}

- **Replaces (classical):** FS≤7 classical early stages (embeds SynthSeg/Strip/Morph)
- **CLI / resource:** `recon-all`
- **Why chosen:** Alternate morphometry engine (XOR with FastSurfer). FS8 already embeds DL for strip/seg/reg while keeping classical surfaces. Offered as profile 'fs8' for sites standardized on FreeSurfer outputs or longitudinal FS workflows.
- **Cite:**
  - FreeSurfer 8.0.0 release notes (SynthSeg, SynthStrip, SynthMorph in recon-all).
  - Fischl B. FreeSurfer. NeuroImage 2012.
- **Alternatives:** `fastsurfer_core` (production), `recon_all_clinical` (production)

### TopoFit {#topofit}

- **Replaces (classical):** Topology fixer + white-surface placement (partial)
- **CLI / resource:** `mris_estimate_wm`
- **Why chosen:** Best Production DL white-surface fit already shipped in FreeSurfer (mris_estimate_wm). First Phase-3 surf-dl building block: lowest integration risk. Does not alone replace pial/thickness/aparc — pair with recon-surf pial or V2C-Flow for full surfaces.
- **Cite:**
  - Hoopes A, et al. TopoFit. MIDL 2022.
  - https://github.com/ahoopes/topofit
- **Alternatives:** `v2c_flow` (ready), `cortexode` (research), `recon_surf` (classical)

### V2C-Flow (Vox2Cortex-Flow) {#v2c_flow}

- **Replaces (classical):** White+pial surfaces; often sphere.reg via template IDs
- **CLI / resource:** `vox2organ / V2C-Flow pretrained`
- **Why chosen:** Best Ready full explicit CSR: joint WM+pial, <2s, fsaverage-compatible vertex correspondence. Primary candidate to replace recon-surf for speed once TBI±LIT validation passes. Not SUBJECTS_DIR drop-in — adapter must map meshes into FS tree / analysis convention (scanner RAS).
- **Cite:**
  - Bongratz F, et al. Vox2Cortex. CVPR 2022.
  - Bongratz F, et al. V2C-Flow. arXiv:2401.12938 (2024).
  - https://github.com/ai-med/Vox2Cortex
- **Alternatives:** `vox2cortex` (ready), `cortexode` (research), `pialnn` (research), `surfnn` (research), `topofit` (production)

### SUGAR {#sugar}

- **Replaces (classical):** Spherical registration to fsaverage (sphere.reg)
- **CLI / resource:** `SUGAR (see upstream README)`
- **Why chosen:** Best Ready dedicated spherical surface registration (large multi-dataset eval, sub-second). Used when recon-surf or TopoFit meshes exist but classical sphere.reg is the measured bottleneck — or when V2C-Flow correspondences are not used.
- **Cite:**
  - Ren J, et al. SUGAR. arXiv:2307.00511 (2023).
  - https://github.com/pBFSLab/SUGAR
- **Alternatives:** `s3reg` (ready), `v2c_flow_ids` (ready), `classical_sphere_reg` (classical)

### DL-CTE / CortexMorph family {#dl_cte}

- **Replaces (classical):** Surface-based cortical thickness (when surfaces not required)
- **CLI / resource:** `dl-cte / cortexmorph`
- **Why chosen:** Best Ready fast thickness without full FreeSurfer surfaces (CNN seg + diffeomorphic DiReCT-style registration). Profile 'thickness-fast' only — NOT a substitute for surface morphometry or connectome parcels.
- **Cite:**
  - Rebsamen M, et al. DL+DiReCT. Hum Brain Mapp 2020.
  - CortexMorph arXiv:2307.11567 (2023).
  - Wu et al. DL-CTE 2025. https://github.com/wujiong-hub/DL-CTE
- **Alternatives:** `dl_direct` (ready), `cortexmorph` (ready), `surface_thickness` (classical)

### FreeSurfer longitudinal (-base / -long) {#freesurfer_long}

- **Replaces (classical):** Cross-sectional-only morphometry
- **CLI / resource:** `recon-all -base … ; recon-all -long …`
- **Why chosen:** Best Production alternative for the longitudinal gap. FreeSurfer -base/-long remains the field standard; FastSurfer longitudinal support is limited.
- **Cite:**
  - Reuter et al. NeuroImage 2012 (longitudinal FreeSurfer)
  - FreeSurfer Longitudinal Processing docs
- **Alternatives:** `synthseg_per_tp` (production), `v2c_long` (early)

### FreeSurfer hippocampal/amygdala subfields (HA) {#segment_ha}

- **Replaces (classical):** Whole-hippocampus aseg only
- **CLI / resource:** `segmentHA_T1.sh <sid> <SUBJECTS_DIR>`
- **Why chosen:** Best Production alternative for the HA gap — segmentHA_T1 / recon-all -hippocampal-subfields-T1 on an existing SUBJECTS_DIR.
- **Cite:**
  - Iglesias et al. NeuroImage 2015 (hippocampal subfields)
  - Saygin et al. NeuroImage 2017 (amygdala)
- **Alternatives:** `hippunfold` (ready), `hippodeep` (research)

### FreeSurfer brainstem structures {#segment_bs}

- **Replaces (classical):** Whole brainstem aseg label
- **CLI / resource:** `segmentBS.sh <sid> <SUBJECTS_DIR>`
- **Why chosen:** Best Production alternative for brainstem nuclei gap (segmentBS.sh).
- **Cite:**
  - Iglesias et al. NeuroImage 2015 (brainstem)
- **Alternatives:** `none_dl_default` (none)

### FreeSurfer thalamic nuclei {#segment_thalamic}

- **Replaces (classical):** Whole thalamus aseg label
- **CLI / resource:** `segmentThalamicNuclei.sh <sid> <SUBJECTS_DIR>`
- **Why chosen:** Best Production alternative for thalamic nuclei gap (segmentThalamicNuclei.sh).
- **Cite:**
  - Iglesias et al. NeuroImage 2018 (thalamic nuclei)
- **Alternatives:** `none_dl_default` (none)

### recon-all-clinical (SynthSeg/SynthDist clinical) {#recon_all_clinical}

- **Replaces (classical):** Standard recon-all on clinical / low-res / odd-contrast
- **CLI / resource:** `recon-all-clinical.sh …`
- **Why chosen:** Best Production alternative for infant/clinical gap when standard recon-all or FastSurferVINN is inappropriate (clinical stream in FS7.3+/FS8).
- **Cite:**
  - Billot SynthSeg; FreeSurfer recon-all-clinical docs
- **Alternatives:** `synthseg` (production), `infant_freesurfer` (production)

### Destrieux (a2009s) parcellation {#atlas_destrieux}

- **Replaces (classical):** DKT-only cortical labels
- **CLI / resource:** `recon-all -s <sid> -sd <SUBJECTS_DIR> -a2009s`
- **Why chosen:** Best alternative for Destrieux gap — classical FreeSurfer -a2009s on existing surfaces (sphere.reg required). Not VINN-native.
- **Cite:**
  - Destrieux et al. NeuroImage 2010
  - FreeSurfer aparc.a2009s docs
- **Alternatives:** `mris_ca_label_manual` (classical)

### Schaefer surface projection {#atlas_schaefer}

- **Replaces (classical):** Anatomical-only cortical atlases
- **CLI / resource:** `mri_surf2surf --srcsubject fsaverage --trgsubject <sid> --sval-annot …`
- **Why chosen:** Best Ready alternative for Schaefer/MMP gap — project fsaverage annot after sphere.reg (classical FS surf2surf). Annot source is external.
- **Cite:**
  - Schaefer et al. Cerebral Cortex 2018
  - FreeSurfer mri_surf2surf / label projection docs
- **Alternatives:** `hcp_mmp` (ready), `yeo_networks` (ready)

### FastSurfer srun / brun HPC wrap {#srun_fastsurfer}

- **Replaces (classical):** Manual sbatch of run_fastsurfer.sh
- **CLI / resource:** `srun_fastsurfer.sh …  OR  brun_fastsurfer.sh …`
- **Why chosen:** Best Production alternative for the srun gap — use upstream srun_fastsurfer.sh / brun_fastsurfer.sh (enabled via --hpc srun).
- **Cite:**
  - FastSurfer HPC docs (brun_fastsurfer / srun_fastsurfer)
- **Alternatives:** `slurm_template` (production)

### Mauri claustrum (mri_claustrum_seg) {#mauri_claustrum}

- **Replaces (classical):** No claustrum in standard aseg / FastSurferVINN
- **CLI / resource:** `mri_claustrum_seg --i <T1w> --o <outdir> --threads N --topo-correct`
- **Lab path:** `Documents/clau_seg`
- **Why chosen:** Best Production DL tool for claustrum — FreeSurfer-integrated contrast-agnostic U-Net (Mauri 2025). Lab path Documents/clau_seg; put0 FoV lock for IDEAS. Not a piriform / PC model — do not reuse weights for Steinbart 125/126.
- **Cite:**
  - Mauri C, et al. Hum Brain Mapp. 2025;46:e70303. doi:10.1002/hbm.70303
  - https://github.com/chiara-mauri/claustrum_segmentation
- **Alternatives:** `albishri_cnn` (research), `casamitjana_bayesian` (research)

### SynthSeg-PC (Billot GMM → U-Net piriform) {#synthseg_pc}

- **Replaces (classical):** MAPER / JLF piriform (Steinbart 125/126) when DL gate passes
- **CLI / resource:** `python Documents/piriform/synthseg_pc/predict_ideas_one.py --images … --model …`
- **Lab path:** `Documents/piriform/synthseg_pc`
- **Why chosen:** Lab SynthSeg-style PC segmenter (Documents/piriform/synthseg_pc): GMM on-the-fly train → U-Net predict on Hammers dense FoV. NOT FreeSurfer mri_synthseg (no PC class). NOT Mauri claustrum weights. Experimental until Hammers/IDEAS eval clears JLF bar; IDEAS production PC remains JLF until that gate.
- **Cite:**
  - Billot B, et al. Nat Commun. 2023 (SynthSeg / GMM training)
  - Steinbart D, et al. Hum Brain Mapp. 2023 (PC labels 125/126)
  - Mauri et al. 2025 (dense FoV / real-T1 epoch pattern — not claustrum weights)
  - Hammers A, et al. Hum Brain Mapp. 2003
- **Alternatives:** `jlf_pc` (production), `maper_pc` (production), `nnunet_pc` (research)

### SynthSR (mri_synthsr) {#synthsr}

- **Replaces (classical):** Manual clinical T1 upsampling / contrast salvage
- **CLI / resource:** `mri_synthsr --i <in> --o <out>`
- **Why chosen:** Optional T1 preprocess only — 1 mm T1-like from poor clinical scans (Billot). Does NOT segment piriform or claustrum. Feed output into core / structure-* profiles. Matches Documents/piriform/synthseg_pc/maybe_synthsr.sh policy.
- **Cite:**
  - Billot B, et al. SynthSR (FreeSurfer mri_synthsr)
  - Iglesias / Billot Synth* family docs
- **Alternatives:** `skip_synthsr` (production), `recon_all_clinical` (production)

### HippUnfold {#hippunfold}

- **Replaces (classical):** FS segmentHA volumetric subfields (surface-unfold alternative)
- **CLI / resource:** `hippunfold <bids> <out> participant …`
- **Lab path:** `Documents/HippUnfold`
- **Why chosen:** Best Ready DL alternative to segmentHA for hippocampal sheet morphometry. Optional profile; default HA gap-fill remains classical segmentHA_T1.
- **Cite:**
  - DeKraker J, et al. eLife 2022;11:e77945
- **Alternatives:** `segment_ha` (production), `hippodeep` (research)

## Deferred (not defaults)

- `hdbet` — Credible Ready stripper, but SynthStrip is already in FS and preferred for one-license tooling.
- `vbg` — Ready fill, but Deutscher 2025 shows VBG can worsen FastSurfer on ms-TBI; TBI policy required first.
- `leapp_vbt` — Stroke-oriented; lab VBT orientation SIGSEGV on radiological TBI T1s.
- `cortexode` — Strong Research CSR; V2C-Flow chosen first as Ready pretrained full WM+pial.
- `pialnn` — WM→pial only; consider after TopoFit if V2C-Flow fails TBI gate.
- `s3reg` — Ready spherical reg; SUGAR chosen first for multi-dataset eval + speed claims.
- `quicknat` — Credible seg; VINN/SynthSeg preferred for FS-shaped trees.
- `deepscan` — Strong hybrid-pipeline seg; keep as documented alternative to VINN.
- `beyondfs_zoo` — SLANT/AssemblyNet/GIF/FIRST/etc. belong in piriform/beyondfs identity (structures FS does not give) — do not dilute DLSurfer core with a methods zoo.

- `mauri_weights_as_pc` — Never cite or run Mauri claustrum weights as Steinbart piriform — wrong structure.

