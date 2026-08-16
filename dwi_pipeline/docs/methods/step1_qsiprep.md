# Step 1 — QSIPrep preprocessing

**Theory and methods** for diffusion MRI preprocessing in the DKT Connectome. Operational details: [Pipeline steps § Step 1](../pipeline_steps.md#step-1-qsiprep).

---

## Background

Diffusion-weighted imaging (DWI) measures water displacement along applied gradient directions. Before tractography, raw DWI must be corrected for:

- **Head motion** and **eddy-current distortions** (within- and between-volume)
- **Susceptibility-induced distortions** (EPI vs. T1w mismatch)
- **Noise** and **partial volume** effects at tissue boundaries
- **Brain extraction** and **T1w–DWI coregistration**

[QSIPrep](https://qsiprep.readthedocs.io/) is an integrative BIDS App that standardizes these steps with pinned containers and QC reportlets (Cieslak et al., *Nature Methods* 2021).

---

## What DKT Connectome runs

| Item | Value |
|------|-------|
| Container | `pennlinc/qsiprep:1.0.0` (`qsiprep.sif`) |
| Inputs | BIDS `dwi/`, `anat/T1w`, optional `fmap/` |
| DWI filter | Default: b = 1000 shell + IntendedFor fieldmaps (`dwi_select_b1000.json`) |
| SDC | Fieldmap TOPUP when fmaps are in the filter; otherwise **must** pass `--syn`, `--fmap-retry`, or `--no-sdc` |

### Processing sequence

1. **BIDS validation / filtering** — `dwi-select` or static filter JSON selects the intended DWI series and associated fieldmaps.
2. **Susceptibility distortion correction (SDC)** — preferred: reversed phase-encoding fieldmaps via FSL TOPUP (Andersson et al. 2003). Without fieldmaps: SyN-based distortion correction (Andersson et al. 2016) when `--syn` is passed.
3. **Motion and eddy correction** — FSL `eddy` (Andersson & Sotiropoulos 2016).
4. **Denoising** — MP-PCA or equivalent per QSIPrep workflow configuration.
5. **Brain extraction** — typically FSL BET / FAST-based methods (Zhang et al. 2001).
6. **T1w–DWI registration** — rigid/affine alignment so anatomical priors can guide downstream steps.
7. **QC reportlets** — HTML summaries under the QSIPrep output tree.

### Key outputs

```text
qsiprep_single_run_output/sub-<ID>/ses-<Y>/dwi/
  *_desc-preproc_dwi.nii.gz      # motion- and SDC-corrected DWI
  *_space-T1w_dwiref.nii.gz      # tractography reference grid (~2 mm)
  *_desc-preproc_T1w.nii.gz      # preprocessed structural reference
```

These files feed Steps 3 (tractography grid) and 4 (registration target).

### Lesion-aware registration

When a BIDS lesion mask (`*_T1w_label-lesion_roi.nii.gz`) is present, QSIPrep can use **cost-function masking** during T1w–DWI registration so the lesion region does not dominate the fit. The mask does not alter the DWI intensities themselves.

### What we pass through to QSIPrep

The orchestrator builds a per-subject BIDS filter (`build_bids_filter.py` + `dwi_select_b*.json`) and forwards these pipeline decisions:

| DKT Connectome flag | QSIPrep behavior |
|---------------------|------------------|
| *(default)* fmap in filter | Measured SDC (TOPUP / phasediff) |
| `--syn` | `--use-syn-sdc warn` when no fmap |
| `--fmap-retry` | `--ignore fieldmaps --use-syn-sdc warn` |
| `--no-sdc` | Skip SDC |
| `--bids-filter PATH` | Static `--bids-filter-file` |
| `--dwi-select PATH` | Custom dwi-select → generated filter |

Decision guide: [Decision tables § SDC](../decision_tables.md#susceptibility-distortion-correction-step-1). Sidecar repair: [BIDS metadata](../bids_metadata.md).

### Denoising and motion (inside QSIPrep)

QSIPrep applies MP-PCA denoising, Gibbs unringing (when configured), and FSL `eddy` motion correction as part of its default workflow. The DKT Connectome does not reimplement these — cite Cieslak et al. 2021 for preprocessing claims.

---

## Susceptibility distortion correction (SDC)

EPI-based DWI suffers from **susceptibility-induced geometric distortion** along the phase-encoding axis. Without correction, white-matter tracts and cortical boundaries misalign with T1w anatomy — a direct source of connectome error.

| Strategy | When used | Reference |
|----------|-----------|-----------|
| **Fieldmap TOPUP** | `fmap/` in dwi-select filter + valid `IntendedFor` | Andersson et al. 2003 |
| **SyN SDC** | No usable fieldmap; pass `--syn` | Andersson et al. 2016 |
| **No SDC** | Legacy only; pass `--no-sdc` | — |

Decision tree: [Preparing your data § SDC](../preparing_data.md#sdc-decision-tree) · Sidecar repair: [BIDS metadata](../bids_metadata.md).

---

## Design notes

- **Single-shell default (b = 1000):** matches the QSIRecon spec `mrtrix_singleshell_ss3t_ACT-hsvs` used in Step 3. Multi-shell data can be processed with a custom `--dwi-select` JSON, but the default reconstruction spec expects one non-zero shell.
- **QSIPrep is upstream:** cite Cieslak et al. 2021 for preprocessing claims; cite this pipeline only for orchestration choices (see [Citation](../citation.md)).

---

## References

| Topic | Citation | Link |
|-------|----------|------|
| **QSIPrep (required)** | Cieslak M, et al. QSIPrep. *Nature Methods* 2021 | [10.1038/s41592-021-01185-5](https://doi.org/10.1038/s41592-021-01185-5) |
| Fieldmap SDC | Andersson JLR, et al. TOPUP. *NeuroImage* 2003 | [10.1016/S1053-8119(03)00336-7](https://doi.org/10.1016/S1053-8119(03)00336-7) |
| SyN SDC | Andersson JLR, et al. *NeuroImage* 2016 | [10.1016/j.neuroimage.2016.06.058](https://doi.org/10.1016/j.neuroimage.2016.06.058) |
| Eddy/motion | Andersson JLR, Sotiropoulos SN. *NeuroImage* 2016 | [10.1016/j.neuroimage.2015.10.019](https://doi.org/10.1016/j.neuroimage.2015.10.019) |

Full table: [References § Step 1](../references.md#step-1-qsiprep-preprocessing).

---

## See also

- [Step 1.5 — Lesion inpainting](step1_5_inpaint.md)
- [Preparing your data](../preparing_data.md)
- [QSIPrep documentation](https://qsiprep.readthedocs.io/)
