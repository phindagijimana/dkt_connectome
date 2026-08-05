# `lit_<version>.sif` — neuroLIT (FastSurfer-LIT) lesion inpainting container

Wraps [deepmi/lit](https://hub.docker.com/r/deepmi/lit) — the diffusion-model
lesion inpainting tool from Pollak et al., *FastSurfer-LIT: Lesion Inpainting
Tool for Whole Brain MRI Segmentation with Tumors, Cavities and Abnormalities*,
Imaging Neuroscience 2025 ([doi.org/10.1162/imag_a_00446](https://doi.org/10.1162/imag_a_00446)).

Used by `subject.sh`'s Step 1.5 (see the pipeline header and
`pipeline_science.md`) to fill in manually-traced lesion regions on the T1w
*before* FreeSurfer/FastSurfer sees it, so recon-all's atlas-based skull-strip,
Talairach registration, and cortical parcellation are not thrown off by
lesion-driven intensity/geometry outliers.

## Build

```bash
bash build_lit.sh                 # pulls deepmi/lit:0.6.0 -> .../containers/lit_0.6.0.sif
LIT_VERSION=0.7.0 bash build_lit.sh
```

This is a straight `apptainer pull` from Docker Hub — no custom layers, unlike
`containers/connectome/build_connectome.sh`. Default output path matches
`CONTAINER_LIT`'s default in `subject.sh`:
`/path/to/others/containers/lit_0.6.0.sif`.

## What's inside

A single CLI, `lit-inpainting`, wrapping a DDPM (denoising diffusion
probabilistic model) with VINN (voxel-size independent neural network) layers
so it works on the T1w at its native resolution instead of requiring a fixed
isotropic grid up front:

```
lit-inpainting -i <input_t1w> -m <lesion_mask> -o <output_dir>
  --dilate N        grow the mask by N voxels before inpainting (default 0)
  --keepgeom         write the result back in the input's native geometry
                     (subject.sh always passes this, so Step 2/4 downstream
                     never have to reconcile a different grid)
  --device auto|cpu|cuda   default auto
  --batch_size N     slices per GPU batch (default 8); lower to fit less VRAM
```

Internally LIT conforms the volume to 1mm isotropic to run the diffusion
model, then (with `--keepgeom`) resamples the result back onto the input's
native grid — this is why `dwi_pipeline/scripts/check_inpainting.py` compares
against a resampling-only control rather than assuming perfect voxel-for-voxel
identity outside the lesion.

Output layout under `-o`:
```
inpainting_volumes/
  inpainting_original_image.nii.gz   input, conformed
  inpainting_mask.nii.gz             lesion mask, conformed (post-dilation)
  inpainting_masked_image.nii.gz     input with the lesion zeroed out
  inpainting_result.nii.gz           <- the file subject.sh treats as the
                                         inpainted T1w
inpainting_images/                   PNG previews of the four volumes above
```

## Runtime

CPU works but is slow (whole-volume 3D diffusion sampling); GPU is
substantially faster — a full run on a ~200x256x256 T1w took ~6.5 minutes on
one GPU with `--batch_size 2` vs. much longer on CPU. `subject.sh` passes
`--nv` to `apptainer exec` whenever `INPAINT_DEVICE` is not `cpu`, and `--nv`
is a no-op (not a hard failure) on nodes with no GPU/driver, so it's always
safe to leave on.

## Citation

If you use this tool for a paper: Pollak C, Kuegler D, Bauer T, Rueber T,
Reuter M, *FastSurfer-LIT: Lesion Inpainting Tool for Whole Brain MRI
Segmentation with Tumors, Cavities and Abnormalities*, Imaging Neuroscience
2025. https://doi.org/10.1162/imag_a_00446
