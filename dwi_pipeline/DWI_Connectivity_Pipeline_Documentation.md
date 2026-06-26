# DWI Connectivity Pipeline Documentation

## Overview

This pipeline generates diffusion MRI tractography and connectome outputs using **QSIPrep**, **FreeSurfer/FastSurfer**, **QSIRecon**, and a post-hoc **Desikan–Killiany (DK) connectome** step.

The workflow has four main stages:

1. **QSIPrep** — preprocesses DWI data and defines the tracking space.
2. **FreeSurfer or FastSurfer** — generates anatomical parcellations from the T1w image.
3. **QSIRecon** — reconstructs diffusion models, runs tractography, and optionally creates an atlas-based connectome.
4. **DK connectome** — warps FreeSurfer labels into QSIPrep space and generates a DK-based connectome.

Tractography and the DK connectome both live in **QSIPrep T1w space**. FreeSurfer supplies anatomical region labels; those labels are aligned to the tractography grid before connections are counted.

---

## Inputs

| Input | Example path |
|-------|----------------|
| BIDS root | `.../CIDUR_BIDS/data_bids` |
| Subject DWI | `sub-001/ses-1/dwi/*_dwi.nii.gz` |
| Subject T1w | `sub-001/ses-1/anat/*_T1w.nii.gz` |
| Fieldmap (optional) | `sub-001/ses-1/fmap/*` with `IntendedFor` in JSON |
| Containers | `qsiprep.sif`, `freesurfer_7.4.1.sif`, `qsirecon.sif` |
| FreeSurfer license | `license.txt` |
| TemplateFlow cache | `.../templateflow` |

---

## Step 1 — QSIPrep

### Purpose

QSIPrep preprocesses diffusion MRI data: distortion correction, registration of DWI to T1w, and derivative outputs in `space-T1w`. QSIPrep defines the reference space used for tractography and DK node alignment.

### Launcher

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
  --fs-license-file /opt/freesurfer/license.txt \
  --work-dir /work \
  --output-resolution 2 \
  --nthreads 8 \
  --omp-nthreads 8 \
  --skip-bids-validation
