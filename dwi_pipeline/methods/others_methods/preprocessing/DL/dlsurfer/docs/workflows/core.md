# core / core-lesion

## `core`

1. FastSurfer VINN (+ CC, CerebNet, HypVINN) — GPU `--seg_only --tal_reg`  
2. recon-surf — CPU `--surf_only`

## `core-lesion`

1. `lit-inpainting` (GPU)  
2. Same as `core` on **inpainted** T1  
3. `lit-postprocessing` (CPU)

Planner collapses contiguous FastSurfer modules into `run_fastsurfer.sh` so citations stay honest without reimplementing the stack.
