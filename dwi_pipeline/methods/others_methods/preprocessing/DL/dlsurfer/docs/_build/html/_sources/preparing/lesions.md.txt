# Lesion masks

For TBI / surgical cavities, prefer **`core-lesion`**:

1. **Standalone neuroLIT** inpainting (GPU) → filled T1  
2. **Ordinary FastSurfer** `--seg_only` / `--surf_only` (GPU then CPU)  
3. Optional **lit-postprocessing** into the subject tree  

This preserves the HPC split. Native FastSurfer `--lesion_mask` (`core-lesion-native`) is opt-in and **cannot** use seg/surf partition split.

Mask: binary (or labeled) NIfTI in approximate T1 space; see neuroLIT / FastSurfer-LIT docs for conventions.
