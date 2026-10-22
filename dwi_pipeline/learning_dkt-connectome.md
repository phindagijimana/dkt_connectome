# Learning walkthrough — DKT-Connectome pipeline session

**Scope.** Comprehensive record of all neuroimaging theory, pipeline
engineering, coding patterns, programming concepts, and specific work
performed during the factorial-paper cohort scale-up session
(2026-09-18 → 2026-09-22). This is your personal textbook to read and
re-read as needed.

**How to use this doc.**
- **Parts 1–3** = concepts. Read once thoroughly; refer back when a
  specific term appears in a log or paper.
- **Part 4** = the chronological session work log. Trace through the
  codebase using the file paths listed.
- **Part 5** = debugging patterns and documentation discipline.
- **Reference** = files touched and a glossary.

**Companion docs.**
- `docs/papers/factorial_paper/vbt_orientation_finding.md`
- `docs/papers/factorial_paper/sidecar_repair_finding.md`
- `docs/papers/factorial_paper/index.md`
- `analysis/paper1/pilot_factorial.py`
- `scripts/repair_bids_sidecars.py`

---

## Contents

**Part 1 — Neuroimaging theory**
1. BIDS specification
2. NIfTI header (sform/qform, orientation)
3. DWI acquisition & shells
4. EPI physics & susceptibility distortion
5. SDC methods (TOPUP, PRELUDE+FUGUE, SyN, no-SDC)
6. Eddy correction
7. FreeSurfer / FastSurfer cortical reconstruction
8. Anatomically-Constrained Tractography
9. Tractography algorithms (iFOD2, SD_STREAM)
10. SIFT2 streamline reweighting
11. Connectome construction & DKT parcellation
12. Disconnectome analysis
13. Virtual Brain Transplant (LeAPP)
14. fMRIPrep + XCP-D + CIFTI
15. Factorial experiment design (anatomy × ACT)

**Part 2 — Pipeline engineering**
1. Snakemake DAG semantics + wildcards + workdir
2. Apptainer / Singularity containerization
3. Bind-mount semantics and constraints
4. Environment variable propagation
5. Per-arm output isolation
6. Marker files and idempotency
7. SLURM scheduling (arrays, dependencies, states)
8. Pipeline preflight validation
9. File formats (NIfTI, MGZ, tck, mif, CIFTI)
10. Container orchestration alternatives considered

**Part 3 — Programming & scripting concepts**
1. Bash idioms (parameter expansion, arrays, quoting, redirections)
2. Bash safety hats (`set -euo pipefail`, `trap`)
3. Python patterns (argparse, pathlib, subprocess)
4. Python scientific stack (numpy, pandas, matplotlib, nibabel)
5. Race conditions & concurrency
6. Atomic operations
7. Provenance and reproducibility
8. Version control patterns

**Part 4 — Session tasks** (chronological work log)
1. VBT — midtrans SIGSEGV fix
2. fMRI CIFTI/LINC pipeline
3. Pilot factorial analysis
4. Cohort copy from TrackTBI_Lesion
5. DWI shell mismatch
6. SDC decision tree
7. BIDS sidecar repair
8. subjects.txt race condition
9. Storage management & CIDUR cleanup
10. TBI011204 end-to-end real Case-2 fmap execution

**Part 5 — Debugging & documentation**
1. Diagnostic patterns
2. Anti-patterns to avoid
3. Reversibility ladder
4. Documentation discipline

**Reference** — files created/modified + glossary

---

# Part 1 — Neuroimaging theory

## 1.1 BIDS (Brain Imaging Data Structure) specification

BIDS is a filesystem convention for organizing neuroimaging data:

```
dataset_root/
├── dataset_description.json      # top-level metadata
├── participants.tsv              # subject demographics
├── sub-<ID>/                     # per-subject directory
│   ├── ses-<SES>/                # per-session (optional but recommended)
│   │   ├── anat/                 # T1w, T2w, FLAIR, lesion masks
│   │   ├── dwi/                  # DWI + bvec + bval
│   │   ├── func/                 # BOLD (task-rest for resting state)
│   │   ├── fmap/                 # fieldmaps for SDC
│   │   └── perf/                 # ASL (perfusion)
```

**Filenames are compositions** of *entities* and a *suffix*:

```
sub-TBI011011_ses-2WK_acq-b1000_dir-ap_run-1_dwi.nii.gz
    ^entity1     ^ent2    ^ent3    ^ent4  ^ent5  ^suffix
```

Recognized entity keys: `sub`, `ses`, `acq`, `ce`, `rec`, `dir`, `run`, `mod`, `echo`, `flip`, `inv`, `mt`, `part`, `task`, `desc`.

**Sidecars.** Every NIfTI `foo.nii.gz` has a paired `foo.json` holding metadata. **The JSON is the source of truth** for scanner-derived fields (PhaseEncodingDirection, TotalReadoutTime, EchoTime, etc.) — tools read from JSON, not NIfTI header.

**Modality guidance.**

- `anat/`: `T1w`, `T2w`, `FLAIR`, `T2starw`. Lesion masks use `..._label-lesion_roi.nii.gz`.
- `dwi/`: `_dwi.nii.gz` + `_dwi.bval` + `_dwi.bvec` (bvals in a single row, bvecs in three rows for x/y/z gradient directions).
- `fmap/`: fieldmaps in one of four "cases" (see 1.5).
- `func/`: `_task-<TASK>_bold.nii.gz` + optional event files.

**Where used this session:** every filesystem inspection touched BIDS conventions; the sidecar-repair utility operates entirely at the JSON layer.

## 1.2 NIfTI header (sform / qform / orientation)

A NIfTI file has a raw 3D or 4D image + a header that describes:

- **Voxel spacing** (pixdim: x, y, z spacing in mm, plus TR for 4D)
- **sform** — 4×4 affine matrix mapping voxel indices → world coordinates (mm)
- **qform** — quaternion-based affine (alternative representation)
- **sform_code / qform_code** — 0 (undefined), 1 (scanner anatomical), 2-4 (aligned templates), etc.

**Radiological vs neurological convention:**

- Neurological: right side of brain = right side of image (X-axis positive → right)
- Radiological: right side of brain = LEFT side of image (X-axis flipped)

The sign of the sform's determinant tells you which:
- Positive determinant → neurological convention
- **Negative determinant → radiological convention**

