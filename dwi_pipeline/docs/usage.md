# Usage

Command-line reference for the DKT Connectome BIDS App (`./run`, `./dkt`) and HPC entry points. Layout follows [QSIPrep usage](https://qsiprep.readthedocs.io/en/stable/usage.html).

For a minimal example, see the [Tutorial](tutorial.md). For **when to use which flag**, see [Decision tables](decision_tables.md). For config keys and env vars, see [Configuration](configuration.md).

---

## Unified CLI (`./dkt`)

`./dkt` wraps install, pull, run, log, and check without changing the BIDS App `./run` contract.

| Command | Purpose |
|---------|---------|
| `./dkt install` | Pull step `.sif` images + write `config.local.yaml` |
| `./dkt pull` | Pull containers only (adds `--write-config` by default) |
| `./dkt run …` | Same as `./run …` |
| `./dkt log …` | List or tail logs under `RESULTS_ROOT/logs` |
| `./dkt check` | Verify tools, license, containers (`doctor`) |
| `./dkt version` | Print `PipelineVersion` from `app.json` |

Examples:

```bash
./dkt install --missing-only
./dkt check --with-dry-run
./dkt run BIDS OUT participant --participant-label 001 --fastsurfer --syn
./dkt log --results-root OUT --subject 001 --stage connectome -f
./dkt check --outputs --subject 001 --results-root OUT
```

For **which steps run in containers vs on the host**, see [Architecture](architecture.md).

Legacy entrypoints (`./run`, `install`, `bash scripts/install.sh`, `./run doctor`) remain supported.

---

## Basic invocation

<a id="basic-invocation"></a>

```bash
cd dwi_pipeline

./run <bids_dir> <output_dir> <analysis_level> \
  --participant-label <ID> [<ID> ...] \
  [options]
```

Docker (orchestrator image; step containers mounted separately):

```bash
docker run --rm \
  -v /path/to/BIDS:/data/bids:ro \
  -v /path/to/out:/out \
  -v /path/to/license.txt:/opt/freesurfer/license.txt:ro \
  -e FS_LICENSE=/opt/freesurfer/license.txt \
  phindagijimana321/dkt-connectome:0.2.2 \
  /data/bids /out participant \
  --participant-label 001 --session-id ses-1
```

HPC (recommended for production):

```bash
export BIDS_DIR=/path/to/BIDS
export RESULTS_ROOT=/path/to/out
bash workflow/run_subject.sh all 001 --session-filter ses-1
# or Slurm array:
bash submit.sh
```

---

## Positional arguments

| Argument | Description |
|----------|-------------|
| `bids_dir` | Root of a [BIDS](https://bids.neuroimaging.io/) dataset (must contain `dataset_description.json`) |
| `output_dir` | Derivatives / results root (`RESULTS_ROOT`); created if missing |
| `analysis_level` | `participant` (process subjects) or `group` (cohort QC + BIDS export only) |

---

## Standard BIDS App options

| Flag | Default | Description |
|------|---------|-------------|
| `--participant-label ID …` | *(required for participant)* | Subject IDs, with or without `sub-` prefix |
| `--session-filter SES` | auto | Single session (`ses-1` or `1`). **QSIPrep alias:** `--session-id` |
| `--n-cpus N` | `8` | Snakemake / tool thread budget. **QSIPrep alias:** `--nprocs` |
| `--omp-nthreads N` | same as `--n-cpus` | OpenMP threads inside containers |
| `--mem-mb N` / `--mem N` | — | Exported as `MEM_MB` for Slurm/HPC wrappers (not enforced by Snakemake) |
| `--random-seed N` | `0` | Seed for pseudorandom number generators |
| `--stop-on-first-crash` | off | Abort multi-subject runs after first failure |
| `--skip-bids-validation` | on (implicit) | Validation off unless `--bids-validation` |
| `--bids-validation` | off | Run [bids-validator](https://github.com/bids-standard/bids-validator) on input |
| `--ignore-warnings` | off | Pass through to bids-validator |
| `--version` / `-v` | — | Print pipeline version |
| `-h` / `--help` | — | Print usage |

---

## Options for filtering BIDS queries

| Flag | Env | Description |
|------|-----|-------------|
| `--dwi-shell N` | `DWI_SHELL_B` | Filter DWI to b=N shell (default `1000`) via `config/dwi_select_b<N>.json` |
| `--dwi-select PATH` | `DWI_SELECT_JSON` | Explicit dwi-select JSON (mutually exclusive with `--bids-filter`) |
| `--bids-filter PATH` | `QSIPREP_BIDS_FILTER` | Static QSIPrep filter JSON. **QSIPrep alias:** `--bids-filter-file` |
| `--no-dwi-filter` | `QSIPREP_NO_DWI_FILTER=1` | Process all DWI series (legacy / debugging) |

See [Preparing your data](preparing_data.md) for fieldmaps, Siemens sidecars, and dwi-select behavior.

---

## Options for performing a subset of the workflow

| Flag | Steps run |
|------|-----------|
| `--mode all` | 1 → 1.1 (if mask) → 2 → 3 → 4 → 4.1 (if mask) → 5 |
| `--mode qsiprep` | Step 1 only |
| `--mode inpaint` | Step 1.1 only |
| `--mode recon` | Step 2 only |
| `--mode qsirecon` | Step 3 only |
| `--mode act` | Step 3.1 only (lesion-aware ACT; needs lesion mask) |
| `--mode connectome` | Step 4 (+ 5 if enabled) |
| `--mode disconnectome` | Step 4.1 only |
| `--mode nodestrength` | Step 5 only |
| `--dry-run` / `-n` | Snakemake plan only; no execution |
| `--no-recon` | Skip Step 2 in `all` mode |
| `--no-connectome` / `--no-dk` | Skip Steps 4 and 5 |
| `--no-node-strength` | Skip Step 5 only |
| `--no-inpaint` / `--inpaint` | Force skip / enable Step 1.1 |
| `--disconnection` | Opt in to Step 4.1 disconnectome (default: off) |
| `--no-disconnectome` | Explicitly skip Step 4.1 |
| `--disconnectome` | Alias for `--disconnection` |

What each step does: [Pipeline steps](pipeline_steps.md).

---

## Options for susceptibility distortion correction (Step 1)

| Flag | Env | Description |
|------|-----|-------------|
| `--syn` / `--use-syn-sdc` | `QSIPREP_USE_SYN_SDC=1` | SyN SDC when no measured fieldmap in dwi-select filter |
| `--fmap-retry` | `QSIPREP_FMAP_RETRY=1` | Ignore BIDS fieldmaps; force SyN |
| `--no-sdc` | `QSIPREP_NO_SDC=1` | Skip SDC entirely (legacy compatibility) |

Without a fieldmap in the filter, the pipeline **requires** one of `--syn`, `--fmap-retry`, or `--no-sdc`.

---

## Options for reconstruction (Step 2)

| Flag | Env | Description |
|------|-----|-------------|
| `--fastsurfer` | `RECON_TOOL=fastsurfer` | FastSurfer instead of `recon-all` |
| `--freesurfer` | `RECON_TOOL=freesurfer` | FreeSurfer `recon-all` (default) |
| `--fast-fs` | `RECON_FSAPARC=1` | FastSurfer + classic DK aparc |

---

## Options for anatomical lesion mitigation (Step 1.1)

Runs only when a BIDS lesion mask (`*_T1w_label-lesion_roi.nii.gz`) exists for the session. Theory: [Step 1.1 methods](methods/step1_1_inpaint.md) · [Lesion-aware tractography](lesion_aware.md).

**Biological question:** Large lesions break cortical surface reconstruction and parcellation because FreeSurfer/FastSurfer expects contiguous GM. Step 1.1 modifies T1w *before* Step 2 so surfaces and DKT labels can be estimated on a plausible whole-brain anatomy. This is **not** a claim that tissue inside the lesion is healthy.

| Backend | Theory (short) | Primary citation |
|---------|----------------|------------------|
| **neurolit** (default) | DDPM inpainting synthesizes plausible tissue in the lesion cavity using a resolution-agnostic VINN (Pollak et al. 2025) | [Pollak et al. 2025](https://doi.org/10.1162/imag_a_00446) |
| **vbt** | Virtual brain transplant: mirror contralesional anatomy into the lesion (LeAPP port; Bey et al. 2024) | [Bey et al. 2024](https://doi.org/10.1002/hbm.26701) |
| **none** | Sensitivity arm — raw T1w; surfaces may fail or be distorted near large lesions | — |

| Flag | Env | Description |
|------|-----|-------------|
| `--anat-mitigation none\|neurolit\|vbt` | `ANAT_MITIGATION` | **none** — raw T1w; **neurolit** (default) — DDPM inpainting; **vbt** — LeAPP-compatible virtual brain transplant |
| `--inpaint` | `RUN_INPAINT=1` | Alias for `--anat-mitigation neurolit` |
| `--no-inpaint` | `RUN_INPAINT=0` | Alias for `--anat-mitigation none`; force-skip even if a mask exists |

**Output roots:** neuroLIT → `inpainted/`; VBT → `vbt/`. Step 2 and Step 4 use `inpainting_volumes/inpainting_result.nii.gz` from whichever backend ran.

```bash
bash workflow/run_subject.sh all 011 --anat-mitigation vbt
bash submit.sh --anat-mitigation none   # original-T1w sensitivity arm
```

**When publishing:** cite Pollak et al. 2025 for neuroLIT; Bey et al. 2024 for VBT and state that VBT is a port of LeAPP's released code, not a full LeAPP container run. See [References § Step 1.1](references.md#step-11-anatomical-lesion-mitigation-optional).

---

## Options for lesion-aware ACT and experiment arms (Steps 3.1–4)

**Anatomy mitigation** (Step 1.1) and **lesion-aware ACT** (Step 3.1) are **orthogonal axes** inspired by the LeAPP factorial design (Bey et al. 2024):

- **Step 1.1** fixes *anatomical* priors for reconstruction and parcellation.
- **Step 3.1** fixes *tractography* priors by placing the **original BIDS lesion mask** in the 5TT pathology channel (Smith et al. 2012 ACT framework).

You can combine them (e.g. VBT-filled T1w + lesion in the pathology channel). Theory: [Step 3.1 methods](methods/step3_1_lesion_act.md) · [Lesion-aware tractography](lesion_aware.md).

| Flag | Env | Description |
|------|-----|-------------|
| `--act-mode standard\|lesion-aware` | `ACT_MODE` | **standard** — QSIRecon iFOD2/SIFT2 (default); **lesion-aware** — rebuild tractography after `5ttedit -path` |
| `--act-5tt-source hsvs\|deep-atropos-native` | `ACT_FIVE_TT_SOURCE` | Base 5TT for lesion-aware ACT: QSIRecon ACPC HSVS (default) or native Deep Atropos |
| `--deep-atropos-seg PATH` | `DEEP_ATROPOS_SEG` | Override Deep Atropos segmentation path (`{subject}` `{session}` placeholders) |
| `--deep-atropos-seg-mode auto\|import\|generate` | `DEEP_ATROPOS_SEG_MODE` | Seg source: auto-discover, require external, or always run ANTsPyNet (default `auto`) |
| `--act-streamlines N` | `ACT_STREAMLINES` | Streamline count for lesion-aware ACT (default `10000000`) |
| `--tractography-model ifod2\|sd_stream\|both` | `TRACTOGRAPHY_MODEL` | Optional deterministic SD_STREAM matrices alongside iFOD2 (Tournier et al. 2019; robustness, not replacement) |
| `--experiment-arm ARM` | `EXPERIMENT_ARM` | Set anatomy + ACT together and write under `RESULTS_ROOT/arms/ARM/` (see table below) |

### Theory: lesion-aware ACT (`--act-mode lesion-aware`)

Standard ACT builds a five-tissue-type (5TT) image from the T1w that Step 2 received. If Step 1.1 inpainted the lesion, the HSVS 5TT may label that region as healthy GM/WM. Lesion-aware ACT re-inserts the **original lesion mask** into the pathology compartment so streamlines seed and terminate under pathology priors rather than false healthy tissue (Smith et al. 2012; Bey et al. 2024). The pathology channel is **not** a hard mask — it signals unreliable tissue priors, not proof of axonal absence.

Two base-5TT sources are supported when `--act-mode lesion-aware`:

| Source | Flag | When to use |
|--------|------|-------------|
| **HSVS ACPC** (default) | `--act-5tt-source hsvs` | Production factorial arms; ACPC-first `5ttedit` workflow |
| **Deep Atropos native** | `--act-5tt-source deep-atropos-native` | Native-T1 sensitivity branch; lesion and 5TT share native BIDS T1w |

```bash
# Default HSVS path (ACPC-first)
bash workflow/run_subject.sh act EXAMPLE --act-mode lesion-aware

# Deep Atropos native path (import external seg or generate with ANTsPyNet)
bash workflow/run_subject.sh act EXAMPLE \
  --act-mode lesion-aware \
  --act-5tt-source deep-atropos-native \
  --deep-atropos-seg-mode auto

# Force ANTsPyNet when no external segs exist
bash workflow/run_subject.sh act EXAMPLE \
  --act-mode lesion-aware \
  --act-5tt-source deep-atropos-native \
  --deep-atropos-seg-mode generate \
  --recon-session 2WK
```

Set `act.deep_atropos.antsxnet_cache` (or `DEEP_ATROPOS_ANTSXNET_CACHE`) to a persistent NFS directory for ANTsXNet model weights. Details: [Deep Atropos branch](deep_atropos_5tt.md).

### Theory: SD_STREAM (`--tractography-model both`)

**SD_STREAM** (Tournier et al. 2019) provides a deterministic complement to probabilistic iFOD2. The pipeline writes parallel `dkt_model-SDSTREAM_connectome_*.csv` files. Use for robustness checks; disagreement in crossing-fibre regions is expected.

### Experiment arms (`--experiment-arm`) {#experiment-arms-experiment-arm}

Each arm is a **separate run** (submit one Slurm job per arm). Requires a lesion mask for any `*-lesion` arm or for neurolit/VBT arms that run Step 1.1. Factorial design follows Bey et al. 2024 (LeAPP). For a concise arm-by-arm guide and LeAPP relationship, see **[TBI experimental arms](TBI_Experimental_Arms.md)**. For cohort-scale manuscript planning (~100 TrackTBI lesion subjects), pre-specified contrasts, and journal targets, see [Publication strategy](publication_strategy.md).

| Arm | Step 1.1 anatomy | Step 3.1 ACT | Typical contrast | Cite when contrasting |
|-----|------------------|--------------|------------------|------------------------|
| `orig-std` | Original T1w (`none`) | Standard | Baseline | — |
| `orig-lesion` | Original T1w | Lesion-aware | ACT effect without anatomical fill | Smith et al. 2012 ACT; Bey et al. 2024 |
| `neurolit-std` | neuroLIT (default backend) | Standard | Inpainting effect on anatomy | Pollak et al. 2025 |
| `neurolit-lesion` | neuroLIT | Lesion-aware | Inpainting + pathology-aware tractography | Pollak et al. 2025; Bey et al. 2024 |
| `vbt-std` | Virtual brain transplant | Standard | VBT vs neuroLIT sensitivity | Bey et al. 2024 |
| `vbt-lesion` | Virtual brain transplant | Lesion-aware | Full LeAPP-style factorial | Bey et al. 2024 |

```bash
# Slurm array — one isolated arm tree per submission
export BIDS_DIR=/path/to/BIDS
export RESULTS_ROOT=/path/to/results
bash submit.sh --experiment-arm neurolit-lesion

# Single subject (Snakemake)
bash workflow/run_subject.sh all EXAMPLE --experiment-arm vbt-lesion

# Equivalent manual flags (no arm prefix on RESULTS_ROOT)
bash workflow/run_subject.sh all EXAMPLE \
  --anat-mitigation vbt --act-mode lesion-aware
```

Set `EXPERIMENT_ISOLATE_OUTPUTS=0` only when you intentionally want multiple arms in one `RESULTS_ROOT` (not recommended).

**When publishing:** cite Bey et al. 2024 for the factorial lesion-processing design; add Pollak et al. 2025 or Bey et al. 2024 per anatomy backend; cite Smith et al. 2012 for ACT when using lesion-aware mode. See [References § Experiment arms](references.md#experiment-arms-factorial-lesion-processing).

---

## Options for connectome and disconnectome (Steps 4–4.1)

| Flag | Env | Description |
|------|-----|-------------|
| `--connectome-weighting count\|sift2` | `CONNECTOME_WEIGHTING` | Edge weights for Steps 4 and 4.1 (default `count`) |
| `--primary-connectome-measure count\|sift2` | `PRIMARY_CONNECTOME_MEASURE` | Which matrix is copied to `dkt_connectome.csv` (default `count`) |
| `--disconnectome-weighting count\|sift2` | `DISCONNECTOME_WEIGHTING` | Override 4.1 weighting only |
| `--disconnectome-core-only` | `DISCONNECTOME_CORE_ONLY=1` | Sensitivity: core label only |
| `--disconnectome-erode-voxels N` | `DISCONNECTOME_ERODE_VOXELS` | Sensitivity: erode lesion N voxels |

Step 4 always writes **Count, SIFT2, MeanLength, MeanFA, and MeanMD** matrices from the same iFOD2 tractogram (`dkt_connectome_*.csv`). See [Outputs](outputs.md).

**Theory:** No single edge metric is universally accepted (Jones et al. 2013). Count is the default primary (`dkt_connectome.csv`); SIFT2 corrects global density bias (Smith et al. 2015); MeanFA/MeanMD sample diffusion along reconstructed paths and must not be interpreted as independent histological ground truth. Multi-measure release precedent: IDEAS II (Taylor et al. 2026). Details: [Step 4 methods](methods/step4_connectome.md#multi-measure-connectomes-one-tractogram).

---

## Options for node strength (Step 5)

| Flag | Env | Description |
|------|-----|-------------|
| `--strength-only` | `NODESTRENGTH_STRENGTH_ONLY=1` | Skip volume/compare outputs |
| `--no-report` | `NODESTRENGTH_NO_REPORT=1` | Skip PDF report and figures |

**Report-only / re-run QC:** There is no separate `--report-only` CLI flag. To regenerate Step 5 PDFs and cohort HTML without reprocessing imaging:

1. **Subject-level:** re-run with `--mode nodestrength` (requires existing Step 4 outputs under `RESULTS_ROOT`).
2. **Group-level:** `./run BIDS OUT group` — rebuilds cohort indexes and subject report links only (same as `scripts/batch_postprocess.sh`).

---

## Provenance and BIDS Derivatives export

| Flag | Description |
|------|-------------|
| `--export-bids-derivatives` | Write `RESULTS_ROOT/derivatives/` symlink mirror after run |
| `--export-copy` | Copy files instead of symlinks (implies export) |

Group-level export (no reprocessing):

```bash
./run /path/to/BIDS /path/to/out group
```

---

## Environment variables

Set before `./run` or `run_subject.sh` when container paths differ from defaults:

| Variable | Purpose |
|----------|---------|
| `FS_LICENSE` | FreeSurfer license file (**required** for recon) |
| `TEMPLATEFLOW_HOME` | TemplateFlow cache (bind-mount in containers) |
| `CONTAINER_QSIPREP` | Path to `qsiprep.sif` |
| `CONTAINER_QSIRECON` | Path to `qsirecon.sif` |
| `CONTAINER_FREESURFER` | Path to FreeSurfer SIF |
| `CONTAINER_FASTSURFER` | Path to FastSurfer SIF |
| `CONTAINER_CONNECTOME` | Path to `dkt_connectome.sif` |
| `CONTAINER_LIT` | Path to neuroLIT SIF |
| `CONTAINER_NODESTRENGTH` | Path to nodestrength SIF |
| `BIDS_APP_CI=1` | Skip Apptainer checks (CI smoke tests only) |

Full table: [Configuration](configuration.md) · [Containers](containers.md).

---

## Entry points

| Method | When to use |
|--------|-------------|
| [`./run`](#basic-invocation) | BIDS Apps interface, Docker, portable CLI |
| [`run_subject.sh`](https://github.com/phindagijimana/dkt_connectome/blob/main/dwi_pipeline/workflow/run_subject.sh) | Single-subject Snakemake CLI (HPC or interactive) |
| [`submit.sh`](https://github.com/phindagijimana/dkt_connectome/blob/main/dwi_pipeline/submit.sh) | Slurm array over a subject list |

---

## Slurm array (HPC)

```bash
export BIDS_DIR=/path/to/BIDS
export RESULTS_ROOT=/path/to/results
export SUBJECT_LIST_FILE=dwi_pipeline/subjects.txt
bash dwi_pipeline/submit.sh
```

Cohort post-processing after array jobs:

```bash
bash dwi_pipeline/scripts/batch_postprocess.sh
# same as: ./run BIDS OUT group
```

---

## See also

- [Decision tables](decision_tables.md) — when to use SDC, recon, weighting, disconnectome, **experiment arms**
- [Lesion-aware tractography](lesion_aware.md) — VBT, lesion-aware ACT, LeAPP context
- [Pipeline steps](pipeline_steps.md) — what happens inside each step
- [Methods](methods/index.md) — theory and citations per step
- [Preparing your data](preparing_data.md) — BIDS sidecars, fieldmaps, lesion masks
- [BIDS metadata](bids_metadata.md)
- [Outputs](outputs.md) — derivative file layout
- [Tutorial](tutorial.md) — end-to-end walkthrough
- [Troubleshooting](troubleshooting.md) — common errors
- [FAQ](faq.md)
