# `dkt_deep_atropos_seg.sif` — generate Deep Atropos segmentation (Step 3.2 (segmentation))

Runs **ANTsPyNet `deep_atropos`** on native BIDS T1w when no external segmentation
is supplied. Output integer labels (0–6) feed `dkt_deep_atropos.sif` → 5TT →
`dkt_lesion_act.sif`.

## When it runs

| `act.deep_atropos.segmentation_mode` | Behavior |
|--------------------------------------|----------|
| `auto` (default) | Use `--deep-atropos-seg` / BIDS derivative if present; else run this container |
| `import` | External seg required; fail if missing |
| `generate` | Always run ANTsPyNet (ignore external files) |

Discovery: config/`DEEP_ATROPOS_SEG` → `derivatives/deep-atropos/` → pipeline output
`<results>/deep_atropos_seg/sub-<ID>/`.

## Build

```bash
cd dwi_pipeline/containers/deep_atropos_seg
bash build_deep_atropos_seg.sh
OUT_SIF=/path/to/dkt_deep_atropos_seg.sif bash build_deep_atropos_seg.sh
```

## HPC — ANTsXNet weight cache

First run downloads model weights (~few GB). On some compute nodes Figshare WAF blocks
direct downloads. **Set a persistent cache** and prefetch once from a login node:

```yaml
# config.local.yaml
act:
  deep_atropos:
    antsxnet_cache: /path/to/shared/.cache/antsxnet
```

`run_deep_atropos_seg.py` rewrites Figshare URLs to `ndownloader.figshare.com` and
prefetches required weights when the cache is empty.

**Login-node warmup** (before batch submit):

```bash
python3 dwi_pipeline/scripts/run_deep_atropos_seg.py \
  --prefetch-only \
  --cache-dir /path/to/shared/.cache/antsxnet
```

Or inside the container:

```bash
apptainer run -B /path/to/cache:/opt/antsxnet_cache dkt_deep_atropos_seg.sif \
  --prefetch-only --cache-dir /opt/antsxnet_cache
```

Preflight **requires** `act.deep_atropos.antsxnet_cache` when seg mode is `auto` or
`generate`.

## Manual run

```bash
apptainer run \
  -B /path/to/cache:/opt/antsxnet_cache \
  dkt_deep_atropos_seg.sif \
  --t1w /bids/sub-XXX/ses-YYY/anat/sub-XXX_ses-YYY_T1w.nii.gz \
  --outdir /out
```

Outputs: `desc-deepatropos_seg.nii.gz`, `deep_atropos_seg.json`.

## Label map (integer seg)

0=background, 1=CSF, 2=cortical GM, 3=WM, 4=subcortical GM, 5=brain stem, 6=cerebellum
(MRtrix Deep Atropos convention).

See [deep_atropos_5tt_plan.md](../../docs/maintainer/deep_atropos_5tt_plan.md).
