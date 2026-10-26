# Specialty structure + Synth* preprocess modules

**Specialty is first-class** in DLSurfer (deep-learning FreeSurfer-suite methods):
T1 structure **and** multimodal FS gaps (DWI bundles, PET quant, fMRI preprocess, QC).

Credibility: **A** first-class · **B** Ready specialty · **C** experimental specialty
(allowed) · **D** classical gated — [CREDIBILITY.md](CREDIBILITY.md).

Orchestrator-only — weights/tools live under lab `Documents/` or FS / Apptainer images.

| Profile | Engine | Lab / env | Status |
|---------|--------|-----------|--------|
| `preprocess-synthsr` | `synthsr` | FS `mri_synthsr` | **P** preprocess |
| `structure-claustrum` | `mauri_claustrum` | `Documents/clau_seg` | **P** DL |
| `structure-piriform-synthseg` | `synthseg_pc` | `Documents/piriform/synthseg_pc` | **E** until JLF gate |
| `structure-hippunfold` | `hippunfold` | `HIPPUNFOLD_SIF` / `dlsurfer-hippunfold` | **live** (SIF + wrapper) |
| `structure-brainstem-mars` | `mars_brainstem` | `MARS_SIF` (brainstem-nnunet) | **R→live** when SIF pulled |
| `structure-sclimbic` | `sclimbic` | FS SIF `mri_sclimbic_seg` | **live** (EG smoke) |
| `nuclei-thalamic-dti-cnn` | `thalamic_dti_cnn` | FS SIF + `THAL_FA`/`THAL_V1` | **tool live** (needs DTI) |
| `seg-wmh-synthseg` | `wmh_synthseg` | FS8+ WMH-SynthSeg `.pth` | **R** (not in FS 7.4.1) |
| `infant-ibeat` | `infant_ibeat` | `IBEAT_SIF` + age months | **R→live** when SIF pulled |
| `seg-wmh-mars` | `mars_wmh` | `MARS_WMH_SIF` + `MARS_FLAIR` | **R** FLAIR+T1 WMH |
| `nuclei-thalamic-deep-thomas` | `deep_thomas` | `DEEP_THOMAS_SIF` | **E** T1 thalamus (weights pending) |
| `sphere-s3reg` | `s3reg` | `S3REG_SIF` | **E** SUGAR backup |
| `structure-hippodeep` | `hippodeep` | `HIPPODEEP_ROOT` | **R** fast HA mask |
| `strip-hdbet` | `hdbet` | `HDBET_SIF` / `hd-bet` | **R** strip alt |
| `lesion-vbg` | `vbg` | `VBG_ROOT` | **E** TBI caution |
| `lesion-enantiomorphic` | `enantiomorphic` | wrapper | **R** unilateral fill |
| `structure-ventricles-mars` | `mars_ventricles` | `MARS_VENT_SIF` | **R** ventricles |
| `structure-claustrum-albishri` | `albishri_claustrum` | `ALBISHRI_ROOT` | **E** Mauri runner-up |
| `structure-piriform-nnunet` | `nnunet_piriform` | `NNUNET_PC_ROOT` | **E** PC nnU-Net |
| `structure-amygdala-go` | `amygdala_go` | `AMYGDALA_GO_ROOT` | **E** whole-amygdala |
| `infant-dhcp` | `dhcp_neonatal` | `DHCP_SIF` + `DHCP_T2` | **E** neonate T2w |
| `surf-dl-{cortexode,pialnn,corticalflow,surfnn,deepcsr,fastcsr}` | CSR zoo | `*_ROOT` | **E** V2C backups |
| `thickness-dl-direct` | `dl_direct` | wrapper | **E** thickness alt |
| `surf-dl-v2c-long` | `v2c_long` | `V2C_LONG_ROOT` | **E** gated |
| `atlas-destrieux-dl` | SUGAR → `-a2009s` | `SUGAR_ROOT` | **E** gated |
| `atlas-schaefer-dl` | SUGAR → Schaefer | `SUGAR_ROOT` | **E** gated |
| `clinical-claustrum` | SynthSR → Mauri | both | **P** chain |
| `subfields-ha` | `segment_ha` | FS Bayesian | **classical** — hidden; needs `--allow-classical` |
| `nuclei-bs-thal` | `segment_bs` + thalamic | FS Bayesian | **classical** — hidden; needs `--allow-classical` |
| `dwi-tractseg` | `tractseg` | `TRACTSEG_SIF` / ROOT + DWI | **B** alt to TRACULA |
| `dwi-deepwma` | `deepwma` | `DEEPWMA_ROOT` | **C** TractSeg backup |
| `pet-dl-quant` | `pet_dl_quant` | `PET_DL_ROOT` + PET | **B** alt to FS PET parc/SUVR |
| `fmri-deepprep` | `deepprep` | `DEEPPREP_SIF` / ROOT + BIDS | **B** alt to FS-FAST / fMRI helpers |
| `qc-brainqcnet` | `brainqcnet` | `BRAINQCNET_*` | **B** QC triage (not edit loops) |
| `seg-synthseg-robust` | `synthseg_robust` | FS `mri_synthseg --robust --qc` | **A** SynthSeg 2.0 QC |
| `seg-super-synth` | `super_synth` | FS `mri_super_synth` + `SUPERSYNTH_MODE` | **B** multi-task Synth* |
| `atlas-easyatlas` | `easyatlas` | FS `mri_easyatlas` + `EASYATLAS_INPUT_DIR` | **B** group DL atlas |
| `structure-histo-atlas` | `histo_atlas` | FS `mri_histo_atlas_segment_fireants` | **B** NextBrain FireANTs |
| `structure-hypvinn-t2` | `hypvinn_t2` | FastSurfer `--t2` / `HYPVINN_T2` | **A** HypVINN + T2 |
| `fs8-dl-modules` | `fs8_dl_helpers` (+ `freesurfer8`) | FS≥8 `recon-all` internals | **B** inventory of embedded DL |

