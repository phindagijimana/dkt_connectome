# BIDS App specification

The DKT Connectome implements the [BIDS Apps](https://bids-apps.neuroimaging.io/) contract. This page documents **metadata, analysis levels, and the container model**. For every flag and example invocation, see **[Usage](usage.md)**.

---

## Specification files

| File | Role |
|------|------|
| [`run`](https://github.com/phindagijimana/dkt_connectome/blob/main/dwi_pipeline/run) | BIDS App entrypoint (`./run`) |
| [`dkt`](https://github.com/phindagijimana/dkt_connectome/blob/main/dwi_pipeline/dkt) | Unified CLI (`./dkt install|pull|run|log|check`) |
| [`app.json`](https://github.com/phindagijimana/dkt_connectome/blob/main/dwi_pipeline/app.json) | Machine-readable BIDS App metadata |
| [`dkt_connectome_bids_app.json`](https://github.com/phindagijimana/dkt_connectome/blob/main/dwi_pipeline/dkt_connectome_bids_app.json) | Boutiques / BIDS Exec descriptor |
| [Documentation site](home.md) | Human-readable guide (this site) |

Version string: `./run --version` (matches `app.json` → `PipelineVersion`).

---

## Invocation contract

```text
./run <bids_dir> <output_dir> <analysis_level> [options]
```

| Argument | Meaning |
|----------|---------|
| `bids_dir` | BIDS dataset root (`BIDS_DIR`) |
| `output_dir` | Derivatives / results root (`RESULTS_ROOT`; created if missing) |
| `analysis_level` | `participant` or `group` |

Subject IDs may be given with or without the `sub-` prefix. Full CLI tables: **[Usage](usage.md)**.

---

## Analysis levels

| Level | Behavior |
|-------|----------|
| **`participant`** | Full per-subject pipeline (Steps 1–5; optional 1.1 / 4.1 when inputs and flags allow) |
| **`group`** | Cohort QC HTML indexes + BIDS Derivatives export to `derivatives/` (no reprocessing) |

Group-level outputs include `cohort_qc.html` and, when disconnectome was run, `disconnectome_cohort_qc.html`. See **[Quality control](qc.md)**.

---

## Required and optional inputs

Per [`app.json`](https://github.com/phindagijimana/dkt_connectome/blob/main/dwi_pipeline/app.json):

| Modality | Required | Notes |
|----------|----------|-------|
| `dwi` | Yes | Preprocessed by Step 1 (QSIPrep) |
| `T1w` | Yes | Structural reference for recon and ACT tractography |
| `fmap` | Recommended | Enables measured SDC; otherwise pass `--syn` (see [Preparing your data](preparing_data.md#fieldmaps-and-sdc)) |

Optional BIDS lesion mask (`*_T1w_label-lesion_roi.nii.gz`) enables Step 1.1 inpainting and Step 4.1 disconnectome when requested.

---

## Output types

Declared in `app.json`: **NIfTI_GZ**, **CSV**, **JSON**, plus HTML QC reports. File layout: **[Outputs](outputs.md)** · export policy: **[Derivatives](derivatives.md)**.

---

## Container model

Unlike a single monolithic QSIPrep image, this BIDS App **orchestrates multiple pinned step containers** (QSIPrep, FreeSurfer/FastSurfer, QSIRecon, connectome, LIT, nodestrength) via Snakemake. This matches typical HPC deployments where upstream BIDS Apps are cached on shared filesystems.

| Deployment | Image / path |
|------------|--------------|
| **Docker orchestrator** | `phindagijimana321/dkt-connectome:<version>` on [Docker Hub](https://hub.docker.com/r/phindagijimana321/dkt-connectome) and `ghcr.io/phindagijimana/dkt-connectome:<version>` |
| **HPC (Apptainer)** | Step `.sif` files via `bash install.sh` — [Containers](containers.md) |

The orchestrator image wraps `./run`; step images mount at runtime. **`FS_LICENSE`** must point to **your** FreeSurfer license ([Installation](installation.md#freesurfer-license-you-must-obtain-this)).

---

## Implementation

Under the hood, `./run` invokes the Snakemake workflow in [`workflow/Snakefile`](https://github.com/phindagijimana/dkt_connectome/blob/main/dwi_pipeline/workflow/Snakefile) through `run_subject.sh`.

- Direct Snakemake / HPC usage: **[Snakemake workflow](snakemake_workflow.md)**
- `./run` flags and examples: **[Usage](usage.md)**
- First run walkthrough: **[Tutorial](tutorial.md)**

---

## Registry listing (optional)

Listing on [bids-apps.neuroimaging.io](https://bids-apps.neuroimaging.io/apps/) is **not required** to run, cite, or release the pipeline. Maintainer submission guide (GitHub only): [bids_apps_registry.md on GitHub](https://github.com/phindagijimana/dkt_connectome/blob/main/dwi_pipeline/docs/maintainer/bids_apps_registry.md).
