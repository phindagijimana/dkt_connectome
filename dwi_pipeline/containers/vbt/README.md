# `dkt_vbt.sif` — Virtual Brain Transplant (Step 1.1)

LeAPP-compatible VBT for TBI lesion mitigation (`--anat-mitigation vbt`). Implements
`dwi_pipeline/scripts/run_vbt.py` (mirror, midline alignment, smoothed contralesional
blending) with FSL tools staged from the pipeline's QSIPrep image.

## Build

```bash
bash build_vbt.sh
CONTAINER_QSIPREP=/path/to/qsiprep.sif OUT_SIF=/path/to/dkt_vbt.sif bash build_vbt.sh
```

Requires a local `qsiprep.sif` (default: `/path/to/others/containers/qsiprep.sif`).

## Runtime

Production Snakemake (`inpaint.smk`) runs VBT via **qsiprep.sif** FSL + bind-mounted
`run_vbt.py` (same as `subject.sh`). The lean `dkt_vbt.sif` remains for standalone
smoke tests; its staged FSL `midtrans` requires Ubuntu 18.04 (see Dockerfile).

```bash
apptainer run dkt_vbt.sif \
  --t1w sub-01_T1w.nii.gz \
  --mask lesion_mask_prepared.nii.gz \
  --output inpainting_result.nii.gz \
  --smoothing-factor 2.0 \
  --work-dir /tmp/vbt_work
```

Wire into the workflow via `containers.vbt` in `config.local.yaml` or
`CONTAINER_VBT=/path/to/dkt_vbt.sif`.

## Publish (Docker Hub)

After building the SIF:

```bash
export DOCKERHUB_USER=phindagijimana321
export DOCKERHUB_TOKEN=...   # access token from hub.docker.com/settings/security
SIF=/path/to/others/containers/dkt_vbt.sif bash publish_dockerhub.sh
```

Pull elsewhere: `docker pull phindagijimana321/dkt-vbt:0.1.0` or
`apptainer pull docker://phindagijimana321/dkt-vbt:0.1.0`.

Primary pin: `ghcr.io/phindagijimana/dkt-vbt:0.1.0` (GitHub Container Registry).
Docker Hub mirror: `phindagijimana321/dkt-vbt:0.1.0`.

## Citation

Bey P, et al. *Human Brain Mapping* 2024;45(9):e26701.
https://doi.org/10.1002/hbm.26701
