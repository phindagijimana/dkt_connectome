# Decision tables

QSIPrep-style **when to use which flag** reference. Full flag list: [Usage](usage.md). Config keys: [Configuration](configuration.md).

---

## Susceptibility distortion correction (Step 1)

| Your data | Recommended flag | Why |
|-----------|------------------|-----|
| BIDS fmap with valid `IntendedFor` → target DWI | *(none)* | dwi-select includes fmap → measured TOPUP/phasediff SDC |
| Siemens phasediff but sparse JSON sidecars | Repair first ([BIDS metadata](bids_metadata.md)), then default | QSIPrep needs `TotalReadoutTime` on **DWI** JSON |
| GE / no fieldmaps | `--syn` | SyN SDC when no measured fmap in filter |
| Fieldmaps exist but known bad | `--fmap-retry` | Ignore fmaps; force SyN |
| Reproducing legacy no-SDC cohort | `--no-sdc` | Skip SDC entirely (not recommended for new studies) |
| Unsure what filter selects | Dry-run `build_bids_filter.py` | See [Preparing your data § Field maps & SDC](preparing_data.md#fieldmaps-and-sdc) |

**Fail-fast rule:** without fmaps in the filter, you **must** pass `--syn`, `--fmap-retry`, or `--no-sdc`.

---

## DWI series selection

| Goal | Flag | Result |
|------|------|--------|
| Standard single-shell connectomics | *(default)* | b=1000 + IntendedFor fmaps via `dwi_select_b1000.json` |
| Different shell | `--dwi-shell 3000` | Uses `dwi_select_b3000.json` |
| Custom cohort rules | `--dwi-select PATH.json` | Explicit filter JSON |
| Static QSIPrep filter | `--bids-filter PATH.json` | Bypasses dwi-select builder |
| Debug / all series | `--no-dwi-filter` | All DWI in BIDS (legacy) |

---

## Cortical reconstruction (Step 2)

| Goal | Flag | Runtime | Atlas for Step 4 |
|------|------|---------|------------------|
| Production default | `--freesurfer` | Hours | DKT 78-node (default) |
| Faster recon | `--fastsurfer` | ~10× faster | DKT 78-node (only atlas FastSurfer writes) |
| FastSurfer + classic DK-68 volume | `--fast-fs` | FastSurfer + fsaparc | DKT default; DK available with `CONNECTOME_PARCELLATION=dk` |
| Skip recon (precomputed FS) | `--no-recon` | — | Requires existing `freesurfer/sub-<ID>/` |

**Mixed cohorts:** use DKT default so FreeSurfer and FastSurfer subjects share one 78-node matrix.

---

## Lesion inpainting (Step 1.5)

| Situation | Behavior |
|-----------|----------|
| BIDS `*_T1w_label-lesion_roi.nii.gz` present | Auto inpaint before recon |
| No mask | Silent skip (raw T1w → Step 2) |
| Mask present but skip desired | `--no-inpaint` |
| QC failure should abort run | `INPAINT_FAIL_ON_QC=1` |

---

## Connectome weighting (Steps 4 & 4.5)

| Weighting | When to use | Step 4.5 requirement |
|-----------|-------------|----------------------|
| **`count`** (default) | Group comparisons, standard graphs | Use same for disconnectome |
| **`sift2`** | Quantitative density interpretation | **Must** match Step 4; mismatch invalidates D matrix |

---

## Disconnectome (Step 4.5)

| Situation | Flag |
|-----------|------|
| Standard connectome only | *(default — off)* |
| Lesion disconnection analysis | `--disconnection` |
| Sensitivity: core only | `--disconnectome-core-only` |
| Sensitivity: eroded lesion | `--disconnectome-erode-voxels 1` |
| Standalone re-run | `--mode disconnectome` |

Requires: lesion mask from Step 1.5 + DKT connectome from Step 4.

---

## Node strength (Step 5)

| Goal | Flag |
|------|------|
| Full report (default) | *(none)* |
| Skip Step 5 | `--no-node-strength` |
| Metrics only, no PDF | `--no-report` |
| Strength CSVs only | `--strength-only` |

---

## Analysis level

| Level | Command | Use |
|-------|---------|-----|
| `participant` | `./run BIDS OUT participant --participant-label ID` | Process one or more subjects |
| `group` | `./run BIDS OUT group` | Cohort QC HTML + BIDS Derivatives export (no reprocessing) |

---

## See also

- [Preparing your data](preparing_data.md)
- [Preparing your data § Field maps & SDC](preparing_data.md#fieldmaps-and-sdc)
- [Methods](methods/index.md)
