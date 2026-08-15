# Outputs

Derivatives written under `RESULTS_ROOT` (the BIDS App `<output_dir>`). Paths use BIDS-style subject IDs (`sub-<ID>`). Layout policy and BIDS compliance notes: [derivatives.md](derivatives.md).

---

## Top-level layout

```text
RESULTS_ROOT/
├── dataset_description.json   # derivative dataset provenance (auto-written by ./run)
├── qsiprep_single_run_output/sub-<ID>/     Step 1
├── inpainted/sub-<ID>/ses-<Y>/             Step 1.5 (lesion subjects only)
├── freesurfer/sub-<ID>/                    Step 2
├── qsirecon_single_run_output/sub-<ID>/    Step 3
├── connectomes/sub-<ID>/                   Step 4 (+ optional 4.5/)
├── qc/sub-<ID>/subject_qc.html             Unified QC dashboard (Steps 1–5)
├── cohort_qc.html                          Group-level QC index (./run group)
├── derivatives/                            BIDS Derivatives export (symlink mirror)
├── node_strength/                          Step 5 (cohort-shared tree)
├── intermediate_results_qsiprep_single/
└── logs/
```

---

## Step 1 — QSIPrep

| Path | Description |
|------|-------------|
| `qsiprep_single_run_output/sub-<ID>/ses-<Y>/dwi/*_desc-preproc_dwi.nii.gz` | Preprocessed DWI |
| `.../anat/*_desc-preproc_T1w.nii.gz` | Preprocessed T1w |
| `.../dwi/*_space-T1w_dwiref.nii.gz` | DWI reference in T1w space |
| `figures/` | QC reportlets |

---

## Step 1.5 — Inpaint

Only when `*_T1w_label-lesion_roi.nii.gz` exists for the session:

| Path | Description |
|------|-------------|
| `inpainted/sub-<ID>/ses-<Y>/lesion_mask_prepared.nii.gz` | Resampled / label-selected mask |
| `inpainted/sub-<ID>/ses-<Y>/lesion_mask_prepared.json` | Provenance |
| `inpainted/sub-<ID>/ses-<Y>/inpainting_volumes/inpainting_result.nii.gz` | Inpainted T1w |
| `inpainted/sub-<ID>/ses-<Y>/inpainting.json` | QC metrics |

---

## Step 2 — Recon

| Path | Description |
|------|-------------|
| `freesurfer/sub-<ID>/mri/aparc+aseg.mgz` | Segmentation |
| `freesurfer/sub-<ID>/mri/aparc.DKTatlas+aseg.mgz` | DKT labels (when available) |
| `freesurfer/sub-<ID>/surf/` | Surfaces |

---

## Step 3 — QSIRecon

| Path | Description |
|------|-------------|
| `qsirecon_single_run_output/sub-<ID>/ses-<Y>/anat/*_streamlines.tck.gz` | ACT-HSVS tractogram |
| `.../*_sift2_streamlineweights.txt` | SIFT2 weights (optional weighting) |
| Atlas connectome (4S156) | When `QSIRECON_ATLASES` enabled |

---

## Step 4 — Connectome (primary)

Under `connectomes/sub-<ID>/`:

| File | Description |
|------|-------------|
| `dkt_connectome.csv` | **Primary** 78×78 DKT matrix (default: streamline counts) |
| `nodes.mif` | DKT parcellation on DWI grid |
| `parcellation.json` | Atlas metadata |
| `native_to_preproc_T1w_0GenericAffine.mat` | Registration used for lesion warp (4.5) |
| `assignments.csv` | Streamline–node assignments (debug) |

With `CONNECTOME_PARCELLATION=dk`: `dk_connectome.csv` (84 nodes, recon-all only).

---

## Step 4.5 — Disconnectome (optional, manual)

Under `connectomes/sub-<ID>/disconnectome/`:

| File | Description |
|------|-------------|
| `dkt_connectome_C_both.csv` | Strictest spared connectome (Option C) |
| `disconnection_matrix.csv` | Edge disconnection index (D = 1 − spared/P) |
| `lesion_roi_metrics.csv` | Per-node lesion overlap |
| `disconnectome.json` | Provenance and summary stats |

Full file list: [Inpainting/disconnection.md §Outputs](https://github.com/phindagijimana/dkt_connectome/blob/main/dwi_pipeline/Inpainting/disconnection.md).

---

## Step 5 — Node strength

Cohort-level directory `node_strength/` with per-subject subfolders under `reports/sub-<ID>/`:

| Output | Description |
|--------|-------------|
| `strength/` | Node strength CSVs |
| `volume/` | Volume asymmetry |
| `compare/` | Interhemispheric AI |
| `reports/sub-<ID>/report.pdf` | ENIGMA-style summary |

---

## Weighting consistency

Step 4 and Step 4.5 must use the same edge weighting (`count` by default). Mismatch invalidates the disconnection matrix — see [Integrity QC](integrity_qc.md).

---

## One `RESULTS_ROOT` per pipeline variant

Do not mix runs with different settings (FastSurfer vs FreeSurfer, inpaint on/off, connectome off) in the same output directory.
