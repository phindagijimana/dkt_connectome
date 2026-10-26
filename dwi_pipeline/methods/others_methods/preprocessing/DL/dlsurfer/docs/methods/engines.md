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
| **DL-CTE / CortexMorph family** (`dl_cte`) · ready | `dlsurfer-cortexmorph` | Rebsamen M, et al. DL+DiReCT. Hum Brain Mapp 2020.<br>CortexMorph arXiv:2307.11567 (2023). https://github.com/SCAN-NRAD/CortexMorph<br>Wu et al. DL-CTE 2025 (repo placeholder at time of wiring). |
| **FreeSurfer longitudinal (-base / -long)** (`freesurfer_long`) · production | `recon-all -base … ; recon-all -long …` | Reuter et al. NeuroImage 2012 (longitudinal FreeSurfer)<br>FreeSurfer Longitudinal Processing docs |
| **V2C-Long** (`v2c_long`) · ready | `dlsurfer-v2c-long` | Bongratz F, et al. V2C-Long. Imaging Neuroscience 2025. doi:10.1162/imag_a_00500<br>https://github.com/ai-med/Vox2Cortex |
| **FreeSurfer hippocampal/amygdala subfields (HA)** (`segment_ha`) · production | `segmentHA_T1.sh <sid> <SUBJECTS_DIR>` | Iglesias et al. NeuroImage 2015 (hippocampal subfields)<br>Saygin et al. NeuroImage 2017 (amygdala) |
| **FreeSurfer brainstem structures** (`segment_bs`) · production | `segmentBS.sh <sid> <SUBJECTS_DIR>` | Iglesias et al. NeuroImage 2015 (brainstem) |
| **MARS brainstem (nnU-Net)** (`mars_brainstem`) · ready | `dlsurfer-mars-brainstem` | Gesierich B, et al. Hum Brain Mapp. 2025. doi:10.1002/hbm.70141<br>https://github.com/miac-research/dl-brainstem<br>Zenodo nnU-Net weights: https://zenodo.org/records/13323293 |
| **FreeSurfer thalamic nuclei** (`segment_thalamic`) · production | `segmentThalamicNuclei.sh <sid> <SUBJECTS_DIR>` | Iglesias et al. NeuroImage 2018 (thalamic nuclei) |
| **FreeSurfer thalamic nuclei DTI-CNN** (`thalamic_dti_cnn`) · ready | `dlsurfer-thalamic-dti-cnn / mri_segment_thalamic_nuclei_dti_cnn` | FreeSurfer wiki ThalamicNucleiDTI (CNN extension of Iglesias thalamic atlas)<br>https://surfer.nmr.mgh.harvard.edu/fswiki/ThalamicNucleiDTI |
| **recon-all-clinical (SynthSeg/SynthDist clinical)** (`recon_all_clinical`) · production | `recon-all-clinical.sh …` | Billot SynthSeg; FreeSurfer recon-all-clinical docs<br>recon-all-clinical / SynthDist arXiv:2409.03889 |
| **iBEAT V2.0** (`infant_ibeat`) · ready | `dlsurfer-ibeat` | Wang L, et al. iBEAT V2.0. Nat Protoc. 2023;18:1488-1509<br>https://github.com/iBEAT-V2/iBEAT-V2.0-Docker<br>http://www.ibeat.cloud |
| **Destrieux (a2009s) parcellation** (`atlas_destrieux`) · production | `recon-all -s <sid> -sd <SUBJECTS_DIR> -a2009s` | Destrieux et al. NeuroImage 2010<br>FreeSurfer aparc.a2009s docs |
| **Schaefer surface projection** (`atlas_schaefer`) · ready | `mri_surf2surf --srcsubject fsaverage --trgsubject <sid> --sval-annot …` | Schaefer et al. Cerebral Cortex 2018<br>FreeSurfer mri_surf2surf / label projection docs |
| **ScLimbic (mri_sclimbic_seg)** (`sclimbic`) · production | `dlsurfer-sclimbic / mri_sclimbic_seg` | Greve DN, et al. NeuroImage 2021;118610 (ScLimbic)<br>https://surfer.nmr.mgh.harvard.edu/fswiki/ScLimbic |
| **WMH-SynthSeg** (`wmh_synthseg`) · ready | `dlsurfer-wmh-synthseg / mri_WMHsynthseg` | Laso P, et al. Quantifying WMH and brain volumes in heterogeneous clinical and low-field MRI. arXiv:2312.05119<br>https://surfer.nmr.mgh.harvard.edu/fswiki/WMH-SynthSeg |
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
- **Why chosen:** Best Production alternative when T1 quality/contrast/resolution is non-standard, or when using profile fs8 / seg-quick-synthseg. Domain-randomized; ships in FreeSurfer. Not the default for research-grade isotropic T1 (VINN preferred). Profile `seg-synthseg-robust` adds `--robust` / `--qc`.
- **Cite:**
  - Billot B, et al. SynthSeg. Medical Image Analysis / FreeSurfer wiki SynthSeg.
  - https://surfer.nmr.mgh.harvard.edu/fswiki/SynthSeg
