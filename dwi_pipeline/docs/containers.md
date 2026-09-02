# Containers

The DKT Connectome orchestrates **multiple Apptainer `.sif` images** on HPC. Use **`bash install.sh`** to pull pinned images and write `workflow/config/config.local.yaml`, or set `CONTAINER_*` environment variables (see [Installation](installation.md)).

**Docker orchestrator (BIDS App):** `phindagijimana321/dkt-connectome:0.2.1` on [Docker Hub](https://hub.docker.com/r/phindagijimana321/dkt-connectome) and `ghcr.io/phindagijimana/dkt-connectome:0.2.1`. Step images still mount from cache at runtime.

---

## Step images

| Step | Image | Build / obtain |
|------|-------|----------------|
| 1 — QSIPrep | `qsiprep_1.0.0.sif` | `bash install.sh --mode qsiprep` or [QSIPrep releases](https://github.com/pennlinc/qsiprep) |
| 1.1 — Inpaint (neuroLIT) | `lit_0.6.0.sif` | `install.sh` or [`containers/lit/build_lit.sh`](https://github.com/phindagijimana/dkt_connectome/blob/main/dwi_pipeline/containers/lit/build_lit.sh) |
| 1.1 — Inpaint (VBT) | `dkt_vbt.sif` | `install.sh --mode inpaint` or [`containers/vbt/build_vbt.sh`](https://github.com/phindagijimana/dkt_connectome/blob/main/dwi_pipeline/containers/vbt/build_vbt.sh) · Docker Hub `phindagijimana321/dkt-vbt:0.1.0` |
| 2 — Recon | `freesurfer_7.4.1.sif` | `install.sh` or [`containers/pull_freesurfer_sif.sbatch`](https://github.com/phindagijimana/dkt_connectome/blob/main/dwi_pipeline/containers/pull_freesurfer_sif.sbatch) |
| 2 alt | `fastsurfer_latest.sif` | `install.sh` or [FastSurfer](https://github.com/Deep-MI/FastSurfer) |
| 3 — QSIRecon | `qsirecon_1.2.1.sif` | `install.sh` or [QSIRecon releases](https://github.com/pennlinc/qsirecon) |
| 3.1 — Lesion-aware ACT | `dkt_lesion_act.sif` | `install.sh --mode act` or [`containers/lesion_act/build_lesion_act.sh`](https://github.com/phindagijimana/dkt_connectome/blob/main/dwi_pipeline/containers/lesion_act/build_lesion_act.sh) · Docker Hub `phindagijimana321/dkt-lesion-act:0.1.0` |
| 3.2 (5TT) — Deep Atropos native 5TT | `dkt_deep_atropos.sif` | [`containers/deep_atropos/build_deep_atropos.sh`](https://github.com/phindagijimana/dkt_connectome/blob/main/dwi_pipeline/containers/deep_atropos/build_deep_atropos.sh) · optional; `--act-5tt-source deep-atropos-native` |
| 3.2 (seg) — Deep Atropos segmentation | `dkt_deep_atropos_seg.sif` | [`containers/deep_atropos_seg/build_deep_atropos_seg.sh`](https://github.com/phindagijimana/dkt_connectome/blob/main/dwi_pipeline/containers/deep_atropos_seg/build_deep_atropos_seg.sh) · ANTsPyNet; `segmentation_mode=generate` or `auto` |
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
| `CONTAINER_VBT` | `containers.vbt` |
| `CONTAINER_LESION_ACT` | `containers.lesion_act` |
| `CONTAINER_DEEP_ATROPOS` | `containers.deep_atropos` |
| `CONTAINER_DEEP_ATROPOS_SEG` | `containers.deep_atropos_seg` |
| `CONTAINER_NODESTRENGTH` | `containers.nodestrength` |
| `DKT_CONTAINER_CACHE` | Default install cache (`~/.cache/dkt-connectome/containers`) |

Reference upstream tags with `container_pins:` in config — see [Configuration](configuration.md). Full auto-generated catalog: [on GitHub](https://github.com/phindagijimana/dkt_connectome/blob/main/dwi_pipeline/docs/config_catalog.md).

---

## HPC vs Docker

**Production (recommended):** [`submit.sh`](https://github.com/phindagijimana/dkt_connectome/blob/main/dwi_pipeline/submit.sh) + Apptainer on Slurm, or `./run` after `bash install.sh`.

**Docker / cloud:** orchestrator image + cached step `.sif` files (`DKT_AUTO_INSTALL=1`, `docker-compose.yml`). See [Installation § Docker Compose](installation.md) and [BIDS App specification](bids_app.md).

---

## Build notes

- **Step 1.1 neuroLIT:** [containers/lit/README.md](https://github.com/phindagijimana/dkt_connectome/blob/main/dwi_pipeline/containers/lit/README.md)
- **Step 1.1 VBT:** [containers/vbt/README.md](https://github.com/phindagijimana/dkt_connectome/blob/main/dwi_pipeline/containers/vbt/README.md) — stages FSL from `qsiprep.sif`
- **Step 3.1 lesion-aware ACT:** [containers/lesion_act/README.md](https://github.com/phindagijimana/dkt_connectome/blob/main/dwi_pipeline/containers/lesion_act/README.md) — stages ANTs + MRtrix from `qsirecon.sif`; HSVS ACPC and Deep Atropos native paths
- **Step 3.2 Deep Atropos:** [containers/deep_atropos/README.md](https://github.com/phindagijimana/dkt_connectome/blob/main/dwi_pipeline/containers/deep_atropos/README.md) · [deep_atropos_seg/README.md](https://github.com/phindagijimana/dkt_connectome/blob/main/dwi_pipeline/containers/deep_atropos_seg/README.md)
- **Step 4:** [containers/connectome/README.md](https://github.com/phindagijimana/dkt_connectome/blob/main/dwi_pipeline/containers/connectome/README.md)
- **Publish orchestrator:** [Release checklist on GitHub](https://github.com/phindagijimana/dkt_connectome/blob/main/dwi_pipeline/docs/maintainer/publishing.md)
