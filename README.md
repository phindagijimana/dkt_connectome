# DKT Connectome

**Lesion-aware structural connectomics BIDS App** — QSIPrep → optional inpainting → recon → QSIRecon ACT tractography → DKT connectome → optional disconnectome → node strength.

[![Snakemake](https://img.shields.io/badge/snakemake-≥8.0-brightgreen.svg)](https://snakemake.readthedocs.io)
[![License: Apache 2.0](https://img.shields.io/badge/License-Apache_2.0-blue.svg)](LICENSE)
[![Documentation](https://readthedocs.org/projects/dkt-connectome/badge/?version=latest)](https://dkt-connectome.readthedocs.io/en/latest/)
[![BIDS App](https://img.shields.io/badge/BIDS--App-v0.2.2-blue.svg)](https://dkt-connectome.readthedocs.io/en/latest/bids_app/)

**New here?** Use the **[documentation site](https://dkt-connectome.readthedocs.io/en/latest/)** (tutorial, flags, troubleshooting) or follow the steps below on GitHub.

---

## Requirements

| Component | Notes |
|-----------|--------|
| Linux | HPC or workstation |
| [Apptainer](https://apptainer.org/) | Step containers (`.sif`) |
| Python 3.9+ · [Snakemake](https://snakemake.readthedocs.io/) ≥ 8 | Orchestration |
| **FreeSurfer license** | [Free registration](https://surfer.nmr.mgh.harvard.edu/registration.html) — `export FS_LICENSE=/path/to/license.txt` |

Optional: Slurm for cohort arrays · Docker for cloud (`phindagijimana321/dkt-connectome:0.2.2`)

---

## Quick start (5 commands)

```bash
git clone https://github.com/phindagijimana/dkt_connectome.git
cd dkt_connectome/dwi_pipeline
chmod +x dkt run install

export FS_LICENSE=/path/to/your/license.txt
./dkt install          # pull step .sif images + write config.local.yaml
./dkt check            # verify tools, license, containers

# Plan first (no compute):
./dkt run /path/to/BIDS /path/to/out participant \
  --participant-label 01 --session-filter ses-1 --dry-run

# Full run:
./dkt run /path/to/BIDS /path/to/out participant \
  --participant-label 01 --session-filter ses-1 --n-cpus 8 --fastsurfer --syn
```

**Sample data:** `bash scripts/download_ideas_sample.sh` then follow [Tutorial](https://dkt-connectome.readthedocs.io/en/latest/tutorial.html).

**Docker:**

```bash
docker pull phindagijimana321/dkt-connectome:0.2.2
docker run --rm -e BIDS_APP_CI=1 -e FS_LICENSE=/tmp/license.txt \
  phindagijimana321/dkt-connectome:0.2.2 dkt check
```

**CLI:** `./dkt install | pull | run | log | check | version` — `./dkt run …` equals `./run …` (BIDS App). See [Usage](https://dkt-connectome.readthedocs.io/en/latest/usage.html).

---

## Workflow

![DKT Connectome pipeline workflow](dwi_pipeline/docs/img/pipeline_overview.svg)

| Step | Tool | Notes |
|------|------|--------|
| 1 | [QSIPrep](https://qsiprep.readthedocs.io/) | DWI preprocessing, SDC, T1w–DWI alignment |
| 1.1 | neuroLIT / VBT | Optional inpainting when a BIDS lesion mask exists |
| 2 | FreeSurfer / FastSurfer | Surfaces + DKT parcellation |
| 3 | [QSIRecon](https://qsirecon.readthedocs.io/) | SS3T-CSD + ACT-HSVS tractography |
| 3.1 | Lesion-aware ACT | Optional `--act-mode lesion-aware` |
| 4 | `dkt_connectome.sif` | 78×78 DKT connectome (count, length, FA, MD) |
| 4.1 | Disconnectome | Opt-in `--disconnection` |
| 5 | nodestrength | Graph metrics + ENIGMA-style report |

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
| GitHub release | [v0.2.2](https://github.com/phindagijimana/dkt_connectome/releases/tag/v0.2.2) |

---

## HPC / cohort

```bash
export BIDS_DIR=/path/to/BIDS
export RESULTS_ROOT=/path/to/out
bash dwi_pipeline/submit.sh          # Slurm array (from repo root)
# or one subject:
bash dwi_pipeline/workflow/run_subject.sh all SUBJ01 --fastsurfer --syn
```

---

## Legacy root workflow

> Repo-root [`./connectome`](connectome) and [`Snakefile`](Snakefile) remain for **Dockstore compatibility only**. New work: `dwi_pipeline/` + `./dkt` or `./run`.

[Comparisons § Legacy](dwi_pipeline/docs/comparisons.md)

---

## License

[Apache License 2.0](LICENSE)