- **Alternatives:** `fastsurfer_vinn` (production), `synthseg_robust` (production), `super_synth` (ready), `wmh_synthseg` (ready)
- **Run:** `dlsurfer tool synthseg --t1 T1 --sd SD --sid SID` · robust+QC: see [FS_DL_METHODS](../reference/FS_DL_METHODS.md)

### SynthSeg (--robust + QC) {#synthseg_robust}

- **Replaces (classical):** Manual QC of odd-contrast aseg
- **CLI / resource:** `mri_synthseg --parc --robust --qc … --vol …`
- **Why chosen:** SynthSeg 2.0 robust mode with automated Dice QC + volume CSV.
- **Cite:**
  - Billot B, et al. SynthSeg. *Medical Image Analysis* 2023.
  - https://surfer.nmr.mgh.harvard.edu/fswiki/SynthSeg
- **Alternatives:** `synthseg` (production)
- **Run:** `dlsurfer tool synthseg-robust --t1 T1 --sd SD --sid SID`

### SuperSynth {#super_synth}

- **Replaces (classical):** Separate SynthSeg+SynthSR+reg pipelines for odd FOV / ex vivo
- **CLI / resource:** `mri_super_synth --mode invivo|exvivo|cerebrum|left-hemi|right-hemi`
- **Why chosen:** Multi-task Synth* foundation (seg / WMH / MNI reg / contrast synth / QC). Needs FS with `mri_super_synth`.
- **Cite:**
  - https://surfer.nmr.mgh.harvard.edu/fswiki/SuperSynth
  - Billot SynthSeg / SynthSR lineage
- **Alternatives:** `synthseg` (production), `synthsr` (production)
- **Run:** `SUPERSYNTH_MODE=invivo dlsurfer tool super-synth --t1 T1 --sd SD --sid SID`

### EasyAtlas {#easyatlas}

- **Replaces (classical):** `make_average_subject` / classical template building
- **CLI / resource:** `mri_easyatlas --i <scan_dir> --o <out>`
- **Why chosen:** DL group atlas via iterative EasyReg (~1 min/scan CPU).
- **Cite:**
  - Iglesias JE, et al. EasyReg. *Sci Rep.* 2023. doi:10.1038/s41598-023-33781-0
  - https://surfer.nmr.mgh.harvard.edu/fswiki/EasyReg
- **Alternatives:** `easyreg` (production)
- **Run:** `EASYATLAS_INPUT_DIR=/scans dlsurfer tool easyatlas --t1 T1 --sd SD --sid SID`

### NextBrain histo atlas (FireANTs) {#histo_atlas}

- **Replaces (classical):** Coarse subcortical labeling without histology prior
- **CLI / resource:** `mri_histo_atlas_segment_fireants --side left|right --mode invivo|…`
- **Why chosen:** Fine-grained (~300 ROI/hemi) NextBrain histology-informed segmentation (fast FireANTs path).
- **Cite:**
  - Casamitjana A, et al. NextBrain atlas. *Nature* 2025. doi:10.1038/s41586-025-09708-2
  - Puonti O, et al. Fast NextBrain segmentation. *Imaging Neuroscience* 2026. doi:10.1162/imag.a.1244
  - https://surfer.nmr.mgh.harvard.edu/fswiki/HistoAtlasSegmentation
- **Alternatives:** `super_synth` (ready), `synthseg` (production)
- **Run:** `HISTO_ATLAS_SIDE=left HISTO_ATLAS_MODE=invivo dlsurfer tool histo-atlas --t1 T1 --sd SD --sid SID`

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
- **Why chosen:** Production hypothalamus + adjacent structure module. Preferred over ScLimbic when the FastSurfer engine is selected (XOR with FS-only ScLimbic path). Pass `--t2` / `HYPVINN_T2` or use profile `structure-hypvinn-t2`.
- **Cite:**
  - Estrada S, et al. FastSurfer-HypVINN. Imaging Neuroscience 2023.
  - FastSurfer HypVINN module docs (`--t2`)
