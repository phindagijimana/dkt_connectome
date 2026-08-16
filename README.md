# dk_connectome

**Canonical pipeline:** [DKT Connectome documentation](https://dkt-connectome.readthedocs.io/en/latest/) — lesion-aware structural connectomics (QSIPrep → inpaint → recon → QSIRecon → DKT connectome → disconnectome → node strength).

[![Snakemake](https://img.shields.io/badge/snakemake-≥8.0-brightgreen.svg)](https://snakemake.readthedocs.io)
[![License: Apache 2.0](https://img.shields.io/badge/License-Apache_2.0-blue.svg)](LICENSE)
[![Documentation](https://readthedocs.org/projects/dkt-connectome/badge/?version=latest)](https://dkt-connectome.readthedocs.io/en/latest/)
[![BIDS App](https://img.shields.io/badge/BIDS--App-v0.2.0-blue.svg)](https://dkt-connectome.readthedocs.io/en/latest/bids_app/)

## Quick start (DKT Connectome)

```bash
git clone https://github.com/phindagijimana/dkt_connectome.git
cd dk_connectome/dwi_pipeline

./run /path/to/BIDS /path/to/out participant \
  --participant-label 01 --session-filter ses-1 --n-cpus 8
```

HPC / Slurm: [`dwi_pipeline/submit.sh`](dwi_pipeline/submit.sh). Full guide: [Tutorial](https://dkt-connectome.readthedocs.io/en/latest/tutorial/).

## Legacy root workflow

> The repository root [`./connectome`](connectome) CLI and 4-stage [`Snakefile`](Snakefile) (QSIPrep → recon → QSIRecon → DK connectome only) remain for **Dockstore backward compatibility**. Do not use for new cohort work.

Details: [Comparisons § Legacy root workflow](dwi_pipeline/docs/comparisons.md#vs-legacy-root-dk_connectome-this-repo-only) · [USER_GUIDE.md](USER_GUIDE.md) (legacy `./connectome` reference).

## More

| Resource | Link |
|----------|------|
| Documentation | [dkt-connectome.readthedocs.io](https://dkt-connectome.readthedocs.io/en/latest/) |
| BIDS App | [`dwi_pipeline/run`](dwi_pipeline/run) |
| Registries & executors | [REGISTRY.md](REGISTRY.md) |
| Step 4 container | [containers/](containers/) |
| Citation | [`CITATION.cff`](CITATION.cff) |

## License

[Apache License 2.0](LICENSE).
