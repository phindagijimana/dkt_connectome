# `dkt_lesion_act.sif` — Post-QSIRecon lesion-aware ACT (Step 3.5)

Rebuilds matched iFOD2 + SIFT2 after `5ttedit -path` inserts the lesion into the
MRtrix pathology channel. ANTs and MRtrix are staged from the pipeline's
QSIRecon image (same toolchain as `dkt_connectome.sif` without FreeSurfer).

## Build

```bash
bash build_lesion_act.sh
CONTAINER_QSIRECON=/path/to/qsirecon.sif OUT_SIF=/path/to/dkt_lesion_act.sif bash build_lesion_act.sh
```

## Runtime

```bash
apptainer run dkt_lesion_act.sif \
  --five-tt sub-01_space-ACPC_seg-hsvs_probseg.nii.gz \
  --wm-fod sub-01_model-ss3t_param-fod_label-WM_dwimap.mif.gz \
  --dwiref sub-01_space-T1w_dwiref.nii.gz \
  --lesion-mask-t1w lesion_mask_t1w.nii.gz \
  --orig-to-t1w sub-01_from-orig_to-T1w_mode-image_xfm.mat \
  --outdir /out/lesion_aware_act/sub-01 \
  --streamlines 10000000
```

Configure via `containers.lesion_act` or `CONTAINER_LESION_ACT`.

## Citation

Bey P, et al. *Human Brain Mapping* 2024; Smith et al. ACT 2012.
