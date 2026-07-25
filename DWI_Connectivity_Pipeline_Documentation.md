# DWI Connectivity Pipeline Documentation

*Last updated: July 2026 — reflects strict fail-fast pipeline, default dwi-select (b1000), and separated result folders.*

## Overview

This pipeline generates diffusion MRI tractography and connectome outputs using **QSIPrep**, **FreeSurfer/FastSurfer**, **QSIRecon**, and an optional post-hoc **Desikan–Killiany (DK) connectome** step.

The workflow has four main stages:

1. **QSIPrep** — preprocesses DWI data (with **dwi-select** series filtering by default) and defines the tracking space.
2. **FreeSurfer or FastSurfer** — generates anatomical parcellations from the T1w image.
3. **QSIRecon** — reconstructs diffusion models, runs tractography, and optionally creates an atlas-based connectome (4S156).
4. **DK connectome** (optional) — warps FreeSurfer labels into QSIPrep space and generates an 84-region DK matrix.

Tractography and the DK connectome both live in **QSIPrep T1w / dwiref space**. FreeSurfer supplies anatomical region labels; those labels are aligned to the tractography grid before connections are counted.

---

## Pipeline variants and result folders

| Variant | Wrapper / entry | Step 4 |
|---------|-----------------|--------|
| **Full pipeline** | `dwi_pipeline/subject.sh` | ON (`RUN_CONNECTOME=1`) |
| **Atlas connectome only** | `dwi_connect_default/subject.sh` | OFF (`RUN_CONNECTOME=0`) |

`RESULTS_ROOT` is yours to choose. Give each cohort its own directory so that
runs made with different settings cannot overwrite one another.

Repo docs:

- [`dwi_pipeline/README.md`](dwi_pipeline/README.md) — launcher reference
- [`bids.md`](bids.md) — PE metadata and dwi-select
- [`fmaps.md`](fmaps.md) — SDC / fieldmap behavior

---

## BIDS preparation (before QSIPrep)

Sidecar repair is **not** run inside the pipeline. Apply fixes first:

```bash
./dwi_pipeline/scripts/run_bids_repair.sh /path/to/bids SUBJ01 --dry-run
./dwi_pipeline/scripts/run_bids_repair.sh /path/to/bids SUBJ01
```

Then verify the dwi-select filter (see § dwi-select below). See [`bids.md`](bids.md) for TRT, `IntendedFor`, and spreadsheet-driven repair.

---

## dwi-select (default ON at QSIPrep)

Config: `dwi_pipeline/config/dwi_select_b1000.json` → per-subject QSIPrep `--bids-filter-file`.

| Rule | Behavior |
|------|----------|
| DWI shell | Keeps series matching **b=1000** (configurable via `--dwi-shell`) |
| Fmap exclude | Skips `acq-rs` fmaps (files stay on disk; not in filter) |
| Fmap include | **IntendedFor only** — fmap kept iff it points at a kept DWI; no session fallback |
| Disable | `--no-dwi-filter` or `QSIPREP_NO_DWI_FILTER=1` |

Dry-run:

```bash
python3 dwi_pipeline/scripts/build_bids_filter.py \
  --bids-dir /path/to/bids --subject SUBJ01 \
  --select-json dwi_pipeline/config/dwi_select_b1000.json \
  --output /tmp/bids_filter_check.json
```

---

## Strict fail-fast behavior

The pipeline avoids silent fallbacks. Failures print `ERROR [label]: ...` and exit non-zero.

| Area | Behavior |
|------|----------|
| FreeSurfer SIF | Requires `freesurfer_7.4.1.sif`; no fallback to FastSurfer's trimmed FS |
| SDC | Measured when fmap in filter; else require `--syn` or `--fmap-retry` |
| Recon rerun | Fails if `aparc+aseg.mgz` exists unless `RECON_SKIP_IF_EXISTS=1` |
| Step 4 inputs | Exactly one tractogram, dwiref, desc-preproc T1w, session-matched BIDS T1w |
| Step 4 space | `CONNECTOME_RESAMPLE_TO_DWI=1` required |
| `--no-recon` | Does not auto-switch to ACT-fast; set spec or provide FS dir |

