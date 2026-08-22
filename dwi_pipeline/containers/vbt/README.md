# `dkt_vbt.sif` — Virtual Brain Transplant (Step 1.5)

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

## Citation

Bey P, et al. *Human Brain Mapping* 2024;45(9):e26701.
https://doi.org/10.1002/hbm.26701
