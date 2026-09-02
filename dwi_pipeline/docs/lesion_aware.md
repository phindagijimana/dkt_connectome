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

`--act-mode lesion-aware` rebuilds iFOD2 + SIFT2 after inserting the **original BIDS
lesion mask** into the MRtrix pathology channel. Two base-5TT sources:

| Source | Flag | Edit grid | Reference |
|--------|------|-----------|-----------|
| HSVS ACPC (default) | `--act-5tt-source hsvs` | QSIRecon ACPC HSVS (channel-0 ref) | ACPC-first HSVS workflow |
| Deep Atropos native | `--act-5tt-source deep-atropos-native` | Native BIDS T1w | Native-T1 pathology ACT workflow |

Shared steps after base 5TT is loaded:

1. Resample lesion → 5TT reference grid (label-preserving).
2. `5ttedit -path`; `5ttcheck`; pathology overlap QA.
3. Resample edited 5TT → `dwiref`; clip and renormalize tissue fractions.
4. Matched iFOD2 and SIFT2 in `dkt_lesion_act.sif`.

Primary warp (HSVS): QSIPrep `T1wNative→ACPC`; fallback: empirical
affine BIDS T1w → `desc-preproc_T1w` (same as Step 4 connectome).

The native-T1 pathology ACT recipe (segmentation strategy flexible): resample contusion into segmentation
space, add to 4D 5TT pathology channel, renormalize so fractions sum to 1 — implemented
in both paths via `5ttedit -path` and `clip_renormalize_5tt()`.

The corrected or approximated anatomy is used for processing, while the
original lesion mask is retained as biological information. Inpainting is not
equivalent to deleting or ignoring the lesion.

### Experiment arms (anatomy × ACT)

For factorial sensitivity analyses on lesion subjects, use `--experiment-arm`
to set Step 1.1 backend and Step 3.1 ACT together. The design follows the
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

### Intentional cross-source design on `*-lesion` inpainted arms

On **`neurolit-lesion`** and **`vbt-lesion`**, Step 2–3 and Step 3.1 deliberately
use **different anatomical references**:

| Processing layer | Source | Purpose |
|------------------|--------|---------|
| Recon + HSVS 5TT | Inpainted T1w (Step 1.1) | Surfaces, parcellation, tissue segmentation |
| ACT pathology channel | **Original BIDS lesion ROI** | Biological injury location for tractography priors |
| DWI / WM FOD | Unmodified QSIPrep output | Diffusion signal at the lesion site is real, not inpainted |

This is **not a registration bug** when grids align. It is the **LeAPP factorial
contrast** (Bey et al. 2024): anatomical mitigation and lesion-aware ACT are
**orthogonal factors**. Inpainting asks whether corrected T1w improves
reconstruction; lesion-aware ACT asks whether marking the **original injury ROI**
as pathological changes tractography **given** that corrected anatomy—and **given**
that DWI abnormality persists at that location.

**Hypotheses the inpainted `*-lesion` arms test:**

1. **Main effect of inpainting** (`neurolit-std` vs `orig-std`, `vbt-std` vs `orig-std`): connectome/parcellation change from anatomical mitigation alone.
2. **Main effect of lesion-aware ACT** (`orig-lesion` vs `orig-std`): tractography change from pathology channel alone, without inpainting.
3. **Interaction** (`neurolit-lesion` vs `neurolit-std`, `vbt-lesion` vs `vbt-std`): incremental effect of pathology ACT **after** inpainting—does ACT still matter when recon already sees “healthy” tissue at the lesion site?

**How to describe this in methods text:**

> Structural T1w was lesion-mitigated before cortical reconstruction (neuroLIT or
> virtual brain transplant). HSVS five-tissue-type images were derived from that
> mitigated anatomy. For lesion-aware ACT, the **clinician-traced lesion mask on
> the original pre-mitigation T1w** was retained, transformed to diffusion space,
> and assigned to the MRtrix pathology compartment (`5ttedit -path`). Diffusion
> MRI was not inpainted. This follows the factorial lesion-processing framework
> of Bey et al. (2024): corrected anatomy for segmentation, original lesion extent
> for tractography priors.

**Required QC for inpainted `*-lesion` arms:**

- Overlay original lesion ROI on inpainted T1w and on HSVS WM/GM channels.
- Confirm pathology channel after `5ttedit` matches the transformed original ROI.
- Compare tractography statistics across the 2×2 (or 3×2) arm grid; do not merge
  arms without provenance.

**Important:** LeAPP validated ischemic stroke. TBI lesions require cohort-specific QC before treating any arm as production-default. Do not pool connectomes across arms without tracking provenance.

Theory pages: [Step 1.1 — Inpainting](methods/step1_1_inpaint.md) · [Step 3.1 — Lesion-aware ACT](methods/step3_1_lesion_act.md) · [Deep Atropos branch](deep_atropos_5tt.md).

**Concise arm reference:** [TBI experimental arms](TBI_Experimental_Arms.md) — factorial design, LeAPP relationship, TBI011011 pilot.

CLI examples and Slurm usage: [Usage — experiment arms](usage.md).
Decision guide: [Decision tables — experiment arms](decision_tables.md).
Citations: [References § Experiment arms](references.md#experiment-arms-factorial-lesion-processing).

### Publication planning

For cohort scale (~100 TrackTBI lesion subjects), manuscript portfolio (flagship
vs clinical disconnectome vs optional Deep Atropos branch), pre-specified factorial
contrasts, journal targets, and reporting checklist, see
**[Publication strategy — TBI lesion-aware connectomics](publication_strategy.md)**.

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
