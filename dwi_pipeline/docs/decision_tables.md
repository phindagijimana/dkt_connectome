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

## Lesion inpainting (Step 1.1)

| Situation | Behavior |
|-----------|----------|
| BIDS `*_T1w_label-lesion_roi.nii.gz` present | Auto Step 1.1 before recon (default backend: neuroLIT) |
| No mask | Silent skip (raw T1w → Step 2) |
| Mask present but skip desired | `--no-inpaint` or `--anat-mitigation none` |
| LeAPP-compatible VBT instead of neuroLIT | `--anat-mitigation vbt` |
| QC failure should abort run | `INPAINT_FAIL_ON_QC=1` |

---

## Anatomical mitigation backend (Step 1.1)

| Goal | Flag | Output directory | Cite when publishing |
|------|------|------------------|----------------------|
| Production default (learned inpainting) | `--anat-mitigation neurolit` or *(default)* | `inpainted/` | Pollak et al. 2025 |
| Deterministic contralesional fill (LeAPP port) | `--anat-mitigation vbt` | `vbt/` | Bey et al. 2024 (LeAPP VBT) |
| Sensitivity: no anatomical fill | `--anat-mitigation none` | *(Step 1.1 skipped)* | — |

Both backends write the same filename for Step 2: `inpainting_volumes/inpainting_result.nii.gz`. Theory: [Step 1.1 methods](methods/step1_1_inpaint.md).

---

## Lesion-aware ACT (Step 3.1)

| Goal | Flag | Tractogram source for Step 4 | Cite when publishing |
|------|------|------------------------------|----------------------|
| Default cohort processing | *(none)* / `--act-mode standard` | QSIRecon iFOD2 + SIFT2 | Smith et al. 2012/2020 (ACT-HSVS) |
| Insert lesion into 5TT pathology channel | `--act-mode lesion-aware` | Rebuilt iFOD2 + SIFT2 under `lesion_aware_act/` | Bey et al. 2024; Smith et al. 2012 ACT |
| HSVS ACPC base 5TT (default) | `--act-5tt-source hsvs` (default) | QSIRecon HSVS → ACPC `5ttedit` → dwiref | Smith et al. 2020 HSVS |
| Native Deep Atropos base 5TT | `--act-5tt-source deep-atropos-native` | ANTsPyNet seg → native `5ttedit` → dwiref | Sensitivity vs HSVS; [Deep Atropos branch](deep_atropos_5tt.md) |
| Import external Deep Atropos segs | `--deep-atropos-seg-mode import` | Skip ANTsPyNet; require external seg | — |
| Generate segs in-pipeline | `--deep-atropos-seg-mode generate` | Run `dkt_deep_atropos_seg.sif` | Pilot / no external segs |
| Re-run Step 3.1 only | `--mode act` | — | — |
| Deterministic robustness matrices | `--tractography-model both` | Parallel SD_STREAM connectomes | Tournier et al. 2019 |

Requires lesion mask. Uses **original BIDS mask** for 5TT editing (not the inpainted region). Theory: [Step 3.1 methods](methods/step3_1_lesion_act.md).

---

## Experiment arms (anatomy × ACT) {#experiment-arms}

Use when running factorial sensitivity analyses on lesion subjects, following the LeAPP design (Bey et al. 2024). **One arm per `RESULTS_ROOT` tree** (default: `RESULTS_ROOT/arms/<arm>/`).

| Arm | Anatomy | ACT | When to use | Primary citations for contrasts |
|-----|---------|-----|-------------|-------------------------------|
| `orig-std` | Original T1w | Standard | Baseline | — |
| `orig-lesion` | Original T1w | Lesion-aware | Tractography-only lesion handling | Smith et al. 2012; Bey et al. 2024 |
| `neurolit-std` | neuroLIT | Standard | Inpainting effect on surfaces/DKT | Pollak et al. 2025 |
| `neurolit-lesion` | neuroLIT | Lesion-aware | Inpainting + pathology ACT | Pollak et al. 2025; Bey et al. 2024 |
| `vbt-std` | VBT | Standard | Compare VBT vs neuroLIT anatomy | Bey et al. 2024 |
| `vbt-lesion` | VBT | Lesion-aware | Full factorial (validate on TBI first) | Bey et al. 2024 |

**Publishing guidance:** Report which arms were run and isolate outputs per arm. Do not pool connectomes across arms without harmonizing anatomy and tractography provenance. Cite Bey et al. 2024 for the factorial framework; add backend-specific papers per row above.

```bash
bash submit.sh --experiment-arm neurolit-lesion
bash workflow/run_subject.sh all ID --experiment-arm vbt-std
```

Full flag reference: [Usage — experiment arms](usage.md) · [References § Experiment arms](references.md#experiment-arms-factorial-lesion-processing).

---

## Connectome weighting (Steps 4 & 4.1)

| Weighting | When to use | Step 4.1 requirement | Cite |
|-----------|-------------|----------------------|------|
| **`count`** (default) | Group comparisons, standard graphs | Use same for disconnectome | Tournier et al. 2019 |
| **`sift2`** | Quantitative density interpretation | **Must** match Step 4; mismatch invalidates D matrix | Smith et al. 2015 |

Step 4 also writes **MeanLength, MeanFA, MeanMD** from the same tractogram. Interpret diffusion metrics cautiously (Jones et al. 2013). See [Step 4 methods](methods/step4_connectome.md#multi-measure-connectomes-one-tractogram).

---

## Disconnectome (Step 4.1)

| Situation | Flag |
|-----------|------|
| Standard connectome only | *(default — off)* |
| Lesion disconnection analysis | `--disconnection` |
| Sensitivity: core only | `--disconnectome-core-only` |
| Sensitivity: eroded lesion | `--disconnectome-erode-voxels 1` |
| Standalone re-run | `--mode disconnectome` |

Requires: lesion mask from Step 1.1 + DKT connectome from Step 4.

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
