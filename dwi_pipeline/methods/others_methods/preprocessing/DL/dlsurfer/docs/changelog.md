# Changelog

## 0.2.2

- **Default surfaces = V2C-Flow** (no classical recon-surf on `core` / `core-lesion`); fallback profile `core-recon-surf` behind `--allow-classical`; `tbi_lit_surfaces` passed
- **Unified FreeSurfer-shaped contract for all outputs:** `outputs_registry.yaml` + `dlsurfer contract [--list|--sd|--profile]`; every profile maps to `$SD/$SID/` paths; runner uses `check_profile_contract` + `ensure_fs_tree`; backup meshes under `surf/dlsurfer/`
- **FS surface contract for DL surfaces:** `dlsurfer-install-surfaces` / engine `fs_surf_contract` maps TopoFit/V2C/SUGAR meshes into `$SD/$SID/surf/`; profile `core-dl-surf` (`recon-surf-dl`) = VINN seg_only + V2C + contract (no classical recon-surf); wrappers auto-install after V2C/SUGAR
- **LIT = DL separable only:** standalone neuroLIT → FastSurfer split → lit-post (`core-lesion` / alias `core-lesion-native`); upstream `--lesion_mask` removed from public surface; `--stage gpu|cpu` + `hpc/slurm_core_lesion_split.sh`; [LIT_SPLIT.md](reference/LIT_SPLIT.md)
- **Remaining FreeSurfer/FastSurfer DL gaps wired:** SuperSynth, EasyAtlas, SynthSeg `--robust`/`--qc`, HypVINN `--t2` (`--t2` / `HYPVINN_T2`), NextBrain histo atlas (FireANTs), FS8 embedded DL helpers inventory (`fs8-dl-modules`)
- Tool aliases: `super-synth`, `synthseg-robust`, `easyatlas`, `histo-atlas`, `hypvinn-t2`, `fs8-dl`
- **Docs:** [FS_DL_METHODS.md](reference/FS_DL_METHODS.md) — literature + concise run for each; engines.md / STRUCTURE_MODULES / cli updated; NextBrain *Nature* 2025 + Puonti *Imaging Neurosci* 2026 cites
- Restored specialty engine registry after disk-full truncation; doctor checks for `mri_super_synth` / `mri_easyatlas` / histo CLI

## 0.1.2

- **v0.2.1 multimodal FS-suite DL:** TractSeg (↔TRACULA), PET-DL quant, DeepPrep (↔fMRI helpers), BrainQCNet (↔QC triage) as B specialty; identity = deep-learning FreeSurfer-suite methods (not T1-only)
- **v0.2.0 identity finalize:** specialty first-class; credibility A/B/C/D; C = experimental specialty (allowed); D classical gated
- **DL-only FS-shaped CLI:** `dlsurfer recon-all` (→ FastSurferVINN `core`, not classical recon-all), `dlsurfer tool` / `tools`, classical profiles gated behind `--allow-classical` / hidden from default `profiles`/`engines`
- `dlsurfer freeview --sd … --sid …` launcher (+ `env/bin/freeview` SIF wrapper)
- UX: help order (doctor→smoke→run→freeview first), `-q`/`--quiet` plans, doctor optional-MISS note, version 0.1.2
- UX: `doctor --brief`, `compare`/`gaps-remaining` summaries (`--full` for markdown), `freeview --check`
- Specialty DL live: `dlsurfer-hippunfold` + lab SIF; FS wrappers for ScLimbic / thalamic DTI-CNN; MARS image URI `brainstem-nnunet`; EG ScLimbic smoke
- Wire expanded specialty DL catalog: MARS-WMH/ventricles, Deep-THOMAS, S3Reg, Hippodeep, HD-BET, VBG, enantiomorphic, Albishri, nnU-Net PC, AmygdalaGo, dHCP, CSR zoo + DL+DiReCT (`_dlsurfer_specialty.sh`)
- Wire **best Ready DL alternatives** for classical gap-fills:
  HippUnfold (HA), MARS brainstem, ScLimbic, WMH-SynthSeg, thalamic DTI-CNN,
  iBEAT infant, V2C-Long, SUGAR→Destrieux/Schaefer profiles
- Mark classical HA/BS/thalamus/`fs-long`/`recon-surf` as non-DL fallbacks in `engines.yaml`
- Wrappers: `dlsurfer-{mars-brainstem,sclimbic,wmh-synthseg,v2c-long,thalamic-dti-cnn,ibeat}`
- Gates: `tbi_lit_v2c_long`; SUGAR gate also blocks `atlas-*-dl`

## 0.1.1

- Literature-best Phase-3 wiring: **V2C-Flow** CSR (`dlsurfer-v2c`), SUGAR / DL-CTE separate gates  
- TopoFit Chamfer/Hausdorff scoring + FreeView QC script  
- EG GPU confirmatory job 191960 completed (`recon-surf.done`)  
- Schaefer 400/17 annots bundled; `SUBJECTS_DIR` propagated in FS Apptainer wrapper; executed on EG  
- SynthSeg-PC env wired; production PC remains **JLF** until Hammers eval  
- BIDS App: derivatives layout, Boutiques descriptor, container entrypoint, CI fixture  
- Ops: `compare_metrics_slurm.py`, meta-SIF `containers/dlsurfer.def`

## 0.1.0

- Initial public release of DLSurfer orchestrator  
- Profiles: `core`, `core-lesion`, seg-quick, specialty, Phase-3 TopoFit  
- Apptainer cluster wrappers + `dlsurfer doctor` READY path  
- Production gates (`tbi_lit_topofit` passed machine check on EG)  
- MkDocs documentation site (DKT Connectome IA + QSIPrep depth)  
- Methods page: per-engine resources + paper citations (from `engines.yaml`)  
- `dlsurfer bids-app` stub toward BIDS App standard  
