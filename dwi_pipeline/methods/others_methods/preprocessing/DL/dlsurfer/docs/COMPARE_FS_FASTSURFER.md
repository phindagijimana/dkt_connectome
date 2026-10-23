# DLSurfer vs FreeSurfer vs FastSurfer — coverage & gaps

DLSurfer is an **orchestrator**. This table compares capability surfaces.

Legend: **Y** = first-class · **P** = partial / via called tool · **N** = missing · **E** = experimental in DLSurfer · **C** = classical (non-DL) still used · **W** = wired best alternative (profile/flag)

Gaps **without** any credible alternative: [`GAPS_WITHOUT_ALTERNATIVES.md`](GAPS_WITHOUT_ALTERNATIVES.md) · `dlsurfer gaps-remaining`

## A. Core morphometry

| Capability | FreeSurfer | FastSurfer | DLSurfer now | Gap / note |
|------------|------------|------------|--------------|------------|
| Whole-brain aseg | Y (CA / SynthSeg in FS8) | Y (VINN) | Y (`core` → VINN; `fs8`; `seg-quick-synthseg`) | — |
| Cortical parc **DKT** | Y | Y (native) | Y (default) | — |
| Cortical parc **DK** | Y | P (`--fsaparc`) | **W** (`--atlas dk` / `core-dk` → `--fsaparc`) | Implemented |
| Cortical parc **Destrieux** | Y | N native | **W** (`atlas-destrieux` → `-a2009s`) | Needs prior surfaces |
| Schaefer / MMP / custom annot | P (project) | P (project) | **W** (`atlas-schaefer`; MMP same pattern) | Needs `SCHAEFER_ANNOT_*` |
| Surfaces white/pial | Y | Y (recon-surf **C**) | Y (calls recon-surf **C**) | DL surface backends **E** (`surf-dl-*`) |
| Thickness / curv / area | Y | Y | Y (via recon-surf) | Fast thickness **E** (`thickness-fast`) |
| `sphere.reg` / fsaverage | Y | Y | Y (via recon-surf); SUGAR **E** | — |
| CC / cereb / hypothal modules | P / add-ons | Y | Y + **W** toggles (`--no-cc` / `--no-cereb` / `--no-hypothal`) | — |
| Lesion inpainting | N native | Y (LIT ≥2.6) | Y (`core-lesion` standalone default) | Native LIT profile opt-in |
| GPU/CPU job split | Manual | Y (`srun_fastsurfer`) | Y (plan + HPC) + **W** `--hpc srun\|brun` | Native LIT cannot split |
| High-res `<1 mm` VINN | — | Y (`--vox_size`) | **W** (`--vox-size`) | — |
| Single container story | FS install | Docker/Apptainer | Pins documented; meta-image **N** | **No alt** — see gaps-remaining |
| `dlsurfer doctor` | — | — | Y | Ops-only |

## B. FreeSurfer suite areas

| Capability | FS | FastSurfer | DLSurfer | Status |
|------------|----|------------|----------|--------|
| Longitudinal `-base` / `-long` | Y | Limited | **W** (`fs-long`) | Best alt = classical FS long |
| Hippocampal/amygdala subfields (HA) | Y | Downstream FS | **W** (`subfields-ha`) | Runners-up: HippUnfold, Hippodeep |
| Brainstem / thalamic nuclei | Y | P | **W** (`nuclei-bs-thal`) | No stronger DL default |
| Infant / clinical recon-all-clinical | Y | N | **W** (`fs-clinical`); Infant FS = runner-up only | Neonates still external |
| Manual edit loops (`-autorecon2-*`) | Y | P | **N** | **No alt** (by design) |
| TRACULA / PET / fMRI helpers | Y | N | **N** | **No alt** (out of scope) |
| Full QC GUI (FreeView workflows) | Y | Y | **N** | **No alt** — use FreeView |
| Bit-identical recon-all | Y | N | **N** | **Non-claim** |
| Claustrum | N (add-on `mri_claustrum_seg`) | N | **W** (`structure-claustrum`) | Mauri 2025 |
| Piriform cortex 125/126 | N | N | **E** (`structure-piriform-synthseg`); JLF alt documented | Not in VINN |
| SynthSR T1 salvage | Y (`mri_synthsr`) | N | **W** (`preprocess-synthsr`) | Preprocess only |
| HippUnfold HA | External | N | **W** (`structure-hippunfold`) | Ready alt to segmentHA |

## C. FastSurfer-specific (CLI completeness)

| FastSurfer feature | In DLSurfer? |
|--------------------|--------------|
| `run_fastsurfer.sh` full defaults | Y (`core`) |
| `--seg_only` / `--surf_only` split | Y (`core` / `core-lesion` plans) |
| `--lesion_mask` native | Y (`core-lesion-native`) |
| `--fsaparc` | **W** (`--atlas dk`) |
| CerebNet / HypVINN / CC toggles | **W** (`--no-cc` / `--no-cereb` / `--no-hypothal`) |
| `brun_fastsurfer` / `srun_fastsurfer` | **W** (`--hpc srun\|brun`) |
| High-res `<1 mm` VINN | **W** (`--vox-size`) |

## D. What DLSurfer adds (neither FS nor FastSurfer alone)

| Addition | Why |
|----------|-----|
| Cited engine registry + “why chosen” | Lab / paper transparency |
| Standalone-LIT-first lesion profile for HPC split | Upstream native LIT blocks seg/surf split |
| Optional Ready/Research backends catalogued (TopoFit, V2C-Flow, …) | Future without forking FS |
| Explicit non-interference with DKT connectome | Isolation.md |
| Multi-atlas wiring | ATLASES.md + gap-fill profiles |
| Documented no-alternative remainder | GAPS_WITHOUT_ALTERNATIVES.md |

## E. Bottom line

| Question | Answer |
|----------|--------|
| Replace FreeSurfer? | **No** |
| Replace FastSurfer? | **No** — wraps it |
| Gaps with best alt wired? | DK, Destrieux, Schaefer, long, HA, BS/thal, clinical, module toggles, srun, hires |
| Gaps **without** alternatives? | Meta-SIF, manual edits, FreeView GUI, TRACULA/PET/fMRI, bit-identity, Infant FS (partial), native-LIT+split |
