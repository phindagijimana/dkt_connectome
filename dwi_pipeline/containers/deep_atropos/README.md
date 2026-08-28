# `dkt_deep_atropos.sif` — Deep Atropos seg → native-T1 5TT (Step 3.5a)

Converts integer Deep Atropos segmentation to MRtrix ACT `base_5tt_native.mif` on the
**native BIDS T1w grid**. Optional when `act.five_tt_source=deep-atropos-native`.

**Segmentation source:** `dkt_deep_atropos_seg.sif` (`auto`/`generate`), external cohort files
(`import`), or `derivatives/deep-atropos/` — see [deep_atropos_seg README](../deep_atropos_seg/README.md).

Uses `scripts/convert_deep_atropos_to_5tt.py` (Python mapper; MRtrix 3.0.4 lacks
`5ttgen deep_atropos`). Skips scipy resample when seg and T1w share grid/affine.

## Build

```bash
cd dwi_pipeline/containers/deep_atropos
bash build_deep_atropos.sh
CONTAINER_QSIRECON=/path/to/qsirecon.sif OUT_SIF=/path/to/dkt_deep_atropos.sif bash build_deep_atropos.sh
```

Configure via `containers.deep_atropos` or `CONTAINER_DEEP_ATROPOS`.

## Manual run

```bash
apptainer run dkt_deep_atropos.sif \
  --t1w /bids/sub-XXX/ses-YYY/anat/sub-XXX_ses-YYY_T1w.nii.gz \
  --segmentation /path/to/desc-deepatropos_seg.nii.gz \
  --outdir /out/deep_atropos/sub-XXX
```

Outputs: `base_5tt_native.mif`, `deep_atropos_5tt.json`.

## Snakemake

Rule `deep_atropos_5tt` in `workflow/rules/deep_atropos_5tt.smk` runs after
`deep_atropos_seg` when `--act-5tt-source deep-atropos-native`.

See [deep_atropos_5tt_plan.md](../../docs/maintainer/deep_atropos_5tt_plan.md).
