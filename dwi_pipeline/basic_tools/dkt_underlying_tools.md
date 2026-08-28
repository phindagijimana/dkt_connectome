# DKT Connectome underlying tools by pipeline step

## Purpose

This guide explains what happens in each stage of the DKT Connectome Pipeline:

1. Step 1 — QSIPrep diffusion preprocessing
2. Step 1.1 — neuroLIT lesion inpainting
3. Step 2 — FreeSurfer or FastSurfer anatomical reconstruction
4. Step 3 — QSIRecon diffusion reconstruction and tractography
5. Step 4 — DKT connectome construction
6. Step 4.1 — optional disconnectome analysis
7. Step 5 — node strength, asymmetry, and reporting

For every stage, the guide provides:

- A 12th-grade-level conceptual explanation.
- Inputs and outputs.
- The underlying programs.
- Mathematical theory and rendered formulas.
- An explanation of every symbol.
- A representative production command.
- A line-by-line code walkthrough.
- Summaries and key ideas of the supporting papers.

The commands are representative of the actual pipeline implementation. Paths
such as `${BIDS_DIR}` are variables filled by the workflow. Simplified Python
examples explain the calculations but do not replace the production source.

## How to read the mathematics

- \(x\) normally means a position or voxel.
- \(I(x)\) is image brightness at position \(x\).
- \(S\) usually means diffusion MRI signal.
- A hat, as in \(\hat S\), means an estimate.
- \(\sum\) means add a collection of values.
- \(\arg\min\) means choose settings that make an error as small as possible.
- \(\arg\max\) means choose the option with the largest score.
- \(\|\cdot\|^2\) is a total squared-error measurement.
- \(\lambda\) controls the balance between competing goals.
- \(\mathbf 1[\text{condition}]\) equals 1 when the condition is true and 0
  otherwise.

The equations summarize a method's goal. Production software contains
additional numerical safeguards, optimizers, and quality checks.

## End-to-end view

```text
BIDS T1w + DWI + metadata + optional lesion mask
                       |
                       v
Step 1: QSIPrep -> corrected DWI, T1w reference, transforms, QC
                       |
          +------------+-------------+
          |                          |
          v                          v
Step 1.1: neuroLIT             Original lesion retained
          |                          |
          v                          |
Step 2: FreeSurfer/FastSurfer        |
          |                          |
          +------------+-------------+
                       v
Step 3: QSIRecon -> FOD, 5TT, ACT tractogram, SIFT2
                       |
                       v
Step 4: DKT labels + tractogram -> DKT connectivity matrix
                       |
          +------------+-------------+
          |                          |
          v                          v
Step 4.1: Disconnectome       Step 5: Node metrics/report
```

# Step 1 — QSIPrep diffusion preprocessing

## Beginner concept

Diffusion MRI is collected as many brain images, each sensitive to water motion
in a different direction. A participant may move between images, magnetic
fields may stretch the brain, and random noise may hide the signal. QSIPrep is
the preparation stage that corrects these problems and keeps the diffusion
gradient directions synchronized with the corrected images.

QSIPrep is not one algorithm. It is a BIDS-aware workflow that connects several
published tools:

- PyBIDS identifies DWI, T1w, fieldmaps, metadata, and lesion ROIs.
- Nipype organizes operations as a directed workflow graph.
- MRtrix3 performs MP-PCA denoising and Gibbs-ringing correction.
- FSL `topup` estimates susceptibility distortion from opposite phase encoding.
- FSL `eddy` corrects movement and eddy-current distortion.
- ANTs performs anatomical registration and spatial transforms.
- QSIPrep supplies SHORELine, workflow logic, standardized outputs, and QC.

## Inputs and outputs

Inputs:

- BIDS T1w image.
- DWI NIfTI image.
- `.bval` diffusion strengths.
- `.bvec` diffusion directions.
- JSON acquisition metadata.
- Fieldmaps or reverse phase-encoded images when available.
- Optional `*_T1w_label-lesion_roi.nii.gz`.

Important outputs:

- Preprocessed DWI.
- Corrected and rotated gradient table.
- DWI reference image (`dwiref`).
- Preprocessed T1w in QSIPrep/ACPC space.
- Brain masks and tissue products.
- Spatial transforms.
- ImageQC and visual reports.

Production note: the `subject.sh` and Snakemake implementations both require an
explicit susceptibility-distortion policy. They use measured fieldmaps when the
selected BIDS data include them, requested SyN when configured, or an explicitly
requested no-SDC path. They do not silently choose no correction.

## Theory 1: MP-PCA denoising

### Beginner explanation

Nearby voxels and repeated diffusion measurements contain shared patterns.
Random noise does not repeat in the same organized way. MP-PCA separates strong
shared patterns from weak patterns that behave like random noise.

\[
X=S+N
\]

- \(X\): measured local diffusion data.
- \(S\): structured signal we want.
- \(N\): random noise.

The local matrix is decomposed:

\[
X=U\Sigma V^\top.
\]

The program keeps singular values in \(\Sigma\) that are larger than the
random-matrix noise range and reconstructs \(\hat S\).

## Theory 2: susceptibility correction

Echo-planar diffusion images can be stretched along the phase-encoding
direction:

\[
I_{\mathrm{observed}}(x)
\approx
I_{\mathrm{true}}(x+d(x)p)J_d(x).
\]

- \(p\): phase-encoding direction.
- \(d(x)\): location-dependent displacement.
- \(J_d(x)\): brightness correction for stretching or compression.

Opposite phase-encoding images bend in opposite directions. `topup` estimates
one smooth field that makes their corrected anatomy agree.

## Theory 3: movement, eddy currents, and b-vector rotation

`eddy` compares an observed diffusion volume with a prediction:

\[
\hat\theta_i
=
\arg\min_{\theta_i}
\left\|
I_i\circ T_{\theta_i}-\hat I_i
\right\|^2
+\lambda R(\theta_i).
\]

