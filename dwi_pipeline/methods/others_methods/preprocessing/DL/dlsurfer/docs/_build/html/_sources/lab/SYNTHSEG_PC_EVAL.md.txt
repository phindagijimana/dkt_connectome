# SynthSeg-PC vs JLF — eval status

**Production choice (literature / deployment):** IDEAS piriform remains **JLF** (Wang multi-atlas) until SynthSeg-PC clears Hammers Dice/Jaccard.

**DL candidate:** lab SynthSeg-PC (`Documents/piriform/synthseg_pc`, best fold0 `dice_016.h5`). Not FreeSurfer `mri_synthseg`; not Mauri claustrum weights.

## Wired

```bash
source env/cluster_containers.sh
# SYNTHSEG_PC_ROOT / MODEL / LABELS / SYNTHSEG_ROOT
bash scripts/eval_synthseg_pc_vs_jlf.sh
```

Set `SSP_GT_DIR` / `SSP_IMG_DIR` (Hammers val FoV) and optional `JLF_PRED_DIR` for head-to-head. Gate `synthseg_pc_vs_jlf` stays **open** until tables show PC ≥ JLF on labels 1/2.
