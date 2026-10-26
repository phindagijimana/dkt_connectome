# SynthSeg-PC vs JLF — eval status

**Production choice (literature / deployment):** IDEAS piriform remains **JLF** (Wang multi-atlas) until SynthSeg-PC clears Hammers Dice/Jaccard.

## Hammers val dataset (ready)

Fold-0 FoV crops from `prepare_labels.py` (12 images + 12 GT; IDs 4/9/13/16/19/27 × lh/rh):

| Alias | Real path |
|-------|-----------|
| `data/hammers_val_img` | → `data/val_images` |
| `data/hammers_val_gt` | → `data/val_labels` |

See `Documents/piriform/synthseg_pc/data/HAMMERS_VAL_README.md`.

**DL candidate:** lab SynthSeg-PC (`Documents/piriform/synthseg_pc`, best fold0 `dice_016.h5`). Not FreeSurfer `mri_synthseg`; not Mauri claustrum weights.

## Wired

```bash
source env/cluster_containers.sh
# SYNTHSEG_PC_ROOT / MODEL / LABELS / SYNTHSEG_ROOT
bash scripts/eval_synthseg_pc_vs_jlf.sh
```

Set `SSP_GT_DIR` / `SSP_IMG_DIR` (Hammers val FoV) and optional `JLF_PRED_DIR` for head-to-head. Gate `synthseg_pc_vs_jlf` stays **open** until tables show PC ≥ JLF on labels 1/2.
