# Separable LIT (DL-only) + GPU seg / CPU surf split

## Policy

**LIT on the public DLSurfer surface is DL-only** via standalone neuroLIT
(`lit-inpainting` → ordinary FastSurfer → `lit-postprocessing`).

Upstream FastSurfer **`--lesion_mask`** (LIT inside recon) is **not offered**:
it blocks `--seg_only` / `--surf_only` and is not needed when inpaint is separable.

## Orchestration

1. **GPU** — `lit-inpainting` → FastSurfer `--seg_only`
2. **CPU** — FastSurfer `--surf_only` → `lit-postprocessing`

| Profile | Behavior |
|---------|----------|
| `core-lesion` | DL separable neuroLIT (default) |
| `core-lesion-native` | Same as `core-lesion` (alias) |

## Run

```bash
dlsurfer run --profile core-lesion \
  --t1 T1.nii.gz --lesion-mask lesion.nii.gz \
  --sd "$SD" --sid "$SID" --fs-license "$FS_LICENSE" -q

# HPC slices
dlsurfer run … --device cuda --stage gpu --no-post-lit -q
dlsurfer run … --device cpu  --stage cpu -q

# SLURM two-partition submit
export T1=… LESION=… SD=… SID=… FS_LICENSE=… FASTSURFER_HOME=… FREESURFER_HOME=…
EXECUTE=1 sbatch hpc/slurm_core_lesion_split.sh
```

Also: `dlsurfer recon-all -i T1 -sd SD -s SID --lesion-mask lesion.nii.gz` → `core-lesion`.

## Cite

Pollak C, et al. FastSurfer-LIT. *Imaging Neuroscience* 2025.
https://deep-mi.org/FastSurfer/stable/overview/modules/LIT.html
