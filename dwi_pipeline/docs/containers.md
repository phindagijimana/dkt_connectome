# Containers

The DKT Connectome orchestrates **multiple Apptainer `.sif` images** on HPC. Use **`bash install.sh`** to pull pinned images and write `workflow/config/config.local.yaml`, or set `CONTAINER_*` environment variables (see [Installation](installation.md)).

**Docker orchestrator (BIDS App):** `phindagijimana321/dkt-connectome:0.2.0` on [Docker Hub](https://hub.docker.com/r/phindagijimana321/dkt-connectome) and `ghcr.io/phindagijimana/dkt-connectome:0.2.0`. Step images still mount from cache at runtime.

---

## Step images

| Step | Image | Build / obtain |
|------|-------|----------------|
| 1 — QSIPrep | `qsiprep_1.0.0.sif` | `bash install.sh --mode qsiprep` or [QSIPrep releases](https://github.com/pennlinc/qsiprep) |
| 1.5 — Inpaint | `lit_0.6.0.sif` | `install.sh` or [`containers/lit/build_lit.sh`](https://github.com/phindagijimana/dkt_connectome/blob/main/dwi_pipeline/containers/lit/build_lit.sh) |
| 2 — Recon | `freesurfer_7.4.1.sif` | `install.sh` or [`containers/pull_freesurfer_sif.sbatch`](https://github.com/phindagijimana/dkt_connectome/blob/main/dwi_pipeline/containers/pull_freesurfer_sif.sbatch) |
| 2 alt | `fastsurfer_latest.sif` | `install.sh` or [FastSurfer](https://github.com/Deep-MI/FastSurfer) |
| 3 — QSIRecon | `qsirecon_1.2.1.sif` | `install.sh` or [QSIRecon releases](https://github.com/pennlinc/qsirecon) |
| 4 — Connectome | `dkt_connectome.sif` | `install.sh` (pull/build fallbacks) or [`containers/connectome/build_connectome.sh`](https://github.com/phindagijimana/dkt_connectome/blob/main/dwi_pipeline/containers/connectome/build_connectome.sh) |
| 5 — Node strength | `nodestrength_0.1.0.sif` | `install.sh` or Docker Hub `phindagijimana321/nodestrength:0.1.0` |

**Step 4 OCI on Docker Hub (legacy name):** `phindagijimana321/dkt_connectome:latest` — the connectome *step* container, not the orchestrator.

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
| `DKT_CONTAINER_CACHE` | Default install cache (`~/.cache/dkt-connectome/containers`) |

Reference upstream tags with `container_pins:` in config — see [Configuration](configuration.md). Full auto-generated catalog: [on GitHub](https://github.com/phindagijimana/dkt_connectome/blob/main/dwi_pipeline/docs/config_catalog.md).

---

## HPC vs Docker

**Production (recommended):** [`submit.sh`](https://github.com/phindagijimana/dkt_connectome/blob/main/dwi_pipeline/submit.sh) + Apptainer on Slurm, or `./run` after `bash install.sh`.

**Docker / cloud:** orchestrator image + cached step `.sif` files (`DKT_AUTO_INSTALL=1`, `docker-compose.yml`). See [Installation § Docker Compose](installation.md) and [BIDS App specification](bids_app.md).

---

## Build notes

- **Step 4:** [containers/connectome/README.md](https://github.com/phindagijimana/dkt_connectome/blob/main/dwi_pipeline/containers/connectome/README.md)
- **Step 1.5:** [containers/lit/README.md](https://github.com/phindagijimana/dkt_connectome/blob/main/dwi_pipeline/containers/lit/README.md)
- **Publish orchestrator:** [Release checklist on GitHub](https://github.com/phindagijimana/dkt_connectome/blob/main/dwi_pipeline/docs/maintainer/publishing.md)
