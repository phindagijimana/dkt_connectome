# Step 3.1 — Lesion-aware ACT tractography

**Theory and methods** for rebuilding iFOD2/SIFT2 after inserting the lesion into the MRtrix five-tissue-type (5TT) pathology channel. Operational details: [Pipeline steps § Step 3.1](../pipeline_steps.md#step-31-lesion-aware-act-optional) · [Usage § lesion-aware flags](../usage.md) · [Lesion-aware tractography](../lesion_aware.md) · [Deep Atropos branch](../deep_atropos_5tt.md).

---

## Background

Standard **Anatomically Constrained Tractography (ACT)** uses a 5TT image with cortical GM, subcortical GM, WM, CSF, and a fifth **pathological / undefined** compartment (Smith et al. 2012). In the default QSIRecon spec (`mrtrix_singleshell_ss3t_ACT-hsvs`), that 5TT is built from FreeSurfer/FastSurfer segmentation on the T1w that Step 2 received — including any Step 1.1 anatomical mitigation.

If the lesion was **inpainted or transplanted**, the HSVS 5TT may label the former lesion site as apparently healthy tissue. Streamlines can then seed and terminate there under normal GM/WM priors, even though the underlying biology is pathological.

**Lesion-aware ACT** keeps the mitigated anatomy for parcellation and registration, but transforms the **original BIDS lesion mask** into the 5TT reference grid and assigns those voxels to the **pathology channel** with `5ttedit -path` before matched `tckgen` and `tcksift2` (LeAPP-style workflow; Bey et al. 2024).

The **HSVS ACPC path** and the **Deep Atropos native-T1 path** share the same pathology edit (resample lesion → `5ttedit -path` → renormalize tissue fractions). They differ only in **where the base 5TT lives** before that edit.

---

## What the pathology channel means

The fifth compartment is **not** a hard exclusion mask. It tells ACT that standard tissue priors are unreliable inside the lesion: streamlines may enter, traverse, or terminate in pathology voxels according to the diffusion model and ACT rules (Smith et al. 2012; MRtrix ACT documentation).

Lesion-aware ACT therefore answers: *How should tractography behave where anatomical priors are uncertain?* It does **not** prove axonal preservation or absence inside the lesion.

---

## Two base-5TT sources (`act.five_tt_source`)

| Source | Flag / config | Base 5TT grid | Lesion warp for `5ttedit` | Typical use |
|--------|---------------|---------------|---------------------------|-------------|
| **HSVS (default)** | `hsvs` | QSIRecon ACPC HSVS | BIDS native T1w → ACPC 5TT ref (channel 0) | Production factorial arms |
| **Deep Atropos native** | `deep-atropos-native` | Native BIDS T1w (from Deep Atropos seg) | Already on native T1w | Sensitivity / native-T1 priors |

Both paths then **resample the edited 5TT → `dwiref`**, clip, renormalize, and run matched iFOD2 + SIFT2 in `dkt_lesion_act.sif`.

Full Deep Atropos branch reference: [Deep Atropos native-T1 5TT](../deep_atropos_5tt.md).

---

## Processing sequence — HSVS / ACPC (default)

Maps to `run_hsvs_acpc_workflow()` in `containers/lesion_act/run_lesion_aware_act.sh`:

1. Load QSIRecon HSVS 5TT (ACPC) and WM FOD (`dwiref` grid).
2. Prepare **original BIDS** lesion mask on native T1w (`prepare_lesion_mask.py`).
3. Extract 5TT channel 0 as the ACPC reference grid (`five_tt_ref`).
4. Binarize / label-select lesion; warp lesion → ACPC 5TT grid:
   - primary: QSIPrep `from-T1wNative_to-T1wACPC` transform (`antsApplyTransforms`, GenericLabel);
   - fallback: empirical affine BIDS T1w → `desc-preproc_T1w` (Step 4 recipe).
5. `5ttedit -path` on the **ACPC grid**; `5ttcheck`; pathology overlap QA.
6. Resample edited 5TT → `dwiref`; clip and renormalize tissue fractions (sum to 1 along axis 4).
7. Re-run iFOD2 ACT + SIFT2 inside **`dkt_lesion_act.sif`**.
8. Step 4 consumes the rebuilt tractogram and weights when `--act-mode lesion-aware`.

QSIPrep preprocessing, anatomical reconstruction, and SS3T-CSD FOD estimation are **not** repeated.

---

## Processing sequence — Deep Atropos native

When `--act-5tt-source deep-atropos-native`:

### Step 3.2 (segmentation) — Segmentation (`dkt_deep_atropos_seg.sif`, optional)

| `act.deep_atropos.segmentation_mode` | Behavior |
|--------------------------------------|----------|
| `auto` (default) | Use external seg if found; else run ANTsPyNet |
| `import` | External seg required (precomputed cohort files) |
| `generate` | Always run ANTsPyNet on native BIDS T1w |

Discovery order: `--deep-atropos-seg` / config path → `derivatives/deep-atropos/` → `<results>/deep_atropos_seg/sub-<ID>/`.

Output: `deep_atropos_seg/sub-<ID>/desc-deepatropos_seg.nii.gz` (integer labels 0–6).

### Step 3.2 — Seg → base 5TT (`dkt_deep_atropos.sif`)

`scripts/convert_deep_atropos_to_5tt.py` maps Deep Atropos labels to MRtrix ACT channels on the **native BIDS T1w grid** (Python fallback; MRtrix 3.0.4 lacks `5ttgen deep_atropos`).

Output: `deep_atropos/sub-<ID>/base_5tt_native.mif`.

### Step 3.1 — Lesion edit + tractography (`dkt_lesion_act.sif`)

1. Resample prepared lesion mask → native 5TT grid (`five_tt_ref` from channel 0).
2. `5ttedit -path` on **native grid** (no ACPC warp for edit).
3. Resample edited 5TT → `dwiref` via `desc-preproc_T1w` intermediate.
4. Clip + renormalize; iFOD2 + SIFT2 (same as HSVS path).

On inpainted factorial arms, Deep Atropos seg and base 5TT use **original BIDS T1w** while the lesion ROI remains the **original BIDS mask** (orthogonal to Step 1.1 anatomy).

---

## Relationship to Step 1.1 and experiment arms

| Layer | Flag | Question addressed |
|-------|------|-------------------|
| Anatomical mitigation | `--anat-mitigation` | Can we reconstruct surfaces/parcellation without lesion-driven segmentation failure? |
| Lesion-aware ACT | `--act-mode lesion-aware` | Can tractography respect pathology during seeding/termination? |
| 5TT source (optional) | `--act-5tt-source` | HSVS ACPC vs native Deep Atropos for base tissue priors |

These are **orthogonal factors** in a deliberate factorial design (LeAPP; Bey et al. 2024). `--experiment-arm` sets anatomy + ACT. `--act-5tt-source` is an additional sensitivity flag on existing arms — not a new arm name.

### Intentional cross-source design (`neurolit-lesion`, `vbt-lesion`)

When Step 1.1 runs, recon and QSIRecon HSVS 5TT reflect **inpainted** anatomy,
but lesion-aware ACT always uses the **original BIDS lesion ROI** (traced on
pre-mitigation T1w). DWI is never modified.

This mismatch is **by design**, not an implementation error:

- **Inpainted 5TT** encodes what segmentation believes about tissue *after*
  anatomical mitigation (often normal GM/WM at the former lesion site).
- **Original lesion ROI** encodes where the injury was and where diffusion
  abnormality typically persists—informing ACT that standard priors are unreliable
  there regardless of T1w mitigation.

The factorial arms therefore isolate:

| Contrast | Comparison |
|----------|------------|
| Inpainting only | `*-std` vs `orig-std` |
| Lesion-aware ACT only | `orig-lesion` vs `orig-std` |
| ACT after inpainting (interaction) | `*-lesion` vs matching `*-std` |
| Deep Atropos 5TT source | `--act-5tt-source deep-atropos-native` vs default `hsvs` on same arm |

Provenance is written to `lesion_aware_act.json` (`factorial_design`,
`recon_anatomy_source`, `act_lesion_mask_source`, `five_tt_source`). See
[Lesion-aware § Intentional cross-source design](../lesion_aware.md#intentional-cross-source-design-on--lesion-inpainted-arms).

---

## Validation notes (TBI)

LeAPP validated ischemic stroke. TBI lesions (contusion, hemorrhage, edema, bilateral injury) require cohort-specific QC before treating lesion-aware ACT as production-default. Compare standard vs lesion-aware tractograms side-by-side; do not overwrite the standard tractogram until validated.

Manuscript planning for the TrackTBI factorial cohort: [Publication strategy](../publication_strategy.md).

---

## References

| Topic | Citation | Link |
|-------|----------|------|
| **LeAPP framework (primary context)** | Bey P, et al. Lesion-aware automated processing for clinical stroke MRI. *Human Brain Mapping* 2024;45(9):e26701. | [10.1002/hbm.26701](https://doi.org/10.1002/hbm.26701) |
| **ACT tractography** | Smith RE, et al. Anatomically-constrained tractography. *NeuroImage* 2012;62(3):1924–1938. | [10.1016/j.neuroimage.2012.02.004](https://doi.org/10.1016/j.neuroimage.2012.02.004) |
| **HSVS 5TT** | Smith RE, et al. Hybrid surface/volume segmentation. *NeuroImage* 2020;223:117345. | [10.1016/j.neuroimage.2020.117345](https://doi.org/10.1016/j.neuroimage.2020.117345) |
| **SIFT2** | Smith RE, et al. SIFT2. *NeuroImage* 2015;119:338–351. | [10.1016/j.neuroimage.2015.02.069](https://doi.org/10.1016/j.neuroimage.2015.02.069) |
| MRtrix ACT docs | Smith RE, Tournier JD. | [ACT documentation](https://mrtrix.readthedocs.io/en/latest/quantitative_structural_connectivity/act.html) |

Full table: [References § Step 3.1](../references.md#step-31-lesion-aware-act-optional).

---

## See also

- [Deep Atropos native-T1 5TT](../deep_atropos_5tt.md)
- [Lesion-aware tractography](../lesion_aware.md)
- [Step 1.1 — Inpainting](step1_1_inpaint.md)
- [Step 4 — Connectome](step4_connectome.md)
- [Lesion-aware ACT container README](https://github.com/phindagijimana/dkt_connectome/blob/main/dwi_pipeline/containers/lesion_act/README.md)
- [Disconnectome](../disconnectome.md) — post-hoc lesion disconnection (different question)
