# Lesion masks

For TBI / surgical cavities, use **`core-lesion`** (DL-only LIT):

1. **Standalone neuroLIT** inpainting (GPU) → filled T1  
2. **Ordinary FastSurfer** `--seg_only` / `--surf_only` (GPU then CPU)  
3. Optional **lit-postprocessing** into the subject tree  

This preserves the HPC split (`--stage gpu|cpu`). Upstream FastSurfer
`--lesion_mask` is **not** on the public path — see [LIT_SPLIT.md](../reference/LIT_SPLIT.md).

Mask: binary (or labeled) NIfTI in approximate T1 space; see neuroLIT / FastSurfer-LIT docs for conventions.