- \(I_i\): measured volume \(i\).
- \(\hat I_i\): model prediction of that volume.
- \(T_{\theta_i}\): movement and distortion correction.
- \(R\): penalty against unstable correction.

If the head rotates, the gradient direction must rotate:

\[
g_i'=R_i g_i.
\]

Otherwise the corrected image and its diffusion direction would disagree.

## Theory 4: lesion cost-function masking

QSIPrep recognizes a correctly named BIDS lesion ROI and excludes it from the
T1w-to-template registration score:

\[
\Omega_{\mathrm{fit}}=\Omega_{\mathrm{brain}}\setminus\Omega_{\mathrm{lesion}}.
\]

In plain language: align the brain using unaffected tissue. The lesion remains
in the image and is transformed normally; it simply does not pull the
registration optimizer toward an incorrect solution.

## Production wrapper command

```bash
apptainer run --cleanenv --containall \
  -B "${BIDS_DIR}":/bids_input:ro \
  -B "${QSIPREP_OUT}":/output \
  -B "${WORK_QSIPREP}":/work \
  -B "${FS_LICENSE}":/opt/freesurfer/license.txt:ro \
  -B "${TEMPLATEFLOW_HOME}":/templateflow \
  "${filter_binds[@]}" \
  --env "TEMPLATEFLOW_HOME=/templateflow" \
  "${CONTAINER_QSIPREP}" \
  /bids_input /output participant \
  --participant-label "${SUBJECT}" \
  --fs-license-file /opt/freesurfer/license.txt \
  --work-dir /work \
  --output-resolution "${OUTPUT_RES}" \
  --nthreads "${NTHREADS}" \
  --omp-nthreads "${OMP_NTHREADS}" \
  --skip-bids-validation \
  "${xtra[@]}"
```

## Line-by-line walkthrough

1. `apptainer run --cleanenv --containall \` starts the QSIPrep container in an
   isolated environment. The backslash means the command continues.
2. `-B "${BIDS_DIR}":/bids_input:ro \` mounts BIDS data read-only.
3. `-B "${QSIPREP_OUT}":/output \` mounts the output directory read/write.
4. `-B "${WORK_QSIPREP}":/work \` provides temporary working storage.
5. `-B "${FS_LICENSE}":...:ro \` makes the FreeSurfer license available.
6. `-B "${TEMPLATEFLOW_HOME}":/templateflow \` mounts template resources.
7. `"${filter_binds[@]}" \` adds an optional BIDS-filter file.
8. `--env "TEMPLATEFLOW_HOME=/templateflow" \` tells software where templates
   are mounted.
9. `"${CONTAINER_QSIPREP}" \` selects the QSIPrep container image.
10. `/bids_input /output participant \` supplies input, output, and analysis
    level.
11. `--participant-label "${SUBJECT}" \` selects one participant.
12. `--fs-license-file ... \` gives QSIPrep the license path.
13. `--work-dir /work \` selects temporary storage inside the container.
14. `--output-resolution "${OUTPUT_RES}" \` sets output voxel size.
15. `--nthreads "${NTHREADS}" \` sets general CPU threads.
16. `--omp-nthreads "${OMP_NTHREADS}" \` limits OpenMP threads.
17. `--skip-bids-validation \` skips repeated validation because the outer
    pipeline handles validation policy.
18. `"${xtra[@]}"` appends subject-specific fieldmap, SyN, or filter options.

## Paper summaries

### Cieslak et al. 2021 — QSIPrep

- Problem: diffusion preprocessing was inconsistent across sampling schemes.
- Key idea: inspect BIDS metadata and build an appropriate reproducible
  workflow automatically.
- Innovation: SHORELine, standardized gradients/transforms, visual QC, and
  integration of established tools.
- Source: DOI `10.1038/s41592-021-01185-5`.

### Veraart et al. 2016 — MP-PCA denoising

- Problem: random noise biases diffusion models.
- Key idea: use random-matrix theory to separate signal-related singular values
  from noise-related singular values.
- Source: DOI `10.1016/j.neuroimage.2016.08.016`.

### Kellner et al. 2016 — Gibbs-ringing correction

- Problem: finite Fourier sampling creates bright and dark ripples near edges.
- Key idea: choose local subvoxel shifts that minimize ringing-related
  variation.
- Source: DOI `10.1002/mrm.26054`.

### Andersson et al. 2003 and Andersson & Sotiropoulos 2016

- The 2003 paper estimates susceptibility fields from opposite
  phase-encoding images (`topup` concept).
- The 2016 paper jointly handles motion and eddy-current effects using
  diffusion-informed predictions (`eddy`).
- Sources: DOI `10.1016/S1053-8119(03)00336-7` and
  `10.1016/j.neuroimage.2015.10.019`.

### Brett et al. 2001 — lesion cost-function masking

- Problem: lesions distort spatial normalization.
- Key idea: exclude lesion voxels from the fitting score while still
  transforming the complete image.
- This is the lesion-aware registration concept used automatically by QSIPrep.

# Step 1.1 — neuroLIT lesion inpainting

## Beginner concept

FreeSurfer and FastSurfer expect tissue to look approximately like brain tissue
seen during their development. A lesion may look like blood, fluid, missing
tissue, or abnormal intensity. neuroLIT replaces the lesion appearance with a
plausible synthetic estimate so anatomical reconstruction has a complete image.

The synthetic voxels are processing aids. They are not measured healthy tissue.
The original lesion mask remains the biological record for lesion load,
disconnectome analysis, and future lesion-aware ACT.

## Inputs and outputs

Inputs:

- Original T1w.
- BIDS lesion ROI.
- Selected lesion labels.

Outputs:

- Prepared lesion mask on the exact T1w grid.
- Inpainted T1w with preserved geometry.
- QC JSON and provenance.

Subjects without a lesion mask skip Step 1.1 and retain their original T1w.

## Theory 1: DDPM forward process

A denoising diffusion model gradually adds Gaussian noise:

\[
x_t
=
\sqrt{\bar\alpha_t}x_0
+\sqrt{1-\bar\alpha_t}\epsilon,
\qquad
\epsilon\sim\mathcal N(0,I).
\]

- \(x_0\): original clean training image.
- \(x_t\): noisy image at time \(t\).
- \(\bar\alpha_t\): amount of original signal retained.
- \(\epsilon\): random Gaussian noise.

The network learns to predict the added noise:

\[
\mathcal L
=
\mathbb E
\left[
\|\epsilon-\epsilon_\theta(x_t,t)\|^2
\right].
\]

At inference, the reverse process repeatedly removes predicted noise.

## Theory 2: conditional inpainting

Let \(M(x)=1\) inside the lesion and 0 outside. At every reverse step:

\[
x_t^{\mathrm{combined}}
=
M\odot x_t^{\mathrm{generated}}
+(1-M)\odot x_t^{\mathrm{known}}.
\]

The generated content is used only inside the mask. Known anatomy outside the
mask is reinserted, providing context and protecting healthy tissue.

## Theory 3: outside-lesion QC

Pearson correlation outside the lesion is:

\[
r
=
\frac{
\sum_i(a_i-\bar a)(b_i-\bar b)
}{
\sqrt{\sum_i(a_i-\bar a)^2}
\sqrt{\sum_i(b_i-\bar b)^2}
}.
\]

- \(a_i\): original outside-lesion intensity.
- \(b_i\): inpainted outside-lesion intensity.
- \(r=1\): perfect linear agreement.

The default threshold is very high because healthy tissue should remain nearly
unchanged.

## Production command

```bash
python3 "${PREPARE_LESION_MASK}" \
  --t1w "${t1w}" --mask "${mask}" \
  --out "${mask_prepared}" --json "${mask_json}" \
  --labels "${INPAINT_LABELS}"

