# Inputs

## Required

| Input | Flag | Notes |
|-------|------|--------|
| T1w NIfTI | `--t1` | 3D T1; FastSurfer will conform |
| SUBJECTS_DIR | `--sd` | **Dedicated** tree owned by DLSurfer |
| Subject ID | `--sid` | FreeSurfer-style, e.g. `sub-01` |
| FS license | `--fs-license` or `FS_LICENSE` | Required for FS/FastSurfer tools |

## Optional

| Input | Flag | When |
|-------|------|------|
| Lesion mask | `--lesion-mask` | `core-lesion` / native lesion profiles |
| Device | `--device auto\|cpu\|cuda` | Default `auto` |
| Threads | `--threads` | FastSurfer / recon-surf |
| Atlas | `--atlas dkt\|dk\|…` | Default DKT labeling |

## BIDS (stub only)

Preferred production API remains **explicit paths** (`--t1`, `--sd`, `--sid`).  
A BIDS App–style stub exists but is **short of** the standard — see [BIDS App status](../bids_app.md):

```bash
dlsurfer bids-app BIDS_DIR OUT_DIR participant --participant_label 01 --profile core
```