- **Alternatives:** `hypvinn_t2` (production), `sclimbic` (production), `skip_hypothal` (production)
- **Run:** T1-only via `core`; with T2: `dlsurfer tool hypvinn-t2 --t1 T1 --t2 T2 --sd SD --sid SID` · [FS_DL_METHODS](../reference/FS_DL_METHODS.md)

### HypVINN with T2 {#hypvinn_t2}

- **Replaces (classical):** T1-only hypothalamic labeling
- **CLI / resource:** `run_fastsurfer.sh --t1 … --t2 <T2w> --seg_only …`
- **Why chosen:** Explicit multi-modal HypVINN path when co-registered T2 exists.
- **Cite:** Estrada S, et al. FastSurfer-HypVINN. *Imaging Neuroscience* 2023.
- **Alternatives:** `hypvinn` (production; T1-only in `core`)
- **Run:** `dlsurfer tool hypvinn-t2 --t1 T1 --t2 T2 --sd SD --sid SID` or `dlsurfer recon-all … --t2 T2`

### FS8 embedded DL helpers {#fs8_dl_helpers}

- **Replaces (classical):** Manual pial edits for sinus/MCA; classical EC WM
- **CLI / resource:** Inside FS≥8 `recon-all` (not separate binaries)
- **Why chosen:** Inventory exposure of FS8-internal DL (sinus/MCA-dura pial, EC WM DL, Synth* touches). Public DL morphometry default remains FastSurfer `core`.
- **Cite:**
  - FreeSurfer 8 release notes
  - Fischl B. FreeSurfer. *NeuroImage* 2012;62:774–781
- **Alternatives:** `fastsurfer_vinn` (production), `topofit` (production)
- **Run:** `dlsurfer tool fs8-dl --t1 T1 --sd SD --sid SID` · [FS_DL_METHODS](../reference/FS_DL_METHODS.md)

### neuroLIT / FastSurfer-LIT {#neurolit}

- **Replaces (classical):** No native classical lesion fill in FS/FastSurfer
- **CLI / resource:** `lit-inpainting ; lit-postprocessing`
- **Why chosen:** Best Production lesion inpainting (DDPM). DLSurfer LIT is **DL separable only** (standalone inpaint → FastSurfer split → lit-post). Upstream `--lesion_mask` is not on the public path (blocks HPC split).
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
- **CLI / resource:** `dlsurfer-cortexmorph`
- **Why chosen:** Best Ready fast thickness without full FreeSurfer surfaces. Implementation default is CortexMorph (public weights; SCAN-NRAD) because Wu DL-CTE GitHub is empty. Profile 'thickness-fast' only — NOT for connectome parcels.
- **Cite:**
  - Rebsamen M, et al. DL+DiReCT. Hum Brain Mapp 2020.
  - CortexMorph arXiv:2307.11567 (2023). https://github.com/SCAN-NRAD/CortexMorph
  - Wu et al. DL-CTE 2025 (repo placeholder at time of wiring).
- **Alternatives:** `dl_direct` (ready), `cortexmorph` (ready), `surface_thickness` (classical)

### FreeSurfer longitudinal (-base / -long) {#freesurfer_long}

- **Replaces (classical):** Cross-sectional-only morphometry
- **CLI / resource:** `recon-all -base … ; recon-all -long …`
- **Why chosen:** Classical Production longitudinal path (not DL). Prefer profile surf-dl-v2c-long (V2C-Long) when Phase-3 longitudinal DL gate passes.
- **Cite:**
  - Reuter et al. NeuroImage 2012 (longitudinal FreeSurfer)
  - FreeSurfer Longitudinal Processing docs
- **Alternatives:** `v2c_long` (ready), `synthseg_per_tp` (production)

### V2C-Long {#v2c_long}

- **Replaces (classical):** FreeSurfer -base/-long surface longitudinal
- **CLI / resource:** `dlsurfer-v2c-long`
- **Why chosen:** Best Ready dedicated deep-learning longitudinal CSR (spatiotemporal template correspondence). Preferred DL alternative to classical fs-long once V2C-Flow and V2C-Long TBI±LIT gates pass.
- **Cite:**
  - Bongratz F, et al. V2C-Long. Imaging Neuroscience 2025. doi:10.1162/imag_a_00500
  - https://github.com/ai-med/Vox2Cortex
- **Alternatives:** `freesurfer_long` (production), `v2c_flow` (ready)