apptainer exec --nv --cleanenv --containall \
  -B "$(dirname "${t1w}")":/t1w_input:ro \
  -B "${mask_prepared}":/mask/lesion_mask_prepared.nii.gz:ro \
  -B "${outdir}":/out \
  "${CONTAINER_LIT}" \
  lit-inpainting \
  -i "/t1w_input/$(basename "${t1w}")" \
  -m /mask/lesion_mask_prepared.nii.gz \
  -o /out \
  --dilate "${INPAINT_DILATE}" \
  --keepgeom \
  --device "${INPAINT_DEVICE}" \
  --batch_size "${INPAINT_BATCH_SIZE}"
```

## Line-by-line walkthrough

1. `python3 "${PREPARE_LESION_MASK}" \` starts mask preparation.
2. `--t1w ... --mask ... \` provides the reference T1w and source mask.
3. `--out ... --json ... \` names the prepared mask and provenance JSON.
4. `--labels ...` chooses lesion labels such as core and edema.
5. `apptainer exec --nv ... \` runs neuroLIT with GPU access and isolation.
6. The first `-B` mounts the T1w directory read-only.
7. The second `-B` mounts the prepared mask read-only.
8. The third `-B` mounts the output directory.
9. `"${CONTAINER_LIT}" \` selects the neuroLIT container.
10. `lit-inpainting \` starts the inpainting application.
11. `-i ... \` selects the T1w.
12. `-m ... \` selects the lesion mask.
13. `-o /out \` selects the output directory.
14. `--dilate ... \` expands the mask by a small voxel margin.
15. `--keepgeom \` returns the result on the original T1w grid.
16. `--device ... \` selects CPU, CUDA, or automatic device choice.
17. `--batch_size ...` controls slices processed together and GPU memory use.

## Paper summaries

### Pollak et al. 2025 — FastSurfer-LIT/neuroLIT

- Problem: brain segmentation tools fail around tumors, cavities, and abnormal
  anatomy.
- Key idea: lesion inpainting provides a plausible anatomical image for
  downstream segmentation while retaining lesion information separately.
- Source: DOI `10.1162/imag_a_00446`.

### Ho, Jain, and Abbeel 2020 — DDPM

- Problem: learn a generative model capable of producing realistic images.
- Key idea: train a network to reverse a gradual Gaussian noising process.
- Source: arXiv `2006.11239`.

### Henschel et al. 2022 — FastSurferVINN

- Problem: ordinary CNNs depend on voxel resolution.
- Key idea: use voxel-size-aware internal resampling so networks operate in
  physical units across resolutions.
- Source: DOI `10.1016/j.media.2022.102313`.

### Lugmayr et al. 2022 — RePaint

- Problem: guide diffusion generation using known image areas.
- Key idea: repeatedly reinsert known pixels while resampling unknown masked
  pixels.
- Source: DOI `10.1109/CVPR52688.2022.01175`.

# Step 2 — FreeSurfer or FastSurfer reconstruction

## Beginner concept

Step 2 creates the anatomical map used by tractography and the connectome.
FreeSurfer uses atlas-based image processing and deformable cortical surfaces.
FastSurfer accelerates segmentation with neural networks and then creates
FreeSurfer-compatible surfaces and files.

Both routes must produce:

- White and pial cortical surfaces.
- Subcortical `aseg` labels.
- DKT cortical labels.
- `aparc.DKTatlas+aseg.mgz`.
- Native-grid `rawavg.mgz`.

Production note: Step 2 uses the neuroLIT-inpainted T1w when Step 1.1 produced
one; otherwise it uses the raw BIDS T1w for the selected session. It does not
use QSIPrep's `desc-preproc_T1w` as the FreeSurfer/FastSurfer input.

## Theory 1: probabilistic labeling

For each voxel, a simplified Bayesian label is:

\[
\hat L(x)
=
\arg\max_k
P(I(x)\mid L=k)
P(L=k\mid x)
P(L=k\mid L(\mathcal N_x)).
\]

The program combines:

- Whether intensity resembles tissue \(k\).
- Whether the atlas expects \(k\) at that location.
- Whether \(k\) makes sense beside neighboring labels.

## Theory 2: cortical surface placement

FreeSurfer adjusts a triangular mesh by minimizing:

\[
E
=
\lambda_I E_{\mathrm{image}}
+\lambda_S E_{\mathrm{smooth}}
+\lambda_T E_{\mathrm{topology}}.
\]

Image forces pull the mesh toward tissue boundaries. Smoothness prevents spikes.
Topology correction prevents holes and handles that would make the cortex
impossible to map consistently.

## Theory 3: FastSurfer classification

A neural network produces a class probability for each voxel:

\[
\hat L(x)=\arg\max_k p_\theta(L(x)=k\mid I).
\]

The label with the largest predicted probability is selected. FastSurfer's
speed comes mainly from replacing slow atlas-based volume labeling with trained
neural networks; surface reconstruction remains a geometric process.

## FreeSurfer production command

```bash
export FS_LICENSE=/.fs_license.txt
export SUBJECTS_DIR=/sd
recon-all -all \
  -s "sub-${SUBJECT}" \
  -i /t1w_input/T1w.nii.gz \
  -openmp "${NTHREADS}"
