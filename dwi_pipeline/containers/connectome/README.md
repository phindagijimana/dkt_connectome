# connectome container

Shareable **~150 MB** Apptainer image for Step 4 (structural connectome).

The image is parcellation-neutral: it warps whichever FreeSurfer segmentation it
is given onto the DWI grid and applies whichever `labelconvert` lookup table it
is given, so the same image produces the 78-node Desikan–Killiany–Tourville
matrix (the pipeline default) or the 84-node Desikan–Killiany one.

## Contents (legacy-staged from pipeline SIFs)

| Component | Source | Staged size |
|-----------|--------|-------------|
| `mri_label2vol`, `mri_convert`, LUT | `freesurfer_7.4.1.sif` | ~8 MB |
| ANTs 2.4.3 | `qsirecon.sif` `/opt/ants` | ~381 MB |
| MRtrix 3.0.4 | `qsirecon.sif` `/opt/mrtrix3-latest` | ~298 MB |

Final **`connectome.sif`**: **~146 MB** (squashfs).

Because the ANTs/MRtrix trees are copied in rather than installed, no package
manager records their dependencies, so the base image declares the runtime
libraries by hand (`libtiff5`, `libpng16-16`, `libfftw3-double3`, `zlib1g`,
`libgomp1`). The build ends with an `ldd` sweep over every staged binary and
fails if any library is unresolved — a missing one does not break the build,
only every later run, with exit 127 and no output.

Validated: `subject.sh connectome TBI011204` with baked entrypoint →
**byte-identical** matrix vs job 48036.

## Build

```bash
cd /mnt/nfs/home/urmc-sh.rochester.edu/pndagiji/Documents/TrackTBI-Sub

bash dwi_pipeline/containers/connectome/build_connectome.sh
# -> .../others/containers/connectome.sif

SKIP_STAGE=1 bash dwi_pipeline/containers/connectome/build_connectome.sh  # rebuild SIF only
```

Requires: `freesurfer_7.4.1.sif`, `qsirecon.sif`, `apptainer`, network for Ubuntu `apt` in `%post`.

## Publish to Docker Hub

Lab shareable as OCI on Docker Hub (`phindagijimana321/connectome`):

```bash
# Build SIF first, then push with a Docker Hub access token
export DOCKERHUB_USER=phindagijimana321
export DOCKERHUB_TOKEN=...   # hub.docker.com → Account Settings → Security
bash dwi_pipeline/containers/connectome/publish_dockerhub.sh
```

Pull elsewhere: `docker pull phindagijimana321/connectome:latest`

FreeSurfer binaries are in the image — use a **private** repo or restrict access; recipients still need a valid FS license at runtime.

## Share across the lab

```bash
export CONTAINER_CONNECTOME=/mnt/nfs/.../others/containers/connectome.sif
export FS_LICENSE=/path/to/license.txt
bash dwi_pipeline/subject.sh connectome SUBJECT
```

Recipients need a valid **FreeSurfer license** (bind-mounted at runtime). Do not publish the SIF publicly without respecting FreeSurfer terms.

## Entrypoint options

`run_connectome.sh` takes the segmentation and the lookup table separately,
because `labelconvert` matches regions by name: applying the DKT table to a DK
image silently discards bankssts and the frontal/temporal poles instead of
reassigning that territory to neighbouring gyri.

| Option | Default | Notes |
|--------|---------|-------|
| `--segmentation` | `<subject>/mri/aparc+aseg.mgz` | Pass `aparc.DKTatlas+aseg.mgz` for DKT from a recon-all tree |
| `--mrtrix-lut` | `fs_default.txt` (DK, 84 nodes) | `fs_dkt.txt` for DKT (78 nodes) |

## Pipeline variables

| Variable | Default | Notes |
|----------|---------|-------|
| `CONTAINER_CONNECTOME` | `.../others/containers/connectome.sif` | Shared image |
| `CONNECTOME_BIND_ENTRYPOINT` | `0` | Set `1` to override entrypoint from repo |
| `CONNECTOME_LEGACY_DUAL_CONTAINER` | `0` | Set `1` for old freesurfer + qsirecon runtime path |
