# Outputs

Derivatives written under `RESULTS_ROOT` (the BIDS App `<output_dir>`). Paths use BIDS-style subject IDs (`sub-<ID>`). Layout policy and BIDS compliance notes: [derivatives.md](derivatives.md).

---

## Top-level layout

```text
RESULTS_ROOT/
├── dataset_description.json   # derivative dataset provenance (auto-written by ./run)
├── qsiprep_single_run_output/sub-<ID>/     Step 1
├── inpainted/sub-<ID>/ses-<Y>/             Step 1.1 neuroLIT (lesion subjects)
├── vbt/sub-<ID>/ses-<Y>/                   Step 1.1 VBT (--anat-mitigation vbt)
├── lesion_aware_act/sub-<ID>/              Step 3.1 (--act-mode lesion-aware)
├── deep_atropos_seg/sub-<ID>/              Step 3.2 (segmentation) (--act-5tt-source deep-atropos-native)
├── deep_atropos/sub-<ID>/                  Step 3.2 (--act-5tt-source deep-atropos-native)
├── freesurfer/sub-<ID>/                    Step 2
├── qsirecon_single_run_output/sub-<ID>/    Step 3
├── connectomes/sub-<ID>/                   Step 4 (+ optional 4.1/)
├── arms/<arm>/                             Experiment-arm isolated runs (optional)
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

## Step 1.1 — Inpaint

Only when `*_T1w_label-lesion_roi.nii.gz` exists for the session:

| Path | Description |
|------|-------------|
| `inpainted/sub-<ID>/ses-<Y>/…` | neuroLIT backend (default) |
| `vbt/sub-<ID>/ses-<Y>/…` | VBT backend (`--anat-mitigation vbt`) |
| `…/lesion_mask_prepared.nii.gz` | Resampled / label-selected mask |
| `…/lesion_mask_prepared.json` | Provenance |
| `…/inpainting_volumes/inpainting_result.nii.gz` | Mitigated T1w (Step 2 input) |
| `…/inpainting.json` | QC metrics and backend provenance |

---

## Step 3.1 — Lesion-aware ACT

When `--act-mode lesion-aware` or a `*-lesion` experiment arm:

| Path | Description |
|------|-------------|
| `lesion_aware_act/sub-<ID>/lesion_aware_5tt.mif` | 5TT with pathology channel (dwiref grid) |
| `lesion_aware_act/sub-<ID>/lesion_aware_5tt_acpc.mif` | Edited 5TT on ACPC grid (`hsvs` source only) |
| `lesion_aware_act/sub-<ID>/lesion_aware_5tt_native.mif` | Edited 5TT on native grid (`deep-atropos-native` only) |
| `lesion_aware_act/sub-<ID>/lesion_mask_in_dwi.nii.gz` | Mask in DWI space |
| `lesion_aware_act/sub-<ID>/model-ifod2_streamlines.tck` | Rebuilt tractogram |
| `lesion_aware_act/sub-<ID>/model-sift2_streamlineweights.csv` | SIFT2 weights |
| `lesion_aware_act/sub-<ID>/lesion_aware_act.json` | Provenance (`five_tt_source`, warp method, factorial fields) |

### Step 3.2 — Deep Atropos (optional, `--act-5tt-source deep-atropos-native`)

| Path | Description |
|------|-------------|
| `deep_atropos_seg/sub-<ID>/desc-deepatropos_seg.nii.gz` | Integer Deep Atropos seg (labels 0–6) |
| `deep_atropos_seg/sub-<ID>/deep_atropos_seg.json` | Seg provenance (`segmentation_source`: import or generated) |
| `deep_atropos/sub-<ID>/base_5tt_native.mif` | Base 5TT on native BIDS T1w grid |
| `deep_atropos/sub-<ID>/deep_atropos_5tt.json` | Conversion provenance |

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
| `dkt_connectome.csv` | **Primary** 78×78 alias (default: count → same as `dkt_connectome_count.csv`) |
| `dkt_connectome_count.csv` | Streamline counts |
| `dkt_connectome_sift2.csv` | SIFT2 weights (**optional** — `--connectome-sift2`) |
| `dkt_connectome_meanlength.csv` | Mean streamline length per edge (mm) |
| `dkt_connectome_meanfa.csv` | Mean FA along streamlines |
| `dkt_connectome_meanmd.csv` | Mean MD along streamlines |
| `dkt_desc-FA_dwi.nii.gz`, `dkt_desc-MD_dwi.nii.gz` | Voxelwise tensor maps |
| `dkt_nodes.mif` | DKT parcellation on DWI grid |
| `parcellation.json` | Atlas metadata |
| `native_to_preproc_T1w_0GenericAffine.mat` | Registration used for lesion warp (4.1) |
| `assignments.csv` | Streamline–node assignments (debug) |

With `--tractography-model both`: additional `dkt_model-SDSTREAM_connectome_*.csv` files.

With `CONNECTOME_PARCELLATION=dk`: `dk_connectome.csv` (84 nodes, recon-all only).

---

## Step 4.1 — Disconnectome (optional, manual)

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

Step 4 and Step 4.1 must use the same edge weighting (`count` by default). Mismatch invalidates the disconnection matrix — see [Disconnectome § Integrity QC](disconnectome.md#integrity-qc).

---

## One `RESULTS_ROOT` per pipeline variant

Do not mix runs with different settings (FastSurfer vs FreeSurfer, inpaint on/off, connectome off) in the same output directory.

**Experiment arms:** by default each `--experiment-arm` writes to `RESULTS_ROOT/arms/<arm>/` with the full step tree under that prefix. Run one arm per Slurm submission when comparing anatomy × ACT factorial designs. See [Usage — experiment arms](usage.md).
