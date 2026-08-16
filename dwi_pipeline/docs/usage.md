# Usage

Command-line reference for the DKT Connectome BIDS App (`./run`) and HPC entry points. Layout follows [QSIPrep usage](https://qsiprep.readthedocs.io/en/stable/usage.html).

For a minimal example, see [Quick start](quickstart.md). For **when to use which flag**, see [Decision tables](decision_tables.md). For config keys and env vars, see [Configuration](configuration.md).

---

## Basic invocation

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
  phindagijimana321/dkt-connectome:0.2.0 \
  /data/bids /out participant \
  --participant-label 001 --session-id ses-1
```

HPC (recommended for production):

```bash
export BIDS_DIR=/path/to/BIDS
export RESULTS_ROOT=/path/to/out
bash subject.sh all 001 --session-filter ses-1
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
| `--mem-mb N` / `--mem N` | — | Informational memory hint (logged only) |
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
| `--mode all` | 1 → 1.5 (if mask) → 2 → 3 → 4 → 4.5 (if mask) → 5 |
| `--mode qsiprep` | Step 1 only |
| `--mode inpaint` | Step 1.5 only |
| `--mode recon` | Step 2 only |
| `--mode qsirecon` | Step 3 only |
| `--mode connectome` | Step 4 (+ 5 if enabled) |
| `--mode disconnectome` | Step 4.5 only |
| `--mode nodestrength` | Step 5 only |
| `--dry-run` / `-n` | Snakemake plan only; no execution |
| `--no-recon` | Skip Step 2 in `all` mode |
| `--no-connectome` / `--no-dk` | Skip Steps 4 and 5 |
| `--no-node-strength` | Skip Step 5 only |
| `--no-inpaint` / `--inpaint` | Force skip / enable Step 1.5 |
| `--disconnection` | Opt in to Step 4.5 disconnectome (default: off) |
| `--no-disconnectome` | Explicitly skip Step 4.5 |
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

## Options for connectome and disconnectome (Steps 4–4.5)

| Flag | Env | Description |
|------|-----|-------------|
| `--connectome-weighting count\|sift2` | `CONNECTOME_WEIGHTING` | Edge weights for Steps 4 and 4.5 (default `count`) |
| `--disconnectome-weighting count\|sift2` | `DISCONNECTOME_WEIGHTING` | Override 4.5 weighting only |
| `--disconnectome-core-only` | `DISCONNECTOME_CORE_ONLY=1` | Sensitivity: core label only |
| `--disconnectome-erode-voxels N` | `DISCONNECTOME_ERODE_VOXELS` | Sensitivity: erode lesion N voxels |

---

## Options for node strength (Step 5)

| Flag | Env | Description |
|------|-----|-------------|
| `--strength-only` | `NODESTRENGTH_STRENGTH_ONLY=1` | Skip volume/compare outputs |
| `--no-report` | `NODESTRENGTH_NO_REPORT=1` | Skip PDF report and figures |

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

Set before `./run` or `subject.sh` when container paths differ from defaults:

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
| [`./run`](bids_app.md) | BIDS Apps interface, Docker, portable CLI |
| [`subject.sh`](https://github.com/phindagijimana/dkt_connectome/blob/main/dwi_pipeline/subject.sh) | HPC scripts, full flag surface |
| [`submit.sh`](https://github.com/phindagijimana/dkt_connectome/blob/main/dwi_pipeline/submit.sh) | Slurm array over a subject list |
| [`run_subject.sh`](https://github.com/phindagijimana/dkt_connectome/blob/main/dwi_pipeline/workflow/run_subject.sh) | Snakemake backend (used by `./run`) |

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

- [Decision tables](decision_tables.md) — when to use SDC, recon, weighting, disconnectome flags
- [Pipeline steps](pipeline_steps.md) — what happens inside each step
- [Methods](methods/index.md) — theory and citations per step
- [Preparing your data](preparing_data.md) — BIDS sidecars, fieldmaps, lesion masks
- [BIDS metadata](bids_metadata.md) · [Field maps & SDC](fieldmaps_sdc.md)
- [Outputs](outputs.md) — derivative file layout
- [Tutorial](tutorial.md) — end-to-end walkthrough
- [Troubleshooting](troubleshooting.md) — common errors
- [FAQ](faq.md)