### FreeSurfer hippocampal/amygdala subfields (HA) {#segment_ha}

- **Replaces (classical):** Whole-hippocampus aseg only
- **CLI / resource:** `segmentHA_T1.sh <sid> <SUBJECTS_DIR>`
- **Why chosen:** Classical Bayesian HA/amygdala nuclei (Iglesias/Saygin) — not DL. Prefer structure-hippunfold (HippUnfold) for DL hippocampal morphometry.
- **Cite:**
  - Iglesias et al. NeuroImage 2015 (hippocampal subfields)
  - Saygin et al. NeuroImage 2017 (amygdala)
- **Alternatives:** `hippunfold` (ready), `hippodeep` (research)

### FreeSurfer brainstem structures {#segment_bs}

- **Replaces (classical):** Whole brainstem aseg label
- **CLI / resource:** `segmentBS.sh <sid> <SUBJECTS_DIR>`
- **Why chosen:** Classical Bayesian brainstem (Iglesias 2015) — not DL. Prefer structure-brainstem-mars (MARS nnU-Net) for DL brainstem volumes.
- **Cite:**
  - Iglesias et al. NeuroImage 2015 (brainstem)
- **Alternatives:** `mars_brainstem` (ready)

### MARS brainstem (nnU-Net) {#mars_brainstem}

- **Replaces (classical):** FS segmentBS Bayesian brainstem
- **CLI / resource:** `dlsurfer-mars-brainstem`
- **Why chosen:** Best Ready deep-learning brainstem segmentation with public Apptainer/Docker and Zenodo weights (Gesierich 2025). Preferred DL alternative to classical segmentBS for total brainstem / substructure volumes (not FS AAN nuclei).
- **Cite:**
  - Gesierich B, et al. Hum Brain Mapp. 2025. doi:10.1002/hbm.70141
  - https://github.com/miac-research/dl-brainstem
  - Zenodo nnU-Net weights: https://zenodo.org/records/13323293
- **Alternatives:** `segment_bs` (production), `mars_mdgru` (ready)

### FreeSurfer thalamic nuclei {#segment_thalamic}

- **Replaces (classical):** Whole thalamus aseg label
- **CLI / resource:** `segmentThalamicNuclei.sh <sid> <SUBJECTS_DIR>`
- **Why chosen:** Classical Bayesian thalamic nuclei (Iglesias 2018) — not DL. Prefer nuclei-thalamic-dti-cnn when FA/V1 available (FS DL CNN).
- **Cite:**
  - Iglesias et al. NeuroImage 2018 (thalamic nuclei)
- **Alternatives:** `thalamic_dti_cnn` (ready), `deep_thomas` (research)

### FreeSurfer thalamic nuclei DTI-CNN {#thalamic_dti_cnn}

- **Replaces (classical):** Bayesian segmentThalamicNuclei (T1-only)
- **CLI / resource:** `dlsurfer-thalamic-dti-cnn / mri_segment_thalamic_nuclei_dti_cnn`
- **Why chosen:** Best Ready deep-learning thalamic nuclei tool in FreeSurfer — CNN trained to handle T1+FA+V1 with variable DTI resolution (25 nuclei). Preferred DL alternative when diffusion prep exists; T1-only Bayesian remains fallback.
- **Cite:**
  - FreeSurfer wiki ThalamicNucleiDTI (CNN extension of Iglesias thalamic atlas)
  - https://surfer.nmr.mgh.harvard.edu/fswiki/ThalamicNucleiDTI
- **Alternatives:** `segment_thalamic` (production), `deep_thomas` (research)

### recon-all-clinical (SynthSeg/SynthDist clinical) {#recon_all_clinical}

- **Replaces (classical):** Standard recon-all on clinical / low-res / odd-contrast
- **CLI / resource:** `recon-all-clinical.sh …`
- **Why chosen:** Hybrid DL clinical stream (SynthSeg + SynthSR + SynthDist SDF CNN + classical geometry). Best Production path for odd contrast/resolution; for true infants prefer infant-ibeat (DL) XOR Infant FreeSurfer.
- **Cite:**
  - Billot SynthSeg; FreeSurfer recon-all-clinical docs
  - recon-all-clinical / SynthDist arXiv:2409.03889
- **Alternatives:** `infant_ibeat` (ready), `synthseg` (production), `infant_freesurfer` (production)

### iBEAT V2.0 {#infant_ibeat}

