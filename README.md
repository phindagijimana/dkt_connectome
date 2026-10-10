# DKT Connectome — lesion-aware structural connectomics BIDS App

QSIPrep → optional inpainting → recon → QSIRecon ACT tractography → DKT connectome → optional disconnectome → node strength.

[![Snakemake](https://img.shields.io/badge/snakemake-≥8.0-brightgreen.svg)](https://snakemake.readthedocs.io)
[![License: Apache 2.0](https://img.shields.io/badge/License-Apache_2.0-blue.svg)](LICENSE)
[![Documentation](https://readthedocs.org/projects/dkt-connectome/badge/?version=latest)](https://dkt-connectome.readthedocs.io/en/latest/)
[![BIDS App](https://img.shields.io/badge/BIDS--App-v0.3.0-blue.svg)](https://dkt-connectome.readthedocs.io/en/latest/bids_app/)

**New here?** Use the **[documentation site](https://dkt-connectome.readthedocs.io/en/latest/)** or the commands below.

The only pipeline in this repository is **`dwi_pipeline/`**. BIDS App contract: **`./run`** at the repo root (or `dwi_pipeline/run`). Day-to-day commands: `cd dwi_pipeline` and use **`./dkt`**.

| What | Name |
|------|------|
| Display name | **DKT Connectome** |
| CLI | `./dkt` |
| GitHub repo | `phindagijimana/dkt_connectome` |
| Docs | [dkt-connectome.readthedocs.io](https://dkt-connectome.readthedocs.io/en/latest/) |
| Orchestrator image (BIDS App wrapper) | `dkt-connectome` |
| Step 4 image (connectome + disconnectome) | GHCR `dk-connectome` · Docker Hub `dkt_connectome` |

`dk-connectome` is a leftover registry name from the older DK (84-node) atlas. The pipeline default is **DKT (78 nodes)**. Do not confuse the Step 4 image with the orchestrator. Details: [Containers](dwi_pipeline/docs/containers.md).

---

## Requirements

| Component | Notes |
|-----------|--------|
| Linux | HPC or workstation |
| [Apptainer](https://apptainer.org/) | Step containers (`.sif`) |
| Python 3.9+ · [Snakemake](https://snakemake.readthedocs.io/) ≥ 8 | Orchestration (`environment.yml`) |
| **FreeSurfer license** | [Free registration](https://surfer.nmr.mgh.harvard.edu/registration.html) — `export FS_LICENSE=/path/to/license.txt` |

Optional: Slurm for cohort arrays. Docker is optional for the orchestrator only — step `.sif` images are still required.

---

## Quick start

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

`./dkt install` reads [`release_manifest.json`](dwi_pipeline/release_manifest.json). First-time image pulls can take 30–90 minutes; use a **local (non-NFS)** `DKT_CONTAINER_CACHE` and `APPTAINER_TMPDIR`.

Full walkthrough: [Tutorial](https://dkt-connectome.readthedocs.io/en/latest/tutorial.html).

---

## Public demos (software validation)

This pipeline was used on the **TRACK-TBI DoD** project (Phase 1: ~650 participants, two timepoints; ~100 with lesion masks). Those data stay under the study **data-use agreement** and are not in this repository.

What we share: **one IDEAS II subject** and **one BTC glioma subject** (lesion-aware path). They show the software runs. They are not TRACK-TBI clinical validation.

| Demo | Role | Download |
|------|------|----------|
| [IDEAS II](dwi_pipeline/docs/datasets/ideas.md) (`ds007401`) | First-run / no-lesion smoke test | `bash scripts/download_ideas_sample.sh` |
| [BTC glioma PAT20](dwi_pipeline/docs/datasets/btc_glioma.md) (`ds001226`) | Lesion-aware path (`--disconnection`) | `bash scripts/download_btc_glioma_sample.sh` |

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

Each step uses its own pinned `.sif` image. That is intentional — see [Containers](https://dkt-connectome.readthedocs.io/en/latest/containers.html).

---

## How to start a run

| Situation | Command |
|-----------|---------|
| One subject (tutorial / workstation) | `./dkt run …` from `dwi_pipeline/` |
| Slurm cohort | `bash dwi_pipeline/submit.sh` (FastSurfer by default) |

`./dkt run` is the BIDS App (`./run`). Do not call `subject.sh` for new work.

---

## Documentation

| Start here | Link |
|------------|------|
| **Hosted guide** | [dkt-connectome.readthedocs.io](https://dkt-connectome.readthedocs.io/en/latest/) |
| Installation | [installation.md](dwi_pipeline/docs/installation.md) |
| Tutorial | [tutorial.md](dwi_pipeline/docs/tutorial.md) |
| CLI flags | [usage.md](dwi_pipeline/docs/usage.md) |
| Configuration order | [configuration.md](dwi_pipeline/docs/configuration.md) |
| Changelog | [changelog.md](dwi_pipeline/docs/changelog.md) |

---

## License

[Apache License 2.0](LICENSE)