---

## Inputs

| Input | Example path |
|-------|----------------|
| BIDS root | `$BIDS_DIR` — any [BIDS](https://bids.neuroimaging.io/)-valid dataset |
| Subject DWI | `sub-XXX/ses-*/dwi/*_dwi.nii.gz` |
| Subject T1w | `sub-XXX/ses-*/anat/*_T1w.nii.gz` |
| Fieldmap (optional) | `sub-XXX/ses-*/fmap/*` with `IntendedFor` in JSON |
| Containers | `qsiprep.sif`, `freesurfer_7.4.1.sif`, `qsirecon.sif` |
| FreeSurfer license | `license.txt` |
| TemplateFlow cache | `$TEMPLATEFLOW_HOME` (defaults to `templateflow/` in the repo) |

---

## Step 1 — QSIPrep

### Purpose

QSIPrep preprocesses diffusion MRI data: distortion correction, registration of DWI to T1w, and derivative outputs in `space-T1w`. QSIPrep defines the reference space used for tractography and DK node alignment.

**Before the container runs**, `subject.sh` builds a dwi-select BIDS filter (unless `--no-dwi-filter`).

### Susceptibility distortion correction

| Condition | Behavior |
|-----------|----------|
| dwi-select includes fmap | **Measured SDC** (TOPUP / phasediff); log: `dwi-select includes fmap -> measured SDC` |
| No fmap in filter + `--syn` | `--use-syn-sdc warn` |
| `--fmap-retry` | `--ignore fieldmaps --use-syn-sdc warn` |
| No fmap, no SyN flag | **Pipeline fails** (strict) |

See [`fmaps.md`](fmaps.md) for details.

### Launcher (conceptual)

```bash
apptainer run --cleanenv --containall \
  -B "${BIDS_DIR}":/bids_input:ro \
  -B "${QSIPREP_OUT}":/output \
  -B "${WORK_QSIPREP}":/work \
  -B "${FS_LICENSE}":/opt/freesurfer/license.txt:ro \
  -B "${TEMPLATEFLOW_HOME}":/templateflow \
  --env "TEMPLATEFLOW_HOME=/templateflow" \
  "${CONTAINER_QSIPREP}" \
  /bids_input /output participant \
  --participant-label "${SUBJECT}" \
  --bids-filter-file /work/bids_filter.json \
  --fs-license-file /opt/freesurfer/license.txt \
  --work-dir /work \
  --output-resolution 2 \
  --nthreads 8 --omp-nthreads 8 \
  --skip-bids-validation
```

### Key outputs

- `qsiprep_single_run_output/sub-XXX/anat/sub-XXX_desc-preproc_T1w.nii.gz` (subject- or session-level)
- `.../ses-*/dwi/*_space-T1w_desc-preproc_dwi.nii.gz`
- `.../ses-*/dwi/*_space-T1w_dwiref.nii.gz`

### Space defined by QSIPrep

- **`desc-preproc_T1w`** — ~1 mm isotropic anatomical reference
- **`dwiref`** — ~2 mm tractography grid

The DK step reads **BIDS T1w** to compute an empirical affine into `desc-preproc_T1w`.

---

## Step 2 — FreeSurfer or FastSurfer

### Purpose

Parcellate the brain and produce **`aparc+aseg.mgz`** and **`rawavg.mgz`** (native T1w grid).

### Input

Raw **BIDS T1w** from the session selected by the dwi-select filter (not QSIPrep preprocessed T1w).

### FreeSurfer requirements

- Container: **`freesurfer_7.4.1.sif`** (dedicated full image; pipeline fails if missing)
- If `aparc+aseg.mgz` already exists: **fail** unless `RECON_SKIP_IF_EXISTS=1`

### Output space

- `aparc+aseg.mgz` — FreeSurfer conformed (256³ @ 1 mm)
- `rawavg.mgz` — native scanner T1w grid (used in DK Step 4a)

QSIPrep and FreeSurfer can run in parallel in principle; `subject.sh all` runs QSIPrep first, then recon.

---

## Step 3 — QSIRecon

### Purpose

SS3T CSD + ACT tractography with HSVS 5TT (default spec `mrtrix_singleshell_ss3t_ACT-hsvs`). Produces ~10M streamlines and optional **4S156** atlas connectome inside QSIRecon.

### Requirements

- QSIPrep outputs
- FreeSurfer subjects dir when using ACT-HSVS spec

### Key outputs

- `*_space-T1w_model-ifod2_streamlines.tck.gz`
- `*_space-T1w_connectivity.mat` (if `--atlases 4S156Parcels`)
- HSVS / 5TT tissue maps

Tractogram is in **QSIPrep T1w space**.

---

## Step 4 — Post-hoc anatomical connectome

*Skipped when `RUN_CONNECTOME=0` (`dwi_connect_default` / `--no-connectome`).*

### Purpose

Build an anatomical connectome from the QSIRecon tractogram and a FreeSurfer parcellation.

The default is the **78-node Desikan–Killiany–Tourville (DKT)** matrix, from either recon tool:
FastSurfer's `aparc+aseg.mgz` is already DKT, and a `recon-all` tree is read via its
`aparc.DKTatlas+aseg.mgz`. The **84-node Desikan–Killiany (DK)** matrix is available with
`CONNECTOME_PARCELLATION=dk`, but only from `recon-all`.

The lookup table and the segmentation must describe the same atlas: `labelconvert` matches
regions by name, so applying the DKT table to a DK image silently *drops* bankssts and the
frontal/temporal poles instead of reassigning their territory to neighbouring gyri.

### Coordinate alignment

| Volume / stage | Space |
|----------------|-------|
| `aparc+aseg.mgz` | FreeSurfer conformed (256³ @ 1 mm) |
| After Step 4a | Native T1w (`rawavg.mgz` grid) |
| After Step 4b-2 | QSIPrep `desc-preproc_T1w` (~1 mm) |
| After Step 4b-3 | QSIPrep T1w / `dwiref` grid (~2 mm) |

**Why not QSIPrep's packaged `from-T1wNative_to-T1wACPC` alone?** FreeSurfer `rawavg.mgz` and BIDS T1w share scanner-native headers; an **empirical affine** (BIDS T1w → `desc-preproc_T1w`) bridges the gap. Session-matched T1w, dwiref, and tractogram are required.

### Containers

| Sub-step | Container |
|----------|-----------|
| 4a–4f (default) | `dkt_connectome.sif` — FreeSurfer 7.4.1 + ANTs + MRtrix3 |
| 4a–4f (legacy) | `freesurfer_7.4.1.sif` + `qsirecon.sif` when `CONNECTOME_LEGACY_DUAL_CONTAINER=1` |

Build the Step 4 image:

```bash
bash dwi_pipeline/containers/connectome/build_connectome.sh
```

Runtime binds: FreeSurfer subject dir, QSIPrep/QSIRecon outputs, BIDS T1w, output dir, and `FS_LICENSE`.

### Step 4a — Warp labels to native space

```bash
# $SEG is aparc+aseg.mgz, or aparc.DKTatlas+aseg.mgz for DKT from recon-all
mri_label2vol --seg $SEG \
  --temp /fs_subject/mri/rawavg.mgz \
  --o /out/aparc+aseg_in_rawavg.mgz \
  --regheader $SEG
```

### Step 4b — Warp into QSIPrep space

1. Affine register BIDS T1w → `desc-preproc_T1w` (`antsRegistration`)
2. Apply affine to native labels → `aparc+aseg_in_t1w.nii.gz`
3. Resample onto `dwiref` grid (`antsApplyTransforms -n GenericLabel`)

### Step 4c–4f — Connectome

```bash
# $LUT is fs_default.txt (DK, 84 nodes) or fs_dkt.txt (DKT, 78 nodes)
labelconvert ... $LUT /out/nodes.mif
tck2connectome -symmetric -zero_diagonal \
  /out/streamlines.tck /out/nodes.mif /out/connectome.csv \
  -out_assignments /out/assignments.csv
```

### Step 4 outputs (`connectomes/sub-XXX/`)

| File | Description |
|------|-------------|
| `dkt_connectome.csv` | 78 × 78 symmetric streamline-count matrix (default) |
| `dk_connectome.csv` | 84 × 84 instead, when `CONNECTOME_PARCELLATION=dk` |
| `parcellation.json` | Atlas, node count, LUT, segmentation read, empty-node count |
| `assignments.csv` | Per-streamline node-pair assignments |
| `nodes.mif` / `nodes.mrinfo.txt` | MRtrix label image + QC metadata |
| `tracks.tckinfo.txt` | Tractogram QC (expect ~10M streamlines) |
| `aparc+aseg_in_dwi.nii.gz` | Labels on tractography grid |
| `native_to_preproc_T1w_0GenericAffine.mat` | BIDS T1w → desc-preproc_T1w affine |

---

## Running the pipeline

### Full pipeline with the anatomical connectome (recommended)

```bash
cd /path/to/repo

export BIDS_DIR=/path/to/bids
export RESULTS_ROOT=/path/to/results
export PIPELINE_MODE=all
export RUN_CONNECTOME=1

bash dwi_pipeline/subject.sh all SUBJ01
```

### Atlas connectome only (no Step 4)

```bash
export RESULTS_ROOT=/path/to/results_atlas_only
bash dwi_connect_default/subject.sh all SUBJ01
# or: ./dwi_connect_default/submit.sh
```

### Individual stages

```bash
bash dwi_pipeline/subject.sh qsiprep SUBJ01
bash dwi_pipeline/subject.sh recon SUBJ01
bash dwi_pipeline/subject.sh qsirecon SUBJ01
bash dwi_pipeline/subject.sh connectome SUBJ01
```

### Slurm array

```bash
export RESULTS_ROOT=/path/to/results
export SUBJECT_LIST_FILE=dwi_pipeline/subjects.txt
./dwi_pipeline/submit.sh
```

---

## Two connectomes, one tractogram

| Output | Parcellation | Produced by |
|--------|--------------|-------------|
| `*_connectivity.mat` | 4S156 (156 regions) | QSIRecon (`--atlases 4S156Parcels`) |
| `dkt_connectome.csv` | Desikan–Killiany–Tourville (78 regions) | Post-hoc Step 4 |

Only the label map differs; the underlying streamline set is the same.

---

## Validation checklist

| Check | Expected |
|-------|----------|
| BIDS repair | PE/TRT/`IntendedFor` applied before QSIPrep |
| dwi-select log | Keeps b1000 DWI + IntendedFor fmaps; excludes acq-rs |
| QSIPrep | Measured SDC when fmaps in filter; exit 0 |
| FreeSurfer | `aparc+aseg.mgz`, `rawavg.mgz`, `recon-all.done` |
| QSIRecon | ~10M streamlines; ACT-HSVS completes |
| Step 4 log | Space chain: conformed → native → desc-preproc_T1w → dwiref |
| `nodes.mrinfo.txt` | Grid matches dwiref (~2 mm) |
| `dkt_connectome.csv` | 78×78 symmetric; all ROIs populated (no empty rows) |
| `parcellation.json` | `empty_nodes: 0`, and `aparc_aseg` matches the requested atlas |

---

## Summary

**QSIPrep** (with **dwi-select**) defines the tracking space and SDC path. **FreeSurfer** defines anatomical labels. **QSIRecon** generates streamlines in QSIPrep T1w space. The **DK step** warps labels through native T1w, an empirical affine into `desc-preproc_T1w`, and a final resample onto `dwiref`, then assigns streamline endpoints with `tck2connectome`.

```
Tractography space  = QSIPrep T1w / dwiref grid (~2 mm)
DK node space       = FS labels → rawavg → desc-preproc_T1w → dwiref
```

Both must align before the connectome matrix is computed.