- **Replaces (classical):** Infant FreeSurfer / adult FastSurfer on neonates–toddlers
- **CLI / resource:** `dlsurfer-ibeat`
- **Why chosen:** Best Ready deep-learning infant cortical pipeline (birth–6 years, T1/T2, Docker/cloud). XOR with adult core / fs-clinical — not a drop-in adult TBI default.
- **Cite:**
  - Wang L, et al. iBEAT V2.0. Nat Protoc. 2023;18:1488-1509
  - https://github.com/iBEAT-V2/iBEAT-V2.0-Docker
  - http://www.ibeat.cloud
- **Alternatives:** `recon_all_clinical` (production), `dhcp_dl_neonatal` (ready)

### Destrieux (a2009s) parcellation {#atlas_destrieux}

- **Replaces (classical):** DKT-only cortical labels
- **CLI / resource:** `recon-all -s <sid> -sd <SUBJECTS_DIR> -a2009s`
- **Why chosen:** Classical FS -a2009s classifier (not DL). Prefer atlas-destrieux-dl (SUGAR sphere.reg → -a2009s) so the registration stage is deep learning.
- **Cite:**
  - Destrieux et al. NeuroImage 2010
  - FreeSurfer aparc.a2009s docs
- **Alternatives:** `sugar` (ready), `mris_ca_label_manual` (classical)

### Schaefer surface projection {#atlas_schaefer}

- **Replaces (classical):** Anatomical-only cortical atlases
- **CLI / resource:** `mri_surf2surf --srcsubject fsaverage --trgsubject <sid> --sval-annot …`
- **Why chosen:** Annot projection is classical surf2surf; Schaefer atlas itself is not a network. Prefer atlas-schaefer-dl (SUGAR → project) so registration is deep learning.
- **Cite:**
  - Schaefer et al. Cerebral Cortex 2018
  - FreeSurfer mri_surf2surf / label projection docs
- **Alternatives:** `sugar` (ready), `hcp_mmp` (ready), `yeo_networks` (ready)

### ScLimbic (mri_sclimbic_seg) {#sclimbic}

- **Replaces (classical):** Missing limbic subunits (BF, septum, fornix, MB, NAc beyond HypVINN)
- **CLI / resource:** `dlsurfer-sclimbic / mri_sclimbic_seg`
- **Why chosen:** Best Production FreeSurfer deep-learning limbic toolbox (3D U-Net). XOR with HypVINN on FastSurfer core for overlapping hypothalamus; use on FS trees or when basal forebrain / fornix / mammillary bodies are required.
- **Cite:**
  - Greve DN, et al. NeuroImage 2021;118610 (ScLimbic)
  - https://surfer.nmr.mgh.harvard.edu/fswiki/ScLimbic
- **Alternatives:** `hypvinn` (production)

### WMH-SynthSeg {#wmh_synthseg}

- **Replaces (classical):** SynthSeg without WMH; classical WMH tools (LST/BIANCA)
- **CLI / resource:** `dlsurfer-wmh-synthseg / mri_WMHsynthseg`
- **Why chosen:** Best Ready deep-learning anatomy+WMH segmenter for clinical / low-field / lesioned T1 (domain-randomized U-Net). Prefer over plain SynthSeg when WMH (FS label 77) matters for TBI/clinical cohorts.
- **Cite:**
  - Laso P, et al. Quantifying WMH and brain volumes in heterogeneous clinical and low-field MRI. arXiv:2312.05119
  - https://surfer.nmr.mgh.harvard.edu/fswiki/WMH-SynthSeg
- **Alternatives:** `synthseg` (production), `recon_all_clinical` (production)

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
- **Why chosen:** Best Ready deep-learning alternative to classical segmentHA for hippocampal sheet morphometry (U-Net + topological unfold). Preferred DL HA profile (structure-hippunfold); classical subfields-ha remains Bayesian fallback.
- **Cite:**
  - DeKraker J, et al. eLife 2022;11:e77945
- **Alternatives:** `segment_ha` (production), `hippodeep` (research)

See also: [FS DL methods — sources + how to run](../reference/FS_DL_METHODS.md).

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
- `deep_thomas` — T1-only thalamic nnU-Net (ISMRM 2025) — credible Research; wait for public weights before wiring.
- `dhcp_dl_neonatal` — Ready neonatal T2w CSR (Qiang MedIA 2024); narrower than iBEAT birth–6y T1/T2 — document only for now.
- `amygdala_nuclei_dl` — No Production DL amygdala-nuclei peer to FS Bayesian; whole-amygdala nets only (AmygdalaGo etc.).

