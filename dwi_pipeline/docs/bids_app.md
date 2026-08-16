# BIDS App

The pipeline implements the [BIDS Apps](https://bids-apps.neuroimaging.io/) specification via:

| File | Role |
|------|------|
| [`run`](https://github.com/phindagijimana/dkt_connectome/blob/main/dwi_pipeline/run) | Executable entrypoint |
| [`app.json`](https://github.com/phindagijimana/dkt_connectome/blob/main/dwi_pipeline/app.json) | Machine-readable metadata |
| [`dkt_connectome_bids_app.json`](https://github.com/phindagijimana/dkt_connectome/blob/main/dwi_pipeline/dkt_connectome_bids_app.json) | Boutiques / BIDS Exec descriptor |
| [`docs/`](index.md) | Human-readable documentation (this site) |

**Analysis levels:** `participant` (full pipeline), `group` (cohort QC + BIDS Derivatives export to `derivatives/`).

Under the hood, `./run` calls the **Snakemake workflow** in [`workflow/Snakefile`](https://github.com/phindagijimana/dkt_connectome/blob/main/dwi_pipeline/workflow/Snakefile) via `run_subject.sh`. See [Snakemake workflow](snakemake_workflow.md) for direct `snakemake` usage and all plugin targets.

---

## Basic usage

```bash
cd dwi_pipeline

./run <bids_dir> <output_dir> participant \
  --participant-label <ID> [<ID> ...] \
  [options]
```

### Example

```bash
./run /data/CIDUR_BIDS/data_bids /data/derivatives participant \
  --participant-label 009 \
  --session-filter ses-1 \
  --n-cpus 8
```

- `<bids_dir>` → `BIDS_DIR`
- `<output_dir>` → `RESULTS_ROOT` (created if missing)
- Subject IDs may be given with or without the `sub-` prefix.

---

## Positional arguments

| Argument | Description |
|----------|-------------|
| `bids_dir` | BIDS dataset root |
| `output_dir` | Derivatives / results root |
| `analysis_level` | `participant` (full pipeline) or `group` (cohort QC + BIDS Derivatives export) |

---

## Standard BIDS App options

| Flag | Default | Description |
|------|---------|-------------|
| `--participant-label ID …` | *(required)* | One or more subjects |
| `--session-filter SES` | auto | Single session (`ses-1` or `1`). Alias: `--session-id` |
| `--n-cpus N` | 8 | Thread budget. Aliases: `--nprocs` |
| `--omp-nthreads N` | same as `--n-cpus` | OpenMP threads inside containers |
| `--mem-mb N` | — | Logged hint only (not enforced) |
| `--random-seed N` | `0` | Seed for pseudorandom number generators |
| `--stop-on-first-crash` | off | Abort multi-subject runs after first failure |
| `--bids-validation` | off | Run `bids-validator` on `bids_dir` before processing |
| `--ignore-warnings` | off | Pass through to bids-validator |
| `--version` | — | Print pipeline version |

---

## Pipeline-specific options

| Flag | Default | Description |
|------|---------|-------------|
| `--mode MODE` | `all` | `all`, `qsiprep`, `inpaint`, `recon`, `qsirecon`, `connectome`, `disconnectome`, `nodestrength` |
| `--fastsurfer` | off | FastSurfer for Step 2 |
| `--no-inpaint` | off | Skip Step 1.5 even if lesion mask exists |
| `--no-recon` | off | Skip Step 2 |
| `--disconnection` | off | Opt in to Step 4.5 disconnectome |
| `--no-disconnectome` | — | Explicitly skip Step 4.5 |
| `--disconnectome` | — | Alias for `--disconnection` |
| `--disconnectome-core-only` | off | Sensitivity: core label only |
| `--disconnectome-erode-voxels N` | 0 | Sensitivity: erode lesion N voxels |
| `--connectome-weighting` | `count` | Step 4 + 4.5 edge weights |
| `--dry-run` | off | Snakemake plan only |

Step 4.5 disconnectome runs **only when** you pass **`--disconnection`** (or `--mode disconnectome`)
and a prepared lesion mask + DKT connectome exist. Off by default while the method is validated.

Modes: `all`, `qsiprep`, `inpaint`, `recon`, `qsirecon`, `connectome`, **`disconnectome`**, `nodestrength`.

---

## Environment overrides

Set before `./run` when container paths differ from site defaults:

| Variable | Purpose |
|----------|---------|
| `FS_LICENSE` | FreeSurfer license file (**required**) |
| `TEMPLATEFLOW_HOME` | TemplateFlow cache bind-mount |
| `CONTAINER_QSIPREP` | Path to `qsiprep.sif` |
| `CONTAINER_QSIRECON` | Path to `qsirecon.sif` |
| `CONTAINER_FREESURFER` | Path to `freesurfer_7.4.1.sif` |
| `CONTAINER_FASTSURFER` | Path to FastSurfer SIF |
| `CONTAINER_CONNECTOME` | Path to `dkt_connectome.sif` |
| `CONTAINER_LIT` | Path to `lit_0.6.0.sif` (inpainting) |
| `CONTAINER_NODESTRENGTH` | Path to nodestrength SIF (Step 5) |
| `CONNECTOME_WEIGHTING` | Default `count` |

See [Installation](installation.md) for default paths, **`bash install.sh`**, and build instructions.

Quick install:

```bash
bash install.sh
export FS_LICENSE=/path/to/license.txt
./run doctor
```

---

## Container model

Unlike a single monolithic QSIPrep image, this BIDS App **orchestrates multiple Apptainer images** (QSIPrep, FreeSurfer/FastSurfer, QSIRecon, connectome, LIT, nodestrength) via Snakemake. This matches common HPC deployments where upstream BIDS Apps are already cached on shared filesystems.

Required inputs per [`app.json`](https://github.com/phindagijimana/dkt_connectome/blob/main/dwi_pipeline/app.json):

- `dwi`
- `T1w`
- `fmap` (optional — SyN or explicit flags if absent)

Output types: NIfTI_GZ, CSV, JSON.

---

## Multi-subject invocation

```bash
./run /data/BIDS /data/derivatives participant \
  --participant-label 001 003 009 \
  --n-cpus 8
```

Subjects run sequentially; any failure sets a non-zero exit code.

---

## Session handling

When a subject has **multiple BIDS sessions**, pass exactly one filter per invocation:

```bash
./run /data/BIDS /data/out participant \
  --participant-label 009 \
  --session-filter ses-1
```

Multiple `--session-filter` values are rejected — run separate jobs per session.

---

## Help

```bash
./run --help
# or
./run /data/BIDS /data/out participant -h
```

---

## Registering as a BIDS App

Submit to the [BIDS Apps registry](https://bids-apps.neuroimaging.io/apps/) with:

- **Name:** DKT Connectome  
- **Version:** 0.2.0 (see `./run --version`)  
- **Documentation:** https://dkt-connectome.readthedocs.io/en/latest/  
- **Docker Hub:** `phindagijimana321/dkt-connectome:0.2.0` (orchestrator; step images mounted at runtime)  
- **Test dataset:** `dwi_pipeline/tests/fixtures/bids_minimal/`  

Step-by-step checklist: [bids_apps_registry.md](bids_apps_registry.md).

Full descriptor: [`app.json`](https://github.com/phindagijimana/dkt_connectome/blob/main/dwi_pipeline/app.json).
