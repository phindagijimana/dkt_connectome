# rs-fMRI resources (fMRIPrep, XCP-D, fMRIStroke)

Optional **resting-state fMRI** path for TrackTBI / Paper 2 lives in the repository’s **`fMRI_pipeline/`** tree (local pilot scripts; not part of the DKT Connectome Snakemake app). This page ties **literature**, **tool roles**, and **official fMRIStroke documentation** to how we run cohorts.

For structural (DWI) citations, see [References by step](references.md). For **each fMRI stage, scripts, containers, and outputs**, see [`fMRI_pipeline/fmri_pipeline.md`](../../fMRI_pipeline/fmri_pipeline.md). Science and arms A–D: `fMRI_pipeline/FC.md`; fMRIStroke ops: `fMRI_pipeline/configs/fmristroke.md`.

---

## Are these the papers fMRIStroke refers to?

**Yes.** The citations at the bottom of [fMRIStroke — Outputs](https://fmristroke.readthedocs.io/en/latest/outputs.html) are the methodological sources fMRIStroke builds on. They appear in the tool docs as `[Yourganov2017]`, `[Siegel2016]`, `[Siegel2017]`, and `[Scheafer2018]` (Schaefer atlas spelling in the upstream docs).

| Tag | Role in fMRIStroke | Reference |
|-----|-------------------|-----------|
| **Yourganov2017** | Lesion-aware denoising: WM/CSF + **ICA components overlapping the lesion ROI** (`ICLesionGS`, `SimpleLesionGS`); core stroke rs-fMRI artifact removal | Yourganov G, Fridriksson J, Stark B, Rorden C. Removal of artifacts from resting-state fMRI data in stroke. *Neuroimage Clin* 2017. [10.1016/j.nicl.2017.10.027](https://doi.org/10.1016/j.nicl.2017.10.027) |
| **Siegel2016** | **Hemodynamic lag** after stroke distorts FC; motivates lag maps in fMRIStroke QC | Siegel JS, Snyder AZ, Ramsey L, Shulman GL, Corbetta M. The effects of hemodynamic lag on functional connectivity and behavior after stroke. *J Cereb Blood Flow Metab* 2016. [10.1177/0271678X15614846](https://doi.org/10.1177/0271678X15614846) |
| **Siegel2017** | Practical guidance on **measuring FC in stroke** (lag, exclusions); supports interpreting lag reports | Siegel JS, Shulman GL, Corbetta M. Measuring functional connectivity in stroke: Approaches and considerations. *J Cereb Blood Flow Metab* 2017. [10.1177/0271678X17709198](https://doi.org/10.1177/0271678X17709198) |
| **Schaefer2018** | Default **atlas for fMRIStroke connectivity matrices** (400 ROIs / Yeo networks); not the DKT graph used for SC–FC coupling in our pipeline | Schaefer A, Kong R, Gordon EM, Laumann TO, Zuo XN, Holmes AJ, Eickhoff SB, Yeo BTT. Local-global parcellation of the human cerebral cortex from intrinsic functional connectivity MRI. *Cerebral Cortex* 2018. [10.1093/cercor/bhx179](https://doi.org/10.1093/cercor/bhx179) |

**Implementation paper (tool itself):** Lamouroux A, Lioi G, Coloigner J, Maurel P, Farrugia N. fMRIStroke: A preprocessing pipeline for fMRI Data from Stroke patients. *JOSS* 2024. [10.21105/joss.06636](https://doi.org/10.21105/joss.06636) · [GitHub alixlam/fmristroke](https://github.com/alixlam/fmristroke)

---

## How fMRIPrep and fMRIStroke connect

fMRIStroke is a **BIDS App that runs after fMRIPrep**. It does **not** read FreeSurfer `SUBJECTS_DIR` directly; it indexes **precomputed fMRIPrep derivatives** under `--fmriprep_dir`.

```text
BIDS (T1w, task-rest BOLD, optional *_label-lesion_roi.nii.gz)
        │
        ▼
   fMRIPrep  ──►  $OUT_ROOT/fmriprep/   (motion, SDC, BOLD→T1w, confounds, surfaces/fsLR if FS available)
        │
        ├──►  XCP-D (our primary FC stream; see below)
        │
        └──►  fMRIStroke  ──►  $OUT_ROOT/fmristroke/
              • Lesion on coregistration plots
              • Extra confounds (lesion signal, WM/CSF+lesion, ICA–lesion)
              • Lag / correlation maps (Siegel lineage)
              • Multiple denoised BOLD pipelines (Yourganov-style JSON strategies)
              • Optional Schaefer connectivity `.npy` (not DKT)
```

**Inputs fMRIStroke expects (official):**

- **BIDS root:** T1w, rs-fMRI, binary lesion mask with `_roi` suffix in `anat/` (see [Usage Notes](https://fmristroke.readthedocs.io/en/latest/usage.html)); `.bidsignore` entry for `*_roi.nii.gz` if needed.
- **`--fmriprep_dir`:** fMRIPrep derivative tree (T1w-space preproc BOLD, brain masks, confounds TSV, and FreeSurfer-derived segmentations in the layout its grabber expects).

**Outputs (summary):** See [Outputs of fMRIStroke](https://fmristroke.readthedocs.io/en/latest/outputs.html) — HTML QC (coregistration with ROI, hemodynamic lag maps), extended `desc-confounds_timeseries`, `pipeline-*_desc-denoised_bold`, and optional atlas connectivity matrices.

**Version note (TrackTBI pilot):** fMRIStroke **1.0.0** documents compatibility with fMRIPrep derivatives from versions **prior to 24.0.0**; our pilot uses **fMRIPrep 24.1.1**. **`run_fmristroke.sh`** runs **`stage_fmristroke_fmriprep_anat.sh`** first to write `desc-aseg` / `desc-aparcaseg` dseg NIfTIs from `FS_SUBJECTS_DIR` onto the `desc-preproc_T1w` grid (see `fMRI_pipeline/configs/fmristroke.md`).

---

## Is fMRIStroke a substitute for XCP-D?

**No — not in our prespecified pipeline.**

| | **XCP-D** (Stage 2) | **fMRIStroke** (optional Stage 1b) |
|---|---------------------|--------------------------------------|
| **Runs on** | fMRIPrep derivatives only | BIDS + fMRIPrep derivatives |
| **Primary goal** | Standard post-fMRIPrep denoising + **LINC/fsLR** atlas FC (Gordon, HCP, 4S, …) | **Stroke-specific** QC, confounds, ICA–lesion denoising, **lag maps** |
| **Lesion logic** | None (generic 36P-style path in our `run_xcpd.sh`) | Lesion signal, WM/CSF+lesion, ICLesionGS ([Yourganov2017](https://doi.org/10.1016/j.nicl.2017.10.027)) |
| **DKT aligned with SC** | Via our **Stage 3–4** (`postprocess_dkt.py` + `apply_lesion_fc_mask.py`) on XCP-D (or fMRIPrep fallback BOLD in LINC mode) | Optional **Stages 3b–4b** on fMRIStroke denoised BOLD, same DKT + lesion censoring |
| **Default atlas FC inside tool** | Gordon / HCP / 4S / Glasser (XCP-D 0.10.6) | Schaefer400 by default ([Schaefer2018](https://doi.org/10.1093/cercor/bhx179)) |

**Recommended use here:** Treat **XCP-D + DKT stages 3–4** as the **primary empirical FC stream** for Paper 2 (fsLR/LINC + SC-aligned DKT graph). Run **fMRIStroke in parallel** on the **same fMRIPrep run** for **sensitivity analysis, lag QC, and lesion-aware denoising**—then pick **one primary FC definition** in the analysis plan. fMRIStroke does **not** replace the DWI disconnectome or XCP-D’s role as the standard LINC postprocessor.

Official fMRIStroke wording: it **uses fMRIPrep outputs** and adds stroke-specific steps; it is **not** documented as a replacement for general-purpose postprocessors such as XCP-D.

---

## Quick map — rs-fMRI stack (TrackTBI)

| Stage | Tool | Primary references / docs |
|-------|------|---------------------------|
| 1 | fMRIPrep 24.1.1 | Esteban et al. 2019/2020 · [fMRIPrep outputs](https://fmriprep.org/en/stable/outputs.html) |
| 2 | XCP-D 0.10.6 | Mehta et al. 2024 (XCP-D) · PennLINC/XCP-D |
| 1b (optional) | fMRIStroke 1.0.0 | JOSS 2024 · [Usage](https://fmristroke.readthedocs.io/en/latest/usage.html) · [Outputs](https://fmristroke.readthedocs.io/en/latest/outputs.html) |
| 3–4 | `postprocess_dkt.py`, `apply_lesion_fc_mask.py` | DKT / SC alignment · Griffis-style parcel censoring (see `fMRI_pipeline/FC.md`) |
| 5 | `stage_fc_characterization_arms.py` (`--stream xcp_d`) | Arm B empirical FC disconnection (DKT-78) |
| 3b–4b (optional) | Same DKT scripts on fMRIStroke BOLD | Yourganov / ICLesionGS stream |
| 5b (optional) | `stage_fc_characterization_arms.py` (`--stream fmristroke`) | Arm B on fMRIStroke stream |

---

## External links

- [fMRIStroke documentation](https://fmristroke.readthedocs.io/en/latest/)
- [fMRIStroke — Outputs (confounds, denoising, connectivity)](https://fmristroke.readthedocs.io/en/latest/outputs.html)
- [fMRIPrep](https://fmriprep.org/)
- [XCP-D](https://github.com/PennLINC/xcp_d)