```

## FreeSurfer line-by-line walkthrough

1. `export FS_LICENSE=...` tells FreeSurfer where its license is mounted.
2. `export SUBJECTS_DIR=/sd` selects the output subjects directory.
3. `recon-all -all \` requests the complete standard reconstruction workflow.
4. `-s ... \` sets the subject directory name.
5. `-i ... \` supplies the original or inpainted T1w.
6. `-openmp ...` sets the CPU thread count.

## FastSurfer production command

```bash
/fastsurfer/run_fastsurfer.sh \
  --fs_license /fs_license/license.txt \
  --sid "sub-${SUBJECT}" \
  --sd /sd \
  --t1 /t1w_input/T1w.nii.gz \
  --parallel \
  --threads "${NTHREADS}" \
  --device "${RECON_FASTSURFER_DEVICE}" \
  --fsaparc
```

## FastSurfer line-by-line walkthrough

1. `run_fastsurfer.sh \` starts the combined segmentation and surface workflow.
2. `--fs_license ... \` supplies the FreeSurfer license.
3. `--sid ... \` sets the subject identifier.
4. `--sd /sd \` selects the output directory.
5. `--t1 ... \` supplies the T1w.
6. `--parallel \` allows independent operations to run concurrently.
7. `--threads ... \` sets CPU threads.
8. `--device ... \` selects CPU or GPU inference.
9. `--fsaparc` optionally creates classic DK products in addition to DKT.

## Paper summaries

### Fischl 2012 and Dale et al. 1999 — FreeSurfer

- Problem: reconstruct cortical surfaces and anatomical labels from MRI.
- Key idea: combine intensity normalization, probabilistic segmentation,
  topology correction, deformable surfaces, and spherical atlas registration.
- Sources: DOI `10.1016/j.neuroimage.2012.03.001` and
  `10.1006/nimg.1998.0395`.

### Henschel et al. 2020 — FastSurfer

- Problem: FreeSurfer volume processing takes many hours.
- Key idea: use deep learning for rapid, accurate whole-brain segmentation
  while retaining FreeSurfer-compatible outputs.
- Source: DOI `10.1016/j.neuroimage.2020.117357`.

### Klein and Tourville 2012 — DKT

- Problem: cortical labeling protocols contained inconsistent boundary rules.
- Key idea: create 101 consistently labeled brains and a clearer cortical
  labeling protocol.
- Relevance: the pipeline's primary atlas has 78 cortical-plus-subcortical
  nodes.
- Source: DOI `10.3389/fnins.2012.00171`.

# Step 3 — QSIRecon, SS3T-CSD, ACT-HSVS, and tractography

## Beginner concept

QSIPrep corrected the images; QSIRecon now models fiber directions and creates
millions of candidate white-matter paths. The selected reconstruction recipe is:

```text
mrtrix_singleshell_ss3t_ACT-hsvs
```

- `mrtrix`: use MRtrix3 tools.
- `singleshell`: one nonzero b-value shell.
- `ss3t`: estimate white matter, gray matter, and CSF contributions.
- `ACT`: apply anatomical rules during tractography.
- `hsvs`: build the 5TT from surfaces and volume labels.

## Theory 1: spherical deconvolution

The measured signal is a blurred combination of fiber directions:

\[
S(g)
=
\int_{\mathbb S^2}
R(g\cdot n)f(n)\,dn.
\]

- \(R\): expected signal from one coherent fiber.
- \(f(n)\): fiber-orientation distribution.
- The algorithm estimates \(f\) while preventing negative fiber amplitudes.

SS3T adds three tissue contributions:

\[
S
\approx
R_{\mathrm{WM}}*f_{\mathrm{WM}}
+c_{\mathrm{GM}}R_{\mathrm{GM}}
+c_{\mathrm{CSF}}R_{\mathrm{CSF}}.
\]

## Theory 2: five-tissue image

At each voxel:

\[
\mathbf t(x)
=
[t_{\mathrm{cortGM}},t_{\mathrm{subGM}},t_{\mathrm{WM}},
t_{\mathrm{CSF}},t_{\mathrm{pathology}}].
\]

HSVS uses surfaces for the thin cortical ribbon and volume segmentation for
deep structures. ACT treats this as a traffic map:

- White matter: propagation is allowed.
- Gray matter: valid endpoint.
- CSF: invalid pathway.
- Pathology: special/uncertain tissue handling.

## Theory 3: iFOD2 tractography

The FOD gives more support to some directions than others. iFOD2 proposes
curved steps and samples among them:

\[
P(\gamma\mid f)
\propto
\prod_s f(\gamma(s),\dot\gamma(s)).
\]

This is a conceptual path score, not the biological probability that an axon
exists.

## Theory 4: SIFT2

\[
\hat w
=
\arg\min_{w\ge0}
\|Aw-d\|^2+\lambda R(w).
\]

- \(A\): where each streamline travels.
- \(w\): one unknown weight per streamline.
- \(d\): FOD-derived fiber-density target.

SIFT2 makes weighted streamline density resemble diffusion-derived density.
Weights are not literal axon counts.

## Production wrapper command

```bash
apptainer run --cleanenv --containall \
  -B "${QSIPREP_OUT}":/qsiprep_input:ro \
  -B "${QSIRECON_OUT}":/output \
  -B "${WORK_QSIRECON}":/work \
  -B "${FS_SUBJECTS_DIR}":/freesurfer:ro \
  "${CONTAINER_QSIRECON}" \
  /qsiprep_input /output participant \
  --input-type qsiprep \
  --recon-spec "${QSIRECON_SPEC}" \
  --participant-label "${SUBJECT}" \
  --fs-subjects-dir /freesurfer \
  --work-dir /work \
  --nthreads "${NTHREADS}" \
  --omp-nthreads "${OMP_NTHREADS}" \
  --output-resolution "${OUTPUT_RES}"