```

### Susceptibility distortion correction

| Condition | Extra flags |
|-----------|-------------|
| BIDS fieldmap present | None; TOPUP runs automatically |
| No fieldmap, SyN opt-in | `--use-syn-sdc warn` |
| Fieldmap retry mode | `--ignore fieldmaps --use-syn-sdc warn` |

### Internal tools

QSIPrep invokes tools inside its workflow (not called manually), including **topup**, **eddy**, **BBR**, N4 bias correction, brain extraction, and resampling. With fieldmaps, logs may show:

```
[Node] Executing "topup" <qsiprep.interfaces.fmap.ParallelTOPUP>
```

### Key outputs

- `qsiprep_single_run_output/sub-001/anat/sub-001_desc-preproc_T1w.nii.gz`
- `qsiprep_single_run_output/sub-001/ses-1/dwi/*_space-T1w_desc-preproc_dwi.nii.gz`
- `qsiprep_single_run_output/sub-001/ses-1/dwi/*_space-T1w_dwiref.nii.gz`
- `qsiprep_single_run_output/sub-001/ses-1/anat/*_from-orig_to-T1w_mode-image_xfm.txt` (or `.mat`) — QSIPrep metadata; **not used directly by the DK step** (see Step 4)

### Space defined by QSIPrep

- **`desc-preproc_T1w`** — approximately 1 mm isotropic (QSIPrep anatomical reference)
- **DWI reference (`dwiref`)** — approximately 2 mm resolution (tractography grid)

Both are used later for tractography and DK alignment. The DK step also reads the **BIDS T1w** from `data_bids` to compute an empirical affine into `desc-preproc_T1w`.

---

## Step 2 — FreeSurfer or FastSurfer

### Purpose

FreeSurfer or FastSurfer parcellates the brain and produces **`aparc+aseg.mgz`**, an integer-labeled cortical and subcortical segmentation.

### Input

Raw **BIDS T1w**, not the QSIPrep preprocessed T1w:

```
/bids/sub-001/ses-1/anat/sub-001_ses-1_T1w.nii.gz
```

### Output space

FreeSurfer outputs are in **conformed space**:

- 256 × 256 × 256
- 1 mm resolution
- LIA orientation

`aparc+aseg.mgz` is not yet in QSIPrep space. **`rawavg.mgz`** (native T1w grid) is also written and used in Step 4.

### Parallelization

QSIPrep and FreeSurfer can run in parallel; both read from BIDS and do not depend on each other.

### FreeSurfer launcher

```bash
apptainer exec --cleanenv --containall \
  -B "${BIDS_DIR}":/bids:ro \
  -B "${RECON_OUT}":/sd \
  -B "${FS_LICENSE}":/.fs_license.txt:ro \
  "${CONTAINER_FREESURFER}" \
  bash -lc "
    export FS_LICENSE=/.fs_license.txt
    export SUBJECTS_DIR=/sd
    recon-all -all -s sub-001 \
      -i /bids/sub-001/ses-1/anat/sub-001_ses-1_T1w.nii.gz \
      -openmp 8
  "
```

### FastSurfer alternative

```bash
apptainer exec --cleanenv --containall \
  -B "${BIDS_DIR}":/bids:ro \
  -B "${RECON_OUT}":/sd \
  -B "${FS_LICENSE}":/fs_license/license.txt:ro \
  "${CONTAINER_FASTSURFER}" \
  /fastsurfer/run_fastsurfer.sh \
    --fs_license /fs_license/license.txt \
    --sid sub-001 \
    --sd /sd \
    --t1 /bids/sub-001/ses-1/anat/sub-001_ses-1_T1w.nii.gz \
    --parallel \
    --threads 8 \
    --device cpu
```

### Key output

```
freesurfer/sub-001/mri/aparc+aseg.mgz
freesurfer/sub-001/mri/rawavg.mgz
```

---

## Step 3 — QSIRecon

### Purpose

QSIRecon reads QSIPrep derivatives and reconstructs diffusion models. With the **ACT-HSVS** specification it uses FreeSurfer outputs to build tissue models for anatomically constrained tractography.

QSIRecon performs:

- FOD estimation (SS3T CSD)
- 5TT / HSVS generation
- Tractography (`tckgen`)
- SIFT2 weighting
- Optional atlas-based connectome generation

### Reference space

QSIRecon operates in **QSIPrep T1w space**.

### Requirements

- QSIPrep outputs (Step 1)
- FreeSurfer outputs (Step 2) when using `mrtrix_singleshell_ss3t_ACT-hsvs`

### Launcher

```bash
apptainer run --cleanenv --containall \
  -B "${QSIPREP_OUT}":/qsiprep_input:ro \
  -B "${QSIRECON_OUT}":/output \
  -B "${WORK_QSIRECON}":/work \
  -B "${FS_SUBJECTS_DIR}":/freesurfer:ro \
  -B "${FS_LICENSE}":/opt/freesurfer/license.txt:ro \
  -B "${TEMPLATEFLOW_HOME}":/templateflow \
  --env "TEMPLATEFLOW_HOME=/templateflow" \
  "${CONTAINER_QSIRECON}" \
  /qsiprep_input /output participant \
  --input-type qsiprep \
  --recon-spec mrtrix_singleshell_ss3t_ACT-hsvs \
  --participant-label 001 \
  --fs-license-file /opt/freesurfer/license.txt \
  --fs-subjects-dir /freesurfer \
  --work-dir /work \
  --nthreads 8 \
  --omp-nthreads 8 \
  --output-resolution 2 \
  --atlases 4S156Parcels
```

### Internal MRtrix workflow (conceptual)

1. Estimate FODs (`dwi2fod` / SS3T CSD)
2. Build HSVS / 5TT tissue map in T1w space from FreeSurfer surfaces
3. Run ACT tractography:

```bash
tckgen -act <5tt_in_T1w.nii.gz> \
  -algorithm iFOD2 \
  -backtrack \
  -crop_at_gmwmi \
  -select 10000000 \
  <wm_mtnorm.mif> \
  tracked.tck
```

4. Apply SIFT2 weighting; optionally build an atlas connectome:

```bash
tck2connectome <streamlines.tck> <4S156_dseg.mif> connectivity.mat
```

### Key outputs

- `sub-001_ses-1_*_space-T1w_model-ifod2_streamlines.tck.gz`
- `sub-001_ses-1_*_space-T1w_connectivity.mat`
- `sub-001/anat/sub-001_space-fsnative_seg-hsvs_probseg.mif.gz`

The tractogram is in **QSIPrep T1w space**. FreeSurfer provides surfaces and tissue information for HSVS/5TT; it does not define the tractography voxel grid.

---

## Step 4 — Post-hoc Desikan–Killiany connectome

### Purpose

Build an **84-node DK connectome** from the QSIRecon tractogram and FreeSurfer `aparc+aseg.mgz`.

### Coordinate alignment

FreeSurfer labels must be warped into the **QSIPrep DWI reference grid** before `tck2connectome` counts streamline endpoints.

| Volume / stage | Space |
|----------------|-------|
| `aparc+aseg.mgz` | FreeSurfer conformed (256³ @ 1 mm) |
| After Step 4a | Native T1w (`rawavg.mgz` grid) |
| After Step 4b-2 | QSIPrep `desc-preproc_T1w` (~1 mm) |
| After Step 4b-3 | QSIPrep T1w / `dwiref` grid (~2 mm) |

Labels are moved from conformed space to native space, then warped into QSIPrep anatomical space via an **empirical affine** (BIDS T1w → `desc-preproc_T1w`), then resampled onto the tractography `dwiref` grid.

**Why not QSIPrep’s `from-orig_to-T1w` / `from-T1wNative_to-T1wACPC`?** Those transforms assume QSIPrep’s reoriented T1wNative frame. FreeSurfer `rawavg.mgz` and the BIDS T1w share scanner-native headers; applying QSIPrep’s packaged `.mat` alone mis-aligns labels by ~20+ mm in ITK-SNAP QC. The affine registration bridges BIDS T1w to `desc-preproc_T1w` empirically.

For multi-session datasets, select BIDS T1w, `desc-preproc_T1w`, and `dwiref` from the **same session** as the tractogram.

### Containers

| Sub-step | Container |
|----------|-----------|
| 4a — `mri_label2vol` | `freesurfer_7.4.1.sif` |
| 4b–4f — ANTs, MRtrix | `qsirecon.sif` |

```bash
# Step 4a
apptainer exec ... "${CONTAINER_FREESURFER}" bash -lc 'mri_label2vol ...'

# Steps 4b–4f
apptainer exec ... "${CONTAINER_QSIRECON}" bash -lc 'antsRegistration ...; antsApplyTransforms ...; labelconvert ...; tck2connectome ...'
```

Bind mounts: FreeSurfer subject dir, BIDS input, QSIPrep output, QSIRecon output, DK output directory, license, and FreeSurfer LUT.

### Step 4a — Warp labels to native space

```bash
mri_label2vol --seg /fs_subject/mri/aparc+aseg.mgz \
  --temp /fs_subject/mri/rawavg.mgz \
  --o /out/aparc+aseg_in_rawavg.mgz \
  --regheader /fs_subject/mri/aparc+aseg.mgz
```

Output: `aparc+aseg_in_rawavg.mgz` on the native T1w grid.

### Step 4b — Warp labels into QSIPrep space (three sub-steps)

#### 4b-1 — Affine register BIDS T1w → `desc-preproc_T1w`

```bash
mri_convert /out/aparc+aseg_in_rawavg.mgz /out/aparc+aseg_in_rawavg.nii.gz

antsRegistration --dimensionality 3 --float 0 \
  --output [/out/native_to_preproc_T1w_,/out/native_to_preproc_T1w_Warped.nii.gz] \
  --interpolation Linear \
  --winsorize-image-intensities [0.005,0.995] \
  --use-histogram-matching 1 \
  --transform Affine[0.1] \
  --metric MI[/qsiprep/sub-001/anat/sub-001_desc-preproc_T1w.nii.gz,/bids/sub-001/ses-1/anat/sub-001_ses-1_T1w.nii.gz,1,32] \
  --convergence [500x250x100,1e-6,10] \
  --shrink-factors 4x2x1 \
  --smoothing-sigmas 2x1x0vox
```

Output: `native_to_preproc_T1w_0GenericAffine.mat` (empirical native/BIDS → QSIPrep T1w).

#### 4b-2 — Apply affine to native labels → QSIPrep T1w grid

```bash
antsApplyTransforms -d 3 \
  -i /out/aparc+aseg_in_rawavg.nii.gz \
  -r /qsiprep/sub-001/anat/sub-001_desc-preproc_T1w.nii.gz \
  -t /out/native_to_preproc_T1w_0GenericAffine.mat \
  -n GenericLabel \
  -o /out/aparc+aseg_in_t1w.nii.gz
```

| Flag | Role |
|------|------|
| `-r desc-preproc_T1w` | QSIPrep anatomical reference (~1 mm) |
| `-t native_to_preproc_T1w_0GenericAffine.mat` | BIDS/scanner-native → QSIPrep T1w |
| `-n GenericLabel` | Label-safe interpolation |

Output: `aparc+aseg_in_t1w.nii.gz` on the QSIPrep T1w grid.

#### 4b-3 — Resample onto the tractography `dwiref` grid

```bash
antsApplyTransforms -d 3 \
  -i /out/aparc+aseg_in_t1w.nii.gz \
  -r /qsiprep/sub-001/ses-1/dwi/sub-001_ses-1_*_space-T1w_dwiref.nii.gz \
  -n GenericLabel \
  -o /out/aparc+aseg_in_dwi.nii.gz
```

| Flag | Role |
|------|------|
| `-r dwiref` | Target grid (QSIPrep T1w tractography reference, ~2 mm) |
| `-n GenericLabel` | Label-safe interpolation (no transform — same space, different grid) |

Output: `aparc+aseg_in_dwi.nii.gz` aligned to the tractogram grid.

### Step 4c — Map labels to DK node indices

```bash
labelconvert -force /out/aparc+aseg_in_dwi.nii.gz \
  /opt/freesurfer/FreeSurferColorLUT.txt \
  /opt/mrtrix3-latest/share/mrtrix3/labelconvert/fs_default.txt \
  /out/dk_nodes.mif
```

Maps FreeSurfer label IDs to DK node indices (1–84).

### Step 4d — Prepare tractogram

MRtrix 3.0.4 may require an uncompressed `.tck`:

```bash
gunzip -c /qsirecon/.../streamlines.tck.gz > /out/streamlines.tck
```

### Step 4e — Quality control

Confirm tractogram and node image share a compatible grid:

```bash
mrinfo /out/dk_nodes.mif      | tee /out/dk_nodes.mrinfo.txt
tckinfo /out/streamlines.tck  | tee /out/tracks.tckinfo.txt
```

`dk_nodes.mif` dimensions and voxel size should match the preprocessed DWI / `dwiref` image.

### Step 4f — Build connectome matrix

```bash
tck2connectome -force \
  /out/streamlines.tck \
  /out/dk_nodes.mif \
  /out/dk_connectome.csv \
  -symmetric \
  -zero_diagonal \
  -out_assignments /out/dk_assignments.csv
```

For each streamline, MRtrix reads endpoint voxels in `dk_nodes.mif` and increments the corresponding entry in the symmetric matrix **M[i, j]**.

### DK outputs

Directory: `dk_connectomes/sub-001/`

| File | Description |
|------|-------------|
| `dk_connectome.csv` | 84 × 84 symmetric streamline-count matrix |
| `dk_assignments.csv` | Per-streamline node-pair assignments |
| `aparc+aseg_in_rawavg.mgz` | Labels on native T1w grid |
| `native_to_preproc_T1w_0GenericAffine.mat` | Empirical BIDS T1w → `desc-preproc_T1w` affine |
| `aparc+aseg_in_t1w.nii.gz` | Labels on QSIPrep `desc-preproc_T1w` grid |
| `aparc+aseg_in_dwi.nii.gz` | Labels resampled to tractography `dwiref` grid |
| `dk_nodes.mif` | MRtrix label image (84 DK nodes) |
| `dk_nodes.mrinfo.txt` | Node image metadata (QC) |
| `tracks.tckinfo.txt` | Tractogram metadata (QC) |

---

## How the spaces connect

| Stage | Space |
|-------|-------|
| QSIPrep / QSIRecon tractography | QSIPrep T1w, 2 mm DWI reference grid |
| FreeSurfer `aparc+aseg.mgz` | FreeSurfer conformed space |
| DK connectome | FreeSurfer labels warped into QSIPrep T1w / `dwiref` space |

Streamlines and DK nodes must share the same coordinate frame before connectome generation.

---

## Running the pipeline

### Full run (one subject)

```bash
export BIDS_DIR=.../data_bids
export RESULTS_ROOT=.../dwi_test2
export PIPELINE_MODE=all
export QSIRECON_SPEC=mrtrix_singleshell_ss3t_ACT-hsvs
export QSIRECON_ATLASES=4S156Parcels
export RUN_RECON=1
export RECON_TOOL=freesurfer
export RUN_DK_CONNECTOME=1

bash dwi_pipeline/subject.sh all 001
```

### Individual stages

```bash
bash dwi_pipeline/subject.sh qsiprep 001
bash dwi_pipeline/subject.sh recon 001
bash dwi_pipeline/subject.sh qsirecon 001
bash dwi_pipeline/subject.sh dk 001
```

### Stage dependencies

| Stage | Requires |
|-------|----------|
| `qsiprep` | BIDS input |
| `recon` | BIDS T1w |
| `qsirecon` | QSIPrep + recon outputs |
| `dk` | QSIRecon + recon outputs |

QSIPrep and recon can run in parallel. QSIRecon needs both. The DK step needs the tractogram, parcellation, and QSIPrep transforms.

### Slurm submission

```bash
export RESULTS_ROOT=.../dwi_test2
export SUBJECT_LIST_FILE=dwi_pipeline/subjects.txt
./dwi_pipeline/submit.sh
```

---

## Two connectomes, one tractogram

The same tractogram can support two connectome outputs:

| Output | Parcellation | Produced by |
|--------|--------------|-------------|
| `*_connectivity.mat` | 4S156 (156 regions) | QSIRecon built-in atlas connectome |
| `dk_connectome.csv` | Desikan–Killiany (84 regions) | Post-hoc DK step |

Only the label map differs; the underlying streamline set is the same.

---

## Validation checklist

| Check | Expected |
|-------|----------|
| QSIPrep | SDC applied; TOPUP when fieldmaps are in BIDS |
| FreeSurfer / FastSurfer | `freesurfer/sub-XXX/mri/aparc+aseg.mgz` and `rawavg.mgz` exist |
| QSIRecon | Workflow completes; ~10 million streamlines |
| DK log | Reports three-hop warp: conformed → native → QSIPrep T1w (affine) → `dwiref` |
| `dk_nodes.mrinfo.txt` | Grid matches preprocessed DWI / `dwiref` |
| `dk_connectome.csv` | Few or no isolated DK nodes |

---

## Summary

**QSIPrep** defines the tracking space. **FreeSurfer** defines anatomical labels. **QSIRecon** generates streamlines in QSIPrep T1w space. The **DK step** warps labels through native T1w, an empirical affine into `desc-preproc_T1w`, and a final resample onto `dwiref`, then assigns streamline endpoints with `tck2connectome`.

```
Tractography space  = QSIPrep T1w / dwiref grid (~2 mm)
DK node space       = FreeSurfer labels → native T1w → desc-preproc_T1w → dwiref
```

Both must align before the connectome matrix is computed.
