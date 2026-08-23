# DKT Connectome

**Lesion-aware structural connectomics BIDS App** — QSIPrep → optional inpainting → recon → QSIRecon ACT tractography → DKT connectome → optional disconnectome → node strength.

[![Snakemake](https://img.shields.io/badge/snakemake-≥8.0-brightgreen.svg)](https://snakemake.readthedocs.io)
[![License: Apache 2.0](https://img.shields.io/badge/License-Apache_2.0-blue.svg)](LICENSE)
[![Documentation](https://readthedocs.org/projects/dkt-connectome/badge/?version=latest)](https://dkt-connectome.readthedocs.io/en/latest/)
[![BIDS App](https://img.shields.io/badge/BIDS--App-v0.2.0-blue.svg)](https://dkt-connectome.readthedocs.io/en/latest/bids_app/)

## Workflow

![DKT Connectome pipeline workflow](dwi_pipeline/docs/img/pipeline_overview.svg)

| Step | Tool | Notes |
|------|------|--------|
| 1 | [QSIPrep](https://qsiprep.readthedocs.io/) | DWI preprocessing, SDC, T1w–DWI alignment |
| 1.5 | neuroLIT / VBT | Optional inpainting when a BIDS lesion mask exists |
| 2 | FreeSurfer / FastSurfer | Surfaces + DKT parcellation |
| 3 | [QSIRecon](https://qsirecon.readthedocs.io/) | SS3T-CSD + ACT-HSVS tractography |
| 3.5 | Lesion-aware ACT | Optional `--act-mode lesion-aware` rebuild |
| 4 | `dkt_connectome.sif` | 78×78 DKT connectome (count, length, FA, MD) |
| 4.5 | Disconnectome | Opt-in `--disconnection` |
| 5 | nodestrength | Graph metrics + ENIGMA-style report |

Theory and citations: [How it works](https://dkt-connectome.readthedocs.io/en/latest/science_overview.html) · Full operator guide: [`dwi_pipeline/README.md`](dwi_pipeline/README.md)

## Quick start

```bash
git clone https://github.com/phindagijimana/dkt_connectome.git
cd dkt_connectome/dwi_pipeline

export FS_LICENSE=/path/to/your/license.txt
./run /path/to/BIDS /path/to/out participant \
  --participant-label 01 --session-filter ses-1 --n-cpus 8
```

HPC / Slurm: [`dwi_pipeline/submit.sh`](dwi_pipeline/submit.sh) · Tutorial: [Read the Docs](https://dkt-connectome.readthedocs.io/en/latest/tutorial.html)

## Documentation

| Resource | Link |
|----------|------|
| **Hosted docs (QSIPrep-style)** | [dkt-connectome.readthedocs.io](https://dkt-connectome.readthedocs.io/en/latest/) |
| GitHub docs hub | [`dwi_pipeline/docs/home.md`](dwi_pipeline/docs/home.md) |
| BIDS App CLI | [`dwi_pipeline/run`](dwi_pipeline/run) |
| Installation & containers | [`dwi_pipeline/docs/installation.md`](dwi_pipeline/docs/installation.md) |
| Methods by step | [`dwi_pipeline/docs/methods/`](dwi_pipeline/docs/methods/) |
| Registries & executors | [REGISTRY.md](REGISTRY.md) |

Build docs locally: `cd dwi_pipeline/docs && pip install -r requirements.txt && make html`

## Legacy root workflow

> The repository root [`./connectome`](connectome) CLI and 4-stage [`Snakefile`](Snakefile) (QSIPrep → recon → QSIRecon → DK connectome only) remain for **Dockstore backward compatibility**. Do not use for new cohort work.

Details: [Comparisons § Legacy root workflow](dwi_pipeline/docs/comparisons.md) · [USER_GUIDE.md](USER_GUIDE.md)

## License

[Apache License 2.0](LICENSE)
