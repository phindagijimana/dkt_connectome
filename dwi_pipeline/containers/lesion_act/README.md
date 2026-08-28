# `dkt_lesion_act.sif` — Post-QSIRecon lesion-aware ACT (Step 3.5)

Rebuilds matched iFOD2 + SIFT2 after `5ttedit -path` inserts the lesion into the
MRtrix pathology channel. ANTs and MRtrix are staged from the pipeline's
QSIRecon image (same toolchain as `dkt_connectome.sif` without FreeSurfer).

## Two spatial workflows (`--five-tt-source`)

### `hsvs` (default) — Jim's ACPC-first fix

1. Load QSIRecon HSVS 5TT (ACPC).
2. Extract channel 0 as reference grid (`five_tt_ref` ≡ Jim's `vol0000` from `fslsplit`).
3. Warp original BIDS lesion → ACPC 5TT grid:
   - primary: QSIPrep `from-T1wNative_to-T1wACPC` (`antsApplyTransforms`, GenericLabel);
   - fallback: empirical affine BIDS T1w → `desc-preproc_T1w`.
4. `5ttedit -path` on ACPC grid; pathology QA.
5. Resample edited 5TT → `dwiref`; clip + renormalize (sum to 1 along axis 4).
6. `tckgen -act` + `tcksift2`.

### `deep-atropos-native` — Daniel's native-T1 branch

Requires `base_5tt_native.mif` from `dkt_deep_atropos.sif` (Step 3.5a).

1. Resample prepared lesion → native 5TT grid (same as BIDS T1w).
2. `5ttedit -path` on native grid (no ACPC warp for edit).
3. Resample edited 5TT → `dwiref` via `desc-preproc_T1w`.
4. Clip + renormalize; `tckgen -act` + `tcksift2`.

Both paths use the **original BIDS lesion ROI**, not the inpainted region.

## Build

```bash
bash build_lesion_act.sh
CONTAINER_QSIRECON=/path/to/qsirecon.sif OUT_SIF=/path/to/dkt_lesion_act.sif bash build_lesion_act.sh
```

## Runtime (HSVS example)

```bash
apptainer run dkt_lesion_act.sif \
  --five-tt-source hsvs \
  --five-tt sub-01_space-ACPC_seg-hsvs_probseg.nii.gz \
  --wm-fod sub-01_model-ss3t_param-fod_label-WM_dwimap.mif.gz \
  --dwiref sub-01_space-T1w_dwiref.nii.gz \
  --lesion-mask-t1w lesion_mask_t1w.nii.gz \
  --bids-t1w sub-01_T1w.nii.gz \
  --preproc-t1w sub-01_desc-preproc_T1w.nii.gz \
  --native-to-acpc sub-01_from-T1wNative_to-T1wACPC_mode-image_xfm.mat \
  --outdir /out/lesion_aware_act/sub-01 \
  --streamlines 10000000
```

Deep Atropos native:

```bash
apptainer run dkt_lesion_act.sif \
  --five-tt-source deep-atropos-native \
  --five-tt /out/deep_atropos/sub-01/base_5tt_native.mif \
  ...  # same WM FOD, dwiref, lesion, T1w inputs
```

Configure via `containers.lesion_act` or `CONTAINER_LESION_ACT`.

**After changing `run_lesion_aware_act.sh`:** rebuild the SIF and re-run all `*-lesion`
experiment arms.

## Publish (Docker Hub)

```bash
export DOCKERHUB_USER=phindagijimana321
export DOCKERHUB_TOKEN=...
SIF=/path/to/others/containers/dkt_lesion_act.sif bash publish_dockerhub.sh
```

Primary pin: `ghcr.io/phindagijimana/dkt-lesion-act:0.1.0`.

## See also

- [Step 3.5 methods](../../docs/methods/step3_5_lesion_act.md)
- [Deep Atropos branch](../../docs/maintainer/deep_atropos_5tt_plan.md)

## Citation

Bey P, et al. *Human Brain Mapping* 2024; Smith et al. ACT 2012.
