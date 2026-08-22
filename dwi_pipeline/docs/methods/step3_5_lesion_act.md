# Step 3.5 — Lesion-aware ACT tractography

**Theory and methods** for rebuilding iFOD2/SIFT2 after inserting the lesion into the MRtrix five-tissue-type (5TT) pathology channel. Operational details: [Pipeline steps § Step 3.5](../pipeline_steps.md#step-35-lesion-aware-act-optional) · [Usage § lesion-aware flags](../usage.md) · [Lesion-aware tractography](../lesion_aware.md).

---

## Background

Standard **Anatomically Constrained Tractography (ACT)** uses a 5TT image with cortical GM, subcortical GM, WM, CSF, and a fifth **pathological / undefined** compartment (Smith et al. 2012). In the default QSIRecon spec (`mrtrix_singleshell_ss3t_ACT-hsvs`), that 5TT is built from FreeSurfer/FastSurfer segmentation on the T1w that Step 2 received — including any Step 1.5 anatomical mitigation.

If the lesion was **inpainted or transplanted** on T1w, the HSVS 5TT may label the former lesion site as apparently healthy tissue. Streamlines can then seed and terminate there under normal GM/WM priors, even though the underlying biology is pathological.

**Lesion-aware ACT** keeps the mitigated anatomy for parcellation and registration, but transforms the **original BIDS lesion mask** into DWI space and assigns those voxels to the **pathology channel** with `5ttedit -path` before matched `tckgen` and `tcksift2` (LeAPP-style workflow; Bey et al. 2024).

---

## What the pathology channel means

The fifth compartment is **not** a hard exclusion mask. It tells ACT that standard tissue priors are unreliable inside the lesion: streamlines may enter, traverse, or terminate in pathology voxels according to the diffusion model and ACT rules (Smith et al. 2012; MRtrix ACT documentation).

Lesion-aware ACT therefore answers: *How should tractography behave where anatomical priors are uncertain?* It does **not** prove axonal preservation or absence inside the lesion.

---

## Processing sequence (this pipeline)

1. Load QSIRecon HSVS 5TT and WM FOD (retained derivatives).
2. Resample 5TT to the DWI/FOD grid; clip and renormalize tissue fractions.
3. Prepare lesion mask on native T1w; transform to DWI space (nearest neighbour).
4. `5ttedit -path` → `lesion_aware_5tt.mif`; `5ttcheck` must pass.
5. Verify every lesion voxel maps to the pathology channel.
6. Re-run iFOD2 ACT + SIFT2 with fixed streamline budget (`ACT_STREAMLINES`, default 10M).
7. Step 4 consumes the rebuilt tractogram and weights when `--act-mode lesion-aware`.

QSIPrep preprocessing, anatomical reconstruction, and SS3T-CSD FOD estimation are **not** repeated.

---

## Relationship to Step 1.5 and experiment arms

| Layer | Flag | Question addressed |
|-------|------|-------------------|
| Anatomical mitigation | `--anat-mitigation` | Can we reconstruct surfaces/parcellation without lesion-driven segmentation failure? |
| Lesion-aware ACT | `--act-mode lesion-aware` | Can tractography respect pathology during seeding/termination? |

These are **orthogonal**. `--experiment-arm` sets both for factorial sensitivity analyses inspired by LeAPP (Bey et al. 2024). See [Decision tables § Experiment arms](../decision_tables.md#experiment-arms).

---

## Validation notes (TBI)

LeAPP validated ischemic stroke. TBI lesions (contusion, hemorrhage, edema, bilateral injury) require cohort-specific QC before treating lesion-aware ACT as production-default. Compare standard vs lesion-aware tractograms side-by-side; do not overwrite the standard tractogram until validated.

---

## References

| Topic | Citation | Link |
|-------|----------|------|
| **LeAPP framework (primary context)** | Bey P, et al. Lesion-aware automated processing for clinical stroke MRI. *Human Brain Mapping* 2024;45(9):e26701. | [10.1002/hbm.26701](https://doi.org/10.1002/hbm.26701) |
| **ACT tractography** | Smith RE, et al. Anatomically-constrained tractography. *NeuroImage* 2012;62(3):1924–1938. | [10.1016/j.neuroimage.2012.02.004](https://doi.org/10.1016/j.neuroimage.2012.02.004) |
| **HSVS 5TT** | Smith RE, et al. Hybrid surface/volume segmentation. *NeuroImage* 2020;223:117345. | [10.1016/j.neuroimage.2020.117345](https://doi.org/10.1016/j.neuroimage.2020.117345) |
| **SIFT2** | Smith RE, et al. SIFT2. *NeuroImage* 2015;119:338–351. | [10.1016/j.neuroimage.2015.02.069](https://doi.org/10.1016/j.neuroimage.2015.02.069) |
| MRtrix ACT docs | Smith RE, Tournier JD. | [ACT documentation](https://mrtrix.readthedocs.io/en/latest/quantitative_structural_connectivity/act.html) |

Full table: [References § Step 3.5](../references.md#step-35-lesion-aware-act-optional).

---

## See also

- [Lesion-aware tractography](../lesion_aware.md)
- [Step 1.5 — Inpainting](step1_5_inpaint.md)
- [Step 4 — Connectome](step4_connectome.md)
- [Disconnectome](../disconnectome.md) — post-hoc lesion disconnection (different question)
