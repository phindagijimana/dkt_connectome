# Container images

The DKT Connectome pipeline orchestrates **multiple Apptainer `.sif` images** on HPC — not a single published Docker image. Configure paths in `workflow/config/config.local.yaml` or via `CONTAINER_*` environment variables (see [Configuration](configuration.md)).

---

## Step images

| Step | Image | Build / obtain |
|------|-------|----------------|
| 1 — QSIPrep | `qsiprep.sif` | [QSIPrep releases](https://github.com/pennlinc/qsiprep) |
| 1.5 — Inpaint | `lit_0.6.0.sif` | [`containers/lit/build_lit.sh`](https://github.com/phindagijimana/dkt_connectome/blob/main/dwi_pipeline/containers/lit/build_lit.sh) |
| 2 — Recon | `freesurfer_7.4.1.sif` | [`containers/pull_freesurfer_sif.sbatch`](https://github.com/phindagijimana/dkt_connectome/blob/main/dwi_pipeline/containers/pull_freesurfer_sif.sbatch) |
| 2 alt | `fastsurfer_latest.sif` | [FastSurfer](https://github.com/Deep-MI/FastSurfer) |
| 3 — QSIRecon | `qsirecon.sif` | [QSIRecon releases](https://github.com/pennlinc/qsirecon) |
| 4 — Connectome | `dkt_connectome.sif` | [`containers/connectome/build_connectome.sh`](https://github.com/phindagijimana/dkt_connectome/blob/main/dwi_pipeline/containers/connectome/build_connectome.sh) |
| 5 — Node strength | `nodestrength_0.1.0.sif` | [dwi-AI / nodestrength](https://github.com/phindagijimana/dwi-AI) |

---

## Environment variables

| Variable | Config key |
|----------|------------|
| `CONTAINER_QSIPREP` | `containers.qsiprep` |
| `CONTAINER_QSIRECON` | `containers.qsirecon` |
| `CONTAINER_FREESURFER` | `containers.freesurfer` |
| `CONTAINER_FASTSURFER` | `containers.fastsurfer` |
| `CONTAINER_CONNECTOME` | `containers.connectome` |
| `CONTAINER_LIT` | `containers.lit` |
| `CONTAINER_NODESTRENGTH` | `containers.nodestrength` |

Reference upstream tags with `container_pins:` in config — see [Derivatives policy](derivatives.md).

---

## HPC vs Docker

**Production (recommended):** [`submit.sh`](https://github.com/phindagijimana/dkt_connectome/blob/main/dwi_pipeline/submit.sh) + Apptainer on Slurm. No orchestrator container required.

An optional [`Dockerfile`](https://github.com/phindagijimana/dkt_connectome/blob/main/dwi_pipeline/Dockerfile) exists for local/docker-only experiments; it is **not published** and is not part of the multi-site HPC path.

---

## Build notes

- **Step 4:** [containers/connectome/README.md](https://github.com/phindagijimana/dkt_connectome/blob/main/dwi_pipeline/containers/connectome/README.md)
- **Step 1.5:** [containers/lit/README.md](https://github.com/phindagijimana/dkt_connectome/blob/main/dwi_pipeline/containers/lit/README.md)
- Full table in [Installation](installation.md)
