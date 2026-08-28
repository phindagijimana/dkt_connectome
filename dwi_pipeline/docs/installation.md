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
chmod +x run install
```

Documentation: [Home](home.md) · Tutorial: [tutorial.md](tutorial.md) · **Hosted:** [Read the Docs](https://dkt-connectome.readthedocs.io/en/latest/).

---

## Auto-install (recommended)

Pull all pinned step `.sif` images and write `workflow/config/config.local.yaml`:

```bash
cd dwi_pipeline
bash install.sh
# or: bash scripts/install.sh --missing-only
```

| Variable / flag | Default | Purpose |
|-----------------|---------|---------|
| `DKT_CONTAINER_CACHE` | `~/.cache/dkt-connectome/containers` | Where `.sif` files are stored |
| `--mode qsiprep` | all steps | Pull only what a mode needs |
| `--missing-only` | off | Skip images already in cache |

Verify before your first run:

```bash
export FS_LICENSE=/path/to/license.txt
./run doctor
```

**Docker orchestrator** with first-run pull:

```bash
docker run --rm \
  -v /data/bids:/data/bids:ro -v /data/out:/out \
  -v ~/dkt_containers:/opt/dkt-connectome/containers \
  -v ~/license.txt:/license.txt:ro \
  -e FS_LICENSE=/license.txt \
  -e DKT_AUTO_INSTALL=1 \
  phindagijimana321/dkt-connectome:0.2.0 \
  /data/bids /out participant --participant-label 1 --fastsurfer --syn --dry-run
```

HPC: `sbatch containers/pull_freesurfer_sif.sbatch` for FreeSurfer only on a compute node; full install on a login node with network.

**VBT, lesion-aware ACT, and Deep Atropos images** are built locally when GHCR pull fails (`install.sh` falls back to `containers/vbt/build_vbt.sh`, `containers/lesion_act/build_lesion_act.sh`, `containers/deep_atropos/build_deep_atropos.sh`, and `containers/deep_atropos_seg/build_deep_atropos_seg.sh`, staging tools from your existing `qsiprep.sif` / `qsirecon.sif`). Use `bash install.sh --mode act` for all Step 3.5 containers. See [Containers](containers.md).

**Docker Compose** (orchestrator + persistent cache volume):

```bash
cd dwi_pipeline
mkdir -p data/bids data/out
# copy or symlink license.txt beside docker-compose.yml
docker compose build
docker compose run --rm dkt-connectome \
  /data/bids /data/out participant \
  --participant-label 1 --session-filter ses-1 --fastsurfer --syn --dry-run
```

Publish orchestrator to Docker Hub (maintainers):

```bash
bash scripts/publish_docker.sh          # local build + smoke
bash scripts/publish_docker.sh --push   # requires docker login
# or: GitHub Actions → "Docker publish" workflow (workflow_dispatch)
```

Verify registry pins without pulling:

```bash
python3 scripts/container_install.py verify
./run doctor --with-dry-run   # adds Snakemake dry-run (slower)
```

---

## FreeSurfer license (you must obtain this)

The pipeline **does not include or distribute** a FreeSurfer license. **Each user and site** must register independently (free for research) and point the pipeline at their own `license.txt` file.

### 1. Register

1. Open [FreeSurfer registration](https://surfer.nmr.mgh.harvard.edu/registration.html).
2. Complete the form for your institution and use case.
3. Download the email attachment **`license.txt`** (plain text, a few lines).

Allow up to 48 hours for approval on first registration.

### 2. Store the file safely

```bash
# Example — keep outside the git clone
mkdir -p ~/.freesurfer
mv ~/Downloads/license.txt ~/.freesurfer/license.txt
chmod 600 ~/.freesurfer/license.txt
```

```{warning} Do not commit the license
Never add `license.txt` to git or upload it to GitHub. The repository and CI **do not** provide a shared license — that is intentional.
```

### 3. Export before every run (HPC / Apptainer)

```bash
export FS_LICENSE="$HOME/.freesurfer/license.txt"
./run doctor    # confirms license path and containers
```

Add to your Slurm prologue or `~/.bashrc` on shared systems so batch jobs inherit it:

```bash
# in submit.sh environment or ~/.bashrc
export FS_LICENSE=/path/to/your/license.txt
```

QSIPrep and FreeSurfer steps bind-mount this file into containers at runtime.

### 4. Docker / cloud

Mount **your** file read-only and set the same variable:

```bash
docker run --rm \
  -v /path/to/your/license.txt:/opt/freesurfer/license.txt:ro \
  -e FS_LICENSE=/opt/freesurfer/license.txt \
  ... \
  phindagijimana321/dkt-connectome:0.2.0 \
  /data/bids /out participant --participant-label 01
```

See also [Cloud deployment](cloud_deployment.md) and [BIDS App specification](bids_app.md).

### 5. When is it required?

| Step | License needed? |
|------|-----------------|
| `./run doctor` (full check) | Yes |
| QSIPrep (Step 1) | Yes (FreeSurfer tools inside QSIPrep) |
| Recon / FastSurfer (Step 2) | Yes |
| `--dry-run` in CI-style stubs | No (see [Contributing](contributing.md)) |

If `./run` fails with `Missing FreeSurfer license`, set `FS_LICENSE` to an existing file — see [Troubleshooting](troubleshooting.md).

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

> **HPC (recommended):** use [`submit.sh`](https://github.com/phindagijimana/dkt_connectome/blob/main/dwi_pipeline/submit.sh) with Apptainer `.sif` images. For Docker/cloud, pull the published orchestrator **`phindagijimana321/dkt-connectome:0.2.0`** — see [Containers](containers.md) and [Installation § Docker Compose](installation.md).

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
./run doctor
./run --help

# Dry-run one subject (after install.sh + FS_LICENSE)
export FS_LICENSE=/path/to/license.txt
./run /path/to/BIDS /path/to/out participant \
  --participant-label 009 --dry-run
```

Next: [Tutorial](tutorial.md) · [Usage](usage.md)
