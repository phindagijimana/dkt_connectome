# Pipeline steps

What happens inside each step of the DKT Connectome. **Theory and rationale:** [Science overview](science_overview.md) and [Methods](methods/index.md). For outputs, see [Outputs](outputs.md). For citation tables, see [References by step](references.md).

---

## Overview

![Pipeline workflow sketch](img/pipeline_overview.svg)

```text
Step 1    QSIPrep           DWI + T1w preprocessing, SDC (fmap or SyN)
Step 1.5  Inpaint           Lesion anatomical mitigation (neuroLIT default; optional VBT)
Step 2    Recon             FreeSurfer or FastSurfer → DKT parcellation
Step 3    QSIRecon          SS3T-CSD, ACT-HSVS tractography, SIFT2 weights
Step 3.5  Lesion-aware ACT  Optional: rebuild tractography with lesion in 5TT (--act-mode lesion-aware)
          ├─ default        QSIRecon HSVS base 5TT → ACPC 5ttedit → dwiref → tckgen
          └─ optional       3.5a-seg → 3.5a native 5TT → 3.5 (--act-5tt-source deep-atropos-native)
Step 4    Connectome        DKT 78-node matrices (Count, MeanLength, MeanFA, MeanMD; optional SIFT2)
Step 4.5  Disconnectome     Options A/B/C + disconnection matrix (--disconnection; needs lesion mask)
Step 5    Node strength     ENIGMA-style report (auto after Step 4)
```

Deep Atropos branch details: [Deep Atropos native-T1 5TT](deep_atropos_5tt.md).

**Experiment arms:** `--experiment-arm` sets Step 1.5 backend and Step 3.5 ACT together — see [Usage — experiment arms](usage.md).

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

**Tools:** [neuroLIT](https://github.com/Deep-MI/lit) (`lit_0.6.0.sif`, default) or LeAPP-compatible **virtual brain transplant** (`--anat-mitigation vbt`)

**Trigger:** sibling `*_T1w_label-lesion_roi.nii.gz` in BIDS for the session

**Processing:**

1. Resample / dilate lesion mask on T1w grid
2. Fill or transplant lesion region on T1w before recon (`neurolit` or `vbt`)
3. QC metrics (`inpainting.json`)

**Skip:** `--no-inpaint` / `--anat-mitigation none`, or no mask present (silent no-op)

**References:** [Step 1.5 — Inpainting (methods)](methods/step1_5_inpaint.md) · [Lesion-aware tractography](lesion_aware.md) · [References table](references.md#step-15-anatomical-lesion-mitigation-optional) (Pollak et al. 2025; Bey et al. 2024).

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

## Step 3.5 — Lesion-aware ACT (optional)

**Tools:** `dkt_lesion_act.sif` (always); optionally `dkt_deep_atropos_seg.sif` + `dkt_deep_atropos.sif` when `--act-5tt-source deep-atropos-native`

**Trigger:** `--act-mode lesion-aware` or an `*-lesion` [experiment arm](usage.md)

**Processing (shared pathology edit — LeAPP-style):**

1. Build or load base 5TT (HSVS ACPC **or** Deep Atropos native T1w)
2. Resample **original BIDS** lesion mask into the **5TT reference grid**
3. Insert pathology with `5ttedit -path`; validate with `5ttcheck`
4. Resample edited 5TT → `dwiref`; clip and renormalize tissue fractions (sum to 1)
5. Rebuild matched iFOD2 tractography and SIFT2 weights

**5TT sources:**

| Source | Flag | Base 5TT | Edit grid |
|--------|------|----------|-----------|
| HSVS (default) | `hsvs` | QSIRecon ACPC HSVS | ACPC (`five_tt_ref` / channel 0) |
| Deep Atropos | `deep-atropos-native` | `deep_atropos/sub-<ID>/base_5tt_native.mif` | Native BIDS T1w |

**Key outputs:**

| Path | Description |
|------|-------------|
| `lesion_aware_act/sub-<ID>/model-ifod2_streamlines.tck` | Rebuilt tractogram |
| `lesion_aware_act/sub-<ID>/model-sift2_streamlineweights.csv` | SIFT2 weights |
| `lesion_aware_act/sub-<ID>/lesion_aware_act.json` | Provenance |
| `deep_atropos_seg/sub-<ID>/desc-deepatropos_seg.nii.gz` | Deep Atropos seg (optional branch) |
| `deep_atropos/sub-<ID>/base_5tt_native.mif` | Native 5TT (optional branch) |

Step 4 uses these tractograms when lesion-aware mode is active.

**References:** [Step 3.5 methods](methods/step3_5_lesion_act.md) · [Deep Atropos branch](deep_atropos_5tt.md) · (Bey et al. 2024; Smith et al. 2012).

---

## Step 4 — Connectome

**Tool:** `dkt_connectome.sif` (FreeSurfer + ANTs + MRtrix3)

**Processing:**

1. Build DKT parcellation on DWI grid (`nodes.mif`)
2. Assign streamlines to 78 DKT nodes (standard QSIRecon or lesion-aware ACT tractogram)
3. Write connectome matrices: **Count, MeanLength, MeanFA, MeanMD** (same tractogram)
4. Optional: **SIFT2** matrix with `--connectome-sift2` (separate Snakemake rule)
5. Copy primary measure to `dkt_connectome.csv` (default: count)

**Primary output:** `connectomes/sub-<ID>/dkt_connectome.csv`

Optional: `--tractography-model both` adds parallel SD_STREAM matrices (`*_model-SDSTREAM_*`).

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

See [Quality control](qc.md).

---

## Snakemake engine

All steps above are implemented as Snakemake **plugin rules** under `dwi_pipeline/workflow/rules/`. The full DAG, targets, and HPC usage are documented in [Snakemake workflow](snakemake_workflow.md).

**Framework references:** [Data standards and workflow](references.md#data-standards-and-workflow-framework) (Gorgolewski et al. 2016/2017; Köster & Rahmann 2012).

```bash
# Equivalent to ./run participant for sub-011
snakemake -s workflow/Snakefile --cores 8 --config subject=011 -- all
```
