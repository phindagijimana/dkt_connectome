# Pipeline steps

What happens inside each step of the DKT Connectome. For outputs, see [Outputs](outputs.md). For **theory, biology, and citations**, see the [Methods](methods/index.md) section (QSIPrep-style, one page per step). For citation tables only, see [References by step](references.md).

---

## Overview

```text
Step 1    QSIPrep           DWI + T1w preprocessing, SDC (fmap or SyN)
Step 1.5  Inpaint           neuroLIT lesion fill (auto when BIDS lesion mask)
Step 2    Recon             FreeSurfer or FastSurfer → DKT parcellation
Step 3    QSIRecon          SS3T-CSD, ACT-HSVS tractography, SIFT2 weights
Step 4    Connectome        DKT 78-node matrix (default: streamline counts)
Step 4.5  Disconnectome     Options A/B/C + disconnection matrix (--disconnection; needs lesion mask)
Step 5    Node strength     ENIGMA-style report (auto after Step 4)
```

---

## Step 1 — QSIPrep

**Tool:** [QSIPrep](https://qsiprep.readthedocs.io/) (`qsiprep.sif`)

**Inputs:** BIDS `dwi/`, `anat/T1w`, optional `fmap/` (via dwi-select filter)

**Processing:**

1. Validate / filter BIDS entities (dwi-select or static filter)
2. Susceptibility distortion correction (fieldmap TOPUP or SyN)
3. Motion correction, denoising, brain extraction
4. T1w–DWI coregistration
5. Write preprocessed DWI, T1w, transforms, QC reportlets

**Key outputs:** `qsiprep_single_run_output/sub-<ID>/ses-<Y>/dwi/*_desc-preproc_dwi.nii.gz`

**SDC decision tree:** see [Preparing your data](preparing_data.md#sdc-decision-tree).

**References:** [Step 1 — QSIPrep (methods)](methods/step1_qsiprep.md) · [References table](references.md#step-1-qsiprep-preprocessing) (Cieslak et al. 2021; Andersson et al. 2003/2016).

---

## Step 1.5 — Inpaint (optional)

**Tool:** [neuroLIT](https://github.com/Deep-MI/lit) (`lit_0.6.0.sif`)

**Trigger:** sibling `*_T1w_label-lesion_roi.nii.gz` in BIDS for the session

**Processing:**

1. Resample / dilate lesion mask on T1w grid
2. Inpaint lesion region on T1w before recon
3. QC metrics (`inpainting.json`)

**Skip:** `--no-inpaint`, or no mask present (silent no-op)

**References:** [Step 1.5 — Inpainting (methods)](methods/step1_5_inpaint.md) · [References table](references.md#step-15-neurolit-inpainting-optional) (Pollak et al. 2025; Ho et al. 2020).

---

## Step 2 — Recon

**Tool:** FreeSurfer `recon-all` or [FastSurfer](https://github.com/Deep-MI/FastSurfer)

**Input T1w:** inpainted T1w when Step 1.5 ran; otherwise QSIPrep preprocessed T1w

**Processing:**

1. Surface reconstruction and parcellation
2. DKT atlas labels (`aparc.DKTatlas+aseg.mgz`) for Step 4

**Key outputs:** `freesurfer/sub-<ID>/`

**References:** [Step 2 — Recon (methods)](methods/step2_recon.md) · [References table](references.md#step-2-cortical-reconstruction-freesurfer-fastsurfer) (Fischl 2012; Henschel et al. 2020; Klein & Tourville 2012).

---

## Step 3 — QSIRecon

**Tool:** [QSIRecon](https://qsirecon.readthedocs.io/) (`qsirecon.sif`)

**Spec:** `mrtrix_singleshell_ss3t_ACT-hsvs` (default)

**Processing:**

1. SS3T-CSD on preprocessed DWI
2. ACT-HSVS tractography (~10M streamlines)
3. SIFT2 streamline weights
4. Optional atlas connectome (4S156)

**Requires:** FreeSurfer subject tree from Step 2 for ACT-HSVS

**References:** [Step 3 — Tractography (methods)](methods/step3_qsirecon.md) · [References table](references.md#step-3-qsirecon-tractography) (Cieslak et al. 2024; Tournier et al. 2019; Smith et al. 2012/2015/2020).

---

## Step 4 — Connectome

**Tool:** `dkt_connectome.sif` (FreeSurfer + ANTs + MRtrix3)

**Processing:**

1. Build DKT parcellation on DWI grid (`nodes.mif`)
2. Assign streamlines to 78 DKT nodes
3. Write connectome matrix (default: **streamline counts**)

**Primary output:** `connectomes/sub-<ID>/dkt_connectome.csv`

**References:** [Step 4 — Connectome (methods)](methods/step4_connectome.md) · [References table](references.md#step-4-dkt-structural-connectome) (Tournier et al. 2019; Klein & Tourville 2012).

---

## Step 4.5 — Disconnectome (optional)

**Trigger:** `--disconnection` flag + prepared lesion mask + DKT connectome from Steps 1.5 and 4

**Processing:**

1. Binary union of core + oedema (no erosion by default)
2. Option A: parcellation excision
3. Option B: streamline exclusion
4. Option C: both A and B
5. Disconnection matrix D = 1 − spared/primary

**Skip:** omit `--disconnection` (default), `--no-disconnectome`, or no lesion mask

Full method: [Disconnectome](disconnectome.md) · Theory: [Step 4.5 — Disconnectome (methods)](methods/step4_5_disconnectome.md).

**References:** [References table](references.md#step-45-disconnectome-optional) (Griffis et al. 2019; Kuceyeski et al. 2013).

---

## Step 5 — Node strength

**Tool:** `nodestrength_0.1.0.sif`

**Trigger:** Step 4 connectome exists

**Processing:**

1. Node strength metrics from connectome
2. ENIGMA-style cortical surface + subcortical panel
3. PDF report

**Skip:** `--no-node-strength`

**References:** [Step 5 — Node strength (methods)](methods/step5_node_strength.md) · [References table](references.md#step-5-node-strength-report) (Rubinov & Sporns 2010; Piper et al. 2026).

---

## QC and reporting

After each participant run, `./run` writes:

- `qc/sub-<ID>/subject_qc.html` — unified dashboard (Steps 1–5)
- `disconnectome/.../disconnectome_qc.html` — when Step 4.5 ran

Group level: `./run … group` → `cohort_qc.html` + BIDS Derivatives export.

See [QC dashboard](qc_dashboard.md).

---

## Snakemake engine

All steps above are implemented as Snakemake **plugin rules** under `dwi_pipeline/workflow/rules/`. The full DAG, targets, and HPC usage are documented in [Snakemake workflow](snakemake_workflow.md).

**Framework references:** [Data standards and workflow](references.md#data-standards-and-workflow-framework) (Gorgolewski et al. 2016/2017; Köster & Rahmann 2012).

```bash
# Equivalent to ./run participant for sub-011
snakemake -s workflow/Snakefile --cores 8 --config subject=011 -- all
```
