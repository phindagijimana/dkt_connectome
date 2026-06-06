# containers/

The dk_connectome workflow is itself an **orchestration of four containers** —
one per stage. Three of those are existing, well-maintained third-party images;
the fourth is built from the recipes in this directory.

| stage | image | source | size | recipe lives where |
|---|---|---|---:|---|
| 1. qsiprep | `docker://pennlinc/qsiprep:1.0.0` | upstream | ~3.5 GB | [PennLINC/qsiprep](https://github.com/PennLINC/qsiprep) |
| 2. recon | `docker://freesurfer/freesurfer:7.4.1` *or* `docker://deepmi/fastsurfer:latest` | upstream | ~6 GB / ~5 GB | upstream |
| 3. qsirecon | `docker://pennlinc/qsirecon:1.2.1` | upstream | ~5 GB | [PennLINC/qsirecon](https://github.com/PennLINC/qsirecon) |
| 4. **dk_connectome** | `docker://ghcr.io/phindagijimana/dk-connectome:0.1.0` | **this repo** | ~900 MB | [Dockerfile.dk_connectome](Dockerfile.dk_connectome) / [Apptainer.dk_connectome.def](Apptainer.dk_connectome.def) |

The DK image is intentionally **minimal** — MRtrix3 + ANTs + the FreeSurfer
color LUT, nothing more. Previously the DK rule rode inside `qsirecon.sif` only
because it happened to bundle those tools; pulling 5 GB of QSIRecon just to run
`antsApplyTransforms` + `tck2connectome` was excessive.

---

## Pull the published image

```bash
# Apptainer / Singularity (typical HPC path)
apptainer pull dk-connectome.sif \
    docker://ghcr.io/phindagijimana/dk-connectome:0.1.0

# Docker
docker pull ghcr.io/phindagijimana/dk-connectome:0.1.0
```

The CLI does this for you in `./connectome install`.

## Build locally

If you cannot reach `ghcr.io` (e.g. air-gapped cluster) or you want to pin to a
custom commit, build from the recipes:

```bash
# --- Docker (multi-stage) ---
docker build \
    -t ghcr.io/phindagijimana/dk-connectome:0.1.0 \
    -f containers/Dockerfile.dk_connectome \
    containers/

# Convert to a .sif for HPC use
apptainer build dk-connectome.sif \
    docker-daemon://ghcr.io/phindagijimana/dk-connectome:0.1.0

# --- Apptainer-native (no Docker daemon) ---
apptainer build dk-connectome.sif containers/Apptainer.dk_connectome.def
```

## What's inside

* **MRtrix3 3.0.4** — `mrconvert` (reads MGZ natively, so no FreeSurfer
  binaries needed), `labelconvert`, `tck2connectome`, `tckinfo`, `mrinfo`
* **ANTs 2.5.0** — `antsApplyTransforms` with `-n GenericLabel` for ITK-native,
  label-aware resampling of the parcellation onto the DWI grid
* **`FreeSurferColorLUT.txt`** — baked in from FreeSurfer's open-source GitHub
  source distribution (pinned to a specific upstream ref). The LUT is a data
  table, not the FreeSurfer toolchain; **no FreeSurfer license is required to
  use this image**

The image stays under ~1 GB. See the in-file comments in
[`Dockerfile.dk_connectome`](Dockerfile.dk_connectome) and
[`Apptainer.dk_connectome.def`](Apptainer.dk_connectome.def) for full provenance.

## CI

`.github/workflows/build-dk-connectome.yml` builds and publishes the image to
`ghcr.io/phindagijimana/dk-connectome` on every tagged release
(`refs/tags/v*`).