**Sources + run recipes (concise):** [FS_DL_METHODS.md](FS_DL_METHODS.md).

## Hard rules

1. **Mauri claustrum ≠ piriform.** Never run claustrum weights as Steinbart 125/126.
2. **SynthSeg-PC ≠ `mri_synthseg`.** Stock FreeSurfer SynthSeg has no PC class.
3. **SynthSR does not segment** PC or claustrum — T1 salvage only.
4. **IDEAS production PC** stays **JLF** until SynthSeg-PC / nnU-Net clears the documented eval bar.
5. **ScLimbic XOR HypVINN** for overlapping hypothalamus — do not double-count.
6. **iBEAT XOR adult `core`** — infant-only age range.
7. Isolation: no DKT connectome imports; write under DLSurfer `--sd/--sid`.

## Env cheat-sheet

```bash
source env/cluster_containers.sh   # sets HIPPUNFOLD_SIF; MARS/IBEAT when SIFs exist

# Pull once (lab containers dir):
# apptainer pull mars_brainstem_nnunet.sif docker://ghcr.io/miac-research/brainstem-nnunet:latest
# apptainer pull ibeat_v2_release205.sif docker://ibeatgroup/ibeat_v2:release205

# Thalamic DTI-CNN (tool is in FS 7.4.1 SIF)
export THAL_FA=/path/fa.nii.gz
export THAL_V1=/path/v1.nii.gz

# iBEAT
export IBEAT_AGE_MONTHS=6

# WMH-SynthSeg needs FS ≥8 + models/WMH-SynthSeg_*.pth (not in lab FS 7.4.1 SIF)
# MARS-WMH:  apptainer pull … docker://ghcr.io/miac-research/wmh-nnunet:latest
#            export MARS_WMH_SIF=… MARS_FLAIR=/path/flair.nii.gz
# Deep-THOMAS / Hippodeep / HD-BET / VBG / S3Reg / CSR zoo: set matching *_SIF or *_ROOT
```

```bash
dlsurfer tools
dlsurfer recon-all -i T1.nii.gz -sd SD -s sub-01 -q
dlsurfer tool sclimbic --t1 T1.mgz --sd SD --sid sub-01 --execute
dlsurfer tool hippunfold --t1 T1.nii.gz --sd SD --sid sub-01 --execute

# FS wiki DL (v0.2.2) — dry-run then --execute; see FS_DL_METHODS.md
dlsurfer tool synthseg-robust --t1 T1.nii.gz --sd SD --sid sub-01 -q
SUPERSYNTH_MODE=invivo dlsurfer tool super-synth --t1 T1.nii.gz --sd SD --sid sub-01 -q
EASYATLAS_INPUT_DIR=/scans dlsurfer tool easyatlas --t1 T1.nii.gz --sd SD --sid sub-01 -q
HISTO_ATLAS_SIDE=left dlsurfer tool histo-atlas --t1 T1.nii.gz --sd SD --sid sub-01 -q
dlsurfer tool hypvinn-t2 --t1 T1.nii.gz --t2 T2.nii.gz --sd SD --sid sub-01 -q
dlsurfer tool fs8-dl --t1 T1.nii.gz --sd SD --sid sub-01 -q

dlsurfer profiles | rg 'structure-|seg-wmh|strip-hdbet|lesion-|sphere-s3|surf-dl-|thickness-dl|infant-|super-synth|easyatlas|histo|hypvinn|fs8-dl'
dlsurfer run --profile seg-wmh-mars --t1 T1.nii.gz --sd SD --sid sub-01 -q
# Classical Bayesian / fs8 / fs-long: dlsurfer profiles --all ; run … --allow-classical
```