```

## Line-by-line walkthrough

1. `apptainer run ... \` starts isolated QSIRecon.
2. The first bind mounts QSIPrep derivatives read-only.
3. The second bind mounts QSIRecon output.
4. The third bind provides temporary work storage.
5. The fourth bind exposes Step 2 surfaces and segmentation read-only.
6. `"${CONTAINER_QSIRECON}" \` selects the QSIRecon image.
7. `/qsiprep_input /output participant \` sets input, output, and analysis level.
8. `--input-type qsiprep \` declares the input derivative format.
9. `--recon-spec ... \` selects SS3T-ACT-HSVS.
10. `--participant-label ... \` selects one subject.
11. `--fs-subjects-dir ... \` points QSIRecon to Step 2 anatomy.
12. `--work-dir ... \` selects temporary storage.
13. `--nthreads ... \` sets general CPU threads.
14. `--omp-nthreads ... \` limits OpenMP parallelism.
15. `--output-resolution ...` sets the reconstruction output grid.

The production default also requests the `4S156Parcels` atlas through
`QSIRECON_ATLASES`. That QSIRecon atlas connectome is separate from the
subject-specific DKT connectome constructed in Step 4.

## Paper summaries

### Cieslak et al. 2024 — QSIRecon preprint

- Problem: reconstruction methods from different diffusion packages are hard to
  compare and reproduce.
- Key idea: define reconstruction workflows declaratively and consume
  standardized QSIPrep derivatives.
- Source: DOI `10.1101/2024.05.30.596511`.

### Tournier et al. 2019 — MRtrix3

- Key idea: provide a fast, flexible framework for diffusion modeling,
  tractography, ACT, SIFT2, and connectomes.
- Source: DOI `10.1016/j.neuroimage.2019.01.066`.

### Jeurissen et al. 2014 — multi-tissue CSD

- Problem: tissue partial volume contaminates white-matter direction estimates.
- Key idea: model WM, GM, and CSF response functions separately.
- SS3T adapts this family of ideas to single-shell data with additional
  constraints.
- Source: DOI `10.1016/j.neuroimage.2014.07.061`.

### Smith et al. 2012 — ACT

- Problem: direction-only tractography produces anatomically impossible paths.
- Key idea: use tissue states to control propagation and termination.
- Source: DOI `10.1016/j.neuroimage.2012.02.004`.

### Smith et al. 2015 — SIFT2

- Problem: raw tractogram density disagrees with FOD-derived density.
- Key idea: optimize a nonnegative weight for every streamline.
- Source: DOI `10.1016/j.neuroimage.2015.02.069`.

### Smith et al. 2020 — HSVS conference method

- Problem: intensity-only tissue segmentation is inaccurate at cortical
  boundaries.
- Key idea: combine surface-defined cortex with volume-defined deep structures.
- This source is an OHBM 2020 conference report rather than a full journal
  validation paper.

# Step 4 — DKT structural connectome

## Beginner concept

Step 3 produced streamlines, but streamlines do not have region names. Step 4
moves the DKT labels onto the tractography grid, assigns each streamline's
endpoints to two regions, and counts the resulting region pairs.

The critical geometry is:

```text
FreeSurfer conformed labels
  -> native T1w grid
  -> QSIPrep T1w space
  -> DWI/tractography grid
  -> compact DKT node numbers
  -> 78 x 78 matrix
```

Labels always use nearest-neighbor or `GenericLabel` interpolation. Averaging
integer labels could invent a nonexistent region.

## Theory 1: registration

\[
\hat A
=
\arg\min_A
\left[
-\mathrm{MI}(I_{\mathrm{preproc}},I_{\mathrm{native}}\circ A)
+\lambda R(A)
\right].
\]

The affine \(A\) moves native T1w anatomy to QSIPrep T1w space. Mutual
information (MI) measures statistical dependence between image intensities and
works across somewhat different contrasts.

## Theory 2: connectome matrix

\[
W_{ij}
=
\sum_s
w_s\mathbf 1[i(s)=i,\ j(s)=j].
\]

- \(i(s)\), \(j(s)\): endpoint nodes of streamline \(s\).
- \(w_s=1\): streamline-count matrix.
- \(w_s\): SIFT2 coefficient for a SIFT2-weighted matrix.

The output is symmetric and has a zero diagonal.

## Production commands

```bash
mri_label2vol --seg "${APARC}" \
  --temp "${RAWAVG}" \
  --o "${OUTDIR}/aparc_in_rawavg.mgz" \
  --regheader "${APARC}"

antsRegistration --dimensionality 3 \
  --output "${OUTDIR}/native_to_preproc_" \
  --transform "Affine[0.1]" \
  --metric "MI[${PREPROC_T1W},${BIDS_T1W},1,32]"

antsApplyTransforms -d 3 \
  -i "${OUTDIR}/aparc_in_rawavg.nii.gz" \
  -r "${PREPROC_T1W}" \
  -t "${OUTDIR}/native_to_preproc_0GenericAffine.mat" \
  -n GenericLabel \
  -o "${OUTDIR}/aparc_in_t1w.nii.gz"