Most modern tools handle both, but some legacy binaries (like FSL's `midtrans`) segfault on negative-determinant sforms. **`fslreorient2std`** rewrites the header + reslices the data to produce a positive-determinant sform without changing the anatomy.

Our VBT bug (Part 4.1) was exactly this: TBI011011's T1w had `sform_code=1`, negative determinant, and `midtrans` crashed. The fix was to preprocess with `fslreorient2std` before any subsequent registration.

## 1.3 DWI acquisition and shells

**Diffusion-Weighted Imaging (DWI)** applies pairs of gradient pulses (the "Stejskal-Tanner sequence") around a refocusing pulse. Water molecules diffusing along the gradient direction acquire a phase shift that partially cancels, attenuating the signal by:

$$S(\vec{g}, b) = S_0 \exp(-b \, \vec{g}^T D \vec{g})$$

Where:
- $b$ (b-value, s/mm²) = strength × duration of gradients (higher b = more diffusion weighting)
- $\vec{g}$ = gradient direction (unit vector)
- $D$ = local diffusion tensor (or, at higher b-values, the underlying orientation distribution function)
- $S_0$ = signal with no diffusion weighting (b=0 image)

Practical acquisition:

- Multiple gradient directions (30–256+) at one b-value → **HARDI shell**
- Multiple shells (b=1000, 2000, 3000) → **multi-shell**
- b=0 volumes interleaved for reference

**Files:** `.bval` (one row, one value per volume), `.bvec` (three rows for x/y/z, one column per volume).

**Shell filtering in our pipeline:** `dwi_select_*.json` defines `target_shell_b` (e.g., 1000) and `shell_tolerance` (e.g., ± 100). QSIPrep is fed only the DWI volumes matching that shell. Prevents multi-shell files from being processed under a single-shell assumption.

**Session context:** our subjects use b=1300 (TBI011011, 011007, 011021, 011029, 011140, 021030) or b=1000 (TBI011204). Different scanners / protocols; each needs its own dwi-select config.

## 1.4 EPI physics & susceptibility distortion

**Echo-Planar Imaging (EPI)** acquires an entire 2D k-space slice with a single RF excitation by rapidly switching gradients — fast (~50-100ms/slice) but geometrically fragile.

**The distortion mechanism:**

1. B0 (main field) is not perfectly uniform. Near air-tissue interfaces (frontal sinuses, ear canals, orbital region), local field perturbations (Δ B0) exist.
2. In EPI, the phase-encoding gradient (usually much weaker than the frequency-encoding gradient) plays continuously across the readout. Local Δ B0 accumulates over the readout time → apparent voxel displacement in the phase-encoding direction.
3. Displacement magnitude: $\Delta y \propto \Delta B_0 \times T_{readout}$
4. Result: frontal poles, temporal poles, orbitofrontal cortex all look squished, stretched, or shifted.

**Two key BIDS fields:**

- **`PhaseEncodingDirection`** — string like `j-` where the letter (`i`, `j`, `k`) is the voxel axis and the sign indicates direction. `j-` = "phase-encode in -y direction" ≈ posterior→anterior in most acquisitions.
- **`TotalReadoutTime`** (TRT) — total time the phase-encoding gradient is played, in seconds. Set by the sequence protocol. Larger TRT → larger distortion.

**Related BIDS fields:**

- **`EffectiveEchoSpacing`** (EES) — time between phase-encoding steps. $TRT = EES \times (N_{PE} - 1)$.
- **`BandwidthPerPixelPhaseEncode`** — reciprocal of TRT × N.

All must be consistent. Our `derive_pe_block` computes EES and BWPPPE from TRT and `ReconMatrixPE`.

## 1.5 SDC methods (Susceptibility Distortion Correction)

Given knowledge of the B0 inhomogeneity map, we can compute the per-voxel displacement and unwarp. Four practical methods, each requiring different input:

### Method A: PRELUDE + FUGUE (BIDS Case-1 or Case-2)

**Input:** an actual fieldmap in Hz (from a Siemens gre_field_mapping scan) or a phase-difference image + two magnitude images.

**Steps:**

1. **PRELUDE** (Phase Region Expanding Labeller for Unwrapping Discrete Estimates) unwraps the phase image (phase is only defined modulo 2π; PRELUDE resolves 2π ambiguities using a magnitude image as amplitude reference).
2. Convert unwrapped phase difference to a fieldmap in Hz: $B_0 = \Delta \phi / (2\pi \times \Delta TE)$ where $\Delta TE = TE_2 - TE_1$.
3. **FUGUE** (FMRIB's Utility for Geometrically Unwarping EPIs) applies the fieldmap to unwarp the target EPI.

**Requires:** for Case-2, a `phasediff.nii.gz` + `phasediff.json` with `EchoTime1` and `EchoTime2` + `magnitude1.nii.gz` + `magnitude2.nii.gz` + IntendedFor pointing at the target EPI.

**This is what our repaired TBI011204 setup uses.**

### Method B: TOPUP (BIDS Case-4)

**Input:** a pair of b=0 volumes acquired with opposite phase-encoding directions (e.g., one dir-ap and one dir-pa). Distortion in each is equal in magnitude but opposite in direction.

**Steps:**

1. **TOPUP** estimates the field from the two opposite-blip b=0s by minimizing the difference after applying opposite-sign warps.
2. The estimated field is Incorporated into Eddy's combined-interpolation step.

**Requires:** `_dir-<PE>_epi.nii.gz` files or embedded reverse-PE b=0 volumes within the DWI acquisition.

**This is what CIDUR-Siemens uses.**

### Method C: SyN synthetic SDC (`--use-syn-sdc`)

**Input:** just the EPI + T1w. No fieldmap needed.

**Steps:**

1. Coregister the EPI to the T1w using SyN (Symmetric Normalization; ANTs).
2. Compute the displacement field.
3. Regularize / restrict displacement to the PE direction (physical prior — susceptibility distortion is only along PE).
4. Apply as SDC.

**Weaknesses:** relies on T1w being high-quality (segmentation-friendly). On GE Signa Premier data (different gradient hardware than the Siemens data the SyN prior was trained on), can misestimate.

**This is what our TBI011204 first ran with (via `--syn` flag), before we wired the real fmap.**

### Method D: No SDC (`--no-sdc`)

Skip SDC entirely. Eddy still runs for motion + eddy currents. Frontal / temporal EPI distortion left uncorrected — accepted as a data limitation.

**QSIPrep behavior:** `--no-sdc` sets `--ignore fieldmaps`, which prevents external fmap discovery but does NOT disable TOPUP if reverse-PE b=0s are embedded in the DWI itself.

**This is what CIDUR-GE and TBI011011 pilot used.**

### Which method for which situation

| Available data | Method | Notes |
|---|---|---|
| Real fieldmap or Case-2 phasediff triplet | **PRELUDE+FUGUE** | Preferred |
| Reverse-PE b=0s | **TOPUP** | Also excellent |
| No fmap, no reverse-PE, good T1w | **SyN** | Approximate; better than nothing on Siemens |
| No fmap on GE | **`--no-sdc`** | Accept limitation |

## 1.6 Eddy correction

FSL's `eddy` corrects two artifacts orthogonal to susceptibility distortion:

1. **Head motion**: inter-volume rigid-body registration. Each volume aligned to a reference (typically the b=0 average).
2. **Eddy currents**: the diffusion gradients themselves induce residual gradient fields that shear/twist each image. Modeled as a spatially-varying linear function of the applied gradient direction, refined via a first-level (linear) and second-level (quadratic-in-time) model.

Additional features:

- **Outlier detection and replacement (`--repol`)**: slice-level Z-score analysis (default threshold ±4σ over 250-voxel intracerebral slices), replaced with Gaussian-process-imputed values.
- **Combined interpolation**: motion + eddy + TOPUP field applied together in one resample step (avoids compounding interpolation blur).
- **Jacobian intensity modulation (`--flm=quadratic`, `--interp=jac`)**: preserves signal intensity through the warp.

Every QSIPrep run includes Eddy, regardless of SDC method chosen.

## 1.7 FreeSurfer / FastSurfer cortical reconstruction

**FreeSurfer** — the classic tool. `recon-all` does:

1. Bias field correction
2. Skull stripping / brain extraction
3. Volume segmentation (WM, GM, subcortical)
4. Surface generation (WM boundary, pial surface)
5. Topology correction (fill defects to enforce genus-zero surfaces)
6. Inflation and spherical registration to fsaverage
7. Cortical parcellation (Desikan-Killiany, DKT, Destrieux atlases)

Runtime: ~10 hours per subject on a single CPU core.

**FastSurfer** — deep-learning acceleration. Replaces the volume segmentation stage with a CNN. Then either runs the classical surface stages or a DL surface-reconstruction pipeline. GPU: ~1 hour. CPU: ~3-4 hours.

**Key outputs:**

- `mri/orig.mgz` — conformed T1w (256³, 1mm iso)
- `mri/brainmask.mgz` — brain mask
- `mri/aparc+aseg.mgz` — parcellation + subcortical (DK atlas)
- `mri/aparc.DKTatlas+aseg.mgz` — DKT-atlas variant
- `surf/[lh|rh].pial` — pial surface (inflated boundary)
- `surf/[lh|rh].white` — white matter boundary
- `stats/aparc.stats` — per-parcel morphometry

**Completion marker:** `scripts/recon-all.done` — a plain text file touched when recon-all completes. FreeSurfer refuses to run on top of an existing subject directory (error: "Running on top of an existing subject directory") — you must delete or `rm -rf sub-<ID>/` before retrying.

**DKT atlas** (Desikan-Killiany-Tourville) — 78 cortical parcels total (39 per hemisphere), based on a refinement of the Desikan-Killiany atlas that reduces variability in labeled regions. **Primary atlas for our factorial connectomes.**

## 1.8 Anatomically-Constrained Tractography (ACT)

Standard tractography can generate streamlines that pass through unphysical regions (CSF, air, GM interior). **ACT** uses a 5-tissue-type (5TT) segmentation of the T1w to constrain streamline propagation:

**5TT channels:**

1. **CGM** — Cortical gray matter
2. **SGM** — Sub-cortical gray matter
3. **WM** — White matter
4. **CSF** — Cerebrospinal fluid
5. **Pathological** — Lesion, edema, or non-brain tissue

**Propagation rules:**

- Streamlines seed inside GM or the GM-WM interface (`-seed_gmwmi`)
- Streamlines can only propagate through WM
- Streamlines terminate at GM (which counts as an endpoint) or exit the brain
- Streamlines that hit CSF or Pathological are rejected

**Standard vs lesion-aware ACT:**

- **`std`**: 5TT computed from T1w-only segmentation. Lesion voxels may end up in WM channel (segmenter mis-assigns bright signal), which lets tractography propagate INTO the lesion — an artifact.
- **`lesion`**: the lesion mask replaces/modifies the 5TT (typically puts the lesion in the Pathological channel, or in WM but excluded from streamline propagation). Streamlines properly terminate at the lesion boundary.

**5TT source variants:**

- **HSVS** (Hybrid Surface-Volume Segmentation) — combines FreeSurfer surface outputs with volume segmentation. Robust default.
- **FSL FAST** — pure volume-based tissue classification.
- **Deep Atropos** — deep-learning 5TT (optional 3rd axis of the factorial).

Our pipeline uses HSVS by default (`ACT-hsvs` in QSIRecon spec).

## 1.9 Tractography algorithms (iFOD2, SD_STREAM)

**Fiber Orientation Distribution (FOD)** — the underlying anisotropic tissue property estimated from HARDI data via constrained spherical deconvolution (CSD). Represented as a spherical harmonic function on each voxel.

**Tractography walks the FOD** to generate streamlines from seed points.

### iFOD2 (2nd-order integration over Fibre Orientation Distributions)

- **Probabilistic**: at each step, samples the FOD amplitude distribution to pick a propagation direction.
- **Second-order integration** (~arc-based): considers curvature, not just tangent direction.
- Better at recovering crossing fibers, curved bundles, and dispersed pathways.
- Sensitive to noise (may include spurious streamlines).

### SD_STREAM (Streamlines Deterministic tractography)

- **Deterministic**: at each step, follows the peak of the FOD.
- Cleaner (no random spurious paths) but misses crossings and dispersed fibers.
- Faster to seed millions of streamlines.

**Our pipeline runs BOTH** (`--tractography-model both`) — iFOD2 as primary for the factorial paper, SD_STREAM as a secondary check.

**Streamline seed density**: typically 5-10 million seeds; after ACT filtering, ~1-5 million valid streamlines. Files: `.tck` (uncompressed) or `.tck.gz` (compressed; ~9GB each in our data).

## 1.10 SIFT2 (Spherical-deconvolution-Informed Filtering of Tractograms, v2)

**Motivation:** raw streamline counts don't quantitatively reflect fiber density. A voxel with 100 fibers may be sampled by 500 streamlines while another with 100 fibers may be sampled by 200 — depends on seed placement, curvature, sampling. Streamline count ≠ fiber count.

**SIFT2** assigns a scalar **weight** to each streamline such that the sum of weighted streamlines through a voxel matches the FOD amplitude in that voxel. Rebalances oversampled/undersampled regions.

**Formal optimization:**

$$\min_w \sum_v \left( \sum_{s \in \text{streamlines through } v} w_s \cdot L_{s,v} - FOD_v \right)^2$$

where $L_{s,v}$ is the length of streamline $s$ through voxel $v$.

**Output:** a `_streamlineweights.csv` file — one weight per streamline. To build a weighted connectome:
```
connectome[i,j] = Σ_{streamlines s with endpoints (i,j)} w_s
```

**Primary connectome measure for the factorial paper** is SIFT2-weighted.

## 1.11 Connectome construction & DKT parcellation

Given (a) a tractogram, (b) a parcellation image, (c) an optional streamline weighting:

1. For each streamline, find where its two endpoints intersect parcels via a `tck2connectome` operation.
2. Increment `connectome[i, j] += weight` where weight = 1 (count), or SIFT2 weight, or `mean(FA / MD / length)` for metric-weighted variants.
3. Symmetrize: `connectome = 0.5 * (connectome + connectome.T)` — connectivity is undirected.

Output: an N × N matrix per parcellation.

- **DKT (78 parcels)** — cortex only; the primary atlas for our factorial.
- **Schaefer 200 / 400 / 1000** — functional cortical parcellation.
- **Glasser 360 / HCP 360** — multi-modal cortical.

**Empty nodes:** parcels with zero connecting streamlines. High empty-node fraction (> 0.05 of nodes) is a QC red flag — suggests tractography failed to reach that region.

## 1.12 Disconnectome analysis

For each `*-lesion` arm, we also compute a **disconnectome matrix**: the connectivity that would have existed but is disrupted by streamlines passing through the lesion.

Three variants:

- **A (parcel-excised):** remove all connectivity to/from lesion-containing parcels.
- **B (stream-excluded):** remove streamlines passing through lesion voxels; recompute connectome.
- **C (both A and B):** most conservative.

Metrics we track per arm:

- `n_edges_primary_gt0` — number of non-zero edges in the reference (primary) connectome
- `n_edges_disrupted_gt0` — number of edges affected by lesion streamlines
- `mean_disconnection_on_primary_edges` — mean fractional disconnection per affected edge
- `total_spared_over_primary` — sum of spared connectivity / sum of primary connectivity (0–1)

Compared to a normative reference (population-average connectome), the disconnectome quantifies **how much predicted disconnection** the lesion causes, independent of the observed subject-level connectome.

## 1.13 Virtual Brain Transplant (LeAPP)

**Problem it solves:** T1w with a lesion cavity confuses FreeSurfer (which expects normal-appearing tissue) and downstream ACT (5TT segmentation labels the lesion as CSF or "other").

**LeAPP's solution:** fill the lesion cavity with mirrored contralateral tissue before running FreeSurfer.

**Sequence** (from `run_vbt.py`):

```
1. Mirror T1w:              fslswapdim -x y z  (right-to-left flip)
2. Lesion-masked reg:       flirt -in Orig -ref Mirror -inweight Mask_invert
                            (exclude lesion voxels from cost function)
3. Half-way transform:      midtrans → 2 half-transforms (Orig→midline, Mirror→midline)
4. Resample to midline:     flirt -applyxfm both original and mirror
5. Compute smooth blend:    Gaussian-smoothed lesion mask (σ = 2 voxels)
                            Blended T1w = Orig * (1 - smooth) + Mirror * smooth
6. Inverse-transform back:  convert_xfm -inverse
                            flirt -applyxfm to original T1w space
7. Mask + combine:          Healthy signal (Orig × inverse mask) + Transplant (blended × mask)
```

**Weakness:** assumes contralateral hemisphere is normal. Bilateral lesions break the mirror step — a known LeAPP failure mode. We list this as an RQ4 finding in the factorial paper.

**Our fix in `run_vbt.py`:** `fslreorient2std` preprocessing before step 1 (see Part 4.1).

## 1.14 fMRIPrep + XCP-D + CIFTI (fsLR)

**fMRIPrep** — resting-state / task BOLD preprocessing:

1. Motion correction (MCFLIRT)
2. Slice-time correction (optional)
3. SDC (if fmap available)
4. Coregistration to T1w
5. Normalization to MNI or fsLR (surface)
6. Confound extraction (Framewise Displacement, aCompCor, DVARS, etc.)

Outputs per `--output-spaces` requested. For us: `T1w`, `MNI152NLin6Asym:res-2`, `fsaverage`, `fsLR` (surface).

**CIFTI / fsLR / grayordinates** — HCP surface convention:

- Cortex: 32,492 vertices per hemisphere (fsLR den-32k mesh) → 64,984 cortical grayordinates
- Subcortical: 31,870 voxels (bilateral thalamus, striatum, cerebellum, etc.) at 2mm iso
- Total: **91,282 grayordinates** = fsLR den-91k

CIFTI files:

- `.dtseries.nii` — time series per grayordinate (4D)
- `.dscalar.nii` — scalar per grayordinate (3D)
- `.pscalar.nii` — scalar per parcel (parcellated)
- `.pconn.nii` — parcel-to-parcel matrix (2D)
- `.ptseries.nii` — time series per parcel

**XCP-D** — post-processing of fMRIPrep outputs:

1. Nuisance regression (36P = 36 confound regressors: 6 motion + 6 derivatives + squares + 3 mean signals: CSF, WM, global)
2. Band-pass filtering (default 0.01–0.08 Hz for resting-state)
3. Denoising (Framewise Displacement scrubbing)
4. Parcellation with multi-atlas support
5. FC matrix computation per atlas
6. Regional metrics (ALFF, ReHo) as dscalar maps
7. QC report

**LINC mode** (`--mode linc`) — Lifespan Informatics NC pipeline convention. Requires fsLR CIFTI input; produces `linc_qc.tsv` with `mean_fd`, `mean_fd_post_censoring`, `mean_relative_rms`, etc.

**Atlases in our XCP-D run:** 4S156Parcels, 4S256Parcels, Gordon, Glasser, HCP.

**Custom DKT extraction:** `postprocess_dkt.py` uses nilearn's `NiftiLabelsMasker` to extract DKT-83 FC from the volumetric preprocessed BOLD — aligns with the SC-side DKT parcellation for same-subject SC↔FC comparison.

## 1.15 Factorial experiment design (anatomy × ACT)

**Factorial design** = manipulating multiple factors simultaneously and measuring their joint effects (main effects + interactions).

**Our factorial is 3 × 2 = 6 arms:**

|                       | ACT: std             | ACT: lesion              |
|-----------------------|----------------------|--------------------------|
| **Anatomy: orig**     | orig-std             | orig-lesion              |
| **Anatomy: neurolit** | neurolit-std         | neurolit-lesion          |
| **Anatomy: vbt**      | vbt-std              | vbt-lesion               |

**Anatomy** axis — which T1w the pipeline processes:
- **orig** — raw T1w (control)
- **neurolit** — deep-learning-inpainted T1w (*standalone* fill; factorial arms set `LIT_MODE=standalone`)
- **vbt** — LeAPP Virtual Brain Transplant (also standalone)

**Production lesion default (DKT pipeline):** `LIT_MODE=integrated` — prepare mask → FastSurfer ≥2.5 `--lesion_mask` on raw T1 (fill + LIT stats in FreeSurfer dir). Opt into standalone with `--lit-standalone`. See `dkt_examples_wt/dwi_pipeline/pipeline_science.md` §1.1.

**ACT** axis — whether streamline propagation respects the lesion:
- **std** — standard ACT (default 5TT, lesion effect implicit)
- **lesion** — lesion-aware ACT (5TT modified by explicit lesion mask)

**Pre-registered contrasts** (from `analysis_plan.md`):

- **Primary**: within-anatomy std vs lesion (3 pairwise contrasts)
- **Secondary**: within-ACT anatomy vs anatomy (6 pairwise contrasts)
- **Interaction**: 2 × 3 repeated-measures ANOVA on the primary metric

**Primary metric**: mean absolute edge difference on the upper triangle of the SIFT2-weighted DKT connectome per subject-arm-pair.

**Statistical framework** (cohort-only): repeated-measures ANOVA with within-subject correction, Bonferroni across the primary contrasts.

**Firewall (per analysis plan § 11):** no group-level inference before the plan is signed off and completion N ≥ threshold. Within-subject pilot descriptives (like our N=1 exploration) are not gated by the firewall.

---

# Part 2 — Pipeline engineering

## 2.1 Snakemake DAG semantics + wildcards + workdir

**Snakemake** is a Python-based workflow engine that reads a `Snakefile` of **rules**. Each rule:

```python
rule qsiprep:
    input:
        dwi = "{results}/bids/sub-{subject}/dwi/sub-{subject}_dwi.nii.gz",
        t1w = "{results}/bids/sub-{subject}/anat/sub-{subject}_T1w.nii.gz",
    output:
        marker = "{results}/.snakemake_markers/sub-{subject}/qsiprep.done",
    params:
        threads = 8,
    shell:
        """
        apptainer run ... {input.dwi} ...
        touch {output.marker}
        """
```

**Wildcards** (`{subject}`) parameterize rules across many concrete subjects. At runtime, Snakemake fills wildcards based on the requested target.

**DAG construction:** Snakemake determines which rule produces each requested output and chains rules together via matching input/output patterns. Missing inputs trigger their producing rules; existing outputs are cached (unless `--forceall`).

**Execution:**

- `--cores N` — parallel job execution
- `--jobs N` — number of concurrent jobs (may include cluster submission)
- `--use-singularity` / `--use-conda` — enable per-rule containerization or conda envs
- Marker files (`touch <path>`) are a common completion signal

**`.snakemake/` metadata directory** — per-workdir bookkeeping:

- `metadata/` — per-output metadata (hash, timestamp, command)
- `locks/` — file locks for concurrent runs
- `incomplete/` — markers for interrupted rules
- `log/` — invocation logs

**Recovery:** if a run is killed mid-rule, Snakemake sees the output as "incomplete" and re-runs on next invocation. If the output is fully written but the process died before Snakemake could record it, the next run may need `--rerun-incomplete` or manual state cleanup.

Our per-arm workdir: `RESULTS_ROOT/arms/<arm>/.snakemake_workdir/sub-<ID>/` — isolates each subject's Snakemake state per arm.

## 2.2 Apptainer / Singularity containerization

**Container = a filesystem + isolated process namespace** packaging an application and its dependencies. For HPC, **Apptainer** (formerly Singularity) is preferred over Docker because it runs as the user's UID (no daemon, no root escalation) and works on shared filesystems.

**SIF images** — Singularity Image Format. Single-file, immutable, cryptographically-verifiable. Built from a definition file or converted from Docker.

**`apptainer run`** — invoke a container:

```bash
apptainer run \
    --cleanenv \                    # start with minimal env
    --containall \                  # full isolation (fresh HOME, /tmp, cwd)
    --env "TEMPLATEFLOW_HOME=/templateflow" \   # set an env var
    -B "$BIDS_DIR:/data:ro" \       # bind-mount host:container[:ro]
    -B "$OUT_DIR:/out" \
    -B "$FS_LICENSE:/opt/freesurfer/license.txt:ro" \
    "$FMRIPREP_SIF" \               # the image
    /data /out participant ...      # arguments passed inside the container
```

**Key flags:**

- `--cleanenv` — drop most host env vars; keep only `APPTAINER_*` and `--env` overrides
- `--containall` — fresh HOME, cwd, /tmp; no host process filesystem visible except explicit binds
- `--env NAME=VALUE` — set env inside the container
- `--gpu` / `--nv` — expose GPU devices
- `-B src:dst[:ro]` — bind mount; RO makes writes silently fail in many tools
- `--pwd /path` — set working directory inside container

**When --cleanenv is needed but breaks something:** must re-export critical env vars via `--env`. Session example: `SUBJECTS_DIR` for FreeSurfer, `TEMPLATEFLOW_HOME` for template caching.

**Container-baked scripts vs host overrides:** the qsiprep container's `/opt/vbt/run_vbt.py` was overridden with `-B host_run_vbt.py:/opt/vbt/run_vbt.py:ro` when `VBT_BIND_DEV=1`. Otherwise, host-side edits are invisible to the running container.

**Verifying you're running the right code inside a container:** add a distinctive log line (`echo "using patched run_vbt.py v20260919"`) and check it appears.

## 2.3 Bind-mount semantics and constraints

**Bind mount** = expose a host path at a specific location inside the container's filesystem. Apptainer treats binds as first-class.

**Rules:**

1. **Only bound paths are visible.** A symlink inside a bound path pointing OUTSIDE the bind → broken inside the container.
2. **`:ro` mounts fail writes silently** in many tools. They treat the read-only as "path doesn't exist" or "no output produced" without a clear error.
3. **Same-path binding** (`-B /host/path:/host/path`) preserves absolute paths across host/container. Symlinks and relative paths work in more cases.
4. **Nested binds:** if `/a` and `/a/b` are both bound, the more specific overrides.
5. **Special mounts** (`/tmp`, `/dev`, `/proc`) can be excluded with `--containall`, restored with `-B`.

**Session gotchas:**

- **fMRIPrep `curv_wf` reading SUBJECTS_DIR env, not CLI flag.** Fix: `--env SUBJECTS_DIR=/fs_subjects_dir`.
- **fMRIPrep writes to subjects_dir; `:ro` bind fails silently.** Fix: copy to writable location, bind `:rw`.
- **Symlinks from BIDS_DIR to TrackTBI_Lesion.** Cross-mount symlinks break because TrackTBI_Lesion isn't bound. Fix: rsync copy.

**Debugging bind issues:** enter the container interactively (`apptainer shell -B ... SIF`) and check `ls`, `readlink`, `env` from inside.

## 2.4 Environment variable propagation

**Chain of env-var propagation:**

```
User's login shell
      │ inherits
      ▼
bash script.sh
      │ export NAME=VALUE
      ▼
subprocess (e.g., ./submit.sh)
      │ inherits + more exports
      ▼
sbatch --export=ALL
      │ captures env at submit time
      ▼
SLURM batch script (compute node)
      │ inherits captured env
      ▼
apptainer run --cleanenv --env NAME=VALUE
      │ strips most env; only --env survives
      ▼
Container process
```

**`sbatch --export=ALL`** (default) — passes the submitter's env to the job.
**`sbatch --export=NONE`** — fresh env.
**`sbatch --export=A,B,C`** — explicit whitelist.

**Common gotcha:** `--cleanenv` strips `SUBJECTS_DIR`, `TEMPLATEFLOW_HOME`, `FREESURFER_HOME`, `LD_LIBRARY_PATH`, `PYTHONPATH`. If a container tool reads any of these, must be `--env`-forwarded.

**Config files read at run time, not submit time.** So if a shared file (subjects.txt) changes between submit and run, the job sees run-time content — which caused our race (see Part 4.8).

## 2.5 Per-arm output isolation

Enforced by `EXPERIMENT_ISOLATE_OUTPUTS=1` (default). All arm outputs live under `RESULTS_ROOT/arms/<arm>/`:

```
arms/<arm>/
├── bids/                             # (optional per-arm BIDS staging)
├── freesurfer/sub-<ID>/              # arm-specific FS (anatomy differs)
├── qsiprep_single_run_output/         # QSIPrep outputs (see below)
├── qsirecon_single_run_output/       # arm-specific 5TT + tractography
├── vbt/sub-<ID>/                     # only in vbt arms; the transplanted T1w
├── lesion_aware_act/sub-<ID>/        # only in *-lesion arms
├── tractography/sub-<ID>/            # arm-specific
├── connectomes/sub-<ID>/             # arm-specific connectome CSVs
├── node_strength/sub-<ID>/           # nodestrength reports
├── qc/sub-<ID>/                      # subject-arm QC summary
├── logs/                             # per-subject-step logs
├── .snakemake_markers/sub-<ID>/      # marker files per rule
└── .snakemake_workdir/sub-<ID>/      # Snakemake work dir (locks, metadata, logs)
```

**Inefficiency worth flagging:** QSIPrep is arm-independent (only depends on DWI + T1w — not anatomy variant or ACT). Re-running it 6× per subject costs ~30 h wall time per subject. Could optimize by symlinking after the first arm, but current design maximizes safety at the cost of duplicated work.

**Cleanup pattern for a failed arm:**

```bash
rm -rf $ARM/freesurfer/sub-$sub $ARM/qsiprep_single_run_output/sub-$sub \
       $ARM/qsirecon_single_run_output/sub-$sub $ARM/vbt/sub-$sub \
       $ARM/lesion_aware_act/sub-$sub $ARM/connectomes/sub-$sub \
       $ARM/tractography/sub-$sub $ARM/qc/sub-$sub \
       $ARM/.snakemake_markers/sub-$sub $ARM/.snakemake_workdir/sub-$sub
```

## 2.6 Marker files and idempotency

**Idempotent** = running twice on already-complete data produces no new work and no errors.

**Marker file pattern:**

```python
rule step:
    input: "input.nii.gz"
    output: marker = ".snakemake_markers/sub-{subject}/step.done"
    shell:
        """
        # do real work
        heavy_command --output real_output.nii.gz {input}
        # only touch marker if the real work succeeded
        touch {output.marker}
        """
```

Snakemake tracks the marker; the marker's existence + timestamp indicate the step is done. The marker file itself is empty; the real outputs live elsewhere (a directory tree).

**When markers go wrong:**

- Step fails mid-execution → partial real outputs on disk, no marker. Snakemake re-runs the step next time. But if the tool refuses to run on partial outputs (FastSurfer!), the retry fails.
- Recovery: delete BOTH partial outputs AND marker before re-running.

**Alternative: output-existence checks in shell:**

```bash
if [[ -f "$OUTPUT" && -s "$OUTPUT" ]]; then
    echo "already done: $OUTPUT"
    exit 0
fi
# ... do work ...
```

## 2.7 SLURM scheduling (arrays, dependencies, states)

**SLURM** = Simple Linux Utility for Resource Management. HPC scheduler.

### Job submission

```bash
sbatch script.slurm            # submit a batch job
sbatch --array=1-5%2 script.slurm   # array with 5 tasks, up to 2 concurrent
```

### #SBATCH directives

```bash
#!/bin/bash
#SBATCH --job-name=my_job
#SBATCH --partition=interactive
#SBATCH --cpus-per-task=8
#SBATCH --mem=32G
#SBATCH --time=12:00:00
#SBATCH --gres=gpu:l40s.24g:1        # 1 24-GB slice of an L40s GPU
#SBATCH --exclude=smdodwork05        # avoid a specific node
#SBATCH --array=1-8%5                # 8-task array, 5 concurrent
#SBATCH --output=logs/%x_%A_%a.out    # %x=jobname, %A=array_id, %a=task_id
#SBATCH --error=logs/%x_%A_%a.err
#SBATCH --dependency=afterany:12345   # start after job 12345 ends
```

### Dependencies

- `afterok:JID` — start only if JID succeeded (exit 0)
- `afterany:JID` — start regardless of JID exit code
- `afternotok:JID` — start only if JID failed
- `after:JID` — start immediately after JID begins (regardless of state)
- `singleton` — only one instance of a job with this name at a time

**Session pattern:** `--sequential --skip-on-fail` in `submit_all_experiment_arms.sh` chains arms with `afterany` so a failed arm doesn't cascade-cancel the rest.

### Job states (from `squeue -T`)

- `PENDING (Reason)` — not yet running. Common reasons: `Dependency`, `Priority`, `Resources`, `PartitionTimeLimit`, `QOSMaxCpuMinutesPerUserLimit`, `Node fail`
- `RUNNING` — executing
- `COMPLETING` — post-run cleanup (usually seconds; can hang if I/O is slow)
- `COMPLETED` — successful exit
- `FAILED` — non-zero exit
- `TIMEOUT` — hit --time limit
- `CANCELLED` (or `CANCELLED+`) — scancel'd
- `NODE_FAIL` — SLURM detected node failure
- `PREEMPTED` — evicted by a higher-priority job (preemption partitions only)

### Query commands

```bash
squeue -u $USER                        # my current jobs
squeue -u $USER --states=RUNNING       # only running
squeue -j 12345                         # specific job
sacct -j 12345 --format=JobID,State,ExitCode,Elapsed,MaxRSS,ReqMem -X
sacct -u $USER --starttime=now-24hours  # historical
scancel 12345                            # cancel one
scancel 12345_1                          # cancel one array task
scancel -u $USER                         # cancel all my jobs
sinfo -p interactive                     # partition info
scontrol show job 12345                  # detailed job info
scontrol show partition interactive      # detailed partition info
scontrol show node smdodwork01           # detailed node info
```

## 2.8 Pipeline preflight validation

`submit.sh` runs a "preflight" check before invoking `sbatch`:

- Required container SIFs exist
- Required env vars set
- Required commands available (`fslreorient2std`, `midtrans`, etc.)
- BIDS subject dir exists
- FreeSurfer license present
- Sensible resource requests

Failures fast-reject at submit time (~1s), avoiding a 1h-into-the-job failure.

**Distinct from run-time validation** inside the Snakemake rules (which verify each step's real output).

**Preflight anti-pattern:** validation so aggressive it blocks valid but unusual configurations. Keep preflight to necessary conditions.

## 2.9 File formats used

| Format | Extension | Purpose | Notes |
|---|---|---|---|
| NIfTI | `.nii`, `.nii.gz` | 3D/4D neuroimaging volumes | Standard for MRI |
| MGZ | `.mgz` | FreeSurfer's compressed NIfTI variant | Used inside FS subject dirs |
| MRtrix Image Format | `.mif`, `.mif.gz` | MRtrix3's native format | FODs, connectomes as CSV or MIF |
| Tractogram (MRtrix) | `.tck`, `.tck.gz` | Streamline tract file | Very large (GB per subject) |
| Tractogram (TrackVis) | `.trk` | Alternative streamline format | Less common in QSIPrep world |
| CIFTI dtseries | `.dtseries.nii` | Surface + subcortical time series | HCP convention |
| CIFTI dscalar | `.dscalar.nii` | Surface + subcortical scalar map | ALFF, ReHo per grayordinate |
| CIFTI pconn | `.pconn.nii` | Parcellated connectivity matrix | Post-parcellation FC |
| CIFTI ptseries | `.ptseries.nii` | Parcellated time series | Post-parcellation BOLD |
| Sidecar JSON | `.json` | BIDS metadata | Paired with each NIfTI |
| bvec / bval | `.bvec`, `.bval` | DWI gradient info | Text files, paired with `_dwi.nii.gz` |

## 2.10 Container orchestration alternatives considered

Not used this session but relevant context:

- **BABS / DataLad** — reproducibility infrastructure that combines DataLad (git-annex for large data) with container-based processing. Would let us track raw DICOM → BIDS → processed outputs with cryptographic provenance.
- **Nextflow / Nipype** — alternative workflow engines. Snakemake was chosen for its Python integration and DAG semantics.
- **Docker Compose / Kubernetes** — cloud-oriented; overkill for an HPC pipeline.

---

# Part 3 — Programming & scripting concepts

## 3.1 Bash idioms used this session

### Variables and expansions

```bash
# Assignment (no spaces around =)
NAME=value
export NAME=value             # export to child processes

# Command substitution
result=$(command)             # modern syntax
result=`command`              # legacy backticks — avoid

# Arithmetic expansion
count=$((n + 1))
size=$((MEM_GB * 1024))       # convert GB to MB

# Parameter expansion
${VAR}                        # value of VAR
${VAR:-default}               # value, or default if unset/empty
${VAR:=default}               # value, or set VAR to default and use it
${VAR:?error}                 # value, or exit with error message
${VAR:+alternate}             # alternate if VAR set, otherwise empty
${VAR#prefix}                 # remove shortest prefix match
${VAR##prefix}                # remove longest prefix match
${VAR%suffix}                 # remove shortest suffix match
${VAR%%suffix}                # remove longest suffix match
${VAR/pattern/replacement}    # replace FIRST match
${VAR//pattern/replacement}   # replace ALL matches
${#VAR}                       # length of VAR
${VAR:offset:length}          # substring
${VAR,,}                      # lowercase (bash 4+)
${VAR^^}                      # UPPERCASE (bash 4+)
```

### Arrays

```bash
# Indexed array
declare -a ARMS=(orig-std orig-lesion neurolit-std)
echo "${ARMS[0]}"             # first element: orig-std
echo "${ARMS[@]}"             # all elements, quoted
echo "${#ARMS[@]}"            # count: 3
echo "${ARMS[@]:1:2}"         # slice: orig-lesion neurolit-std
ARMS+=(vbt-std)               # append
for arm in "${ARMS[@]}"; do   # iterate
    echo "$arm"
done

# Associative array (bash 4+)
declare -A MISSING=(
  [TBI011007]="orig-lesion,neurolit-std"
  [TBI011021]="orig-lesion,vbt-lesion"
)
echo "${MISSING[TBI011007]}"
for sub in "${!MISSING[@]}"; do   # iterate KEYS
    echo "$sub → ${MISSING[$sub]}"
done

# Read command output into array (bash 4+)
mapfile -t files < <(find . -name "*.txt")
```

### Conditionals

```bash
if [[ condition ]]; then ...; fi
[[ -f "$FILE" ]]              # file exists and is regular
[[ -d "$DIR" ]]               # directory exists
[[ -s "$FILE" ]]              # file exists and non-empty
[[ -x "$FILE" ]]              # file exists and executable
[[ -r "$FILE" ]]              # file readable
[[ "$A" == "$B" ]]            # string equality
[[ "$A" != "$B" ]]            # string inequality
[[ "$A" =~ regex ]]           # regex match
[[ "$A" -eq "$B" ]]           # numeric equality
[[ "$A" -lt "$B" ]]           # less than
[[ -z "$STR" ]]               # empty string
[[ -n "$STR" ]]               # non-empty string

# Short-circuit
[[ -f "$FILE" ]] && echo "exists"
[[ -f "$FILE" ]] || echo "missing"

# Compound
[[ -f "$A" && -f "$B" ]] && echo "both exist"
```

### Loops

```bash
for i in 1 2 3; do echo "$i"; done
for i in {1..10}; do echo "$i"; done          # brace expansion
for i in $(seq 1 10); do echo "$i"; done
for f in *.txt; do echo "$f"; done            # glob
for f in ./**/*.txt; do echo "$f"; done       # recursive glob (bash 4+ with shopt -s globstar)

while [[ condition ]]; do ...; done
until [[ condition ]]; do ...; done

# Read file line-by-line
while IFS= read -r line; do
    echo "$line"
done < file.txt
```

### I/O redirection

```bash
cmd > file            # stdout to file (overwrite)
cmd >> file           # stdout to file (append)
cmd 2> file           # stderr to file
cmd &> file           # both stdout and stderr to file
cmd 2>&1              # merge stderr into stdout
cmd 2>/dev/null       # discard stderr
cmd < input.txt       # stdin from file
cmd <<< "string"      # here-string (stdin from string)
cmd | tee file        # split stdout: to terminal AND to file
cmd1 | cmd2           # pipe
```

### Here-docs

```bash
# Unquoted delimiter: variable interpolation active
cat <<EOF
Hello $NAME
EOF

# Quoted delimiter: no interpolation
cat <<'EOF'
Literal $NAME
EOF

# Session example: passing a multi-line commit message
git commit -m "$(cat <<'EOF'
docs: multi-paragraph commit

Second paragraph.
EOF
)"
```

### Process substitution

```bash
diff <(sort file1) <(sort file2)      # feed cmd stdout as if it were a file
mapfile -t arr < <(find . -name '*.json')
tee >(cmd1) >(cmd2) < input           # split stdin to multiple readers
```

### Functions

```bash
run() {
    echo "+ $*" >&2
    "$@"
}

# Usage: run cmd arg1 arg2

# Return value = exit code of last command
# Explicit return: return 0 / return 1

# Local variables (function scope)
my_func() {
    local tmp="$1"
    echo "$tmp"
}
```

### Globbing patterns

```bash
*                     # any string (not including /)
?                     # any single char
[abc]                 # any of a, b, c
[a-z]                 # any lowercase
[!abc]                # any except a, b, c
{a,b,c}               # brace expansion: matches a, b, or c
**                    # recursive (with shopt -s globstar)

# Extended globs (with shopt -s extglob)
?(pattern)            # zero or one
*(pattern)            # zero or more
+(pattern)            # one or more
@(pat1|pat2)          # exactly one of the patterns
!(pattern)            # anything except
```

## 3.2 Bash safety hats

### `set -euo pipefail`

Standard at the top of every script:

- `-e` — exit on any command failure (non-zero exit)
- `-u` — error on unset variable use
- `-o pipefail` — pipeline fails if ANY stage fails, not just the last

Together: your script won't silently continue after errors.

**Caveat:** `set -e` has surprising interactions with `&&` chains, conditionals, and functions. Sometimes you want to explicitly `|| true` a command whose failure you want to ignore.

### `trap` for cleanup

```bash
tmpdir=$(mktemp -d)
trap "rm -rf '$tmpdir'" EXIT
# Anything you do with $tmpdir now is guaranteed to be cleaned up
# even if the script errors out.
```

Trap on `EXIT` catches all script termination (normal exit, error, signal).
Trap on `ERR` catches errors specifically.
Trap on `INT` catches Ctrl-C.

### Quoting

- `"$var"` — expands with word-splitting suppressed. **Use this by default.**
- `'literal'` — no expansion at all.
- `$var` (unquoted) — expands with word-splitting. Only use when you WANT splitting.

**Common bug:** `for f in $(find . -name '*.txt')` breaks on filenames with spaces. Use `while IFS= read -r f; do ...; done < <(find . -name '*.txt' -print0)` or `mapfile`.

## 3.3 Python patterns used this session

### `argparse` for CLIs

```python
import argparse
from pathlib import Path

ap = argparse.ArgumentParser(
    description=__doc__,
    formatter_class=argparse.RawDescriptionHelpFormatter,
)
ap.add_argument("--bids-dir", type=Path, required=True)
ap.add_argument("--subject", action="append",
                help="repeatable; collects all --subject flags into a list")
ap.add_argument("--dry-run", action="store_true")
ap.add_argument("--total-readout-time", type=float,
                help="override TRT for all subjects in this run")
ap.add_argument("--phase-encoding-direction",
                choices=["j-", "j", "i-", "i", "k-", "k"])
args = ap.parse_args()

# Access: args.bids_dir (Path), args.subject (list), args.dry_run (bool)
```

### `pathlib.Path`

```python
from pathlib import Path

root = Path("/some/base")
root.exists(), root.is_file(), root.is_dir()

# Path composition
p = root / "sub-001" / "anat" / "T1w.nii.gz"

# Attributes
p.name        # 'T1w.nii.gz'
p.stem        # 'T1w.nii'  (or 'T1w' after .with_suffix drops)
p.suffix      # '.gz'
p.parent      # '/some/base/sub-001/anat'
p.parents     # iterable of ancestors

# I/O
p.read_text()
p.write_text(content)
p.read_bytes()

# Iteration
for f in root.iterdir():          # direct children
for f in root.glob("*.json"):     # non-recursive glob
for f in root.rglob("*.json"):    # recursive glob
for f in root.rglob("fmap/*.json"):  # deeper pattern

# Metadata
p.stat().st_size
p.stat().st_mtime

# Manipulation
p.with_suffix(".json")            # /some/base/sub-001/anat/T1w.json
p.with_name("brain.nii.gz")       # /some/base/sub-001/anat/brain.nii.gz
p.relative_to(root)               # 'sub-001/anat/T1w.nii.gz'
p.resolve()                        # absolute + resolve symlinks
```

### `subprocess.run`

```python
import subprocess

# Simple invocation with error checking
subprocess.run(["ls", "-la", "/tmp"], check=True)

# Capture output
result = subprocess.run(["date"], capture_output=True, text=True, check=True)
print(result.stdout, result.stderr, result.returncode)

# Session pattern: verbose runner
def run(*args: str) -> None:
    print("+", " ".join(args), flush=True)
    subprocess.run(args, check=True)

# check=True raises subprocess.CalledProcessError on non-zero exit
# stdout/stderr default to inherit (goes to your terminal / SLURM log)
```

### JSON I/O

```python
import json

# Load
data = json.loads(path.read_text())
with open(path) as f: data = json.load(f)

# Dump
text = json.dumps(data, indent=4, sort_keys=False)
path.write_text(text)
with open(path, "w") as f: json.dump(data, f, indent=4)
```

### Type hints (session convention)

```python
from __future__ import annotations   # postponed evaluation of annotations
from pathlib import Path

def load_connectome(root: Path, arm: str, subject: str) -> np.ndarray:
    ...

def fix_phasediff_echoes(
    mag1: Path | None,           # 'X | None' works in 3.10+; use Optional[X] older
    mag2: Path | None,
    phasediff: Path,
    *,
    dry_run: bool,
) -> None:
    ...
```

### Context managers

```python
import tempfile
from pathlib import Path

with tempfile.TemporaryDirectory(prefix="vbt_") as tmp:
    # tmp is automatically deleted on exit
    work = Path(tmp)
    ...

with open(path) as f:
    # f automatically closed
    data = f.read()
```

## 3.4 Python scientific stack (numpy, pandas, matplotlib, nibabel)

### numpy for matrix operations

```python
import numpy as np

# Load a CSV connectome
mat = np.loadtxt(path, delimiter=",")

# Basic properties
mat.shape                    # (78, 78)
mat.dtype                    # float64
mat.size                     # 6084

# Upper triangle (excluding diagonal)
n = mat.shape[0]
iu = np.triu_indices(n, k=1)  # (row_indices, col_indices)
upper = mat[iu]               # 1D array of upper-triangle values

# Boolean masking
positive = mat[mat > 0]
mat[mat < 0] = 0

# Reductions
mat.sum(), mat.mean(), mat.max()
mat.sum(axis=0)              # column sums (row of length n)
mat.sum(axis=1)              # row sums (node strengths for a connectome)

# Statistics
np.corrcoef(a, b)[0, 1]      # Pearson correlation
np.abs(a - b).mean()         # mean absolute difference
np.linalg.norm(mat, ord="fro")  # Frobenius norm

# Random
np.random.seed(42)
np.random.normal(0, 1, size=100)
```

### pandas for tabular data

```python
import pandas as pd

# DataFrame construction
df = pd.DataFrame({
    "arm": ["orig-std", "orig-lesion"],
    "n_edges": [2909, 2924],
    "mean_weight": [2232.2, 2253.1],
})

# I/O
df.to_csv("out.csv", index=False)
df = pd.read_csv("in.csv")

# Access
df["arm"]                     # column as Series
df.iloc[0]                     # first row
df.loc[df.arm == "vbt-std"]    # filter

# Pivot / reshape
df.pivot(index="anatomy", columns="act", values="mean_weight")
```

### matplotlib

```python
import matplotlib.pyplot as plt

fig, axes = plt.subplots(2, 3, figsize=(15, 10), constrained_layout=True)
for i, arm in enumerate(ARMS):
    ax = axes[i // 3, i % 3]
    im = ax.imshow(connectomes[arm], cmap="magma", vmin=0, vmax=vmax)
    ax.set_title(arm)
    ax.set_xticks([]); ax.set_yticks([])

fig.colorbar(im, ax=axes, shrink=0.75)
fig.suptitle("Title")
fig.savefig("out.png", dpi=150, bbox_inches="tight")
plt.close(fig)
```

### nibabel for NIfTI I/O

```python
import nibabel as nib

img = nib.load("T1w.nii.gz")
data = img.get_fdata()        # ndarray, shape from header
affine = img.affine           # 4x4 world coordinate matrix
header = img.header

# Save (preserving affine + header)
new = nib.Nifti1Image(new_data, affine, header)
nib.save(new, "out.nii.gz")

# Read MGZ (FreeSurfer)
img = nib.load("aparc+aseg.mgz")
```

## 3.5 Race conditions & concurrency

**Race condition**: two or more concurrent operations access shared mutable state without synchronization; outcome depends on interleaving.

**Session example:** `submit_all_experiment_arms.sh` wrote to shared `subjects.txt`. When 5 submits ran in a loop, later SLURM jobs read the LAST-written value.

**General patterns to watch:**

1. **Time-of-check-time-of-use (TOCTOU):** `if [[ -f $F ]]; then rm $F; fi` — file could be deleted between check and rm.

2. **Shared mutable state:** any file, env var, or in-memory value that multiple processes read and one might write.

3. **Dependency ordering:** SLURM `afterany` fires downstream regardless of upstream success. If downstream reads shared state populated by upstream, ordering assumptions may fail.

**Fixes:**

- **Per-actor state:** give each subject / job / process its own file (`subjects_${SUBJECT}.txt`).
- **Env-var-based defaults with `${VAR:-default}`**: let callers override without editing scripts.
- **Atomic file operations:** write to temp, `mv`/`os.replace()` — reader sees either old or new, never partial.
- **Explicit locking** (rare for our use): `flock`, `mkdir` as an atomic lock primitive.

## 3.6 Atomic operations

**Atomic** = observable as either "not started" or "fully complete", never partial.

**Filesystem atomicity guarantees:**

- **`os.rename` / `os.replace`**: POSIX-guaranteed atomic within a single filesystem. `mv` when both source and dest are on the same mount is atomic.
- **`open(..., "w")` + write in place**: NOT atomic. A reader can see a partial file. Common bug source.
- **Directory rename**: atomic if within a single filesystem.
- **File creation via `open(..., "x")`**: atomic; fails if file exists (useful for lock files).

**Standard atomic-write pattern in Python:**

```python
import os
from pathlib import Path

def atomic_write(path: Path, content: str) -> None:
    tmp = path.with_suffix(path.suffix + ".tmp")
    tmp.write_text(content)
    os.replace(tmp, path)
```

Our repair script doesn't currently do this — a possible future improvement.

## 3.7 Provenance and reproducibility

**Provenance** = record of what produced a given output, sufficient to reproduce it or verify claims.

**Layers of provenance used this session:**

1. **JSON manifest per analysis run:** `provenance.json` with subject, session, script, git commit, container SHA, timestamp, parameters, interpretive note.

2. **Command logging:** every subprocess invocation prefixed `+ command args` via the `run(*args)` helper; captured in SLURM `.out`/`.err`.

3. **Marker files:** presence indicates step ran; timestamp indicates when.

4. **HTML reports:** fMRIPrep, QSIPrep, XCP-D auto-generate reports with methods paragraphs. **Truth source** for what preprocessing was applied.

5. **Config-driven parameters:** `config/*.json` (rather than script hardcodes) makes runs deterministic and re-invocable.

6. **Sidecar repair provenance:** the finding doc records source of each value (e.g., magnitude JSON EchoTime), the command run, the exact values written.

7. **Container SHAs:** for full reproducibility, record `apptainer inspect --hash SIF` for each SIF at run time.

**Anti-patterns:**

- Reading a value from a spreadsheet and hardcoding in a script → the spreadsheet becomes an undocumented dependency.
- Modifying data in place without keeping the pre-modification state (or a git commit).
- Using unpinned software versions inside containers.

## 3.8 Version control patterns (git)

Not heavily used this session but relevant:

- **Commit early, commit often** — smaller commits are easier to review and revert.
- **Descriptive commit messages** — start with a type prefix (`fix:`, `docs:`, `feat:`) and imperative mood ("Add X" not "Added X").
- **Never rewrite public history.** Force-push, `reset --hard`, `rebase -i` on a shared branch break collaborators.
- **Never `--no-verify` failing hooks** — the hook is telling you something.
- **Prefer `git add <file>` over `git add .`** — avoids accidentally committing secrets, large binaries, or scratch files.

**Session convention for commit messages:**

```
type(scope): short description

Longer paragraph if needed explaining why (not what).

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>
```

Types: `fix`, `feat`, `docs`, `refactor`, `test`, `chore`, `ops`.

---

# Part 4 — Session tasks (chronological work log)

## 4.1 VBT — midtrans SIGSEGV fix

### Problem
`midtrans` (FSL) crashes with SIGSEGV during LeAPP's VBT step for TBI011011. Reproduced 5 times across nodes (jobs 64321, 64330, 64332, 64767, 76165).

### Diagnosis
1. Ruled out compute environment (crash on multiple nodes, deterministic).
2. Inspected T1w header with `fslhd`: `sform_code=1`, but sform matrix determinant **negative** — radiological convention.
3. Minimal reproducer outside Snakemake in the same container: crash without preprocessing, success with `fslreorient2std`.

### Fix — `scripts/run_vbt.py`

```python
# Reorient T1w + mask to FSL standard (positive-determinant sform).
shutil.copy2(t1w, work / "Orig_raw.nii.gz")
run("fslreorient2std", str(work / "Orig_raw.nii.gz"), str(work / "Orig.nii.gz"))
orig_std_img = nib.load(work / "Orig.nii.gz")
shutil.copy2(mask, work / "Mask_raw.nii.gz")
run("fslreorient2std", str(work / "Mask_raw.nii.gz"), str(work / "Mask_std.nii.gz"))
mask_std_img = nib.load(work / "Mask_std.nii.gz")
binary_mask = (mask_std_img.get_fdata() != 0).astype(np.float32)
save_like(binary_mask, orig_std_img, work / "Mask.nii.gz")
save_like(1.0 - binary_mask, orig_std_img, work / "Mask_invert.nii.gz")
```

Also added `"fslreorient2std"` to `REQUIRED_FSL_COMMANDS` so the preflight catches its absence.

### Deployment gotcha (VBT_BIND_DEV=1)
The qsiprep container has `run_vbt.py` baked at `/opt/vbt/run_vbt.py`. Host-side edits don't affect the container without a bind-mount override, gated by `VBT_BIND_DEV=1`:

```bash
VBT_BIND_DEV=1 bash scripts/submit_all_experiment_arms.sh <SUB> ...
```

Long-term: rebuild the SIF with the patched script.

### Validation
End-to-end 14-step Snakemake DAG completed for both TBI011011 vbt arms:
- **vbt-lesion** (job 76167): 6h 47min, 78×78 DKT connectome, 0 empty nodes
- **vbt-std** (job 76168): 5h 05min, 78×78 DKT connectome, 0 empty nodes

### Files touched
- `dwi_pipeline/scripts/run_vbt.py`
- `dwi_pipeline/docs/papers/factorial_paper/vbt_orientation_finding.md`

## 4.2 fMRI CIFTI/LINC pipeline — six cascading fixes

XCP-D `--mode linc` requires fsLR CIFTI. fMRIPrep was producing volumetric-only. Six fixes:

1. Added `fsaverage fsLR` to `--output-spaces`, plus `--cifti-output 91k`.
2. Added `--env "SUBJECTS_DIR=/fs_subjects_dir"` because `--cleanenv` strips it and fMRIPrep's `curv_wf.get_surfaces` reads from env.
3. Removed `--fs-no-reconall` — in fMRIPrep 24.x it disables ALL surface work; auto-detection of `recon-all.done` works without it.
4. Changed FS bind from `:ro` to `:rw` and pointed at a writable copy (`fmri_derivatives/freesurfer/`).
5. XCP-D 0.10.6 flag renames: `-p 36P`, `-r 50`, `-f 0.5`, `--mode linc`, `--linc-qc y --abcc-qc n`.
6. `postprocess_dkt.py`: dropped nilearn ≥ 0.11 kwargs `copy_header`, `force_resample`.

Final working `run_fmriprep.sh` invocation:

```bash
apptainer run --cleanenv --containall \
  --env "TEMPLATEFLOW_HOME=/templateflow" \
  --env "SUBJECTS_DIR=/fs_subjects_dir" \
  -B "$BIDS_DIR:/data:ro" \
  -B "$OUT_DIR:/out" \
  -B "$WORK_DIR:/work" \
  -B "$FS_LICENSE:/opt/freesurfer/license.txt:ro" \
  -B "$FS_SUBJECTS_DIR:/fs_subjects_dir" \
  -B "$BIDS_FILTER:/work/bids_filter.json:ro" \
  -B "$TEMPLATEFLOW_HOME:/templateflow" \
  "$FMRIPREP_SIF" \
    /data /out participant \
      --participant-label "$SUBJECT" \
      --bids-filter-file /work/bids_filter.json \
      --task-id rest \
      --fs-subjects-dir /fs_subjects_dir \
      --output-spaces T1w MNI152NLin6Asym:res-2 fsaverage fsLR \
      --cifti-output 91k \
      --nprocs "$NTHREADS" --omp-nthreads "$NTHREADS" \
      --mem-mb $((MEM_GB * 1024)) --work-dir /work \
      --skip-bids-validation --use-syn-sdc warn --stop-on-first-crash
```

**Deliverables verified for TBI011011 ses-2WK:** fsLR-91k dtseries, 5-atlas parcellated FC (4S156, 4S256, Gordon, Glasser, HCP), ALFF + ReHo dscalar maps, LINC-QC (`mean_fd = 0.14mm`), DKT-83 FC.

Files touched:
- `fMRI_pipeline/scripts/run_fmriprep.sh`
- `fMRI_pipeline/scripts/run_xcpd.sh`
- `fMRI_pipeline/scripts/run_pilot.sh`
- `fMRI_pipeline/scripts/postprocess_dkt.py`

## 4.3 Pilot factorial analysis — N=1 descriptive

Script: `dwi_pipeline/analysis/paper1/pilot_factorial.py`

Loads all 6 SIFT2-weighted DKT connectomes for the pilot subject, computes per-arm summary stats and pairwise arm-to-arm metrics:

```python
def pairwise_arm_diffs(conn):
    for a, b in combinations(conn.keys(), 2):
        ut_a, ut_b = upper_triangle(conn[a]), upper_triangle(conn[b])
        mean_abs = float(np.abs(ut_a - ut_b).mean())      # PRIMARY per analysis_plan
        pearson = float(np.corrcoef(ut_a, ut_b)[0, 1])
        frob = float(np.linalg.norm(conn[a] - conn[b], ord="fro"))
```

Pre-specified contrasts (per `analysis_plan.md`):
- **Primary**: within-anatomy std vs lesion
- **Secondary**: within-ACT anatomy vs anatomy

Result for TBI011011:

| Primary contrast | Mean\|edge diff\| | Pearson r |
|---|---:|---:|
| orig std vs lesion | 146.5 | 0.9979 |
| neurolit std vs lesion | 142.3 | 0.9975 |
| **vbt** std vs lesion | **140.1** | 0.9979 |

Directional signal matches LeAPP theory (orig > neurolit > vbt). At N=1, that's a data point, not a test.

Outputs: 8 CSVs + 2 PNGs + provenance JSON to `<out-dir>/sub-TBI011011_ses-2WK/`.

## 4.4 Cohort copy from `TrackTBI_Lesion/`

Symlink approach doesn't work because `TrackTBI_Lesion/` isn't bound into containers. Fix: rsync copy.

```bash
BIDS_DIR=/mnt/nfs/Gugger_Lab/NIR/dwi_test_TBI_experiment/bids
SRC=/mnt/nfs/home/URMC-SH/pndagiji/Documents/TrackTBI-Sub/TrackTBI_Lesion
for sub in TBI011007 TBI011021 TBI011029 TBI011140 TBI021030; do
  rsync -a "$SRC/sub-$sub" "$BIDS_DIR/"
done
```

Total ~1.5 GB. All 5 subjects have T1w + DWI + lesion mask + rs-fMRI at ses-2WK.

## 4.5 DWI shell mismatch

Default `dwi_select_b1000.json` matches b=1000 ± 100. Our new 5 subjects (and TBI011011) use b=1300. Symptom: `no DWI matched target_shell_b=1000` → qsiprep preflight failure in ~60 sec.

Diagnostic script:

```bash
for sub in TBI011007 TBI011021 TBI011029 TBI011140 TBI021030 TBI011011 TBI011204; do
  bval=$(find $BIDS_DIR/sub-$sub/ses-2WK/dwi -name "*.bval" | head -1)
  echo "$sub: $(tr ' ' '\n' < $bval | awk '{print int(($1+50)/100)*100}' | sort -un | tr '\n' ' ')"
done
```

Fix: use `--dwi-select /path/to/dwi_select_b1300_ses-2WK.json` on the submit. Config already existed.

## 4.6 SDC decision tree

Walked through 4 options: no SDC flag (error) → `--syn` (works but preprocessing inconsistent with TBI011011 pilot which was `--no-sdc`) → `--no-sdc` (matches pilot but no correction) → real Case-2 fmap (only for TBI011204).

**QSIPrep flag reference:**

| Flag | Behavior |
|---|---|
| (no flag) | Discover fmap via IntendedFor; error if none |
| `--syn` | Add `--use-syn-sdc error`; prefer real fmap, SyN fallback |
| `--fmap-retry` | Ignore measured fmaps, always SyN |
| `--no-sdc` | Add `--ignore fieldmaps`; TOPUP still runs on embedded reverse-PE |

**What CIDUR actually did** (from QSIPrep HTML report inspection):

| Subgroup | Fmap present? | SDC method actually run |
|---|:-:|---|
| Siemens (Skyra, TrioTim) | reverse-PE dir-pa EPI | TOPUP folded into Eddy |
| GE (SIGNA Premier) | none | Eddy only, no SDC |

## 4.7 BIDS sidecar repair — `repair_bids_sidecars.py`

Four passes per `(subject, session, fmap-acq)` group. Full source in `sidecar_repair_finding.md` appendix. Key excerpts:

```python
def group_fmap_jsons(subj_root):
    groups = {}
    for jpath in sorted(subj_root.rglob("fmap/*.json")):
        ent, suffix = parse_entities(jpath.name)
        if suffix not in ("magnitude1", "magnitude2", "phasediff",
                          "magnitude", "phase", "fieldmap"):
            continue
        key = (ent.get("session"), ent.get("acquisition"))
        groups.setdefault(key, {})[suffix] = jpath
    return groups

def fix_phasediff_echoes(mag1, mag2, phasediff, *, dry_run):
    meta = load_json(phasediff)
    et1 = load_json(mag1).get("EchoTime") if mag1 else meta.get("EchoTime1")
    et2 = load_json(mag2).get("EchoTime") if mag2 else meta.get("EchoTime2")
    if et1 is None or et2 is None:
        print(f"skip EchoTime1/2 on {phasediff.name}: no source"); return
    for key in ("EchoTime", "EchoTime1", "EchoTime2"):
        meta.pop(key, None)
    anchor = next((k for k in ("EchoNumber", "SAR", "FlipAngle") if k in meta),
                  "RepetitionTime")
    meta = reorder_after_key(meta, anchor, {"EchoTime1": et1, "EchoTime2": et2})
    save_json(phasediff, meta)

def derive_pe_block(meta, *, pe_dir, total_readout_time):
    n_pe = recon_matrix_pe(meta)
    ees = total_readout_time / (n_pe - 1)
    bwpppe = 1.0 / (ees * n_pe)
    return {
        "PhaseEncodingDirection": pe_dir,
        "TotalReadoutTime": total_readout_time,
        "EffectiveEchoSpacing": round(ees, 9),
        "BandwidthPerPixelPhaseEncode": round(bwpppe, 6),
    }
```

**Design boundary — what the script does NOT do:**
- Does not create `.nii.gz` files (missing magnitudes must be recovered by DICOM re-conversion)
- Does not create reverse-PE `epi.nii.gz` for TOPUP
- Does not fabricate EchoTime values
- Does not compute `TotalReadoutTime` from DICOMs (must be provided)

## 4.8 subjects.txt race condition

Bug: `submit_all_experiment_arms.sh:66` unconditionally overwrote a shared `subjects.txt`. Parallel submits from a loop clobbered the file → downstream SLURM jobs (chained via `afterany`, running hours later) read the wrong subject.

Symptom: log filename `sub-TBI011204_recon.log` inside job `76281` (which was `tbi_tbi011007_orig_lesion`). Anomalous cross-subject filenames in logs → shared mutable state race.

Fix in `submit_all_experiment_arms.sh:66`:

```bash
# Before
export SUBJECT_LIST_FILE="${DWI_ROOT}/subjects.txt"

# After
export SUBJECT_LIST_FILE="${SUBJECT_LIST_FILE:-${DWI_ROOT}/subjects_${SUBJECT}.txt}"
```

Two changes: (a) `:-` default so callers can override, (b) per-subject default filename so parallel submits never collide.

## 4.9 Storage management & CIDUR cleanup

Symptom: `[Errno 28] No space left on device` on tiny (<1 KB) Snakemake metadata writes. `df -h` shows 95 TB free on 3.9 PB filesystem → per-project quota, not raw bytes.

Enumerated + safely deleted 470 GB of raw iFOD2 tractograms in CIDUR:

```bash
CIDUR_DERIV=/mnt/nfs/Gugger_Lab/NIR/dwi_CIDUR/results/qsirecon_single_run_output/derivatives/qsirecon-MRtrix3_fork-SS3T_act-HSVS
find $CIDUR_DERIV -name "*_streamlines.tck.gz" -type f > /tmp/tck_delete_list.txt
xargs -a /tmp/tck_delete_list.txt du -c | tail -1    # verify total: 470 GB
xargs -a /tmp/tck_delete_list.txt rm -f              # execute
```

All 59 subjects have final `dkt_connectome_sift2.csv` — tractograms are recoverable by re-running QSIRecon. 449 GB freed, 0 tractograms remaining, 59 connectomes intact.

## 4.10 TBI011204 end-to-end real Case-2 fmap execution

**User Task 1:** EchoTime1 from magnitude1.json + EchoTime2 from magnitude2.json → into phasediff.json, replacing bare EchoTime.

**Prerequisite: backfill missing default fmap JSONs** from source (`phase2_test/sub-TBI011204/ses-2WK/fmap/`):

```bash
SRC=/mnt/nfs/Gugger_Lab/NIR/phase2_test/sub-TBI011204/ses-2WK/fmap
DST=/mnt/nfs/Gugger_Lab/NIR/dwi_test_TBI_experiment/bids/sub-TBI011204/ses-2WK/fmap
cp -av $SRC/sub-TBI011204_ses-2WK_{magnitude1,magnitude2,phasediff}.json $DST/
```

**Values from source:**
- `magnitude1.json` EchoTime = 0.00492 s
- `magnitude2.json` EchoTime = 0.00738 s
- User-provided: PED = `j-`, TRT = 0.0346501 s

**Repair execution:**

```bash
python3 dwi_pipeline/scripts/repair_bids_sidecars.py \
    --bids-dir /mnt/nfs/Gugger_Lab/NIR/dwi_test_TBI_experiment/bids \
    --subject TBI011204 \
    --total-readout-time 0.0346501 \
    --phase-encoding-direction j-
```

**Persistent config entry:**

```json
"TBI011204": {
  "total_readout_time": 0.0346501,
  "phase_encoding_direction": "j-"
}
```

**Result:** default `phasediff.json` now has `EchoTime1=0.00492`, `EchoTime2=0.00738`, `IntendedFor → …_acq-b1000_dwi.nii.gz`, PE block. Derived `EffectiveEchoSpacing=0.000364738 s`, `BandwidthPerPixelPhaseEncode=28.559321 Hz`. `acq-rs` group's IntendedFor stripped.

**Then:** nuked all 4 previously-completed-with-`--syn` TBI011204 arms and resubmitted all 6 arms WITHOUT `--syn` so QSIPrep uses the wired real Case-2 fmap for PRELUDE + FUGUE SDC.

Documented in `sidecar_repair_finding.md § "Executed repair record"`.

---

# Part 5 — Debugging & documentation

## 5.1 Diagnostic patterns

### Look at the actual log, not the summary
SLURM shows FAILED at the job level; the real error is buried in an arm's `.err` log or a step's per-log. Grep for `Error|error|WorkflowError|_pipeline_fail|Killed|Signal|Traceback`.

### Check the HTML report, don't infer from flags
fMRIPrep, QSIPrep, XCP-D auto-generate HTML reports containing the actual methods paragraph. `--no-sdc` in the submit script doesn't mean no SDC ran (TOPUP can still fire on embedded reverse-PE).

### Compare working vs failing
Pilot succeeded, cohort fails → what's different? DWI shell, fmap presence, T1w orientation, PE direction, quotas, container versions.

### Reproduce in isolation
Minimal reproducer outside Snakemake / SLURM. If a container's tool crashes, run the same invocation with the same input outside the pipeline to prove it's the tool, not the wrapper.

### File-mtime tells
The mtime of a sidecar tells you when it was last written. If mtime predates a claimed repair, the repair didn't happen.

### Anomalous cross-contamination
If job A's log contains subject B's filenames, look for shared mutable state (a shared file that both jobs read).

### Instrument with distinctive markers
When you change code inside a container-mounted script, add a distinctive log line (`echo "PATCH v20260919"`) and verify it appears. Otherwise you might be running the container-baked original.

## 5.2 Anti-patterns to avoid

- Never `rm -rf` a globbed path without enumerating first.
- Never `--no-verify` a pre-commit hook that fails.
- Never force-push or `reset --hard` as a debugging shortcut.
- Never mix preprocessing methods within-subject without a full re-run from qsiprep.
- Never trust `df -h` percentage on huge filesystems (rounding hides GB-scale changes).
- Never assume a "default" config works for a new cohort.
- Never guess a value when you can look it up (source DICOMs, magnitude JSONs, imaging tech).
- Never commit a script without testing it in dry-run mode first (for pipeline-affecting changes).
- Never let a running job silently produce useless output because it's mid-flight and hard to cancel.

## 5.3 Reversibility ladder

From cheap to expensive:

| Action | Reversibility | Cost of undo |
|---|---|---|
| Edit a text file | Trivial (git undo) | Zero |
| Delete derived outputs (connectomes, reports) | Cheap | Re-run pipeline (hours) |
| Cancel a running SLURM job | Cheap | Compute-time already spent |
| Delete tractograms | Moderate | Re-run QSIRecon (~5h × N) |
| Delete FreeSurfer outputs | Expensive | Re-run recon (~10h × N) |
| Delete raw BIDS data | Very expensive | Requires re-acquisition |
| Overwrite shared state (subjects.txt) | Cheap alone, disastrous under concurrency | Debug + re-submit; bounded by cohort size × wall time |
| Force-push shared git history | Very expensive | Breaks all collaborators |

## 5.4 Documentation discipline

- Every non-trivial fix gets a `_finding.md` in `docs/papers/factorial_paper/`.
- Structure: executive summary → diagnostic timeline → root-cause narrative → fix code → reproduction steps → deployment notes → manuscript-treatment suggestion.
- Configuration changes captured in `config/*.json`, not just described in prose.
- Session-level walkthroughs (this file) reference all artifacts.
- Every doc has a "See also" section with cross-links.
- When a task is *executed*, the doc records **what was written to disk** — not just "the tool can do this".

---

# Reference

## Files created or modified this session

### New files
- `dwi_pipeline/analysis/paper1/pilot_factorial.py` — within-subject descriptive analyzer
- `dwi_pipeline/docs/papers/factorial_paper/sidecar_repair_finding.md` — 901-line writeup with verbatim code appendix
- `dwi_pipeline/learning_dkt-connectome.md` — this doc

### Modified files
- `dwi_pipeline/scripts/run_vbt.py` — fslreorient2std preprocessing
- `dwi_pipeline/scripts/submit_all_experiment_arms.sh` — per-subject SUBJECT_LIST_FILE
- `dwi_pipeline/config/bids_repair_defaults.json` — TBI011204 subject block
- `dwi_pipeline/docs/papers/factorial_paper/index.md` — sidecar-finding cross-link
- `dwi_pipeline/docs/papers/factorial_paper/factorial_missing.md` — VBT risk register update
- `dwi_pipeline/docs/papers/factorial_paper/leapp_lineage.md` — VBT contribution added
- `dwi_pipeline/docs/papers/factorial_paper/vbt_orientation_finding.md` — end-to-end validation table
- `fMRI_pipeline/scripts/run_fmriprep.sh` — CIFTI + FS env + writable bind + no --fs-no-reconall
- `fMRI_pipeline/scripts/run_xcpd.sh` — LINC mode + flag renames
- `fMRI_pipeline/scripts/run_pilot.sh` — writable FS_SUBJECTS_DIR
- `fMRI_pipeline/scripts/submit_pilot.slurm` — expanded pilot list to 8 subjects
- `fMRI_pipeline/scripts/postprocess_dkt.py` — nilearn compat

### Data operations
- Copied 5 TBI subjects into BIDS from `TrackTBI_Lesion/`
- Deleted 470 GB of CIDUR raw tractograms (52 files)
- Backfilled TBI011204 default fmap JSONs from `phase2_test`
- Nuked and re-ran TBI011204 arms without `--syn` after sidecar repair

## Glossary

- **ACT** — Anatomically-Constrained Tractography (MRtrix3 term)
- **afterany / afterok** — SLURM job dependency types
- **aparc+aseg.mgz** — FreeSurfer parcellation + subcortical segmentation
- **Apptainer** — HPC container runtime (formerly Singularity)
- **atomic operation** — either fully complete or not at all; no observable partial state
- **b-value / b-shell** — DWI gradient strength (s/mm²)
- **BIDS** — Brain Imaging Data Structure
- **CIFTI** — Connectivity Informatics File Format (HCP surface + subcortical)
- **CSD** — Constrained Spherical Deconvolution (DWI processing method)
- **CSD/SS3T** — Single-Shell 3-Tissue variant of CSD
- **DKT** — Desikan-Killiany-Tourville cortical atlas (78 parcels)
- **DAG** — Directed Acyclic Graph (Snakemake execution model)
- **dcm2niix** — DICOM to NIfTI converter
- **ENOSPC** — POSIX errno "No space left on device"
- **EPI** — Echo Planar Imaging (fast readout used for DWI and BOLD)
- **fmap** — fieldmap (BIDS modality for SDC input)
- **FOD** — Fiber Orientation Distribution
- **fsLR** — HCP's 32k-per-hemisphere surface template
- **FUGUE** — FSL tool for EPI unwarping with a fieldmap
- **HARDI** — High Angular Resolution Diffusion Imaging (many gradient directions)
- **HSVS** — Hybrid Surface-Volume Segmentation (5TT source)
- **idempotency** — property that repeating an operation yields the same result
- **iFOD2** — 2nd-order probabilistic tractography (MRtrix3)
- **IntendedFor** — BIDS sidecar field linking fmap → target EPI
- **LeAPP** — Lesion-Aware Preprocessing Pipeline (Bey 2024)
- **LINC** — Lifespan Informatics Neuroimaging Center (XCP-D mode)
- **magnitude1/2** — BIDS Case-2 fieldmap magnitude images at two echoes
- **midtrans** — FSL tool computing the half-way transform
- **neuroLIT / FastSurfer-LIT** — lesion inpainting; **integrated** (default) = FastSurfer `--lesion_mask`; **standalone** = separate `lit-inpainting` then recon
- **NIfTI** — Neuroimaging Informatics Technology Initiative (image format)
- **PED / PhaseEncodingDirection** — BIDS field (`j-`, `i`, etc.)
- **phasediff** — BIDS Case-2 phase-difference image
- **PRELUDE** — FSL tool for phase unwrapping
- **QSIPrep** — DWI preprocessing pipeline (motion, eddy, SDC)
- **QSIRecon** — DWI reconstruction pipeline (FOD, ACT, tractography, connectome)
- **race condition** — outcome depends on interleaving of concurrent operations
- **reverse-PE** — opposite phase-encoding acquisition for TOPUP
- **SD_STREAM** — deterministic tractography (peak-following)
- **SDC** — Susceptibility Distortion Correction
- **sform** — NIfTI's world coordinate matrix
- **SIFT2** — MRtrix3 streamline reweighting
- **Snakemake** — Python-based workflow manager (DAG)
- **SS3T** — Single-Shell 3-Tissue constrained spherical deconvolution
- **subjects.txt** — pipeline's list-of-subjects-to-process file
- **SyN** — Symmetric Normalization (ANTs registration; also used for synthetic SDC)
- **TOCTOU** — Time-of-check-time-of-use (race condition class)
- **TOPUP** — FSL tool for SDC from reverse-PE b=0 pairs
- **TRT / TotalReadoutTime** — BIDS field (seconds) for the phase-encoding readout duration
- **VBT** — Virtual Brain Transplant (LeAPP's lesion-fill method)
- **XCP-D** — DCAN/LINC post-processing for fMRI
- **5TT** — 5-Tissue-Type segmentation (CGM, SGM, WM, CSF, Pathological)

---

*End of walkthrough. Parts 1–3 = concepts; Part 4 = the actual work log
you can trace through the codebase; Part 5 = the lens for future
debugging. Reference at the end for file paths and jargon.*
