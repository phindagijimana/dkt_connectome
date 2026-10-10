# DKT Connectome

**Lesion-aware structural connectomics BIDS App** — QSIPrep → optional inpainting → recon → QSIRecon ACT tractography → DKT connectome → optional disconnectome → node strength.

[![Snakemake](https://img.shields.io/badge/snakemake-≥8.0-brightgreen.svg)](https://snakemake.readthedocs.io)
[![License: Apache 2.0](https://img.shields.io/badge/License-Apache_2.0-blue.svg)](LICENSE)
[![Documentation](https://readthedocs.org/projects/dkt-connectome/badge/?version=latest)](https://dkt-connectome.readthedocs.io/en/latest/)
[![BIDS App](https://img.shields.io/badge/BIDS--App-v0.3.0-blue.svg)](https://dkt-connectome.readthedocs.io/en/latest/bids_app/)

**New here?** Use the **[documentation site](https://dkt-connectome.readthedocs.io/en/latest/)** (tutorial, flags, troubleshooting) or follow the steps below on GitHub.

**Recommended path:** Linux workstation or HPC with **Apptainer** (not Docker-only). Clone → `./dkt install` → `./dkt check --strict` → dry-run on [IDEAS sample](dwi_pipeline/docs/datasets/ideas.md) → run your BIDS data.

---

## Requirements

| Component | Notes |
|-----------|--------|
| Linux | HPC or workstation |
| [Apptainer](https://apptainer.org/) | Step containers (`.sif`) |
| Python 3.9+ · [Snakemake](https://snakemake.readthedocs.io/) ≥ 8 | Orchestration |
| **FreeSurfer license** | [Free registration](https://surfer.nmr.mgh.harvard.edu/registration.html) — `export FS_LICENSE=/path/to/license.txt` |

Optional: Slurm for cohort arrays. Docker is optional for the orchestrator only — step `.sif` images still required ([Installation](https://dkt-connectome.readthedocs.io/en/latest/installation.html)).

---

## Quick start

After clone, always work from `dwi_pipeline/`:

```bash
git clone https://github.com/phindagijimana/dkt_connectome.git
cd dkt_connectome/dwi_pipeline
chmod +x dkt run install
export FS_LICENSE=/path/to/your/license.txt
export DKT_CONTAINER_CACHE=${DKT_CONTAINER_CACHE:-$HOME/.cache/dkt-connectome/containers}
export APPTAINER_TMPDIR=${APPTAINER_TMPDIR:-$HOME/.cache/dkt-connectome/apptainer_tmp}
mkdir -p "$DKT_CONTAINER_CACHE" "$APPTAINER_TMPDIR"
./dkt install
./dkt check --strict
bash scripts/download_ideas_sample.sh
./dkt run "$(pwd)/sample_data/ideas/bids" "$(pwd)/sample_data/ideas/results/sub-1_tutorial" participant \
  --participant-label 1 --session-filter ses-1 --fastsurfer --syn \
  --dwi-select config/dwi_select_ideas_b2500.json --dry-run
```

Download the sample only with `bash scripts/download_ideas_sample.sh` from `dwi_pipeline/`. `./dkt run` is the same command as `./run` (BIDS App). See [Usage](https://dkt-connectome.readthedocs.io/en/latest/usage.html).

`./dkt install` uses [`release_manifest.json`](dwi_pipeline/release_manifest.json): DKT-owned step SIFs from GHCR (`oras://ghcr.io/...`), upstream pennlinc/freesurfer/deepmi images from Docker Hub via `docker://` (first-time OCI→SIF can take 30–90 min; use a local, non-NFS `DKT_CONTAINER_CACHE` and `APPTAINER_TMPDIR`).

### After your first subject (your own BIDS)

```bash
./dkt run /path/to/BIDS /path/to/out participant \
  --participant-label 01 --session-filter ses-1 --n-cpus 8 --fastsurfer --syn
```

Full walkthrough: [Tutorial](https://dkt-connectome.readthedocs.io/en/latest/tutorial.html).

---

## Workflow

![DKT Connectome pipeline workflow](dwi_pipeline/docs/img/pipeline_overview.svg)

| Step | Tool |
|------|------|
| 1 | [QSIPrep](https://qsiprep.readthedocs.io/) — DWI preprocessing |
| 1.1 | Optional inpainting when a BIDS lesion mask exists |
| 2 | FreeSurfer / FastSurfer — surfaces + DKT |
| 3 | [QSIRecon](https://qsirecon.readthedocs.io/) — ACT tractography |
| 4 | 78×78 DKT connectome (count, length, FA, MD) |
| 4.1 | Optional `--disconnection` |
| 5 | Node strength + ENIGMA-style report |

Which steps run in containers vs on the host: [Architecture](https://dkt-connectome.readthedocs.io/en/latest/architecture.html).

---

## Documentation

| Start here | Link |
|------------|------|
| **Hosted guide (recommended)** | [dkt-connectome.readthedocs.io](https://dkt-connectome.readthedocs.io/en/latest/) |
| Installation & containers | [installation.md](dwi_pipeline/docs/installation.md) · [containers.md](dwi_pipeline/docs/containers.md) |
| First-run tutorial | [tutorial.md](dwi_pipeline/docs/tutorial.md) |
| All CLI flags | [usage.md](dwi_pipeline/docs/usage.md) |
| Prepare BIDS data | [preparing_data.md](dwi_pipeline/docs/preparing_data.md) |
| Upgrade / changelog | [upgrading.md](dwi_pipeline/docs/upgrading.md) · [changelog.md](dwi_pipeline/docs/changelog.md) |
| Operator reference (advanced) | [dwi_pipeline/README.md](dwi_pipeline/README.md) |
| GitHub release | [v0.3.0-step-sifs](https://github.com/phindagijimana/dkt_connectome/releases/tag/v0.3.0-step-sifs) |

---

## After your first subject

### HPC / cohort

```bash
export BIDS_DIR=/path/to/BIDS
export RESULTS_ROOT=/path/to/out
bash dwi_pipeline/submit.sh          # Slurm array (from repo root)
# or one subject:
bash dwi_pipeline/workflow/run_subject.sh all SUBJ01 --fastsurfer --syn
```

### Legacy root workflow

> Repo-root [`./connectome`](connectome) and [`Snakefile`](Snakefile) remain for **Dockstore compatibility only**. New work: `dwi_pipeline/` + `./dkt` or `./run`.

[Comparisons § Legacy](dwi_pipeline/docs/comparisons.md)

---

## License

[Apache License 2.0](LICENSE)