antsApplyTransforms -d 3 \
  -i "${OUTDIR}/aparc_in_t1w.nii.gz" \
  -r "${DWIREF}" \
  -n GenericLabel \
  -o "${OUTDIR}/aparc_in_dwi.nii.gz"

labelconvert "${OUTDIR}/aparc_in_dwi.nii.gz" \
  "${FS_LUT_PATH}" "${MRTRIX_LUT_PATH}" "${OUTDIR}/nodes.mif"

tck2connectome "${TRACKS}" "${OUTDIR}/nodes.mif" \
  "${OUTDIR}/dkt_connectome.csv" \
  -symmetric -zero_diagonal \
  -out_assignments "${OUTDIR}/assignments.csv"
```

## Line-by-line walkthrough

1. `mri_label2vol --seg ... \` starts mapping the segmentation from FreeSurfer
   conformed coordinates.
2. `--temp "${RAWAVG}" \` selects the original/native T1w grid.
3. `--o ... \` names the native-grid label volume.
4. `--regheader ...` uses FreeSurfer header geometry for the mapping.
5. `antsRegistration ... \` starts a three-dimensional image registration.
6. `--output ... \` sets the transform/output prefix.
7. `--transform "Affine[0.1]" \` allows global rotation, translation, scaling,
   and shear with the specified optimizer step.
8. `--metric "MI[...]"` compares preprocessed and native T1w using mutual
   information.
9. `antsApplyTransforms -d 3 \` starts transform application in 3D.
10. `-i ... \` supplies the native-grid labels.
11. `-r "${PREPROC_T1W}" \` first selects the QSIPrep T1w grid.
12. `-t ... \` supplies the estimated affine.
13. `-n GenericLabel \` preserves integer anatomical labels.
14. `-o ...aparc_in_t1w...` writes labels in QSIPrep T1w space.
15. The second `antsApplyTransforms -d 3 \` starts a grid-only resampling.
16. `-i ...aparc_in_t1w... \` supplies the already aligned labels.
17. `-r "${DWIREF}" \` selects the tractography voxel grid.
18. `-n GenericLabel \` again preserves integer region identities.
19. `-o ...aparc_in_dwi...` writes the final DWI-grid labels.
20. `labelconvert ... \` starts node-number conversion.
21. The next line supplies the FreeSurfer source lookup, DKT target lookup, and
    compact `nodes.mif` output.
22. `tck2connectome ... \` combines the tractogram and nodes.
23. The next line names the 78-by-78 output matrix.
24. `-symmetric -zero_diagonal \` creates an undirected matrix without
    self-connections.
25. `-out_assignments ...` writes each streamline's endpoint node pair for QC.

## Paper summaries

### Avants et al. 2011 — ANTs

- Problem: nonlinear and affine registration must be accurate and reproducible.
- Key idea: optimize image-similarity metrics under controlled transform models.
- Source: DOI `10.1016/j.neuroimage.2010.09.025`.

### Fischl et al. 2004 — cortical parcellation

- Key idea: assign cortical labels using folding patterns and probabilistic
  atlas information.
- Step 4 converts these individual labels from surfaces/volumes into graph
  nodes.
- Source: DOI `10.1093/cercor/bhg087`.

### MRtrix3 and DKT

- MRtrix3 supplies `labelconvert` and `tck2connectome`.
- Klein and Tourville supply the DKT anatomical node definitions.
- Their algorithms are integrated here; the pipeline does not claim to invent
  either method.

# Step 4.1 — optional disconnectome

## Beginner concept

The primary connectome describes the tractogram generated for the subject.
Step 4.1 asks what connectivity is associated with the lesion by creating
alternative “spared” matrices:

- Option A removes lesion voxels from the parcellation.
- Option B removes streamlines intersecting the lesion.
- Option C applies both.

The primary matrix is never overwritten.

## Theory 1: regional lesion load

\[
\mathrm{LesionLoad}_i
=
\frac{
\#(\mathrm{lesion\ voxels\ in\ node}\ i)
}{
\#(\mathrm{voxels\ in\ node}\ i)
}.
\]

This measures direct regional overlap, not white-matter disconnection.
The implementation flags a node in the lesion-overlap table when lesion load is
at least 0.5 by default; this flag is a reporting threshold and does not change
the primary connectome.

## Theory 2: options A, B, and C

Option A:

\[
N_A(x)=N(x)\,[1-M(x)].
\]

The lesion mask \(M\) removes overlapping node voxels.

Option B:

\[
\mathcal S_B
=
\{s\in\mathcal S:\ s\cap M=\varnothing\}.
\]

Only streamlines that do not intersect the lesion are retained.

Option C uses \(N_A\) and \(\mathcal S_B\) together.

## Theory 3: fractional disconnection

\[
D_{ij}
=
\mathrm{clip}
\left(
1-\frac{W^{\mathrm{spared}}_{ij}}
{W^{\mathrm{primary}}_{ij}},
0,1
\right).
\]

- \(D=0\): no measured loss.
- \(D=1\): complete measured loss.
- Clipping handles numerical cases in which a spared matrix exceeds the primary
  matrix.

## Production-equivalent code

```bash
mrcalc nodes.mif lesion_in_dwi.mif -not -mult nodes_A.mif
tckedit tracks.tck -exclude lesion_in_dwi.mif tracks_B.tck
tck2connectome tracks.tck nodes_A.mif connectome_A.csv \
  -symmetric -zero_diagonal
tck2connectome tracks_B.tck nodes.mif connectome_B.csv \
  -symmetric -zero_diagonal
tck2connectome tracks_B.tck nodes_A.mif connectome_C.csv \
  -symmetric -zero_diagonal
