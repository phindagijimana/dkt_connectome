# Installation

## Requirements

| Component | Version / notes |
|-----------|-----------------|
| OS | Linux (HPC or workstation) |
| [Apptainer](https://apptainer.org/) or Singularity | On `PATH` |
| Python | 3.9+ (orchestration scripts, Snakemake) |
| [Snakemake](https://snakemake.readthedocs.io/) | ≥ 8.0 (workflow engine) |
| FreeSurfer license | [Free registration](https://surfer.nmr.mgh.harvard.edu/registration.html) |
| Git | Clone [dkt_connectome](https://github.com/phindagijimana/dkt_connectome) |

Optional: Slurm for `submit.sh` array jobs.

---

## Clone and enter the BIDS App

```bash
git clone https://github.com/phindagijimana/dkt_connectome.git
cd dkt_connectome/dwi_pipeline
chmod +x run
```

Documentation: [index.md](index.md) · Quick start: [quickstart.md](quickstart.md) · **Hosted:** [Read the Docs](https://dkt-connectome.readthedocs.io/en/latest/).

---

## FreeSurfer license

```bash
export FS_LICENSE=/path/to/license.txt
```

QSIPrep and recon steps read this inside containers via bind-mount.

---

## Containers

The pipeline orchestrates **multiple Apptainer images** (not one monolithic image):

| Step | Image | Obtain |
|------|-------|--------|
| 1 | `qsiprep.sif` | [QSIPrep releases](https://github.com/pennlinc/qsiprep) |
| 2 | `freesurfer_7.4.1.sif` | `sbatch containers/pull_freesurfer_sif.sbatch` |
| 2 alt | `fastsurfer_latest.sif` | Upstream FastSurfer |
| 3 | `qsirecon.sif` | [QSIRecon releases](https://github.com/pennlinc/qsirecon) |
| 4 | `dkt_connectome.sif` | `bash containers/connectome/build_connectome.sh` |
| 1.5 | `lit_0.6.0.sif` | `bash containers/lit/build_lit.sh` |
| 5 | `nodestrength_0.1.0.sif` | [dwi-AI / nodestrength](https://github.com/phindagijimana/dwi-AI) |

### Default paths

Configure in `workflow/config/config.local.yaml` or environment:

| Variable | Typical default |
|----------|-----------------|
| `CONTAINER_QSIPREP` | `.../others/containers/qsiprep.sif` |
| `CONTAINER_QSIRECON` | `.../others/containers/qsirecon.sif` |
| `CONTAINER_FREESURFER` | `.../others/containers/freesurfer_7.4.1.sif` |
| `CONTAINER_CONNECTOME` | `.../others/containers/dkt_connectome.sif` |
| `CONTAINER_LIT` | `.../others/containers/lit_0.6.0.sif` |
| `CONTAINER_NODESTRENGTH` | `.../node_strength/containers/nodestrength_0.1.0.sif` |
| `TEMPLATEFLOW_HOME` | `templateflow/` in repo |

See [README.md §Containers](https://github.com/phindagijimana/dkt_connectome/blob/main/dwi_pipeline/README.md) for full table.

**Pin containers** using `container_pins` in config (reference tags) and local `.sif` paths — see [Derivatives policy](derivatives.md).

---

## BIDS validation (optional)

```bash
npm install -g bids-validator   # or use npx / BIDS_VALIDATOR_SIF
bash scripts/run_bids_validator.sh /path/to/BIDS
```

Enable on every run:

```bash
./run BIDS OUT participant --participant-label 009 --bids-validation
```

Or set `bids.validate: true` in `config.local.yaml`.

---

## Build Step 4 connectome image

```bash
bash dwi_pipeline/containers/connectome/build_connectome.sh
```

Details: [containers/connectome/README.md](https://github.com/phindagijimana/dkt_connectome/blob/main/dwi_pipeline/containers/connectome/README.md).

> **HPC (recommended):** use [`submit.sh`](https://github.com/phindagijimana/dkt_connectome/blob/main/dwi_pipeline/submit.sh) with Apptainer `.sif` images — no Docker orchestrator required. An optional [`Dockerfile`](https://github.com/phindagijimana/dkt_connectome/blob/main/dwi_pipeline/Dockerfile) exists for cloud/docker-only experiments; it is not published and not part of the URMC HPC production path.

---

## Python dependencies (host)

For orchestration and Step 4.5 disconnectome:

```bash
pip install numpy nibabel scipy
```

Snakemake is required for `./run` and `workflow/run_subject.sh`.

---

## Configuration

| File | Purpose |
|------|---------|
| `workflow/config/config.yaml` | Default workflow settings |
| `workflow/config/config.local.yaml` | Site overrides (create locally) |
| `config/dwi_select_b1000.json` | Default DWI shell filter |

Key defaults:

- `connectome.weighting: count`
- `connectome.parcellation: dkt` (78 nodes)
- Inpaint auto-on when lesion mask present

---

## Verify installation

```bash
cd dwi_pipeline
./run --help

# Dry-run one subject
export FS_LICENSE=/path/to/license.txt
./run /path/to/BIDS /path/to/out participant \
  --participant-label 009 --dry-run
```

Next: [Quick start](quickstart.md) · [BIDS App](bids_app.md).
