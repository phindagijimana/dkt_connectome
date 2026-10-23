# Installation

**New users:** [Tutorial](tutorial.md) after this page. Hosted: [Read the Docs](https://dkt-connectome.readthedocs.io/en/latest/). Same first commands: [GitHub README](https://github.com/phindagijimana/dkt_connectome/blob/main/README.md#quick-start).

## Requirements

| Component | Notes |
|-----------|-------|
| Linux | Workstation or HPC |
| [Apptainer](https://apptainer.org/) | On `PATH` |
| Python 3.11+ and [Snakemake](https://snakemake.readthedocs.io/) ≥ 8 | Orchestration (`environment.yml`). Snakemake 8+ does not install on Python 3.9. |
| FreeSurfer license | [Free registration](https://surfer.nmr.mgh.harvard.edu/registration.html) — you obtain this |
| Git | Clone [dkt_connectome](https://github.com/phindagijimana/dkt_connectome) |

Optional: Slurm for `submit.sh`. Cloud: [One-pull](#one-pull-docker--cloud) instead of a local Apptainer install.

---

(auto-install-recommended)=
## Clone and install

```bash
git clone https://github.com/phindagijimana/dkt_connectome.git
cd dkt_connectome/dwi_pipeline
chmod +x run install dkt
./dkt init --license /path/to/your/license.txt --bids /path/to/BIDS --out /path/to/OUT
# init prints the three exports + next commands; then:
./dkt install
./dkt check
./dkt run /path/to/BIDS /path/to/OUT participant --participant-label 001 --profile ideas
./dkt status --results-root /path/to/OUT
```

Manual equivalent (if you prefer env vars):

```bash
export FS_LICENSE=/path/to/your/license.txt
export DKT_CONTAINER_CACHE=$HOME/.cache/dkt-connectome/containers
export APPTAINER_TMPDIR=$HOME/.cache/dkt-connectome/apptainer_tmp
export PROOT_TMP_DIR=$APPTAINER_TMPDIR
mkdir -p "$DKT_CONTAINER_CACHE" "$APPTAINER_TMPDIR"
./dkt install
./dkt check --strict
```

`./dkt install` pulls pinned step `.sif` images and writes `workflow/config/config.local.yaml`. `--strict` compares SHA-256 to [`release_manifest.json`](../release_manifest.json).

`./dkt check` is **path-agnostic**: each step image is OK if it exists in any known location (`CONTAINER_*` env, `config.local.yaml`, or the install cache — pin-named or short names like `qsirecon.sif`). Use `--cache-only` to require pin-named files in the cache directory only.

Install all images, or one container at a time (useful after a failed pull):

```bash
./dkt install                 # all containers
./dkt install all             # same
./dkt install qsirecon        # only qsirecon
./dkt install qsirecon --force
./dkt install --dry-run qsirecon   # print plan; no download
```

| Variable / flag | Default | Purpose |
|-----------------|---------|---------|
| `DKT_CONTAINER_CACHE` | `~/.cache/dkt-connectome/containers` | `.sif` files |
| `APPTAINER_TMPDIR` / `PROOT_TMP_DIR` | `<cache>/../apptainer_tmp` | Pull temp — **not `/tmp`** if that mount is `noexec` |
| positional `KEY` / `all` | all | Pull one container or everything |
| `--mode qsiprep` | — | Pull the image *set* for a pipeline mode (may be several keys) |
| `--only KEY,KEY` | — | Same as positional keys (flag form) |
| `--missing-only` | off | Skip images already in cache |
| `--dry-run` | off | List keys that would be pulled; no download |

Many clusters mount **`/tmp` with `noexec`**. OCI→SIF uses proot, which ignores `APPTAINER_TMPDIR` unless **`PROOT_TMP_DIR`** is set (`install.sh` sets it). First QSIPrep / QSIRecon / FreeSurfer conversion can take 30–90 minutes — prefer local disk, not NFS. Do not use rootless **podman** for the orchestrator pull (`lchown /etc/gshadow`).

Step images: [Containers](containers.md). If GHCR miss for VBT / lesion-ACT / Deep Atropos, `install.sh --mode act` builds them locally.

Next: [Tutorial](tutorial.md).

---

(freesurfer-license-you-must-obtain-this)=
## FreeSurfer license (you must obtain this)

The pipeline **does not ship a license**. Each user registers, downloads `license.txt`, and points `FS_LICENSE` at that file.

1. Register at [FreeSurfer](https://surfer.nmr.mgh.harvard.edu/registration.html) (up to 48 hours).
2. Store the file **outside** the clone (`~/.freesurfer/license.txt`, mode `600`). Never commit it.
3. `export FS_LICENSE=$HOME/.freesurfer/license.txt` in your shell, `~/.bashrc`, or Slurm prologue.

Required for `./run doctor`, QSIPrep, and recon. CI-style `--dry-run` with stubs does not need it. If you see `Missing FreeSurfer license`, see [Troubleshooting](troubleshooting.md). Docker: mount the file and set `FS_LICENSE` as in [One-pull](#one-pull-docker--cloud).

---

(one-pull-docker--cloud)=
(docker-optional)=
## One-pull (Docker / cloud)

The published image is an **orchestrator**, not QSIPrep. `DKT_AUTO_INSTALL=1` pulls the same pinned `.sif` files as `./dkt install` into a cache volume.

```bash
docker pull ghcr.io/phindagijimana/dkt-connectome:0.3.1
# or: docker pull phindagijimana321/dkt-connectome:0.3.1

docker run --rm \
  -v /data/bids:/data/bids:ro -v /data/out:/out \
  -v ~/dkt_containers:/opt/dkt-connectome/containers \
  -v ~/license.txt:/license.txt:ro \
  -e FS_LICENSE=/license.txt \
  -e DKT_AUTO_INSTALL=1 \
  ghcr.io/phindagijimana/dkt-connectome:0.3.1 \
  /data/bids /out participant --participant-label 1 --fastsurfer --syn --dry-run
```

`docker run … --version` must print `0.3.1`. Keep the cache volume; a new container without it starts empty. Compose, Apptainer-of-orchestrator, and maintainer publish: [Advanced](#advanced).

---

## Advanced

**BIDS validator (optional):** `bash scripts/run_bids_validator.sh /path/to/BIDS` or `./run … --bids-validation`.

**Docker Compose** (from `dwi_pipeline/`, with `license.txt` beside `docker-compose.yml`):

```bash
docker compose build
docker compose run --rm dkt-connectome \
  /data/bids /data/out participant \
  --participant-label 1 --session-filter ses-1 --fastsurfer --syn --dry-run
```

**Apptainer of the published orchestrator** (after `PROOT_TMP_DIR` is set):

```bash
SIF=$DKT_CONTAINER_CACHE/dkt_connectome_orchestrator_0.3.1.sif
apptainer pull "$SIF" docker://phindagijimana321/dkt-connectome:0.3.1
apptainer run --cleanenv --no-home "$SIF" --version
```

**Build Step 4 locally** (only if you are not using the GHCR pin): `bash dwi_pipeline/containers/connectome/build_connectome.sh` — [containers/connectome/README.md](https://github.com/phindagijimana/dkt_connectome/blob/main/dwi_pipeline/containers/connectome/README.md).

**Host Python** for orchestration / disconnectome: `pip install numpy nibabel scipy` plus Snakemake ≥ 8.

**Site config:** `workflow/config/config.yaml` (defaults) and `workflow/config/config.local.yaml` (local). Defaults: `connectome.weighting: count`, `connectome.parcellation: dkt`. Full keys: [Configuration](configuration.md).

**Maintainer publish:** `bash scripts/publish_docker.sh --push` or GitHub Actions “Docker publish”.

**HPC:** [`submit.sh`](https://github.com/phindagijimana/dkt_connectome/blob/main/dwi_pipeline/submit.sh). FreeSurfer-only pull: `sbatch containers/pull_freesurfer_sif.sbatch`.