```

```python
primary = load_connectome_csv(primary_path)
spared = load_connectome_csv(spared_path)
disconnection = np.zeros_like(primary)
valid = primary > 0
ratio = 1.0 - spared[valid] / primary[valid]
disconnection[valid] = np.clip(ratio, 0.0, 1.0)
np.savetxt(output_path, disconnection, delimiter=",", fmt="%.6f")
```

## Line-by-line walkthrough

1. `mrcalc ... -not -mult nodes_A.mif` reverses the lesion mask and multiplies
   it by the node image, setting lesion-overlapping node voxels to zero.
2. `tckedit ... -exclude ...` removes any streamline intersecting the lesion.
3. The first `tck2connectome` uses full tracks with excised nodes: Option A.
4. Its next line makes the matrix symmetric with zero diagonal.
5. The second `tck2connectome` uses lesion-excluded tracks with original nodes:
   Option B.
6. Its next line applies the same graph conventions.
7. The third `tck2connectome` uses excluded tracks and excised nodes: Option C.
8. Its next line applies the same graph conventions.
9. `primary = ...` loads the Step 4 matrix.
10. `spared = ...` loads Option A, B, or C.
11. `zeros_like` creates an output matrix with the same shape.
12. `valid = primary > 0` prevents division by zero.
13. `ratio = 1 - spared/primary` calculates fractional loss.
14. `np.clip` restricts values to the interpretable range 0–1.
15. `np.savetxt` writes six-decimal CSV output.

## Paper summaries

### Griffis et al. 2019 — structural disconnection

- Problem: focal lesion location alone does not explain distributed network
  dysfunction.
- Key idea: represent injury by the structural connections it interrupts.
- Their method used normative/reference connectivity; this pipeline uses the
  subject's reconstructed tractogram, so the implementations are related but
  not identical.
- Source: DOI `10.1016/j.celrep.2019.10.058`.

### Kuceyeski et al. 2013 — NeMo

- Problem: estimate how white-matter abnormalities modify structural networks.
- Key idea: intersect alteration maps with reference tractograms and summarize
  regional connectivity change.
- Relevance: motivates virtual-lesion and network-modification thinking.
- Source: DOI `10.1016/j.nicl.2012.10.003`.

# Step 5 — node strength, asymmetry, volume, and report

## Beginner concept

A 78-by-78 matrix is difficult to interpret directly. Step 5 turns each row
into regional summaries and produces tables and figures.

It uses a separate `nodestrength` container because this stage needs Python,
graph mathematics, pandas, plotting, ENIGMA resources, and VTK—not registration
or tractography programs.

## Theory 1: node strength

\[
s_i=\sum_{j\ne i}W_{ij}.
\]

Node strength adds every edge touching region \(i\). In a count matrix it is a
sum of streamline counts. In a SIFT2 matrix it is a sum of SIFT2 weights.
Neither is an anatomical axon count.

## Theory 2: hemispheric asymmetry

\[
\mathrm{AI}
=
\frac{L-R}{L+R}.
\]

- Positive: left is greater.
- Negative: right is greater.
- Zero: equal.

If both sides are severely reduced, AI can remain near zero. It measures
laterality, not overall health.

Log asymmetry is:

\[
\mathrm{logAI}=\ln\left(\frac{L}{R}\right).
\]

## Theory 3: regional volume

\[
V_i=N_i\,v_{\mathrm{voxel}}.
\]

- \(N_i\): voxels assigned to region \(i\) in `nodes.mif`.
- \(v_{\mathrm{voxel}}\): physical volume of one DWI-grid voxel.

This is connectome-grid node volume, not native FreeSurfer morphometry.

## Production wrapper command

```bash
apptainer run --cleanenv --containall \
  -B "${CONNECTOME_OUT}":"${CONNECTOME_OUT}":ro \
  -B "${FS_SUBJECTS_DIR}":"${FS_SUBJECTS_DIR}":ro \
  -B "${NODESTRENGTH_OUT}":"${NODESTRENGTH_OUT}" \
  "${CONTAINER_NODESTRENGTH}" \
  "${CONNECTOME_OUT}" "${NODESTRENGTH_OUT}" "${FS_SUBJECTS_DIR}" \
  --include "${SUBJECT}"
