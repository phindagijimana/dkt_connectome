# Lesion-aware anatomical processing and tractography

## Paper summarized

Bey P, Dhindsa K, Kashyap A, et al. **A lesion-aware automated processing
framework for clinical stroke magnetic resonance imaging.** *Human Brain
Mapping*. 2024;45(9):e26701.
[doi:10.1002/hbm.26701](https://doi.org/10.1002/hbm.26701)

The paper presents the Lesion Aware automated Processing Pipeline (LeAPP), a
containerized framework for structural, diffusion, and functional MRI from
people with ischemic stroke. Its central premise is that a lesion should not be
allowed to silently distort anatomical reconstruction, registration, tissue
classification, tractography, or connectome construction.

## Key ideas

### Lesions affect more than the damaged voxels

A focal lesion can cause conventional pipelines to fail or introduce errors in
brain extraction, registration, surface reconstruction, tissue segmentation,
parcellation, and downstream connectivity. A plausible-looking result is not
necessarily correct if these steps treated pathological tissue as healthy
anatomy.

### Anatomical processing should mitigate lesion-driven errors

LeAPP incorporates lesion-aware structural strategies, including cost-function
masking and virtual brain transplant. These approaches prevent the lesion from
driving registration and approximate healthy-looking anatomy where downstream
tools expect normal tissue. This serves a role similar to T1w inpainting in the
DKT connectome pipeline: it supports more complete surfaces and parcellations.

The DKT pipeline now exposes this as `--anat-mitigation vbt`. Its
`scripts/run_vbt.py` is a direct port of the public BrainModes/LeAPP sequence:
left-right mirroring, lesion-masked six-degree-of-freedom FLIRT registration,
FSL `midtrans` half transforms, smoothed contralesional blending, and inverse
mapping to the native T1w grid. The default smoothing factor is Gaussian
sigma 2 voxels, matching LeAPP's released code. This is a deterministic
enantiomorphic method and is not equivalent to neuroLIT's learned inpainting.
It should be described as a port of LeAPP's released implementation, not as a
complete reproduction of the partly manual Solodkin protocol. It assumes a
largely unilateral lesion and an intact contralesional homolog; LeAPP validated
stroke data, so contusion, hemorrhage, edema, bilateral injury, and substantial
midline shift require separate TBI validation.

### Lesion-aware ACT implementation

`--act-mode lesion-aware` uses QSIRecon's retained ACPC HSVS 5TT and WM FOD.
The 5TT is linearly resampled to the DWI/FOD grid, clipped and renormalized so
its tissue fractions remain valid, and edited with `5ttedit -path` after the
lesion mask is transformed with nearest-neighbor interpolation. The workflow
requires `5ttcheck` to pass and verifies that every lesion voxel is assigned
to the pathological channel before running matched iFOD2 and SIFT2.

The corrected or approximated anatomy is used for processing, while the
original lesion mask is retained as biological information. Inpainting is not
equivalent to deleting or ignoring the lesion.

### Experiment arms (anatomy × ACT)

For factorial sensitivity analyses on lesion subjects, use `--experiment-arm`
to set Step 1.5 backend and Step 3.5 ACT together. The design follows the
**LeAPP factorial framework** (Bey et al. 2024): anatomical mitigation and
lesion-aware tractography are **orthogonal** — inpainting fixes surfaces and
parcellation; ACT pathology editing fixes streamline priors during tractography.
Each arm writes to an isolated tree under `RESULTS_ROOT/arms/<arm>/` by default.

| Arm | Anatomy | ACT | Theory / contrast | Primary citations |
|-----|---------|-----|-------------------|-------------------|
| `orig-std` | Original T1w | Standard | Baseline — no lesion mitigation | — |
| `orig-lesion` | Original T1w | Lesion-aware | Tractography-only pathology handling | Smith et al. 2012 ACT; Bey et al. 2024 |
| `neurolit-std` | neuroLIT | Standard | Learned inpainting effect on anatomy | Pollak et al. 2025 |
| `neurolit-lesion` | neuroLIT | Lesion-aware | Inpainting + pathology ACT | Pollak et al. 2025; Bey et al. 2024 |
| `vbt-std` | VBT | Standard | Deterministic contralesional fill vs neuroLIT | Bey et al. 2024 |
| `vbt-lesion` | VBT | Lesion-aware | Full LeAPP-style factorial | Bey et al. 2024 |

**Important:** LeAPP validated ischemic stroke. TBI lesions require cohort-specific QC before treating any arm as production-default. Do not pool connectomes across arms without tracking provenance.

Theory pages: [Step 1.5 — Inpainting](methods/step1_5_inpaint.md) · [Step 3.5 — Lesion-aware ACT](methods/step3_5_lesion_act.md).

CLI examples and Slurm usage: [Usage — experiment arms](usage.md).
Decision guide: [Decision tables — experiment arms](decision_tables.md).
Citations: [References § Experiment arms](references.md#experiment-arms-factorial-lesion-processing).

### Clinical DWI requires an appropriate preprocessing workflow

The paper uses an MRtrix3-based diffusion workflow designed for clinical
acquisitions that do not necessarily satisfy high-resolution Human Connectome
Project assumptions. Its major stages are diffusion preprocessing, anatomical
tissue segmentation, tractography, and connectome construction.

### ACT should explicitly receive the lesion

MRtrix Anatomically Constrained Tractography (ACT) expects a four-dimensional
five-tissue-type image. Its volumes must be ordered as:

1. Cortical gray matter
2. Subcortical gray matter
3. White matter
4. CSF
5. Pathological or undefined tissue

LeAPP integrates the lesion mask into the fifth compartment. In MRtrix this can
be performed after generating the base 5TT image:

```bash
5ttedit base_5tt.mif lesion_aware_5tt.mif \
  -path lesion_in_5tt_space.mif

5ttcheck lesion_aware_5tt.mif
```

The lesion mask must first be transformed to the exact 5TT space and grid using
label-preserving interpolation. The edited image should be checked visually,
and the five tissue fractions should sum to one inside the brain.

### Pathological tissue is permissive, not an exclusion mask

The fifth compartment tells ACT that normal anatomical priors are not reliable
inside the lesion. ACT suspends those priors while a streamline is in the
pathological compartment and continues to use the diffusion model and other
termination criteria.

Consequently, a streamline may enter, leave, or terminate inside the lesion.
Adding the lesion to the 5TT image does **not** automatically remove all
lesion-crossing streamlines and does not reconstruct axons destroyed by the
injury.

### Connectomes use individualized anatomical regions

The paper constructs structural connectomes from individualized parcellations
and uses SIFT2 to weight streamlines. This separates two related requirements:

- The anatomical correction supports a complete, well-registered
  parcellation.
- The pathological 5TT compartment informs ACT during streamline generation.

Both are needed; a corrected parcellation alone does not make tractography
lesion-aware.

### Validation is based on known or approximated ground truth

The authors evaluated real and artificially lesioned data. Artificial lesions
allowed comparison with the corresponding healthy anatomy and connectome.
Lesion-aware processing reduced errors in affected regional parcellations and
structural-connectivity measurements relative to a non-adapted pipeline.

This validation strategy is important: lesion handling should be assessed
against a reference or controlled sensitivity analysis, not accepted solely
because the output appears anatomically plausible.

## Relationship to the DKT connectome pipeline

The current pipeline already contains two lesion-related mechanisms:

1. T1w inpainting before FreeSurfer/FastSurfer, supporting surfaces and the DKT
   parcellation.
2. Post-tractography disconnectome analyses that modify lesion-affected nodes
   and/or exclude streamlines intersecting the lesion.

The current QSIRecon
`mrtrix_singleshell_ss3t_ACT-hsvs` tractography does not receive the lesion
mask. Its HSVS 5TT is generated from the corrected anatomy, so ACT may classify
the inpainted lesion location as apparently normal tissue.

Lesion-aware ACT would add a distinct intermediate step:

```text
Original lesion mask ──transform──┐
                                 ├── lesion-aware 5TT
Inpainted anatomy ──HSVS 5TT─────┘
                                         │
WM FOD ──────────────────────────────────┼── iFOD2 ACT tractography
                                         │
                                         └── SIFT2 → DKT connectome
```

The inpainted DKT atlas remains appropriate for assigning streamline endpoints.
The original lesion mask, rather than an inpainted image difference, should
populate the pathological compartment.

## Outputs that must be regenerated

Changing the ACT 5TT changes streamline generation. The following products must
therefore be regenerated:

1. Tractogram
2. SIFT2 streamline weights
3. DKT connectome
4. Node-strength and asymmetry summaries
5. Disconnectome products

QSIPrep preprocessing, T1w inpainting, anatomical reconstruction, and the
SS3T-CSD white-matter FOD do not need to be repeated if their retained outputs
are valid.

The present QSIRecon derivative tree retains the WM FOD but not the final ACT
5TT used by `tckgen`; the tractogram header points to a temporary work-directory
file. A production implementation must either export that 5TT or regenerate an
equivalent HSVS 5TT from the retained FreeSurfer/FastSurfer anatomy.

## Recommended validation for TBI

LeAPP was developed and validated for ischemic stroke. TBI lesions can contain
different mixtures of contusion, hemorrhage, edema, encephalomalacia, and
partial tissue preservation. The same pathological-compartment strategy is
reasonable to test, but its performance should not be assumed to transfer
unchanged.

Begin with paired processing of one or more representative TBI subjects:

- Standard ACT using the unedited HSVS 5TT
- Lesion-aware ACT using the edited pathological compartment

Keep the diffusion model, seeding strategy, streamline count, length limits,
SIFT2 configuration, DKT atlas, and endpoint-assignment settings fixed. Compare:

- 5TT lesion overlap and tissue-fraction integrity
- Streamlines entering, terminating in, and crossing the lesion
- Connectome density and total edge weight
- Edge-level differences near the lesion
- Node strength and asymmetry
- Disconnectome estimates
- Visual and quantitative tractography QC

The lesion-aware tractogram should initially be stored alongside, rather than
overwrite, the standard tractogram.

## Interpretation

Lesion-aware ACT and disconnectome analysis answer different questions:

- **Lesion-aware ACT:** How should tractography behave where normal anatomical
  priors are uncertain?
- **Disconnectome:** Which reconstructed connections intersect or depend on the
  lesion?

Using both provides a more complete analysis than either method alone.
Nevertheless, neither method proves the presence, absence, or biological count
of axons. Results remain model-based estimates influenced by DWI quality,
lesion-mask accuracy, FOD estimation, tractography parameters, registration,
and parcellation.

## References

1. Bey P, Dhindsa K, Kashyap A, et al. A lesion-aware automated processing
   framework for clinical stroke magnetic resonance imaging. *Human Brain
   Mapping*. 2024;45(9):e26701.
   [doi:10.1002/hbm.26701](https://doi.org/10.1002/hbm.26701)
2. Smith RE, Tournier JD, Calamante F, Connelly A. Anatomically-constrained
   tractography: improved diffusion MRI streamlines tractography through
   effective use of anatomical information. *NeuroImage*. 2012;62(3):1924–1938.
3. Smith RE, Tournier JD, Calamante F, Connelly A. SIFT2: enabling dense
   quantitative assessment of brain white matter connectivity using streamlines
   tractography. *NeuroImage*. 2015;119:338–351.
4. [MRtrix3 ACT documentation](https://mrtrix.readthedocs.io/en/latest/quantitative_structural_connectivity/act.html)
5. [MRtrix3 `5ttedit` documentation](https://mrtrix.readthedocs.io/en/latest/reference/commands/5ttedit.html)
