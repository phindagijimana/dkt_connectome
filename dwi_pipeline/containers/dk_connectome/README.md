# dk_connectome container

Shareable **~150 MB** Apptainer image for Step 4 (Desikan–Killiany connectome).

## Contents (legacy-staged from pipeline SIFs)

| Component | Source | Staged size |
|-----------|--------|-------------|
| `mri_label2vol`, `mri_convert`, LUT | `freesurfer_7.4.1.sif` | ~8 MB |
| ANTs 2.4.3 | `qsirecon.sif` `/opt/ants` | ~381 MB |
| MRtrix 3.0.4 | `qsirecon.sif` `/opt/mrtrix3-latest` | ~298 MB |

Final **`dk_connectome.sif`**: **~146 MB** (squashfs).

Validated: `subject.sh dk TBI011204` with baked entrypoint → **byte-identical** `dk_connectome.csv` vs job 48036.

## Build

```bash
cd /mnt/nfs/home/urmc-sh.rochester.edu/pndagiji/Documents/TrackTBI-Sub

bash dwi_pipeline/containers/dk_connectome/build_dk_connectome.sh
# -> .../others/containers/dk_connectome.sif

SKIP_STAGE=1 bash dwi_pipeline/containers/dk_connectome/build_dk_connectome.sh  # rebuild SIF only
```

Requires: `freesurfer_7.4.1.sif`, `qsirecon.sif`, `apptainer`, network for Ubuntu `apt` in `%post`.

## Publish to Docker Hub

Lab shareable as OCI on Docker Hub (`phindagijimana321/dk_connectome`):

```bash
# Build SIF first, then push with a Docker Hub access token
export DOCKERHUB_USER=phindagijimana321
export DOCKERHUB_TOKEN=...   # hub.docker.com → Account Settings → Security
bash dwi_pipeline/containers/dk_connectome/publish_dockerhub.sh
```

Pull elsewhere: `docker pull phindagijimana321/dk_connectome:latest`

FreeSurfer binaries are in the image — use a **private** repo or restrict access; recipients still need a valid FS license at runtime.

## Share across the lab

```bash
export CONTAINER_DK_CONNECTOME=/mnt/nfs/.../others/containers/dk_connectome.sif
export FS_LICENSE=/path/to/license.txt
bash dwi_pipeline/subject.sh dk SUBJECT
```

Recipients need a valid **FreeSurfer license** (bind-mounted at runtime). Do not publish the SIF publicly without respecting FreeSurfer terms.

## Pipeline variables

| Variable | Default | Notes |
|----------|---------|-------|
| `CONTAINER_DK_CONNECTOME` | `.../others/containers/dk_connectome.sif` | Shared image |
| `DK_CONNECTOME_BIND_ENTRYPOINT` | `0` | Set `1` to override entrypoint from repo |
| `DK_LEGACY_DUAL_CONTAINER` | `0` | Set `1` for old freesurfer + qsirecon runtime path |