```

## Conceptual calculation code

```python
matrix = np.loadtxt(connectome_csv, delimiter=",")
strength = matrix.sum(axis=1)
left = strength[left_indices]
right = strength[right_indices]
denominator = left + right
side_ai = np.divide(
    left - right,
    denominator,
    out=np.zeros_like(left),
    where=denominator != 0,
)
```

## Line-by-line walkthrough

1. `apptainer run ... \` starts the reporting container.
2. The first bind mounts connectomes read-only.
3. The second bind optionally exposes FreeSurfer anatomy read-only.
4. The third bind mounts the report/output directory read/write.
5. `"${CONTAINER_NODESTRENGTH}" \` selects the container.
6. The next line supplies connectome input, result output, and anatomy path.
7. `--include "${SUBJECT}"` limits processing to one subject.
8. `np.loadtxt` reads the CSV matrix as numbers.
9. `sum(axis=1)` adds every row to calculate node strength.
10. The next two lines select homologous left and right regions.
11. `denominator = left + right` calculates the AI denominator.
12. `np.divide(` begins safe elementwise division.
13. `left - right` is the left–right difference.
14. `denominator` scales the difference by total bilateral strength.
15. `out=np.zeros_like(left)` supplies zero when division cannot be performed.
16. `where=denominator != 0` prevents division by zero.
17. `)` completes the calculation.

## Outputs

- Per-subject strength CSV.
- Strength asymmetry CSV.
- Intrahemispheric strength and asymmetry.
- Regional volume and volume asymmetry.
- Comparison tables.
- ENIGMA-style cortical and subcortical figures.
- Clinical summary PDF.
- Manifest recording atlas, node count, files, and caveats.

## Paper summaries

### Rubinov and Sporns 2010 — graph measures

- Problem: brain-network metrics were often used without clear definitions or
  interpretation.
- Key idea: organize measures such as strength, integration, segregation, and
  centrality and explain their assumptions.
- Step 5 uses the weighted undirected node-strength definition.
- Source: DOI `10.1016/j.neuroimage.2009.10.003`.

### Piper et al. 2026 — clinical connectivity reporting

- Problem: determine how thalamocortical structural connectivity differs in
  children with focal epilepsy.
- Key idea: combine structural connectivity, regional strength, asymmetry, and
  clinically interpretable reporting.
- Step 5 generalizes this reporting approach from thalamic nuclei to DKT/DK
  whole-brain regions; it is not an exact replication of the cohort study.
- Source: DOI `10.1002/epi.70099`.

### ENIGMA consortium context

- Key idea: large multisite collaboration and harmonized measurements can
  establish robust population effects.
- Current AI values are raw within-subject asymmetries, not ENIGMA-derived
  normative z-scores.

# What is original versus borrowed

The pipeline does not claim to invent QSIPrep, DDPM, FreeSurfer, CSD, ACT,
SIFT2, ANTs, DKT, or standard node strength.

Its pipeline-level contribution is the reproducible integration of:

- Automatic BIDS lesion-aware normalization.
- Optional neuroLIT anatomical inpainting.
- FreeSurfer/FastSurfer DKT reconstruction.
- QSIRecon SS3T-ACT-HSVS tractography.
- Correct DKT label transfer to the tractography grid.
- Count/SIFT2 connectomes.
- Subject-specific lesion overlap and disconnectome variants.
- Node strength, asymmetry, volume, QC, provenance, and reporting.

The proposed lesion-aware fifth-5TT branch would also use an established MRtrix
capability. Its research contribution would be TBI-specific integration,
controlled comparison, and validation—not invention of ACT.

# Important beginner cautions

1. A streamline is a model-generated curve, not a directly observed axon.
2. Streamline count is not biological fiber count.
3. SIFT2 weights improve agreement with the diffusion model but remain model
   weights.
4. Inpainting produces synthetic processing anatomy inside the lesion.
5. AI measures left-versus-right balance, not general abnormality.
6. Disconnectome results depend on lesion accuracy, registration, tractography,
   and node definition.
7. DKT and DK matrices have different nodes and must not be pooled.
8. A plausible-looking output still requires quantitative and visual QC.

# Consolidated references

1. Cieslak M, et al. QSIPrep. *Nature Methods*. 2021.
   DOI `10.1038/s41592-021-01185-5`.
2. Veraart J, et al. MP-PCA denoising. *NeuroImage*. 2016.
   DOI `10.1016/j.neuroimage.2016.08.016`.
3. Kellner E, et al. Gibbs-ringing removal. *Magnetic Resonance in Medicine*.
   2016. DOI `10.1002/mrm.26054`.
4. Andersson JLR, et al. Susceptibility correction. *NeuroImage*. 2003.
   DOI `10.1016/S1053-8119(03)00336-7`.
5. Andersson JLR, Sotiropoulos SN. Eddy/motion correction. *NeuroImage*. 2016.
   DOI `10.1016/j.neuroimage.2015.10.019`.
6. Brett M, et al. Lesion cost-function masking. *NeuroImage*. 2001.
7. Pollak TA, et al. FastSurfer-LIT. *Imaging Neuroscience*. 2025.
   DOI `10.1162/imag_a_00446`.
8. Ho J, et al. Denoising diffusion probabilistic models. *NeurIPS*. 2020.
9. Henschel L, et al. FastSurferVINN. *Medical Image Analysis*. 2022.
   DOI `10.1016/j.media.2022.102313`.
10. Lugmayr A, et al. RePaint. *CVPR*. 2022.
    DOI `10.1109/CVPR52688.2022.01175`.
11. Fischl B. FreeSurfer. *NeuroImage*. 2012.
    DOI `10.1016/j.neuroimage.2012.03.001`.
12. Dale AM, et al. Cortical surface reconstruction. *NeuroImage*. 1999.
    DOI `10.1006/nimg.1998.0395`.
13. Henschel L, et al. FastSurfer. *NeuroImage*. 2020.
    DOI `10.1016/j.neuroimage.2020.117357`.
14. Klein A, Tourville J. DKT labeling protocol. *Frontiers in Neuroscience*.
    2012. DOI `10.3389/fnins.2012.00171`.
15. Cieslak M, et al. QSIRecon. *bioRxiv*. 2024.
    DOI `10.1101/2024.05.30.596511`.
16. Tournier JD, et al. MRtrix3. *NeuroImage*. 2019.
    DOI `10.1016/j.neuroimage.2019.01.066`.
17. Jeurissen B, et al. Multi-tissue CSD. *NeuroImage*. 2014.
    DOI `10.1016/j.neuroimage.2014.07.061`.
18. Smith RE, et al. ACT. *NeuroImage*. 2012.
    DOI `10.1016/j.neuroimage.2012.02.004`.
19. Smith RE, et al. SIFT2. *NeuroImage*. 2015.
    DOI `10.1016/j.neuroimage.2015.02.069`.
20. Smith RE, et al. HSVS. *OHBM conference report*. 2020.
21. Avants BB, et al. ANTs registration. *NeuroImage*. 2011.
    DOI `10.1016/j.neuroimage.2010.09.025`.
22. Fischl B, et al. Cortical parcellation. *Cerebral Cortex*. 2004.
    DOI `10.1093/cercor/bhg087`.
23. Griffis JC, et al. Structural disconnection. *Cell Reports*. 2019.
    DOI `10.1016/j.celrep.2019.10.058`.
24. Kuceyeski R, et al. NeMo. *NeuroImage: Clinical*. 2013.
    DOI `10.1016/j.nicl.2012.10.003`.
25. Rubinov M, Sporns O. Brain network measures. *NeuroImage*. 2010.
    DOI `10.1016/j.neuroimage.2009.10.003`.
26. Piper RJ, et al. Thalamocortical structural connectivity. *Epilepsia*.
    2026. DOI `10.1002/epi.70099`.
