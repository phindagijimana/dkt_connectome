# connectome container

Shareable **~150 MB** Apptainer image for Step 4 (structural connectome).

The image is parcellation-neutral: it warps whichever FreeSurfer segmentation it
is given onto the DWI grid and applies whichever `labelconvert` lookup table it
is given, so the same image produces the 78-node Desikan–Killiany–Tourville
matrices (the pipeline default) or the 84-node Desikan–Killiany ones. From one
tractogram it writes Count, SIFT2, MeanLength, MeanFA, and MeanMD connectomes;
it also derives voxelwise FA and MD maps from the QSIPrep DWI.

## Contents (legacy-staged from pipeline SIFs)

| Component | Source | Staged size |
|-----------|--------|-------------|
| `mri_label2vol`, `mri_convert`, LUT | `freesurfer_7.4.1.sif` | ~8 MB |
| ANTs 2.4.3 | `qsirecon.sif` `/opt/ants` | ~381 MB |
| MRtrix 3.0.4 | `qsirecon.sif` `/opt/mrtrix3-latest` | ~298 MB |

Final **`dkt_connectome.sif`**: **~146 MB** (squashfs).

Because the ANTs/MRtrix trees are copied in rather than installed, no package
manager records their dependencies, so the base image declares the runtime
libraries by hand (`libtiff5`, `libpng16-16`, `libfftw3-double3`, `zlib1g`,
`libgomp1`). The build ends with an `ldd` sweep over every staged binary and
fails if any library is unresolved — a missing one does not break the build,
only every later run, with exit 127 and no output.

Validated: `workflow/run_subject.sh connectome SUBJ01` with the baked entrypoint reproduces a
**byte-identical** matrix against a run using the bind-mounted entrypoint.

## Build

```bash
cd /path/to/repo

bash dwi_pipeline/containers/connectome/build_connectome.sh
# -> $OUT_SIF (default: ../containers/dkt_connectome.sif)

SKIP_STAGE=1 bash dwi_pipeline/containers/connectome/build_connectome.sh  # rebuild SIF only
```

Requires: `freesurfer_7.4.1.sif`, `qsirecon.sif`, `apptainer`, network for Ubuntu `apt` in `%post`.

## Publish to Docker Hub

Lab shareable as OCI on Docker Hub (`phindagijimana321/dkt_connectome`):

```bash
# Build SIF first, then push with a Docker Hub access token
export DOCKERHUB_USER=phindagijimana321
export DOCKERHUB_TOKEN=...   # hub.docker.com → Account Settings → Security
bash dwi_pipeline/containers/connectome/publish_dockerhub.sh
```

Pull elsewhere: `docker pull phindagijimana321/dkt_connectome:latest`

FreeSurfer binaries are in the image — use a **private** repo or restrict access; recipients still need a valid FS license at runtime.

## Share across the lab

```bash
export CONTAINER_CONNECTOME=/path/to/containers/dkt_connectome.sif
export FS_LICENSE=/path/to/license.txt
bash dwi_pipeline/workflow/run_subject.sh connectome SUBJECT
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
| `--preproc-dwi`, `--bval`, `--bvec`, `--brain-mask` | required | QSIPrep products used for tensor fitting and FA/MD |
| `--sift2-weights` | required by the workflow | Writes the SIFT2 matrix |
| `--primary-measure` | `count` | Selects the `connectome.csv` compatibility alias (`count` or `sift2`) |

## Pipeline variables

| Variable | Default | Notes |
|----------|---------|-------|
| `CONTAINER_CONNECTOME` | `.../others/containers/dkt_connectome.sif` | Shared image |
| `CONNECTOME_BIND_ENTRYPOINT` | `1` | Uses the versioned repository entrypoint; set `0` only after rebuilding the SIF with matching code |

Legacy dual-container Step 4 (`CONNECTOME_LEGACY_DUAL_CONTAINER=1`): see [workflow/LEGACY.md](../../workflow/LEGACY.md).
