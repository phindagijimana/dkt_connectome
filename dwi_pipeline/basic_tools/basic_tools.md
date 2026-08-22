# FreeSurfer, QSIPrep, and QSIRecon: underlying tools, publications, and innovations

## Purpose

This document explains the relationship between software commands, scientific
algorithms, and published papers in FreeSurfer, QSIPrep, and QSIRecon. These
levels are related, but they are not interchangeable:

```text
Scientific method described in one or more papers
                         ↓
Software implementation, often containing several executables
                         ↓
Orchestration workflow that selects and connects those executables
```

An executable is not necessarily an independently published method. Some
commands implement a method with a dedicated paper; others are utilities or
components of a larger method described across several publications.

## Short answer

No, every FreeSurfer executable does not come from its own independent paper.

- Some commands have a closely corresponding methods paper, such as
  `mri_watershed`.
- Some implement algorithms described in broader FreeSurfer publications, such
  as atlas-based segmentation and cortical surface reconstruction.
- Some are engineering utilities, such as `mri_convert`, and do not require a
  separate scientific publication.
- Some wrap or adapt methods developed outside FreeSurfer, such as N3 bias-field
  correction.

QSIPrep and QSIRecon follow a similar model. They integrate many independently
published tools but also contribute original workflow logic, interfaces,
quality-control methods, data transformations, and—in QSIPrep's case—the
SHORELine motion-correction method. Their innovation is not limited to writing
new mathematical algorithms from scratch.

## What “from scratch” means in scientific software

There are several forms of innovation:

1. **New scientific algorithm:** a new mathematical or statistical method.
2. **New implementation:** software implementing a known method.
3. **New integration:** connecting existing methods into a valid end-to-end
   workflow.
4. **New standardization:** consistent inputs, outputs, metadata, and
   provenance.
5. **New automation:** automatically selecting methods from acquisition
   metadata.
6. **New validation:** demonstrating performance across datasets and acquisition
   schemes.
7. **New accessibility:** packaging complex methods so they can be reproduced
   reliably.

QSIPrep and QSIRecon contain several of these forms. Calling them “only
wrappers” would understate their contribution, but saying that they invented
all underlying algorithms would also be incorrect.

# FreeSurfer and `recon-all`

## What `recon-all` is

`recon-all` is a shell-based workflow controller. It runs many FreeSurfer
executables in a specific order, tracks completed stages, and supports restarting
parts of the anatomical reconstruction.

The workflow includes:

- Input conversion and conformation.
- Motion correction when multiple anatomical images are provided.
- Bias-field correction and intensity normalization.
- Atlas registration.
- Skull stripping.
- White-matter segmentation.
- Surface tessellation and topology correction.
- White- and pial-surface placement.
- Spherical registration.
- Cortical parcellation.
- Volumetric label creation.
- Regional statistics.

The scientific FreeSurfer method is distributed across this workflow. It should
usually be cited with the relevant core FreeSurfer papers, not with an
independent paper for every command.

## `mri_convert`

### Function

`mri_convert` converts image formats, data types, voxel orientations, and image
geometry. `recon-all` uses conversion and conformation operations to prepare
input images.

### Publication status

This is primarily a software utility. It does not represent a distinct
neuroanatomical algorithm with its own foundational methods paper.

### Appropriate citation

When used as part of `recon-all`, cite FreeSurfer and report the FreeSurfer
version. A separate methodological citation for `mri_convert` is generally not
needed.

## `mri_robust_template` and robust registration

### Function

This family of tools creates an unbiased within-subject template from repeated
anatomical scans and supports robust, inverse-consistent registration.

### Publication basis

The robust registration and longitudinal-template methods are described in:

- Reuter M, Rosas HD, Fischl B. **Highly accurate inverse consistent
  registration: a robust approach.** *NeuroImage*. 2010.
- Reuter M, Schmansky NJ, Rosas HD, Fischl B. **Within-subject template
  estimation for unbiased longitudinal image analysis.** *NeuroImage*. 2012.

### Interpretation

The paper describes the general method; the executable is its software
implementation. It is not necessary to treat every mode or option as a separate
published method.

## `mri_nu_correct.mni`

### Function

This command corrects slowly varying intensity nonuniformity in anatomical MRI.

### Publication basis

It uses or wraps the MNI N3 method:

- Sled JG, Zijdenbos AP, Evans AC. **A nonparametric method for automatic
  correction of intensity nonuniformity in MRI data.** *IEEE Transactions on
  Medical Imaging*. 1998.

### Interpretation

N3 was developed outside FreeSurfer. FreeSurfer incorporated it into its
anatomical processing workflow. This is an example of adopting a published
external algorithm rather than inventing every processing stage internally.

## `talairach_avi`

### Function

This stage estimates an initial affine alignment to Talairach-like atlas space.
It supplies standardized orientation and initialization for later atlas-based
processing.

### Publication status

The command does not have to be understood as a standalone method with one
exclusive paper. It derives from established atlas-registration methodology and
is part of the broader FreeSurfer reconstruction framework.

### Appropriate citation

Report the FreeSurfer version and cite the FreeSurfer anatomical-processing
papers. Additional registration references may be included when the precise
algorithm is central to the study.

## `mri_watershed`

### Function

`mri_watershed` removes skull and other nonbrain tissue using a hybrid method
that combines watershed segmentation with a deformable surface.

### Dedicated methods paper

- Ségonne F, Dale AM, Busa E, et al. **A hybrid approach to the skull stripping
  problem in MRI.** *NeuroImage*. 2004.

### Interpretation

This is one of the clearest examples of a FreeSurfer command that closely maps
to a dedicated methodological publication.

## `mri_em_register`

### Function

`mri_em_register` performs linear registration between a participant image and
a probabilistic anatomical atlas. It uses expectation-maximization concepts and
produces an atlas-alignment transform.

### Publication basis

The method belongs to FreeSurfer's probabilistic atlas and automated
segmentation framework, especially:

- Fischl B, Salat DH, Busa E, et al. **Whole brain segmentation: automated
  labeling of neuroanatomical structures in the human brain.** *Neuron*. 2002.

### Interpretation

The executable is one processing component of the broader atlas-segmentation
method. There is not necessarily a unique independent paper corresponding only
to this command.

## `mri_ca_normalize`, `mri_ca_register`, and `mri_ca_label`

### Functions

- `mri_ca_normalize` performs atlas-guided intensity normalization.
- `mri_ca_register` performs nonlinear registration to a probabilistic atlas.
- `mri_ca_label` assigns anatomical labels using atlas priors and image
  information.

### Publication basis

These operations are based on the FreeSurfer probabilistic atlas and whole-brain
segmentation framework described in papers including:

- Fischl et al., **Whole brain segmentation**, 2002.
- Fischl B, van der Kouwe A, Destrieux C, et al. **Automatically parcellating
  the human cerebral cortex.** *Cerebral Cortex*. 2004.

### Interpretation

The three commands divide a larger scientific method into executable stages.
They should not automatically be described as three independently invented or
independently published methods.

## `mris_make_surfaces` and related `mris_*` tools

### Functions

FreeSurfer's surface tools perform operations such as:

- White-surface placement.
- Pial-surface placement.
- Surface smoothing.
- Inflation.
- Spherical mapping.
- Topology correction.
- Surface registration.
- Cortical annotation.

### Publication basis

Core publications include:

- Dale AM, Fischl B, Sereno MI. **Cortical surface-based analysis I:
  segmentation and surface reconstruction.** *NeuroImage*. 1999.
- Fischl B, Sereno MI, Dale AM. **Cortical surface-based analysis II:
  inflation, flattening, and a surface-based coordinate system.**
  *NeuroImage*. 1999.
- Fischl B, Dale AM. **Measuring the thickness of the human cerebral cortex
  from magnetic resonance images.** *Proceedings of the National Academy of
  Sciences*. 2000.
- Fischl B, Liu A, Dale AM. **Automated manifold surgery: constructing
  geometrically accurate and topologically correct models of the human
  cerebral cortex.** *IEEE Transactions on Medical Imaging*. 2001.

### Interpretation

Multiple executables implement different portions of a surface-reconstruction
framework described across multiple papers. The mapping is many-to-many rather
than one command to one paper.

## `mri_aparc2aseg`

### Function

This utility combines cortical surface annotations with volumetric segmentation
to produce a parcellated anatomical volume such as `aparc+aseg.mgz`.

### Publication status

The utility itself does not require a dedicated independent methods paper. Its
scientific basis comes from:

- FreeSurfer surface reconstruction.
- FreeSurfer subcortical segmentation.
- The selected cortical atlas.

For a Desikan–Killiany atlas, cite Desikan et al. For DKT, cite Klein and
Tourville. The atlas citation and the software citation describe different
parts of the result.

## `mri_segstats`

### Function

`mri_segstats` summarizes voxel counts, volumes, intensity values, and related
measurements within labeled regions.

### Publication status

This is primarily an analysis utility. The arithmetic operations do not
constitute a separate major scientific method requiring an individual paper.

### Appropriate reporting

Report:

- FreeSurfer version.
- Input segmentation or atlas.
- Measurement definition.
- Any normalization, intracranial-volume correction, or exclusion criteria.

## How FreeSurfer should be cited

A study does not normally cite every executable launched by `recon-all`.
Instead:

1. Cite FreeSurfer's core anatomical and surface-reconstruction papers.
2. Cite a specialized method when it is central, such as the watershed
   skull-stripping paper.
3. Cite the atlas separately.
4. Report the software version, important flags, and manual corrections.

# QSIPrep

## What QSIPrep is

QSIPrep is a BIDS-compatible diffusion MRI preprocessing platform. It inspects
the acquisition metadata and constructs an appropriate workflow using Nipype.
It was introduced in:

- Cieslak M, Cook PA, He X, et al. **QSIPrep: an integrative platform for
  preprocessing and reconstructing diffusion MRI data.** *Nature Methods*.
  2021;18:775–778. DOI: `10.1038/s41592-021-01185-5`.

QSIPrep is both integration software and a methods contribution.

## Major independently published components used by QSIPrep

Depending on configuration and version, QSIPrep can invoke:

- **BIDS and PyBIDS** for standardized data description and discovery.
- **Nipype** for constructing and executing workflows.
- **fMRIPrep/niworkflows-derived code** for anatomical workflow patterns,
  reporting, transforms, and infrastructure.
- **MRtrix3 `dwidenoise`** using MP-PCA denoising.
- **MRtrix3 `mrdegibbs`** using local subvoxel-shift Gibbs-ringing removal.
- **FSL `topup`** for susceptibility-distortion estimation from opposite
  phase-encoding data.
- **FSL `eddy`** for eddy-current, motion, and related correction.
- **ANTs** for anatomical registration and transformations.
- **N4 bias correction** for intensity nonuniformity.
- **SynthStrip/SynthSeg** in newer anatomical workflows.
- **DSI Studio-derived calculations** for diffusion image-quality measures.
- **DIPY and related Python libraries** for diffusion models, resampling, and
  image operations.

Each of these packages or algorithms has its own literature. QSIPrep does not
claim to have invented MP-PCA, `eddy`, `topup`, ANTs, N4, or MRtrix.

## What QSIPrep developed or innovated

### Adaptive BIDS-driven workflow construction

QSIPrep reads acquisition metadata such as:

- Phase-encoding direction.
- Total readout time.
- Available fieldmaps.
- Reverse phase-encoding images.
- Diffusion sampling scheme.
- Image grouping and sessions.

It then constructs a processing workflow appropriate to those inputs. This
automation is a substantive contribution because diffusion datasets differ
greatly in acquisition design.

### SHORELine

QSIPrep introduced SHORELine, a model-based motion-correction approach designed
to handle diffusion sampling schemes that are not naturally supported by
shell-specific tools.

SHORELine uses q-space modeling, including 3dSHORE-related predictions, to
generate target images for registration. This is a genuine algorithmic
contribution associated with the QSIPrep work, not merely an invocation of an
external executable.

### Support for diverse q-space sampling

QSIPrep was designed to handle:

- Single-shell data.
- Multi-shell data.
- Cartesian diffusion spectrum imaging.
- Random q-space sampling.
- Other nonstandard schemes.

It standardizes gradient and image handling so downstream reconstruction tools
can consume consistent derivatives.

### Coordinate and gradient consistency

Correctly maintaining b-vectors through motion correction, image transforms,
orientation changes, and resampling is scientifically critical. QSIPrep's
handling and validation of these transformations are important workflow
contributions even though matrix and interpolation operations are not entirely
new algorithms.

### Standardized derivatives and visual reports

QSIPrep produces consistent:

- Preprocessed DWI data.
- Gradient tables.
- Reference images.
- Brain masks.
- Transform files.
- Confounds and QC measurements.
- Visual reports.
- Machine-generated methodological descriptions.

This standardization makes independent reconstruction tools easier to compare
and improves reproducibility.

### Cross-dataset validation

The QSIPrep publication evaluated the platform across different diffusion
sampling schemes and datasets. Validation of an integrated workflow is itself a
scientific contribution because correct individual tools can still produce an
incorrect pipeline when coordinate systems, gradients, or transforms are
connected improperly.

### Lesion-aware spatial normalization

QSIPrep can automatically detect a correctly named BIDS lesion ROI and use it
during ANTs T1w-to-template normalization. The underlying cost-function-masking
concept comes from prior lesion-registration research; QSIPrep's contribution
is standardized BIDS discovery and workflow integration.

## What QSIPrep generally did not invent

QSIPrep did not invent:

- Diffusion MRI.
- The diffusion tensor.
- MP-PCA denoising.
- Gibbs-ringing removal.
- FSL `eddy` or `topup`.
- ANTs registration.
- N4 bias correction.
- BIDS.
- Nipype.
- MRtrix3.

It integrates these methods, adds workflow logic and original components, and
validates the combined system.

# QSIRecon

## What QSIRecon is

QSIRecon consumes preprocessed diffusion derivatives and builds reconstruction
workflows that can produce:

- Diffusion models.
- Scalar maps.
- Orientation or fiber-orientation distributions.
- Tractography.
- Tractometry.
- Atlas-based connectivity.
- Tabular summaries.

Current QSIRecon documentation identifies the main citation as the 2021
QSIPrep publication. QSIRecon is therefore not best described as an entirely
separate collection of newly invented reconstruction algorithms with a unique
paper for every workflow.

## Independently published methods integrated by QSIRecon

Depending on the reconstruction specification, QSIRecon can use:

- **MRtrix3** for response estimation, CSD, multi-tissue normalization, ACT,
  iFOD2, SIFT2, and connectomes.
- **DIPY** for tensor, kurtosis, MAP-MRI, tractography, and related models.
- **DSI Studio** for GQI, quantitative anisotropy, tractography, and AutoTrack.
- **AMICO** for accelerated NODDI estimation.
- **pyAFQ** for automated tractometry.
- **TORTOISE** for diffusion modeling and reconstruction workflows.
- **FreeSurfer derivatives** for anatomy and HSVS tissue construction.
- **ANTs/NiTransforms** for transform application.
- **TemplateFlow** for standardized atlas resources.

The mathematical reconstruction models and tractography algorithms generally
come from their respective published methods and software packages.

## Innovations and original contributions of QSIRecon

### Declarative reconstruction specifications

QSIRecon represents workflows as structured YAML specifications. A
specification declares:

- Which software should perform a node.
- Which action or reconstruction should run.
- Which upstream output supplies each downstream input.
- Which atlases, scalars, bundles, or connectivity outputs should be generated.

QSIRecon interprets this specification and constructs an executable workflow.
This separates the scientific recipe from hand-written scripts and makes
alternative methods easier to reproduce.

### Interoperability across reconstruction ecosystems

Diffusion packages often use different:

- File formats.
- Gradient conventions.
- Coordinate systems.
- Model representations.
- Naming systems.
- Output layouts.

QSIRecon provides interfaces that allow outputs from one ecosystem to become
inputs to another. For example, an MRtrix CSD product can feed a tractography or
bundle-analysis stage defined elsewhere in the workflow.

### Standardized use of QSIPrep derivatives

By requiring consistently preprocessed inputs, QSIRecon separates preprocessing
variation from reconstruction variation. This enables more defensible
comparisons among reconstruction methods.

### Workflow-level provenance

QSIRecon records:

- Reconstruction specification.
- Software actions.
- Parameters.
- Input/output relationships.
- Generated methodological boilerplate.
- BIDS-like derivative naming.

These features are workflow innovations even when the underlying model was
published by another group.

### Atlas, scalar, and bundle mapping

QSIRecon provides reusable workflow components for:

- Transforming scalar maps to standard spaces.
- Mapping atlases into reconstruction space.
- Assigning streamlines to atlas regions.
- Summarizing model scalars along bundles.
- Producing connectivity matrices and tabular outputs.

The underlying registration, tractography, and statistics may not be new, but
their generalized representation in a configurable reconstruction framework is
an important engineering and reproducibility contribution.

### Curated built-in workflows

QSIRecon provides tested combinations of methods rather than requiring every
laboratory to create undocumented shell scripts. Examples include MRtrix
single-shell and multi-shell CSD/ACT workflows and specifications using DIPY,
DSI Studio, AMICO, or other packages.

### Custom interfaces and glue code

QSIRecon contains original Python and Nipype code for tasks such as:

- Discovering and validating derivatives.
- Connecting workflow nodes.
- Converting representations.
- Managing spatial transforms.
- Constructing or masking tissue products.
- Collecting atlases and connectivity outputs.
- Writing provenance and reports.

This code is written by QSIRecon developers, but it does not mean that every
scientific algorithm executed by that code was invented by them.

## What QSIRecon generally did not invent

QSIRecon did not invent:

- CSD or SS3T-CSD.
- ACT.
- HSVS.
- iFOD2.
- SIFT or SIFT2.
- The diffusion tensor.
- DKI.
- GQI.
- NODDI.
- MAP-MRI.
- The anatomical atlases it distributes or retrieves.

It makes these methods configurable, interoperable, reproducible, and easier to
apply to standardized data.

# Example: our current QSIRecon specification

The DKT Connectome Pipeline uses:

```text
mrtrix_singleshell_ss3t_ACT-hsvs
```

The conceptual dependency chain is:

```text
QSIPrep derivatives
        ↓
MRtrix response estimation and single-shell three-tissue CSD
        ↓
FreeSurfer/FastSurfer derivatives + MRtrix HSVS 5TT
        ↓
MRtrix ACT with iFOD2 tractography
        ↓
MRtrix SIFT2
        ↓
QSIRecon atlas connectomes and exported derivatives
        ↓
DKT pipeline's subject-specific DKT connectome and reports
```

The scientific algorithms in this chain come mainly from MRtrix and FreeSurfer
publications. QSIRecon contributes the reconstruction specification,
orchestration, interfaces, standardized derivatives, and provenance.

# Implications for the DKT Connectome Pipeline

Our pipeline follows the same scientific-software pattern:

## Methods adopted from published work

- QSIPrep preprocessing and lesion-aware normalization.
- neuroLIT inpainting.
- FreeSurfer/FastSurfer reconstruction.
- DKT parcellation.
- MRtrix SS3T-CSD, HSVS, ACT, iFOD2, and SIFT2.
- Standard graph measurements such as node strength and asymmetry.

## Pipeline-level contributions

- Automated BIDS-to-DKT structural-connectome processing.
- Dual use of corrected anatomy and the retained original lesion.
- Integration of inpainting with FreeSurfer/FastSurfer and QSIRecon.
- Subject-specific DKT connectome construction.
- Regional lesion-load measurement.
- Multiple disconnectome definitions.
- Harmonized count, SIFT2, regional volume, strength, and asymmetry outputs.
- HPC execution, QC, provenance, and BIDS-derivative export.

## Potential algorithmic or methodological addition

Adding the lesion mask to the fifth ACT 5TT compartment is based on established
MRtrix ACT capabilities and lesion-aware literature. Our novelty would lie in:

- A reproducible TBI-specific implementation.
- Integration with neuroLIT-inpainted anatomy.
- Paired standard and lesion-aware tractography.
- Validation across heterogeneous TBI lesions.
- Demonstration of downstream DKT and disconnectome effects.

This would be an integration and validation contribution, not a claim that we
invented ACT or `5ttedit`.

# How to write attribution in a manuscript

Avoid statements such as:

> We developed a novel iFOD2 tractography algorithm.

That would be incorrect because iFOD2 is an MRtrix method.

A more accurate statement is:

> We developed a BIDS-compatible lesion-aware TBI connectomics workflow that
> integrates QSIPrep preprocessing, neuroLIT anatomical inpainting,
> FreeSurfer/FastSurfer reconstruction, and MRtrix SS3T-CSD/ACT tractography
> through QSIRecon, followed by subject-specific DKT connectome and
> disconnectome analyses.

For the proposed 5TT feature:

> We implemented and validated a TBI-specific pathological-5TT branch that
> transforms the original lesion mask into the ACT tissue grid, regenerates
> matched tractography and SIFT2 products, and quantifies its effect on
> individualized DKT connectomes.

This language clearly identifies what was integrated and validated without
claiming ownership of the underlying algorithms.

# Mathematical theory and representative code

## Scope and notation

This section explains the main mathematical ideas and shows representative
commands or pseudocode. The examples are educational simplifications. They do
not reproduce every internal option, heuristic, atlas, or implementation detail
in the production source.

Notation used below:

- \(I(x)\): image intensity at physical position \(x\).
- \(A\): affine transformation matrix.
- \(\phi(x)\): nonlinear spatial transformation.
- \(L(x)\): anatomical or tissue label.
- \(g\): unit diffusion-gradient direction.
- \(b\): diffusion weighting.
- \(S(b,g)\): measured diffusion signal.
- \(S_0\): non-diffusion-weighted signal.
- \(D\): diffusion tensor.
- \(f(n)\): fiber-orientation distribution in direction \(n\).

The Markdown equations use standard mathematical notation. The actual programs
use optimized C, C++, Python, CUDA, shell, or external library implementations.

## How a beginner should read the formulas

The formulas are compact descriptions of an idea, not instructions that a
reader must calculate by hand.

- A letter such as \(I\) or \(S\) usually represents an image or measured
  signal.
- \(x\) represents a location in the brain.
- A hat, as in \(\hat f\), means “our best estimate of something unknown.”
- \(\sum\) means “add all the listed values.”
- \(\arg\min\) means “choose the settings that make an error as small as
  possible.”
- \(\arg\max\) means “choose the option with the largest score or probability.”
- \(\|\cdot\|^2\) measures total squared error.
- \(\lambda\) is a balancing control: a larger value gives the following
  penalty more influence.
- A matrix is a rectangular collection of numbers. A transformation matrix
  stores how to move, rotate, resize, or shear coordinates.
- Probability expressions compare alternatives; they do not mean the software
  knows the biological truth with certainty.

For every method below, first read the **Beginner explanation**, then the
formula, and finally the code example. The formula explains the goal; the code
is one software implementation of that goal.

# FreeSurfer mathematics, theory, and code

## Image conversion and conformation with `mri_convert`

### Beginner explanation

An MRI is like a three-dimensional stack of graph paper. The voxel array stores
brightness values, while the affine matrix tells the computer where that graph
paper sits in real space. Conformation creates a new, standardized sheet of
graph paper and asks, “What brightness from the original image belongs at each
new location?”

In the formula below, \((i,j,k)\) is a voxel address, \(A\) is the coordinate
conversion rule, and \((x,y,z)\) is the corresponding location in millimeters.
The interpolation formula says that a new voxel may combine nearby old voxels
when the grids do not line up exactly.

### Theory

A NIfTI or MGZ image contains both a voxel array and an affine mapping from
voxel coordinates to physical coordinates:

\[
\begin{bmatrix}x\\y\\z\\1\end{bmatrix}
=
A
\begin{bmatrix}i\\j\\k\\1\end{bmatrix}.
\]

Changing orientation metadata without resampling changes how array indices are
interpreted. Conformation instead creates a target grid and samples the original
image on that grid. For a target voxel \(u\), the corresponding source position
is:

\[
v=A_{\mathrm{source}}^{-1}A_{\mathrm{target}}u.
\]

The target intensity is obtained with an interpolation kernel \(K\):

\[
I_{\mathrm{target}}(u)
=
\sum_n I_{\mathrm{source}}(n)K(v-n).
\]

Nearest-neighbor interpolation is appropriate for labels. Linear, cubic, or
sinc-like interpolation is more appropriate for continuous intensities.

### Representative code

```bash
mri_convert input_T1w.nii.gz orig.mgz
mri_convert --conform input_T1w.nii.gz conformed.mgz
```

Conceptual pseudocode:

```python
for target_voxel in target_grid:
    target_world = target_affine @ target_voxel
    source_voxel = inverse(source_affine) @ target_world
    output[target_voxel] = interpolate(input, source_voxel)
```

### Source

This is standard medical-image geometry and resampling implemented as a
FreeSurfer utility. Cite FreeSurfer and report the interpolation and target
geometry; there is no separate foundational `mri_convert` paper.

## Robust template estimation with `mri_robust_template`

### Beginner explanation

Imagine taking several photographs of the same person on different days. The
head is slightly shifted in every picture. Robust template estimation aligns
all photographs and makes an average image, while giving less influence to
blurred or unusual pixels. “Unbiased” means no single visit is treated as the
correct master image.

The formula adds the mismatch between every aligned scan and the shared
template. The program changes the alignments and template until that mismatch
is small. The function \(\rho\) prevents one bad measurement from dominating
the result.

### Theory

For repeated images \(I_i\), the objective is to estimate a subject template
\(T\) and transforms \(M_i\) without selecting one time point as the privileged
reference. A simplified robust objective is:

\[
\min_{T,\{M_i\}}
\sum_i\sum_x
\rho\left(I_i(M_i x)-T(x)\right),
\]

where \(\rho\) is a robust loss that reduces the influence of outliers.
Inverse-consistent registration penalizes disagreement between forward and
inverse mappings rather than estimating unrelated one-way transforms.

The unbiased template is iteratively updated from the transformed images. The
actual FreeSurfer method includes robust estimation and transform
parameterization described by Reuter et al. (2010, 2012).

### Representative code

```bash
mri_robust_template \
  --mov time1.mgz time2.mgz \
  --template subject_template.mgz \
  --lta time1_to_template.lta time2_to_template.lta \
  --satit
```

Conceptual pseudocode:

```python
template = robust_average(images)
repeat:
    transforms = [robust_register(image, template) for image in images]
    aligned = [resample(image, transform) for image, transform in pairs]
    template = robust_weighted_average(aligned)
until convergence
```

### Sources

- Reuter, Rosas, and Fischl, 2010.
- Reuter, Schmansky, Rosas, and Fischl, 2012.

## N3 bias correction with `mri_nu_correct.mni`

### Beginner explanation

This is similar to correcting a photograph taken under uneven lighting. A
uniform tissue can appear brighter on one side of the brain because the scanner
has a slowly changing sensitivity pattern. N3 estimates that smooth “lighting”
field and divides it away.

The first formula says: observed brightness equals real tissue brightness
multiplied by scanner bias, plus noise. Taking the logarithm changes
multiplication into addition, which makes the smooth bias easier to estimate.

### Theory

The observed image is modeled as the product of true tissue signal and a
slowly varying bias field:

\[
I_{\mathrm{obs}}(x)=B(x)I_{\mathrm{true}}(x)+\epsilon(x).
\]

Taking logarithms turns the multiplicative field into an additive component:

\[
\log I_{\mathrm{obs}}(x)
=
\log B(x)+\log I_{\mathrm{true}}(x).
\]

N3 estimates a smooth field that reduces low-frequency intensity
nonuniformity and sharpens the tissue-intensity distribution. The field is
represented smoothly rather than estimated independently at every voxel.

### Representative code

```bash
mri_nu_correct.mni --i orig.mgz --o nu.mgz --n 1
```

Conceptual pseudocode:

```python
log_image = log(image)
bias = zeros_like(image)
repeat:
    corrected = log_image - bias
    residual_low_frequency = estimate_smooth_bias(corrected)
    bias += residual_low_frequency
until histogram_sharpness_stabilizes
output = exp(log_image - bias)
```

### Source

Sled, Zijdenbos, and Evans, 1998. Modern N4 uses a related model with a modified
optimization strategy, but `mri_nu_correct.mni` and ANTs N4 should not be
described as the same executable.

## Affine atlas alignment with `talairach_avi`

### Beginner explanation

Affine registration aligns the whole brain by moving, rotating, resizing, and
slanting it. Think of lining up two transparent brain pictures using one global
adjustment. It cannot bend one small region independently.

In \(x_{\mathrm{atlas}}=Ax_{\mathrm{subject}}\), \(A\) stores all global
adjustments, the right side is a point in the participant's brain, and the left
side is the matching atlas coordinate.

### Theory

An affine transform maps subject coordinates to atlas coordinates:

\[
x_{\mathrm{atlas}}=Ax_{\mathrm{subject}},
\]

where \(A\) can represent translation, rotation, scaling, and shear. The
registration searches for parameters that improve an atlas/image similarity
criterion while maintaining a physically plausible global transform.

This step supplies a standardized orientation and initialization. It does not
perform detailed nonlinear anatomical correspondence.

### Representative code

```bash
talairach_avi --i orig.mgz --xfm transforms/talairach.auto.xfm
```

Conceptual pseudocode:

```python
A = identity_affine()
repeat:
    moved = resample(subject, A, atlas_grid)
    score = atlas_similarity(moved, atlas)
    A = optimizer_update(A, score)
until convergence
```

### Source

The command is part of the FreeSurfer atlas-processing implementation and uses
established affine atlas-registration principles. Cite the FreeSurfer
reconstruction and segmentation literature rather than asserting a unique
paper for this executable.

## Hybrid skull stripping with `mri_watershed`

### Beginner explanation

Watershed treats image intensity like a landscape of hills and valleys and uses
controlled “flooding” to find boundaries. Because flooding alone can leak,
FreeSurfer also uses a flexible surface like a balloon around the brain.

The energy formula is a score the algorithm tries to reduce. One part rewards
following image boundaries, one keeps the surface smooth, and one discourages
an implausible brain shape. The \(\lambda\) values decide how strongly those
goals compete.

### Theory

Watershed segmentation interprets an image-derived surface as topography and
floods basins from seed points. Pure watershed methods can leak or stop at
incorrect boundaries, so FreeSurfer combines watershed initialization with a
deformable surface.

A simplified deformable-surface energy is:

\[
E(S)
=
\lambda_{\mathrm{data}}E_{\mathrm{boundary}}(S,I)
+\lambda_{\mathrm{smooth}}E_{\mathrm{smooth}}(S)
+\lambda_{\mathrm{shape}}E_{\mathrm{shape}}(S).
\]

The data term attracts the surface to likely brain/nonbrain boundaries, while
regularization discourages jagged or implausible geometry.

### Representative code

```bash
mri_watershed -atlas T1.mgz brainmask.mgz
```

Conceptual pseudocode:

```python
initial_mask = watershed_flood(intensity_topography, seeds)
surface = mesh_from_mask(initial_mask)
repeat:
    force = boundary_force(image, surface)
    force += smoothness_force(surface)
    force += atlas_or_shape_force(surface)
    surface = deform(surface, force)
until stable
brain_mask = rasterize(surface)
```

### Source

Ségonne et al., 2004, DOI `10.1016/j.neuroimage.2004.03.032`.

## Probabilistic atlas registration with `mri_em_register`

### Beginner explanation

The atlas says where structures are usually found and what their MRI brightness
usually looks like. The program repeatedly performs two tasks: estimate which
tissues the voxels might be, then improve the atlas alignment using those
estimates. This is similar to sorting puzzle pieces while simultaneously moving
the reference picture underneath them.

The formula tries different alignments \(A\). For every location, it combines
the probability of seeing that brightness for tissue \(k\) with the probability
that tissue \(k\) belongs at that atlas position. The best alignment gives the
largest total probability.

### Theory

The atlas provides spatial priors \(P(L=k\mid x)\) for anatomical classes.
Class-conditional intensity models provide \(P(I(x)\mid L=k)\). Registration
seeks the transform \(A\) that makes the subject intensities most probable under
the atlas:

\[
\hat A
=
\arg\max_A
\sum_x
\log
\left[
\sum_k
P(I(A^{-1}x)\mid L=k)
P(L=k\mid x)
\right].
\]

In an expectation-maximization interpretation:

- The E-step estimates posterior class probabilities.
- The M-step updates registration and intensity parameters to increase expected
  log likelihood.

The exact implementation contains FreeSurfer-specific priors, initialization,
and optimization.

### Representative code

```bash
mri_em_register nu.mgz atlas.gca transforms/talairach.lta
```

Conceptual pseudocode:

```python
A = initial_affine
repeat:
    posteriors = class_posterior(image, atlas_priors, A)
    A = maximize_expected_atlas_likelihood(image, atlas, posteriors)
until convergence
```

### Source

Fischl et al., 2002, whole-brain probabilistic segmentation.

## `mri_ca_normalize`: atlas-guided intensity normalization

### Beginner explanation

Different scans can assign different numerical brightness to the same tissue.
This step calibrates the image so that likely white matter and other tissues
have brightness values expected by FreeSurfer's atlas.

In \(I_{\mathrm{norm}}=aI+c\), \(a\) changes the brightness scale and \(c\)
shifts it. Allowing these corrections to vary smoothly across space handles
scanner shading without creating sharp artificial boundaries.

### Theory

MRI tissue intensities are not absolute physical units. FreeSurfer estimates a
spatially varying correction so that tissue classes better match the atlas
intensity model. A simplified model is:

\[
I_{\mathrm{norm}}(x)=a(x)I(x)+c(x),
\]

where \(a(x)\) and possibly \(c(x)\) vary smoothly and are constrained by
likely tissue classes and control points.

### Representative code

```bash
mri_ca_normalize \
  -c ctrl_pts.mgz \
  nu.mgz atlas.gca transforms/talairach.lta norm.mgz
```

Conceptual pseudocode:

```python
repeat:
    likely_tissues = classify_using_atlas(image, transform)
    control_points = select_reliable_white_matter(likely_tissues)
    correction = fit_smooth_intensity_field(image, control_points)
    image = apply(correction, image)
until white_matter_target_is_stable
```

### Source

This operation belongs to the FreeSurfer probabilistic segmentation framework,
particularly Fischl et al. (2002), rather than a separate paper for the command.

## `mri_ca_register`: nonlinear atlas registration

### Beginner explanation

Affine registration moves the brain as one object. Nonlinear registration is
more like gently bending a rubber sheet so local anatomy lines up with the
atlas. The bend must remain smooth so the program does not tear or fold the
brain simply to improve the match.

The formula balances atlas mismatch against \(R(\phi)\), the penalty for an
unrealistic deformation. The chosen transformation \(\hat\phi\) is the one with
the lowest combined cost.

### Theory

A deformation \(\phi\) aligns the subject with a probabilistic atlas. A
simplified objective is:

\[
\hat\phi
=
\arg\min_\phi
\left[
-\sum_x\log P\left(I(x)\mid
\text{atlas at }\phi(x)\right)
+\lambda R(\phi)
\right].
\]

The first term rewards alignment with atlas intensity and label distributions.
The regularizer \(R(\phi)\) discourages folding and implausibly rough
deformations.

### Representative code

```bash
mri_ca_register \
  -align-after \
  norm.mgz atlas.gca transforms/talairach.lta transforms/talairach.m3z
```

Conceptual pseudocode:

```python
phi = affine_initialization
for resolution in coarse_to_fine:
    repeat:
        likelihood_gradient = atlas_likelihood_gradient(image, atlas, phi)
        regularization_gradient = deformation_penalty_gradient(phi)
        phi = update(phi, likelihood_gradient, regularization_gradient)
    until convergence
```

### Source

Fischl et al., 2002 and related FreeSurfer atlas-registration work.

## `mri_ca_label`: Bayesian anatomical labeling

### Beginner explanation

Each voxel holds a contest among possible anatomical names. A label scores
high when its expected brightness fits, the atlas says it commonly occurs at
that location, and it makes sense beside neighboring labels.

The formula multiplies those three sources of evidence and chooses the label
with the highest score. “Most probable” here means most consistent with the
model; it is not guaranteed anatomical truth.

### Theory

For voxel \(x\), a simplified maximum-a-posteriori label is:

\[
\hat L(x)
=
\arg\max_k
P(I(x)\mid L(x)=k)
P(L(x)=k\mid \phi(x))
P(L(x)=k\mid L(\mathcal N_x)),
\]

where:

- The first term is the class-intensity likelihood.
- The second is the spatial atlas prior.
- The third represents compatibility with neighboring labels.

FreeSurfer's classifier atlas includes richer spatial and neighborhood
information than this compact equation shows.

### Representative code

```bash
mri_ca_label \
  norm.mgz transforms/talairach.m3z atlas.gca aseg.auto.mgz
```

Conceptual pseudocode:

```python
for voxel in brain:
    for label in candidate_labels:
        score[label] = intensity_likelihood(label)
        score[label] *= atlas_prior(label, transformed_position)
        score[label] *= neighborhood_compatibility(label, neighbors)
    output[voxel] = argmax(score)
```

### Source

Fischl et al., 2002.

## Surface reconstruction with `mris_make_surfaces`

### Beginner explanation

FreeSurfer builds a triangular net around the cortex. It first places the net
near the white-matter boundary, then adjusts another surface toward the outside
of cortex. Forces pull vertices toward likely intensity boundaries while other
forces prevent a rough or tangled mesh.

The first energy formula adds image-boundary, smoothness, and topology costs.
The thickness formula measures the distance between white and pial surfaces in
both directions and averages them. The spherical-registration formula aligns
folding patterns after the cortex is inflated to a sphere.

### Theory

The cortex is represented as triangular meshes. Surface placement can be
conceptualized as minimizing:

\[
E(V)
=
\lambda_I E_{\mathrm{intensity}}(V,I)
+\lambda_G E_{\mathrm{gradient}}(V,I)
+\lambda_S E_{\mathrm{smooth}}(V)
+\lambda_T E_{\mathrm{topology}}(V),
\]

where \(V\) contains mesh vertices.

- The white surface is attracted to the white/gray boundary.
- The pial surface is attracted to the gray/CSF boundary.
- Smoothness terms stabilize the mesh.
- Topology correction seeks a surface topologically equivalent to a sphere.

FreeSurfer thickness is commonly defined symmetrically from distances between
white and pial surfaces. In simplified form:

\[
t(v)
=
\frac{1}{2}
\left[
d(v,S_{\mathrm{pial}})
+d(p(v),S_{\mathrm{white}})
\right],
\]

where the implementation evaluates distances in both directions to reduce
one-sided bias.

Spherical registration aligns cortical folding patterns such as curvature
while regularizing distortion:

\[
\min_\psi
\sum_v
\left[c_{\mathrm{subj}}(v)-c_{\mathrm{atlas}}(\psi(v))\right]^2
+\lambda R(\psi).
\]

### Representative code

```bash
mris_make_surfaces -noaparc sub-001 lh
mris_sphere sub-001/surf/lh.inflated sub-001/surf/lh.sphere
mris_register sub-001/surf/lh.sphere atlas.sphere.reg \
  sub-001/surf/lh.sphere.reg
mris_ca_label sub-001 lh sphere.reg classifier.gcs lh.aparc.annot
```

Conceptual pseudocode:

```python
white = initialize_mesh(white_matter_segmentation)
white = deform_to_intensity_boundary(white, t1_image, smoothness=True)
white = correct_topology(white)
pial = expand_and_deform(white, gray_csf_boundary)
sphere = inflate_and_project_to_sphere(white)
sphere_reg = align_folding_features(sphere, atlas)
annotations = classify_surface_vertices(sphere_reg, atlas_classifier)
```

### Sources

- Dale, Fischl, and Sereno, 1999.
- Fischl, Sereno, and Dale, 1999.
- Fischl and Dale, 2000.
- Fischl, Liu, and Dale, 2001.
- Fischl et al., 2004.

## Volumetric parcellation with `mri_aparc2aseg`

### Beginner explanation

The cortical atlas initially lives on the surface mesh, but many tools need a
three-dimensional labeled image. This step “paints” each cortical region from
the surface into voxels lying between the white and pial surfaces, then combines
those labels with subcortical structures.

The formula is an if/then rule: preserve a valid subcortical label; otherwise,
for a cortical-ribbon voxel, use the annotation of the closest appropriate
surface vertex.

### Theory

Cortical annotations live on surface vertices, whereas many downstream tools
require voxel labels. `mri_aparc2aseg` assigns cortical voxels using the
participant's white and pial surfaces and the surface annotation, then merges
those cortical labels with subcortical `aseg` labels.

A simplified assignment is:

\[
L_{\mathrm{voxel}}(x)
=
\begin{cases}
L_{\mathrm{aseg}}(x), & x\text{ belongs to a protected subcortical label},\\
L_{\mathrm{annot}}(v^*), &
x\text{ lies in cortical ribbon and }v^*=\arg\min_v\|x-v\|.
\end{cases}
\]

The production implementation contains hemisphere, ribbon, distance, and label
precedence rules.

### Representative code

```bash
mri_aparc2aseg \
  --s sub-001 \
  --annot DKTatlas \
  --o aparc.DKTatlas+aseg.mgz
```

Conceptual pseudocode:

```python
output = copy(subcortical_aseg)
for cortical_voxel in ribbon:
    hemisphere = determine_hemisphere(cortical_voxel)
    vertex = nearest_valid_surface_vertex(cortical_voxel, hemisphere)
    output[cortical_voxel] = annotation[vertex]
```

### Sources

Cite the FreeSurfer surface/segmentation framework and the selected atlas. For
DKT, cite Klein and Tourville (2012).

## Regional summaries with `mri_segstats`

### Beginner explanation

This is similar to using a spreadsheet to summarize each named brain region.
The program counts its voxels, multiplies by the physical size of one voxel to
obtain cubic millimeters, and can average another measurement inside the
region.

\(N_k\) is the number of voxels carrying label \(k\). \(V_k\) is that count
times voxel volume. The mean formula adds all values in the region and divides
by how many voxels were included.

### Theory

For label \(k\), voxel count and volume are:

\[
N_k=\sum_x \mathbf 1[L(x)=k],
\qquad
V_k=N_k|\det(A_{3\times3})|.
\]

For an intensity or scalar image \(J(x)\), the regional mean and variance are:

\[
\bar J_k
=
\frac{1}{N_k}\sum_{x:L(x)=k}J(x),
\]

\[
s_k^2
=
\frac{1}{N_k-1}
\sum_{x:L(x)=k}
\left(J(x)-\bar J_k\right)^2.
\]

Surface statistics use analogous sums over vertices or area-weighted surface
elements.

### Representative code

```bash
mri_segstats \
  --seg aparc.DKTatlas+aseg.mgz \
  --sum dkt_volume_stats.txt
```

Conceptual pseudocode:

```python
for label in unique(segmentation):
    mask = segmentation == label
    voxel_count = sum(mask)
    volume_mm3 = voxel_count * voxel_volume
    mean_value = mean(measure_image[mask])
```

### Source

This is standard regional summary arithmetic implemented by FreeSurfer. Cite
FreeSurfer, the atlas, and the scientific source of any scalar image being
summarized.

# QSIPrep mathematics, theory, and code

## BIDS discovery and Nipype workflow construction

### Beginner explanation

This is the recipe-management part of QSIPrep. BIDS gives files standardized
names and metadata. QSIPrep reads them and constructs a flowchart in which each
box is a processing operation and each arrow passes a result to the next box.

The graph expression \(G=(V,E)\) simply means that a workflow consists of
processing nodes \(V\) and connections \(E\). It does not describe brain
biology.

### Theory

This component is primarily graph and metadata logic rather than an image
equation. PyBIDS queries files and metadata. QSIPrep converts the resulting
acquisition description into a directed acyclic graph:

\[
G=(V,E),
\]

where each node \(v\in V\) is an operation and each edge \(e\in E\) carries a
typed output from one operation to an input of another.

### Representative pseudocode

```python
layout = BIDSLayout(bids_dir)
dwi = layout.get(subject=subject, suffix="dwi")
fmap = find_intended_fieldmaps(layout, dwi)

workflow = Workflow("qsiprep")
workflow.connect(denoise, "dwi", unring, "dwi")
workflow.connect(unring, "dwi", motion_and_sdc, "dwi")
workflow.connect(motion_and_sdc, "corrected", resample, "dwi")
```

The actual QSIPrep source uses Nipype interfaces, configuration objects, BIDS
queries, and conditional workflow builders.

### Sources

- Gorgolewski et al., 2011, Nipype.
- Gorgolewski et al., 2016, BIDS.
- Cieslak et al., 2021, QSIPrep.

## MP-PCA denoising

### Beginner explanation

Suppose many students describe the same object. Their shared statements contain
the real pattern, while random disagreements behave like noise. MP-PCA examines
small image neighborhoods across all diffusion volumes and keeps strong,
repeated patterns while removing components that look like random noise.

\(X=S+N\) says measured data are signal plus noise. SVD separates \(X\) into
patterns ranked by strength. Random-matrix theory estimates which weak patterns
are likely noise; the retained patterns are recombined into \(\hat S\), the
denoised estimate.

### Theory

A local patch of diffusion measurements is arranged as a matrix:

\[
X=S+N,
\]

where \(S\) is low-rank structured signal and \(N\) is noise. Singular-value
decomposition gives:

\[
X=U\Sigma V^\top.
\]

Random matrix theory predicts the distribution of singular values generated by
noise. Components compatible with the Marchenko–Pastur noise distribution are
removed, while larger signal components are retained:

\[
\hat S=U\Sigma_{\mathrm{retained}}V^\top.
\]

This assumes locally redundant measurements and an appropriate noise model.

### Representative code

```bash
dwidenoise dwi.nii.gz dwi_denoised.nii.gz \
  -noise noise_map.nii.gz
```

Conceptual pseudocode:

```python
for spatial_patch in image:
    X = patch_as_voxels_by_volumes(spatial_patch)
    U, singular_values, Vt = svd(X)
    threshold = marchenko_pastur_noise_edge(singular_values, X.shape)
    keep = singular_values > threshold
    denoised_patch = U[:, keep] @ diag(singular_values[keep]) @ Vt[keep]
    aggregate_overlapping_patch_estimates(denoised_patch)
```

### Source

Veraart et al., 2016.

## Gibbs-ringing correction

### Beginner explanation

MRI scanners measure only a limited range of spatial frequencies. Cutting off
high frequencies is like trying to draw a sharp square using only smooth waves:
small ripples appear beside the edge. `mrdegibbs` tests tiny subvoxel shifts and
chooses the version with less local ringing.

The theory uses Fourier transforms, but the practical idea is simple: identify
the sampling-related oscillation near strong boundaries without smoothing the
whole image indiscriminately.

### Theory

Finite k-space sampling multiplies the continuous spectrum by a rectangular
window. In image space, multiplication in Fourier space becomes convolution
with a sinc-like point-spread function, creating oscillations near sharp
boundaries.

The local subvoxel-shift method evaluates shifted reconstructions and selects
the shift that minimizes local oscillation or total variation near edges.

### Representative code

```bash
mrdegibbs dwi_denoised.nii.gz dwi_unringed.nii.gz
```

Conceptual pseudocode:

```python
for line in each_image_direction:
    candidates = [fourier_subvoxel_shift(line, delta) for delta in shifts]
    score = [local_total_variation(candidate) for candidate in candidates]
    output_line = candidates[argmin(score)]
```

### Source

Kellner et al., 2016.

## Susceptibility correction with FSL `topup`

### Beginner explanation

Echo-planar images can look stretched or squeezed along one direction because
local magnetic fields are uneven. If two b0 images are acquired with opposite
phase-encoding directions, their distortions bend in opposite directions.
`topup` finds a smooth field that unbends both toward a shared anatomy.

In the formula, \(d(x)p\) is the location shift along the phase-encoding
direction, and \(J_d\) corrects the brightness change caused by stretching or
compression.

### Theory

Susceptibility creates a displacement primarily along the phase-encoding
direction. A simplified acquisition model is:

\[
I_{\mathrm{obs}}(x)
\approx
I_{\mathrm{true}}(x+d(x)p)J_d(x),
\]

where:

- \(p\) is the phase-encoding direction.
- \(d(x)\) is displacement determined by the off-resonance field and readout
  time.
- \(J_d(x)\) is an intensity Jacobian correction.

Images acquired with reversed phase encoding have approximately opposite
distortions. `topup` estimates a smooth field that makes the corrected images
agree.

### Representative code

```bash
topup \
  --imain=paired_b0s.nii.gz \
  --datain=acqparams.txt \
  --config=b02b0.cnf \
  --out=topup_results
```

Conceptual pseudocode:

```python
field = initialize_smooth_off_resonance_field()
repeat:
    corrected_forward = unwarp(forward_b0, field, pe_direction=+1)
    corrected_reverse = unwarp(reverse_b0, field, pe_direction=-1)
    loss = similarity(corrected_forward, corrected_reverse)
    loss += smoothness_penalty(field)
    field = optimizer_update(field, loss)
until convergence
```

### Source

Andersson, Skare, and Ashburner, 2003.

## Motion and eddy-current correction with FSL `eddy`

### Beginner explanation

Each diffusion volume can be shifted by head motion and warped by magnetic
fields induced by rapidly changing gradients. `eddy` predicts what each volume
should look like from the other diffusion measurements, then aligns the
observed volume to that prediction.

The error formula compares corrected volume \(I_i\) with prediction
\(\hat I_i\). The program changes motion and distortion settings
\(\theta_i\) until the difference is small. If the head rotates, the gradient
direction must rotate too: \(g_i'=R_i g_i\).

### Theory

Each diffusion volume has a rigid-body motion transform \(R_i,t_i\) and an
eddy-current-induced spatial distortion parameterized from the diffusion
gradient. `eddy` jointly estimates these effects while using predictions of the
diffusion signal to improve registration.

A simplified objective is:

\[
\min_{\theta_i}
\sum_i
\left\|
I_i\circ T_{\theta_i}
-\hat I_i
\right\|^2
+R(\theta_i),
\]

where \(\hat I_i\) is a model-based prediction of volume \(i\), and
\(T_{\theta_i}\) includes motion, eddy-current, and susceptibility terms.

Outlier replacement detects slices whose residuals are inconsistent with the
prediction and replaces them with model estimates for correction purposes.

When the image is rotated by \(R_i\), the corresponding gradient direction must
also rotate:

\[
g_i'=R_i g_i.
\]

### Representative code

```bash
eddy_openmp \
  --imain=dwi.nii.gz \
  --mask=mask.nii.gz \
  --acqp=acqparams.txt \
  --index=index.txt \
  --bvecs=bvecs \
  --bvals=bvals \
  --topup=topup_results \
  --out=eddy_corrected
```

Conceptual pseudocode:

```python
repeat:
    prediction = gaussian_process_predict_each_volume(corrected_data, qspace)
    transforms = register_each_volume_to_prediction(data, prediction)
    detect_and_replace_slice_outliers(data, prediction)
    corrected_data = resample_with_motion_eddy_and_susceptibility(transforms)
    rotated_bvecs = [rotation(T) @ g for T, g in zip(transforms, bvecs)]
until convergence
```

### Source

Andersson and Sotiropoulos, 2016.

## ANTs registration and lesion cost-function masking

### Beginner explanation

Registration is like aligning two transparent maps. ANTs changes the moving map
until its unaffected anatomy matches the fixed map. A lesion can have unusual
brightness and shape, so allowing it to influence the matching score can pull
the rest of the brain into the wrong position.

Cost-function masking tells the optimizer, “Do not grade the alignment inside
the lesion; grade it using the remaining brain.” The formula minimizes image
difference \(D\) plus a smoothness penalty \(R\), using
\(\Omega\setminus L\), meaning all fitting locations except lesion \(L\).

### Theory

Registration estimates a transform \(\phi\) by minimizing:

\[
\hat\phi
=
\arg\min_\phi
D\left(I_{\mathrm{fixed}},
I_{\mathrm{moving}}\circ\phi;
\Omega\right)
+\lambda R(\phi),
\]

where \(D\) may be cross-correlation or mutual information and \(R\) regularizes
the transform.

With lesion cost-function masking, the similarity domain excludes lesion
voxels:

\[
\Omega_{\mathrm{fit}}=\Omega\setminus L.
\]

The lesion is not deleted from the image. It is excluded from contributing to
the fitting objective so that abnormal intensities do not pull the transform.

### Representative code

```bash
antsRegistration \
  --dimensionality 3 \
  --metric "CC[fixed.nii.gz,moving.nii.gz,1,4,Regular,0.2]" \
  --masks "[fixed_fit_mask.nii.gz,moving_fit_mask.nii.gz]" \
  --transform "SyN[0.1,3,0]"
```

Conceptual pseudocode:

```python
fit_mask = brain_mask & ~lesion_mask
phi = initialize_affine()
for stage in [rigid, affine, nonlinear]:
    phi = minimize(
        similarity(fixed, warp(moving, phi), domain=fit_mask)
        + regularization(phi)
    )
```

### Sources

- Brett et al., 2001, lesion cost-function masking.
- Avants et al., 2011, ANTs.
- Cieslak et al., 2021, QSIPrep integration.

## N4 bias-field correction

### Beginner explanation

N4 is another uneven-lighting correction. It estimates a very smooth scanner
brightness field using flexible B-spline curves, then removes that field so the
same tissue has more consistent intensity across the brain.

The formula is the same basic observation model as N3: measured brightness is
true brightness multiplied by scanner bias. N4 changes how that bias is
represented and optimized.

### Theory

N4 uses the same multiplicative observation model:

\[
I_{\mathrm{obs}}(x)=B(x)I_{\mathrm{true}}(x)+\epsilon.
\]

In log space, it estimates a smooth B-spline representation of \(\log B(x)\)
and iteratively sharpens the corrected intensity distribution. N4 modifies and
improves the original N3 optimization.

### Representative code

```bash
N4BiasFieldCorrection \
  -d 3 \
  -i T1w.nii.gz \
  -x brain_mask.nii.gz \
  -o "[T1w_n4.nii.gz,bias_field.nii.gz]"
```

### Source

Tustison et al., 2010.

## SHORELine and 3dSHORE signal prediction

### Beginner explanation

Different diffusion directions naturally produce different image contrast, so
directly aligning one diffusion image to another can be misleading. SHORELine
learns the pattern of how signal changes across q-space, predicts what a
particular volume should look like, and aligns the measured volume to its own
prediction.

The first formula builds signal \(E(q)\) by adding weighted basis patterns
\(\Phi\). The second chooses coefficients \(c\) that reproduce measured signal
while avoiding an unstable, overly complicated model.

### Theory

SHORE represents the diffusion signal in q-space using a basis expansion:

\[
E(q)
=
\sum_{n,l,m}
c_{nlm}\Phi_{nlm}(q).
\]

Coefficients can be estimated with regularized least squares:

\[
\hat c
=
\arg\min_c
\|Bc-s\|_2^2
+\lambda R(c),
\]

where \(B\) contains basis functions evaluated at measured q-space locations.

SHORELine predicts a target diffusion volume from the remaining measurements,
registers the observed volume to its prediction, rotates the gradient, and
iterates. This avoids registering diffusion-weighted images directly to a
single b0 despite their orientation-dependent contrast.

### Representative pseudocode

```python
corrected = input_dwi
repeat:
    for volume in corrected:
        model = fit_3dshore(corrected excluding volume, gradients)
        predicted = model.predict(gradient_of(volume))
        transform = rigid_register(volume, predicted)
        corrected[volume] = resample(volume, transform)
        gradients[volume] = rotation(transform) @ gradients[volume]
until motion_parameters_stabilize
```

QSIPrep selects and configures SHORELine through its workflow rather than
requiring users to reproduce this pseudocode.

### Sources

- Özarslan et al., 3dSHORE basis work.
- Cieslak et al., 2021, SHORELine in QSIPrep.

## Resampling and transform composition

### Beginner explanation

Imagine receiving several navigation instructions: rotate, shift, unwarp, then
move into T1 space. Applying and saving the image after every instruction would
repeatedly blur it. QSIPrep combines the instructions into one route and samples
the image once when practical.

The composition formula means “apply \(\phi_1\), then \(\phi_2\), continuing
through \(\phi_n\).” The output formula looks backward through the combined map
to find where each new voxel came from.

### Theory

Repeated interpolation blurs images. QSIPrep composes transforms and applies
them in a controlled resampling step. If transforms are applied in order
\(\phi_1,\phi_2,\ldots,\phi_n\), the composite mapping is:

\[
\phi_{\mathrm{total}}
=
\phi_n\circ\cdots\circ\phi_2\circ\phi_1.
\]

The output is sampled once where practical:

\[
I_{\mathrm{out}}(x)
=
I_{\mathrm{in}}\left(\phi_{\mathrm{total}}^{-1}(x)\right).
\]

### Representative pseudocode

```python
composite = compose(susceptibility, eddy, motion, coregistration)
preprocessed_dwi = resample_once(
    raw_dwi,
    transform=composite,
    target_grid=t1w_or_requested_grid
)
```

### Source

This is standard spatial-transform theory implemented through QSIPrep,
NiTransforms, ANTs, FSL, and related interfaces. Report the actual QSIPrep
version and generated methods boilerplate.

## SynthStrip and SynthSeg

### Beginner explanation

These programs are neural networks trained using many examples and synthetic
variations. SynthStrip decides brain versus nonbrain. SynthSeg assigns multiple
anatomical classes. For each voxel, the network outputs scores interpreted as
class probabilities.

The loss formula is the training report card. Dice loss rewards overlap with
the correct region, cross-entropy rewards the correct class probability, and
regularization discourages unstable models. Users run the trained network; they
do not retrain it during ordinary QSIPrep processing.

### Theory

These are learned segmentation systems. A neural network maps an image \(I\) to
class probabilities:

\[
p_\theta(L(x)=k\mid I).
\]

Training minimizes a segmentation loss, commonly containing overlap and
classification terms:

\[
\mathcal L
=
\lambda_D\mathcal L_{\mathrm{Dice}}
+\lambda_C\mathcal L_{\mathrm{cross\ entropy}}
+\text{regularization}.
\]

SynthStrip predicts brain versus nonbrain. SynthSeg predicts multiple
anatomical classes and is trained with extensive synthetic contrast and spatial
augmentation to improve robustness across acquisition types.

The exact architectures and training objectives should be taken from their
publications, not inferred from this simplified expression.

### Representative workflow code

```python
brain_mask = synthstrip(t1w)
tissue_labels = synthseg(t1w, mask=brain_mask)
```

### Sources

- Hoopes et al., 2022, SynthStrip.
- Billot et al., 2023, SynthSeg.

## QSIPrep quality control

### Beginner explanation

QC is a report card, not a single pass/fail truth. It records motion, unusual
slices, prediction errors, signal quality, and registration images. Researchers
must decide thresholds suitable for their scanner, participants, and analysis.

The residual formula compares an observed image with the model's prediction and
divides by prediction size, making the error easier to compare across images.

### Theory

QC combines direct measurements and model residuals. Examples include:

- Framewise translation and rotation.
- Slice or volume outlier counts.
- Residual error between corrected observations and predictions.
- Neighboring diffusion-correlation measures.
- Signal-to-noise and contrast summaries.
- Registration overlays.

A generic normalized residual is:

\[
r_i
=
\frac{\|I_i-\hat I_i\|_2}{\|\hat I_i\|_2}.
\]

QC thresholds should be validated for the acquisition and study; a software
default is not automatically a clinical exclusion threshold.

### Representative pseudocode

```python
qc = {
    "mean_translation": mean(norm(motion[:, :3], axis=1)),
    "mean_rotation": mean(norm(motion[:, 3:], axis=1)),
    "outlier_fraction": outlier_slices / total_slices,
    "prediction_residual": norm(observed - predicted) / norm(predicted),
}
```

### Source

Cieslak et al., 2021 and the QSIPrep version-specific documentation and methods
boilerplate.

# QSIRecon and MRtrix mathematics, theory, and code

## YAML reconstruction specifications as executable graphs

### Beginner explanation

The YAML file is a written recipe. It says which program should run each step
and which earlier result it needs. QSIRecon converts that recipe into a
flowchart and runs steps only after their required inputs exist.

As with QSIPrep, a directed acyclic graph means arrows move forward without a
logical loop. The graph is QSIRecon's organizational innovation, while the
scientific algorithms inside the boxes may come from MRtrix, DIPY, or another
package.

### Theory

A QSIRecon specification is a declarative description of a directed acyclic
graph. Each node declares software, action, parameters, and upstream input. A
topological ordering guarantees that a node runs only after its dependencies.

### Representative YAML

```yaml
name: example_mrtrix_workflow
nodes:
  - name: estimate_fod
    software: MRTrix3
    action: csd
  - name: tractography
    software: MRTrix3
    action: tractography
    input: estimate_fod
```

Conceptual workflow-builder code:

```python
spec = load_yaml(path)
graph = DirectedAcyclicGraph()
for node_spec in spec["nodes"]:
    node = build_interface(node_spec["software"], node_spec["action"])
    graph.add(node)
    if "input" in node_spec:
        graph.connect(node_spec["input"], node)
assert graph.is_acyclic()
workflow = compile_to_nipype(graph)
```

### Source

QSIRecon documentation and Cieslak et al., 2021.

## Diffusion tensor model and FA, MD, AD, RD

### Beginner explanation

The tensor models water diffusion as a three-dimensional ellipsoid. Its three
eigenvalues describe diffusion along the ellipsoid's longest, middle, and
shortest axes.

- MD is the average of all three eigenvalues.
- AD is the largest eigenvalue.
- RD is the average of the other two.
- FA measures how unequal the three eigenvalues are: zero is sphere-like and
  values closer to one are more directionally elongated.

The signal equation says stronger diffusion weighting causes more signal loss
when the gradient points along a direction with greater estimated diffusion.
These values describe an MRI model and are not one-to-one measurements of
specific cell structures.

### Theory

The tensor model assumes Gaussian diffusion:

\[
\frac{S(b,g)}{S_0}
=
\exp\left(-b\,g^\top Dg\right).
\]

Taking logarithms gives a linearized fitting equation:

\[
\log\frac{S}{S_0}
=
-b\,g^\top Dg.
\]

After fitting the symmetric positive tensor \(D\), let its eigenvalues be
\(\lambda_1\ge\lambda_2\ge\lambda_3\).

Mean diffusivity:

\[
\mathrm{MD}
=
\frac{\lambda_1+\lambda_2+\lambda_3}{3}.
\]

Axial diffusivity:

\[
\mathrm{AD}=\lambda_1.
\]

Radial diffusivity:

\[
\mathrm{RD}
=
\frac{\lambda_2+\lambda_3}{2}.
\]

Fractional anisotropy:

\[
\mathrm{FA}
=
\sqrt{\frac{3}{2}}
\sqrt{
\frac{
(\lambda_1-\mathrm{MD})^2+
(\lambda_2-\mathrm{MD})^2+
(\lambda_3-\mathrm{MD})^2
}{
\lambda_1^2+\lambda_2^2+\lambda_3^2
}}.
\]

### Representative code

```bash
dwi2tensor dwi.mif tensor.mif
tensor2metric tensor.mif \
  -fa fa.mif \
  -adc md.mif \
  -ad ad.mif \
  -rd rd.mif
```

### Source

Basser, Mattiello, and LeBihan, 1994, with subsequent DTI literature.

## Response functions and constrained spherical deconvolution

### Beginner explanation

A voxel can contain fibers pointing in several directions. The measured signal
is a blurred mixture of those directions. A response function describes the
signal expected from one ideal fiber population. Deconvolution mathematically
removes that blur to estimate the fiber-orientation distribution.

The integral formula says the measured signal combines contributions from all
possible directions. In spherical harmonics, that difficult operation becomes
coefficient multiplication. The optimization finds an FOD that matches the
signal while preventing negative fiber amplitudes.

### Theory

The diffusion signal on a shell is modeled as the spherical convolution of a
single-fiber response \(R\) with a fiber-orientation distribution \(f\):

\[
S(g)
=
\int_{\mathbb S^2}
R(g\cdot n)f(n)\,dn.
\]

In the spherical-harmonic basis, convolution becomes coefficient-wise
multiplication:

\[
S_{lm}=R_l f_{lm}.
\]

Direct inversion is unstable. Constrained spherical deconvolution estimates
coefficients while penalizing negative FOD amplitudes:

\[
\hat f
=
\arg\min_f
\|Rf-S\|_2^2
\quad
\text{subject to }f(n)\ge0
\text{ over sampled directions}.
\]

### Representative code

```bash
dwi2response dhollander dwi.mif \
  wm_response.txt gm_response.txt csf_response.txt

dwi2fod msmt_csd dwi.mif \
  wm_response.txt wmfod.mif \
  gm_response.txt gm.mif \
  csf_response.txt csf.mif
```

### Sources

- Tournier, Calamante, and Connelly, 2007.
- Dhollander and colleagues for three-tissue response estimation.
- Tournier et al., 2019, MRtrix3.

## Single-shell three-tissue CSD

### Beginner explanation

Think of the voxel signal as paint mixed from three sources: directional white
matter, more isotropic gray matter, and very isotropic CSF. SS3T-CSD tries to
estimate how much of each source is present using one nonzero diffusion shell
plus b0 data.

The equation adds those three predicted signals. Because limited measurements
cannot uniquely determine every mixture, the method relies on response shapes,
nonnegativity, and iterative constraints. The answer is model-dependent.

### Theory

The signal is modeled as contributions from anisotropic white matter and
approximately isotropic gray matter and CSF:

\[
S
\approx
R_{\mathrm{WM}}*f_{\mathrm{WM}}
+c_{\mathrm{GM}}R_{\mathrm{GM}}
+c_{\mathrm{CSF}}R_{\mathrm{CSF}}.
\]

With only one nonzero shell, separating all three tissues is underdetermined
without constraints and iterative estimation. SS3T-CSD uses nonnegativity,
tissue response shapes, spatial information, and iterative strategies to
estimate plausible compartments.

### Representative workflow code

```bash
dwi2response dhollander dwi.mif wm.txt gm.txt csf.txt
# The exact SS3T operation depends on the MRtrix3Tissue/QSIRecon implementation.
ss3t_csd_beta1 dwi.mif wm.txt wmfod.mif gm.txt gm.mif csf.txt csf.mif
```

The command name and availability are version-dependent. The QSIRecon-generated
methods and logs are the authoritative record for a specific run.

### Source

Dhollander and Connelly's SS3T-CSD work and the version-specific
MRtrix3Tissue/QSIRecon documentation.

## Multi-tissue intensity normalization with `mtnormalise`

### Beginner explanation

Two parts of a scan may have different overall FOD amplitude because of smooth
scanner bias rather than biology. `mtnormalise` is like matching exposure across
a photograph while considering all tissue compartments together.

The formula says that, after removing a smooth bias field \(b(x)\), the combined
tissue signal should be near a common reference \(C\). It does not force every
individual tissue to be identical.

### Theory

Tissue compartment amplitudes are affected by a smooth multiplicative field
\(b(x)\). `mtnormalise` estimates that field so the summed tissue compartments
have a consistent reference amplitude:

\[
\sum_t c_t(x)\exp(-b(x))
\approx C
\]

within appropriate brain tissue, with \(b(x)\) constrained to be spatially
smooth. The production method uses robust fitting and outlier handling.

### Representative code

```bash
mtnormalise \
  wmfod.mif wmfod_norm.mif \
  gm.mif gm_norm.mif \
  csf.mif csf_norm.mif \
  -mask brain_mask.mif
```

### Source

Raffelt et al., 2017.

## HSVS five-tissue-type image

### Beginner explanation

The 5TT image is five aligned three-dimensional layers. At every location, the
layers describe how much the voxel resembles cortical gray matter, subcortical
gray matter, white matter, CSF, or pathology. ACT reads these layers as
anatomical traffic information.

The vector formula lists the five values at location \(x\). Their sum should
usually be close to one inside the modeled brain. Adding a lesion to the fifth
channel tells ACT that ordinary tissue rules are uncertain there.

### Theory

ACT uses a five-component tissue vector:

\[
\mathbf t(x)
=
\left[
t_{\mathrm{corticalGM}},
t_{\mathrm{subcorticalGM}},
t_{\mathrm{WM}},
t_{\mathrm{CSF}},
t_{\mathrm{pathology}}
\right].
\]

Values are nonnegative and are expected to form meaningful partial-volume
fractions, commonly satisfying approximately:

\[
\sum_{k=1}^{5}t_k(x)\approx1
\]

inside the modeled brain.

HSVS combines FreeSurfer surfaces with volumetric labels to preserve the
gray–white boundary while representing subcortical tissues and CSF.

### Representative code

```bash
5ttgen hsvs /subjects/sub-001 base_5tt.mif
5ttcheck base_5tt.mif
5tt2gmwmi base_5tt.mif gmwm_seed.mif
```

For lesion-aware ACT:

```bash
5ttedit base_5tt.mif lesion_aware_5tt.mif \
  -path lesion_in_5tt_space.mif
5ttcheck lesion_aware_5tt.mif
```

### Source

Smith et al., 2020, hybrid surface–volume segmentation, plus MRtrix3
documentation.

## Anatomically constrained tractography

### Beginner explanation

Diffusion tractography follows local direction estimates, but direction alone
can create biologically implausible paths. ACT adds traffic rules: streamlines
normally travel through white matter and should start or end at plausible tissue
boundaries rather than floating through CSF.

ACT is mainly a state machine rather than one equation. The pseudocode checks
the proposed next location, reads its 5TT tissue values, and decides whether to
continue, terminate, backtrack, or reject.

### Theory

ACT treats streamline propagation as a tissue-state process. A streamline is
accepted, continued, terminated, or rejected according to its current and
previous tissue compartments.

Conceptually:

```python
while streamline_is_active:
    direction = tractography_model.sample_direction(position)
    next_position = integrate(position, direction)
    tissue = five_tissue_image(next_position)

    if transition_is_anatomically_valid(previous_tissue, tissue):
        continue
    elif transition_is_valid_termination(previous_tissue, tissue):
        terminate_and_accept()
    else:
        reject_or_backtrack()
```

The pathological compartment tells ACT that standard tissue rules are
unreliable at those voxels. It is not an exclusion mask and does not prove that
a reconstructed trajectory represents a surviving axon.

### Representative code

```bash
tckgen wmfod.mif tracks.tck \
  -algorithm iFOD2 \
  -act five_tissue.mif \
  -backtrack \
  -crop_at_gmwmi \
  -seed_dynamic wmfod.mif \
  -select 10000000
```

### Source

Smith et al., 2012.

## iFOD2 probabilistic streamline integration

### Beginner explanation

At each step, several directions may be plausible. iFOD2 samples curved
candidate steps, gives greater preference to directions supported by the FOD,
and randomly selects among them. Repeating this from many seeds creates a
tractogram.

The path expression multiplies directional support along a proposed path
\(\gamma\). It is only a conceptual score: it does not mean the final number is
the biological probability that an axon exists.

### Theory

The FOD defines a directional probability-like density. First-order methods
sample a direction at the current point. iFOD2 evaluates candidate curved arcs
over a finite step, improving integration through high-curvature fields.

A conceptual path score is:

\[
P(\gamma\mid f)
\propto
\prod_s
f\left(\gamma(s),\dot\gamma(s)\right),
\]

subject to step-size, curvature, amplitude, mask, and ACT constraints. This is
not a calibrated posterior probability that a biological axon exists.

### Representative pseudocode

```python
position, direction = seed()
while valid:
    arcs = propose_candidate_arcs(position, direction, step_size, max_angle)
    scores = [integrated_fod_amplitude(arc, wmfod) for arc in arcs]
    arc = probabilistic_sample(arcs, scores)
    position, direction = advance_along(arc)
    apply_cutoff_length_mask_and_act_rules()
```

### Sources

Tournier and colleagues' iFOD2 work and Tournier et al., 2019, MRtrix3.

## SIFT2 streamline weighting

### Beginner explanation

A tractogram may contain too many streamlines in some places and too few in
others. SIFT2 gives each streamline a weight so the total weighted streamline
density better agrees with fiber density estimated from the diffusion signal.

In the formula, \(A\) records where each streamline travels, \(w\) contains the
unknown streamline weights, and \(d\) is the FOD-derived target. The method
chooses nonnegative weights that make \(Aw\) resemble \(d\). These weights are
not literal axon counts.

### Theory

Let \(A_{vs}\) describe how streamline \(s\) contributes to fixel or voxel
\(v\), and let \(d_v\) represent the FOD-derived fiber-density target. SIFT2
finds nonnegative streamline weights \(w_s\) so aggregate streamline density
matches the diffusion-derived target:

\[
\hat w
=
\arg\min_{w\ge0}
\|Aw-d\|_2^2
+\lambda R(w).
\]

The exact SIFT2 objective includes proportionality and regularization details.
The result is one coefficient per streamline. It improves correspondence
between tractogram density and the diffusion model but does not produce an
absolute axon count.

### Representative code

```bash
tcksift2 tracks.tck wmfod.mif sift2_weights.txt \
  -act five_tissue.mif \
  -out_mu sift2_mu.txt
```

### Source

Smith et al., 2015.

## Connectome construction with `tck2connectome`

### Beginner explanation

A connectome is like a city-to-city road matrix. Row \(i\) and column \(j\)
store the connection between brain regions \(i\) and \(j\).

- The count formula adds one for every streamline joining the two regions.
- The SIFT2 formula adds each streamline's SIFT2 weight instead.
- The mean-length formula adds streamline lengths and divides by the number of
  streamlines on that edge.

The indicator \(\mathbf 1[\cdot]\) equals one when a streamline has the required
endpoints and zero otherwise.

### Theory

Each accepted streamline is assigned endpoint labels \(i(s)\) and \(j(s)\).
The count matrix is:

\[
W_{ij}^{\mathrm{count}}
=
\sum_s
\mathbf 1[i(s)=i,j(s)=j].
\]

The SIFT2 matrix is:

\[
W_{ij}^{\mathrm{SIFT2}}
=
\sum_s
w_s\mathbf 1[i(s)=i,j(s)=j].
\]

Mean streamline length is:

\[
\bar \ell_{ij}
=
\frac{
\sum_s\ell_s\mathbf 1[i(s)=i,j(s)=j]
}{
\sum_s\mathbf 1[i(s)=i,j(s)=j]
}.
\]

Endpoint radial search, reverse search, assignment to parcels, symmetry, and
diagonal handling affect the result and must be reported.

### Representative code

```bash
tck2connectome tracks.tck nodes.mif count.csv \
  -symmetric -zero_diagonal

tck2connectome tracks.tck nodes.mif sift2.csv \
  -tck_weights_in sift2_weights.txt \
  -symmetric -zero_diagonal

tck2connectome tracks.tck nodes.mif mean_length.csv \
  -scale_length -stat_edge mean \
  -symmetric -zero_diagonal
```

### Source

MRtrix3 and structural-connectome methodology described by Smith and
colleagues; report the exact MRtrix options.

## Sampling scalar maps along streamlines

### Beginner explanation

Imagine laying a path across a temperature map and recording the temperature at
regular points. `tcksample` does the same with FA, MD, or another MRI map along
each streamline.

The integral formula adds scalar \(q\) along path \(\gamma_s\) and divides by
path length \(L_s\), producing the streamline's mean value. Interpolation is
needed because sample points rarely fall exactly at voxel centers.

### Theory

For scalar image \(q(x)\) and streamline path \(\gamma_s(u)\), a mean
streamline scalar is:

\[
\bar q_s
=
\frac{1}{L_s}
\int_0^{L_s}
q(\gamma_s(u))\,du.
\]

Discrete implementation samples interpolated values at points along each
streamline and applies a statistic such as mean, median, minimum, or maximum.

### Representative code

```bash
tcksample tracks.tck fa.mif streamline_mean_fa.txt \
  -stat_tck mean
```

Edge-level MeanFA can then be computed by grouping streamline values according
to their endpoint parcels. Weighting by SIFT2 coefficients and unweighted
averaging answer different questions and must be specified.

### Source

MRtrix3 documentation and Tournier et al., 2019.

## Atlas transformations and node assignment

### Beginner explanation

The atlas and tractography must occupy the same physical grid before streamline
endpoints can be assigned to regions. Transforming a label image is like moving
a colored map onto new graph paper.

The formula uses the inverse transform to ask which source label belongs at
each target location. Nearest-neighbor interpolation is used because averaging
label numbers could invent a region that does not exist.

### Theory

Labels must be resampled with nearest-neighbor or label-aware interpolation:

\[
L_{\mathrm{target}}(x)
=
L_{\mathrm{source}}\left(\phi^{-1}(x)\right).
\]

Unlike continuous images, averaging labels is invalid because an interpolated
number may not correspond to a real region.

### Representative code

```bash
antsApplyTransforms \
  -d 3 \
  -i dkt_labels.nii.gz \
  -r dwiref.nii.gz \
  -o dkt_in_dwi.nii.gz \
  -n NearestNeighbor \
  -t anatomical_to_dwi_transform.mat

labelconvert dkt_in_dwi.nii.gz \
  FreeSurferColorLUT.txt fs_dkt.txt nodes.mif
```

### Source

Standard label-resampling theory, ANTs/NiTransforms, FreeSurfer atlas products,
and MRtrix3 `labelconvert`.

## Alternative models available through QSIRecon

### Diffusion kurtosis imaging

At a beginner level, the diffusion tensor assumes water displacement is
Gaussian, similar to a smooth bell-shaped distribution. Real tissue often
deviates from that shape because membranes and cellular structures restrict
water. DKI adds \(K_{\mathrm{app}}\), an apparent kurtosis term describing the
size of that deviation. The \(b^2\) term means kurtosis becomes more visible at
higher diffusion weighting. It remains a model-based, nonspecific measurement.

DKI extends the logarithmic signal expansion:

\[
\log\frac{S}{S_0}
\approx
-bD_{\mathrm{app}}
+\frac{1}{6}b^2D_{\mathrm{app}}^2K_{\mathrm{app}}.
\]

It estimates non-Gaussian diffusion through apparent kurtosis. Source: Jensen
et al., 2005.

### Generalized q-sampling imaging

At a beginner level, GQI uses the mathematical relationship between q-space
measurements and likely water-displacement directions. Instead of forcing the
signal into a tensor ellipsoid, it can represent several directional peaks in
one voxel. Quantitative anisotropy describes the prominence of an individual
directional peak, but it is not a count of fibers.

GQI estimates orientation-dependent information from the relationship between
q-space measurements and the displacement distribution using a Fourier-based
transform. Quantitative anisotropy reflects peak-specific spin displacement
information. Source: Yeh et al., 2010.

### NODDI

At a beginner level, NODDI treats a voxel as a mixture of three signal sources:
water modeled as being inside neurites, water outside neurites, and freely
diffusing isotropic water. In the formula, \(v_{\mathrm{ic}}\) controls the
intracellular-like fraction and \(v_{\mathrm{iso}}\) controls the free-water
fraction. The remaining fraction belongs to the extracellular-like model.
These compartments are useful model interpretations, not direct microscopic
measurements.

A simplified NODDI signal mixture is:

\[
S
=
(1-v_{\mathrm{iso}})
\left[
v_{\mathrm{ic}}S_{\mathrm{ic}}
+(1-v_{\mathrm{ic}})S_{\mathrm{ec}}
\right]
+v_{\mathrm{iso}}S_{\mathrm{iso}}.
\]

The model estimates intracellular fraction, orientation dispersion, and
isotropic fraction under strong biological assumptions. Source: Zhang et al.,
2012. AMICO provides accelerated optimization.

### MAP-MRI

At a beginner level, MAP-MRI builds the measured q-space signal from a set of
mathematical building blocks. Because each block has a known Fourier-transform
partner, the same fitted coefficients can describe a three-dimensional
water-displacement distribution. In the formulas, \(E(q)\) is measured signal,
\(P(r)\) is the estimated displacement distribution, and \(c_n\) controls how
much of each basis pattern is used.

MAP-MRI expands the q-space signal in a basis whose Fourier transform provides
an analytical displacement propagator:

\[
E(q)=\sum_n c_n\Phi_n(q),
\qquad
P(r)=\sum_n c_n\Psi_n(r).
\]

Derived measures summarize return probabilities and non-Gaussian displacement.
Source: Özarslan et al., 2013.

### QSIRecon's role

QSIRecon does not replace the mathematics in these publications. Its code
selects the appropriate interface, passes standardized QSIPrep derivatives,
connects outputs to mapping or tractometry nodes, and writes reproducible
derivatives and provenance.

## End-to-end code sketch for our pipeline

The following illustrates the scientific dependencies; it is not a replacement
for the production workflow:

```bash
# Preprocessing is performed by QSIPrep.
qsiprep /bids /derivatives participant \
  --participant-label 001 \
  --output-resolution 2

# Anatomical reconstruction uses the inpainted T1w.
recon-all -all -s sub-001 -i inpainted_T1w.nii.gz

# QSIRecon estimates FODs and runs standard ACT.
qsirecon /derivatives/qsiprep /derivatives/qsirecon participant \
  --input-type qsiprep \
  --recon-spec mrtrix_singleshell_ss3t_ACT-hsvs \
  --fs-subjects-dir /subjects

# Proposed lesion-aware branch.
antsApplyTransforms \
  -i lesion_native_T1w.nii.gz \
  -r base_5tt_reference.nii.gz \
  -o lesion_in_5tt_space.nii.gz \
  -n NearestNeighbor \
  -t lesion_to_5tt_transforms

5ttedit base_5tt.mif lesion_aware_5tt.mif \
  -path lesion_in_5tt_space.nii.gz

tckgen wmfod.mif lesion_aware_tracks.tck \
  -algorithm iFOD2 \
  -act lesion_aware_5tt.mif \
  -seed_dynamic wmfod.mif \
  -select 10000000

tcksift2 lesion_aware_tracks.tck wmfod.mif lesion_aware_weights.txt \
  -act lesion_aware_5tt.mif

tck2connectome lesion_aware_tracks.tck dkt_nodes.mif dkt_sift2.csv \
  -tck_weights_in lesion_aware_weights.txt \
  -symmetric -zero_diagonal
```

The actual implementation must reproduce QSIRecon's tractography parameters,
coordinate grids, transform chain, random seed policy, and provenance exactly
for a valid paired standard-versus-lesion-aware comparison.

<!-- BEGIN GENERATED PAPER SUMMARIES -->
# Beginner summaries of every cited paper or conference method

Each summary answers four questions: What problem did the work address? What was its central method? What is the key idea? Why is it relevant here? Conference abstracts are identified as such; they should not be described as full journal validation papers.

## Reference 1: Dale, Fischl, and Sereno (1999), cortical surface reconstruction

- Problem: convert volumetric MRI into an accurate cortical surface.
- Key idea: segment white matter, tessellate its boundary, and deform a mesh toward anatomical boundaries while preserving geometry.
- Why it matters here: it is the foundation of the white and pial surfaces used by FreeSurfer and the DKT atlas.

## Reference 2: Fischl, Sereno, and Dale (1999), inflation and surface coordinates

- Problem: compare highly folded cortices across people.
- Key idea: inflate and map cortex to a sphere while tracking geometric distortion, creating a surface coordinate system for registration.
- Why it matters here: cortical atlas labels are transferred through surface registration.

## Reference 3: Fischl and Dale (2000), cortical thickness

- Problem: estimate cortical thickness without relying on slice orientation.
- Key idea: reconstruct white and pial surfaces and use symmetric distances between them.
- Why it matters here: it explains FreeSurfer thickness outputs, although thickness is not the primary connectome edge measure.

## Reference 4: Fischl, Liu, and Dale (2001), automated manifold surgery

- Problem: MRI-derived meshes can contain holes or handles that violate cortical topology.
- Key idea: automatically correct mesh topology while minimizing changes to the measured anatomy.
- Why it matters here: valid spherical registration requires a topologically correct cortical surface.

## Reference 5: Fischl et al. (2002), whole-brain segmentation

- Problem: label subcortical and other brain structures automatically.
- Key idea: combine atlas location, tissue intensity, and neighborhood relationships in a probabilistic classifier.
- Why it matters here: `aseg` labels contribute subcortical DKT nodes and HSVS tissue construction.

## Reference 6: Fischl et al. (2004), automatic cortical parcellation

- Problem: assign reproducible cortical region names to an individual surface.
- Key idea: use probabilistic folding-pattern information on the spherical surface rather than relying only on Euclidean location.
- Why it matters here: this is the basis for automated surface annotation workflows.

## Reference 7: Ségonne et al. (2004), hybrid watershed skull stripping

- Problem: separate brain from skull and surrounding tissue reliably.
- Key idea: combine watershed initialization with a deformable surface and atlas information.
- Why it matters here: brain extraction errors can propagate through all FreeSurfer stages.

## Reference 8: Reuter, Rosas, and Fischl (2010), robust inverse-consistent registration

- Problem: ordinary registration can be biased by outliers and by choosing one image direction.
- Key idea: robust statistics and inverse consistency reduce outlier influence and forward/reverse asymmetry.
- Why it matters here: it supports stable alignment of repeated anatomical scans.

## Reference 9: Reuter et al. (2012), unbiased longitudinal templates

- Problem: measuring change is biased when one visit is treated as the fixed reference.
- Key idea: build an unbiased within-subject template and initialize every visit from it.
- Why it matters here: it is the correct conceptual model for future longitudinal TBI analyses.

## Reference 10: Sled, Zijdenbos, and Evans (1998), N3

- Problem: scanner sensitivity creates smooth brightness variation unrelated to tissue.
- Key idea: estimate a smooth multiplicative field by sharpening the tissue-intensity distribution.
- Why it matters here: intensity normalization improves atlas registration and segmentation.

## Reference 11: Cieslak et al. (2021), QSIPrep

- Problem: diffusion preprocessing differed across acquisition schemes and laboratories.
- Key idea: use BIDS metadata to build adaptive, tested workflows and introduce SHORELine for general q-space motion correction.
- Why it matters here: QSIPrep supplies standardized DWI, gradients, transforms, QC, and lesion-masked normalization.

## Reference 12: Gorgolewski et al. (2011), Nipype

- Problem: neuroimaging scripts were difficult to reproduce and parallelize.
- Key idea: represent processing as connected interfaces in an executable workflow graph.
- Why it matters here: QSIPrep and QSIRecon use Nipype-style graphs to connect tools and track inputs and outputs.

## Reference 13: Gorgolewski et al. (2016), BIDS

- Problem: neuroimaging datasets used inconsistent names and metadata layouts.
- Key idea: define a community standard for folders, filenames, entities, and sidecar metadata.
- Why it matters here: BIDS enables automatic discovery of DWI, fieldmaps, T1w images, and lesion ROIs.

## Reference 14: Esteban et al. (2019), fMRIPrep

- Problem: fMRI preprocessing choices were inconsistent and difficult to audit.
- Key idea: create a robust BIDS App with adaptive workflows, visual reports, provenance, and methods text.
- Why it matters here: QSIPrep adapted important workflow patterns and infrastructure from fMRIPrep/niworkflows.

## Reference 15: Tournier et al. (2019), MRtrix3

- Problem: diffusion analysis needed a flexible, efficient, interoperable software framework.
- Key idea: provide optimized image operations, CSD, tractography, ACT, SIFT, and connectome tools in one framework.
- Why it matters here: most QSIRecon reconstruction and DKT connectome operations are MRtrix3 commands.

## Reference 16: Smith et al. (2012), ACT

- Problem: diffusion directions alone permit streamlines to start, stop, or travel in anatomically implausible places.
- Key idea: use a five-tissue anatomical image as state rules for propagation and termination.
- Why it matters here: standard and proposed lesion-aware tractography both rely on ACT.

## Reference 17: Smith et al. (2015), SIFT2

- Problem: raw streamline density does not quantitatively match the FOD-derived fiber-density signal.
- Key idea: assign each streamline a nonnegative weight so weighted tractogram density better matches diffusion information.
- Why it matters here: SIFT2 provides an alternative edge weighting, not an absolute axon count.

## Reference 18: Avants et al. (2011), ANTs registration evaluation

- Problem: nonlinear registration methods require reproducible implementation and objective comparison.
- Key idea: evaluate ANTs transformations and similarity metrics across brain-registration tasks.
- Why it matters here: ANTs aligns anatomical, lesion, atlas, and diffusion-space products.

## Reference 19: Tustison et al. (2010), N4

- Problem: N3 bias correction could be improved in convergence and B-spline field estimation.
- Key idea: reformulate and optimize nonparametric bias correction with a smooth B-spline field.
- Why it matters here: QSIPrep uses N4 for anatomical intensity correction.

## Reference 20: Brett et al. (2001), lesion cost-function masking

- Problem: abnormal lesion intensity can pull spatial normalization toward the wrong solution.
- Key idea: exclude lesion voxels from the registration fitting score while still transforming the full image.
- Why it matters here: QSIPrep automatically uses a correctly named BIDS lesion ROI for T1w normalization.

## Reference 21: Veraart et al. (2016), MP-PCA denoising

- Problem: diffusion MRI noise reduces precision and biases derived models.
- Key idea: use random-matrix theory to distinguish locally redundant signal components from noise components.
- Why it matters here: `dwidenoise` improves signal before interpolation and model fitting.

## Reference 22: Kellner et al. (2016), Gibbs-ringing removal

- Problem: finite Fourier sampling creates oscillating bands near sharp boundaries.
- Key idea: search local subvoxel shifts for a reconstruction with lower ringing-related variation.
- Why it matters here: `mrdegibbs` reduces a structured artifact without ordinary broad smoothing.

## Reference 23: Andersson, Skare, and Ashburner (2003), reversed-PE correction

- Problem: susceptibility distorts EPI images along phase encoding.
- Key idea: estimate one smooth off-resonance field from images distorted in opposite directions.
- Why it matters here: this is the basis of FSL `topup` used when paired data are available.

## Reference 24: Andersson and Sotiropoulos (2016), integrated eddy correction

- Problem: motion, eddy currents, susceptibility, and slice outliers interact in diffusion MRI.
- Key idea: use diffusion-informed predictions to jointly estimate distortions, movement, and outlier replacement.
- Why it matters here: corrected images and rotated b-vectors are central QSIPrep outputs.

## Reference 25: Özarslan et al. (2009), 3dSHORE conference report

- Problem: represent arbitrary three-dimensional q-space measurements analytically.
- Key idea: expand signal in a simple-harmonic-oscillator basis with constraints supporting a valid propagator.
- Why it matters here: 3dSHORE supplies the signal-prediction theory used by SHORELine.

## Reference 26: Hoopes et al. (2022), SynthStrip

- Problem: traditional skull stripping often fails across modalities and pathology.
- Key idea: train a contrast-agnostic neural network using synthetic data and broad augmentation.
- Why it matters here: newer QSIPrep anatomical workflows can obtain robust brain masks from varied images.

## Reference 27: Billot et al. (2023), SynthSeg

- Problem: segmentation networks usually depend on a narrow image contrast and resolution.
- Key idea: train almost entirely on synthetic images with randomized contrast and anatomy to generalize without retraining.
- Why it matters here: QSIPrep can obtain robust anatomical labels across acquisition types.

## Reference 28: Basser, Mattiello, and LeBihan (1994), diffusion tensor imaging

- Problem: characterize direction-dependent water diffusion in three dimensions.
- Key idea: represent diffusion with a symmetric tensor and derive its eigenvalues and directions.
- Why it matters here: FA, MD, AD, and RD are all derived from this model.

## Reference 29: Tournier, Calamante, and Connelly (2007), constrained spherical deconvolution

- Problem: one voxel may contain multiple fiber directions that a tensor cannot separate.
- Key idea: deconvolve a single-fiber response from measured signal while enforcing a nonnegative FOD.
- Why it matters here: CSD generates the directional model followed by iFOD2 tractography.

## Reference 30: Raffelt et al. (2017), multi-tissue normalization conference report

- Problem: FOD amplitudes contain smooth scanner bias and arbitrary global scaling.
- Key idea: use the sum of tissue compartments to estimate bias and intensity scaling.
- Why it matters here: `mtnormalise` makes tissue amplitudes more comparable; current code adds log-domain fitting and outlier rejection.

## Reference 31: Smith et al. (2012), ACT duplicate methodological citation

- This is the same core ACT publication summarized under reference 16.
- Key idea: anatomical tissue states constrain streamline propagation and termination.
- Why it matters here: it is cited again where ACT implementation details are discussed.

## Reference 32: Smith et al. (2015), SIFT2 duplicate methodological citation

- This is the same SIFT2 publication summarized under reference 17.
- Key idea: optimize per-streamline weights against FOD-derived density.
- Why it matters here: it is cited again in the mathematical implementation section.

## Reference 33: Smith et al. (2020), HSVS conference report

- Problem: intensity-only 5TT segmentation can misplace tissue interfaces used by ACT.
- Key idea: combine surface reconstructions and volumetric segmentations in one five-tissue image.
- Why it matters here: the QSIRecon `ACT-hsvs` workflow uses this anatomical representation.

## Reference 34: Jensen et al. (2005), diffusion kurtosis imaging

- Problem: biological diffusion often deviates from the Gaussian tensor assumption.
- Key idea: add a kurtosis term to quantify non-Gaussian signal behavior.
- Why it matters here: QSIRecon can generate DKI measures when acquisition supports the model.

## Reference 35: Yeh, Wedeen, and Tseng (2010), GQI

- Problem: infer multiple diffusion directions without forcing a Gaussian tensor model.
- Key idea: use the Fourier relationship between q-space signal and spin-displacement information to estimate orientation distributions.
- Why it matters here: DSI Studio reconstruction specifications can use GQI and quantitative anisotropy.

## Reference 36: Zhang et al. (2012), NODDI

- Problem: obtain interpretable indices of neurite density and orientation dispersion from clinically feasible data.
- Key idea: fit a multi-compartment signal model for intracellular-like, extracellular-like, and isotropic water.
- Why it matters here: QSIRecon can call AMICO/NODDI, but its parameters remain model-dependent rather than direct histology.

## Reference 37: Özarslan et al. (2013), MAP-MRI

- Problem: describe complex three-dimensional water displacement without a simple Gaussian assumption.
- Key idea: use paired q-space and propagator basis functions to estimate displacement and return-probability measures.
- Why it matters here: QSIRecon can integrate MAP-MRI implementations for advanced microstructure analysis.

## Reference 38: Klein and Tourville (2012), DKT labeling protocol

- Problem: cortical atlas protocols and manually labeled training sets were inconsistent.
- Key idea: create 101 consistently labeled brains and a clarified cortical labeling protocol.
- Why it matters here: DKT defines the cortical nodes used by the primary connectome.

<!-- END GENERATED PAPER SUMMARIES -->

<!-- BEGIN GENERATED CODE WALKTHROUGHS -->
# Beginner line-by-line code walkthroughs

This appendix explains every executable Bash, Python/pseudocode, and YAML line shown above. Lines ending in `\` continue the same shell command; they are not separate programs. Python blocks labeled as conceptual pseudocode illustrate logic and are not guaranteed to run unchanged.

## Walkthrough 1: Image conversion and conformation with `mri_convert`

Language: `bash`.

1. `mri_convert input_T1w.nii.gz orig.mgz` — Runs FreeSurfer image conversion or grid conformation.
2. `mri_convert --conform input_T1w.nii.gz conformed.mgz` — Runs FreeSurfer image conversion or grid conformation.

## Walkthrough 2: Image conversion and conformation with `mri_convert`

Language: `python`.

1. `for target_voxel in target_grid:` — Starts a loop that performs the indented steps once for every listed item.
2. `target_world = target_affine @ target_voxel` — Calculates or retrieves the variable `target_world` and stores it under the name `target_world`. The right side, `target_affine @ target_voxel`, describes how it is obtained.
3. `source_voxel = inverse(source_affine) @ target_world` — Calculates or retrieves the variable `source_voxel` and stores it under the name `source_voxel`. The right side, `inverse(source_affine) @ target_world`, describes how it is obtained.
4. `output[target_voxel] = interpolate(input, source_voxel)` — Updates this selected output entry with the newly calculated value.

## Walkthrough 3: Robust template estimation with `mri_robust_template`

Language: `bash`.

1. `mri_robust_template \` — Builds an unbiased template from repeated anatomical scans. The trailing backslash continues the same command on the next line.
2. `--mov time1.mgz time2.mgz \` — The `--mov` option lists the moving input scans that will be combined. The trailing backslash continues the same command.
3. `--template subject_template.mgz \` — The `--template` option names the output template image. The trailing backslash continues the same command.
4. `--lta time1_to_template.lta time2_to_template.lta \` — The `--lta` option names the output transforms from each scan to the template. The trailing backslash continues the same command.
5. `--satit` — The `--satit` option enables robust iterative template estimation.

## Walkthrough 4: Robust template estimation with `mri_robust_template`

Language: `python`.

1. `template = robust_average(images)` — Calculates or retrieves the current shared anatomical estimate and stores it under the name `template`. The right side, `robust_average(images)`, describes how it is obtained.
2. `repeat:` — Conceptual loop marker: repeat the preceding operations until changes become small or the stated stopping rule is met.
3. `transforms = [robust_register(image, template) for image in images]` — Calculates or retrieves the spatial alignments and stores it under the name `transforms`. The right side, `[robust_register(image, template) for image in images]`, describes how it is obtained.
4. `aligned = [resample(image, transform) for image, transform in pairs]` — Calculates or retrieves the input scans resampled into template space and stores it under the name `aligned`. The right side, `[resample(image, transform) for image, transform in pairs]`, describes how it is obtained.
5. `template = robust_weighted_average(aligned)` — Calculates or retrieves the current shared anatomical estimate and stores it under the name `template`. The right side, `robust_weighted_average(aligned)`, describes how it is obtained.
6. `until convergence` — Conceptual loop marker: repeat the preceding operations until changes become small or the stated stopping rule is met.

## Walkthrough 5: N3 bias correction with `mri_nu_correct.mni`

Language: `bash`.

1. `mri_nu_correct.mni --i orig.mgz --o nu.mgz --n 1` — Runs N3-based correction of smooth intensity shading.

## Walkthrough 6: N3 bias correction with `mri_nu_correct.mni`

Language: `python`.

1. `log_image = log(image)` — Calculates or retrieves the logarithm of image intensity and stores it under the name `log_image`. The right side, `log(image)`, describes how it is obtained.
2. `bias = zeros_like(image)` — Calculates or retrieves the smooth estimated intensity bias and stores it under the name `bias`. The right side, `zeros_like(image)`, describes how it is obtained.
3. `repeat:` — Conceptual loop marker: repeat the preceding operations until changes become small or the stated stopping rule is met.
4. `corrected = log_image - bias` — Calculates or retrieves the current corrected image and stores it under the name `corrected`. The right side, `log_image - bias`, describes how it is obtained.
5. `residual_low_frequency = estimate_smooth_bias(corrected)` — Calculates or retrieves the variable `residual_low_frequency` and stores it under the name `residual_low_frequency`. The right side, `estimate_smooth_bias(corrected)`, describes how it is obtained.
6. `bias += residual_low_frequency` — Represents the stated conceptual processing step; production software expands it into validated library operations.
7. `until histogram_sharpness_stabilizes` — Conceptual loop marker: repeat the preceding operations until changes become small or the stated stopping rule is met.
8. `output = exp(log_image - bias)` — Calculates or retrieves the result being built and stores it under the name `output`. The right side, `exp(log_image - bias)`, describes how it is obtained.

## Walkthrough 7: Affine atlas alignment with `talairach_avi`

Language: `bash`.

1. `talairach_avi --i orig.mgz --xfm transforms/talairach.auto.xfm` — Estimates an initial affine alignment to Talairach atlas space.

## Walkthrough 8: Affine atlas alignment with `talairach_avi`

Language: `python`.

1. `A = identity_affine()` — Calculates or retrieves an affine transformation and stores it under the name `A`. The right side, `identity_affine()`, describes how it is obtained.
2. `repeat:` — Conceptual loop marker: repeat the preceding operations until changes become small or the stated stopping rule is met.
3. `moved = resample(subject, A, atlas_grid)` — Calculates or retrieves the variable `moved` and stores it under the name `moved`. The right side, `resample(subject, A, atlas_grid)`, describes how it is obtained.
4. `score = atlas_similarity(moved, atlas)` — Calculates or retrieves the quality score for each candidate and stores it under the name `score`. The right side, `atlas_similarity(moved, atlas)`, describes how it is obtained.
5. `A = optimizer_update(A, score)` — Calculates or retrieves an affine transformation and stores it under the name `A`. The right side, `optimizer_update(A, score)`, describes how it is obtained.
6. `until convergence` — Conceptual loop marker: repeat the preceding operations until changes become small or the stated stopping rule is met.

## Walkthrough 9: Hybrid skull stripping with `mri_watershed`

Language: `bash`.

1. `mri_watershed -atlas T1.mgz brainmask.mgz` — Creates a brain mask using hybrid watershed skull stripping.

## Walkthrough 10: Hybrid skull stripping with `mri_watershed`

Language: `python`.

1. `initial_mask = watershed_flood(intensity_topography, seeds)` — Calculates or retrieves the initial brain-mask estimate and stores it under the name `initial_mask`. The right side, `watershed_flood(intensity_topography, seeds)`, describes how it is obtained.
2. `surface = mesh_from_mask(initial_mask)` — Calculates or retrieves the current surface mesh and stores it under the name `surface`. The right side, `mesh_from_mask(initial_mask)`, describes how it is obtained.
3. `repeat:` — Conceptual loop marker: repeat the preceding operations until changes become small or the stated stopping rule is met.
4. `force = boundary_force(image, surface)` — Calculates or retrieves the variable `force` and stores it under the name `force`. The right side, `boundary_force(image, surface)`, describes how it is obtained.
5. `force += smoothness_force(surface)` — Calls `force += smoothness_force` to perform the named conceptual operation using the values inside parentheses.
6. `force += atlas_or_shape_force(surface)` — Calls `force += atlas_or_shape_force` to perform the named conceptual operation using the values inside parentheses.
7. `surface = deform(surface, force)` — Calculates or retrieves the current surface mesh and stores it under the name `surface`. The right side, `deform(surface, force)`, describes how it is obtained.
8. `until stable` — Conceptual loop marker: repeat the preceding operations until changes become small or the stated stopping rule is met.
9. `brain_mask = rasterize(surface)` — Calculates or retrieves the predicted brain-only mask and stores it under the name `brain_mask`. The right side, `rasterize(surface)`, describes how it is obtained.

## Walkthrough 11: Probabilistic atlas registration with `mri_em_register`

Language: `bash`.

1. `mri_em_register nu.mgz atlas.gca transforms/talairach.lta` — Linearly aligns the image with a probabilistic anatomical atlas.

## Walkthrough 12: Probabilistic atlas registration with `mri_em_register`

Language: `python`.

1. `A = initial_affine` — Calculates or retrieves an affine transformation and stores it under the name `A`. The right side, `initial_affine`, describes how it is obtained.
2. `repeat:` — Conceptual loop marker: repeat the preceding operations until changes become small or the stated stopping rule is met.
3. `posteriors = class_posterior(image, atlas_priors, A)` — Calculates or retrieves the current probabilities of possible tissue labels and stores it under the name `posteriors`. The right side, `class_posterior(image, atlas_priors, A)`, describes how it is obtained.
4. `A = maximize_expected_atlas_likelihood(image, atlas, posteriors)` — Calculates or retrieves an affine transformation and stores it under the name `A`. The right side, `maximize_expected_atlas_likelihood(image, atlas, posteriors)`, describes how it is obtained.
5. `until convergence` — Conceptual loop marker: repeat the preceding operations until changes become small or the stated stopping rule is met.

## Walkthrough 13: `mri_ca_normalize`: atlas-guided intensity normalization

Language: `bash`.

1. `mri_ca_normalize \` — Normalizes image brightness using atlas and control-point information. The trailing backslash continues the same command on the next line.
2. `-c ctrl_pts.mgz \` — The `-c` option provides control points. The trailing backslash continues the same command.
3. `nu.mgz atlas.gca transforms/talairach.lta norm.mgz` — Supplies an input, output, or positional file required by the command; its exact role follows the command syntax above.

## Walkthrough 14: `mri_ca_normalize`: atlas-guided intensity normalization

Language: `python`.

1. `repeat:` — Conceptual loop marker: repeat the preceding operations until changes become small or the stated stopping rule is met.
2. `likely_tissues = classify_using_atlas(image, transform)` — Calculates or retrieves the variable `likely_tissues` and stores it under the name `likely_tissues`. The right side, `classify_using_atlas(image, transform)`, describes how it is obtained.
3. `control_points = select_reliable_white_matter(likely_tissues)` — Calculates or retrieves the variable `control_points` and stores it under the name `control_points`. The right side, `select_reliable_white_matter(likely_tissues)`, describes how it is obtained.
4. `correction = fit_smooth_intensity_field(image, control_points)` — Calculates or retrieves the variable `correction` and stores it under the name `correction`. The right side, `fit_smooth_intensity_field(image, control_points)`, describes how it is obtained.
5. `image = apply(correction, image)` — Calculates or retrieves the variable `image` and stores it under the name `image`. The right side, `apply(correction, image)`, describes how it is obtained.
6. `until white_matter_target_is_stable` — Conceptual loop marker: repeat the preceding operations until changes become small or the stated stopping rule is met.

## Walkthrough 15: `mri_ca_register`: nonlinear atlas registration

Language: `bash`.

1. `mri_ca_register \` — Computes nonlinear alignment to the classifier atlas. The trailing backslash continues the same command on the next line.
2. `-align-after \` — The `-align-after` option requests an additional alignment refinement. The trailing backslash continues the same command.
3. `norm.mgz atlas.gca transforms/talairach.lta transforms/talairach.m3z` — Continues the shell command with the shown positional file or setting.

## Walkthrough 16: `mri_ca_register`: nonlinear atlas registration

Language: `python`.

1. `phi = affine_initialization` — Calculates or retrieves a nonlinear transformation and stores it under the name `phi`. The right side, `affine_initialization`, describes how it is obtained.
2. `for resolution in coarse_to_fine:` — Starts a loop that performs the indented steps once for every listed item.
3. `repeat:` — Conceptual loop marker: repeat the preceding operations until changes become small or the stated stopping rule is met.
4. `likelihood_gradient = atlas_likelihood_gradient(image, atlas, phi)` — Calculates or retrieves the variable `likelihood_gradient` and stores it under the name `likelihood_gradient`. The right side, `atlas_likelihood_gradient(image, atlas, phi)`, describes how it is obtained.
5. `regularization_gradient = deformation_penalty_gradient(phi)` — Calculates or retrieves the variable `regularization_gradient` and stores it under the name `regularization_gradient`. The right side, `deformation_penalty_gradient(phi)`, describes how it is obtained.
6. `phi = update(phi, likelihood_gradient, regularization_gradient)` — Calculates or retrieves a nonlinear transformation and stores it under the name `phi`. The right side, `update(phi, likelihood_gradient, regularization_gradient)`, describes how it is obtained.
7. `until convergence` — Conceptual loop marker: repeat the preceding operations until changes become small or the stated stopping rule is met.

## Walkthrough 17: `mri_ca_label`: Bayesian anatomical labeling

Language: `bash`.

1. `mri_ca_label \` — Assigns probabilistic anatomical labels to voxels. The trailing backslash continues the same command on the next line.
2. `norm.mgz transforms/talairach.m3z atlas.gca aseg.auto.mgz` — Supplies an input, output, or positional file required by the command; its exact role follows the command syntax above.

## Walkthrough 18: `mri_ca_label`: Bayesian anatomical labeling

Language: `python`.

1. `for voxel in brain:` — Starts a loop that performs the indented steps once for every listed item.
2. `for label in candidate_labels:` — Starts a loop that performs the indented steps once for every listed item.
3. `score[label] = intensity_likelihood(label)` — Calls `score[label] = intensity_likelihood` to perform the named conceptual operation using the values inside parentheses.
4. `score[label] *= atlas_prior(label, transformed_position)` — Calls `score[label] *= atlas_prior` to perform the named conceptual operation using the values inside parentheses.
5. `score[label] *= neighborhood_compatibility(label, neighbors)` — Calls `score[label] *= neighborhood_compatibility` to perform the named conceptual operation using the values inside parentheses.
6. `output[voxel] = argmax(score)` — Updates this selected output entry with the newly calculated value.

## Walkthrough 19: Surface reconstruction with `mris_make_surfaces`

Language: `bash`.

1. `mris_make_surfaces -noaparc sub-001 lh` — Constructs or adjusts a cortical surface mesh.
2. `mris_sphere sub-001/surf/lh.inflated sub-001/surf/lh.sphere` — Inflates and maps a cortical surface to a sphere.
3. `mris_register sub-001/surf/lh.sphere atlas.sphere.reg \` — Aligns a spherical cortical surface with a spherical atlas. The trailing backslash continues the same command on the next line.
4. `sub-001/surf/lh.sphere.reg` — Continues the shell command with the shown positional file or setting.
5. `mris_ca_label sub-001 lh sphere.reg classifier.gcs lh.aparc.annot` — Assigns atlas labels to cortical surface vertices.

## Walkthrough 20: Surface reconstruction with `mris_make_surfaces`

Language: `python`.

1. `white = initialize_mesh(white_matter_segmentation)` — Calculates or retrieves the white-matter cortical surface and stores it under the name `white`. The right side, `initialize_mesh(white_matter_segmentation)`, describes how it is obtained.
2. `white = deform_to_intensity_boundary(white, t1_image, smoothness=True)` — Calculates or retrieves the white-matter cortical surface and stores it under the name `white`. The right side, `deform_to_intensity_boundary(white, t1_image, smoothness=True)`, describes how it is obtained.
3. `white = correct_topology(white)` — Calculates or retrieves the white-matter cortical surface and stores it under the name `white`. The right side, `correct_topology(white)`, describes how it is obtained.
4. `pial = expand_and_deform(white, gray_csf_boundary)` — Calculates or retrieves the outer cortical surface and stores it under the name `pial`. The right side, `expand_and_deform(white, gray_csf_boundary)`, describes how it is obtained.
5. `sphere = inflate_and_project_to_sphere(white)` — Calculates or retrieves the spherical version of the cortex and stores it under the name `sphere`. The right side, `inflate_and_project_to_sphere(white)`, describes how it is obtained.
6. `sphere_reg = align_folding_features(sphere, atlas)` — Calculates or retrieves the sphere aligned with the atlas and stores it under the name `sphere_reg`. The right side, `align_folding_features(sphere, atlas)`, describes how it is obtained.
7. `annotations = classify_surface_vertices(sphere_reg, atlas_classifier)` — Calculates or retrieves the cortical region names assigned to vertices and stores it under the name `annotations`. The right side, `classify_surface_vertices(sphere_reg, atlas_classifier)`, describes how it is obtained.

## Walkthrough 21: Volumetric parcellation with `mri_aparc2aseg`

Language: `bash`.

1. `mri_aparc2aseg \` — Converts surface annotations into a labeled volume and merges subcortical labels. The trailing backslash continues the same command on the next line.
2. `--s sub-001 \` — The `--s` option selects the FreeSurfer subject. The trailing backslash continues the same command.
3. `--annot DKTatlas \` — The `--annot` option selects the cortical annotation. The trailing backslash continues the same command.
4. `--o aparc.DKTatlas+aseg.mgz` — The `--o` option names an output image or result.

## Walkthrough 22: Volumetric parcellation with `mri_aparc2aseg`

Language: `python`.

1. `output = copy(subcortical_aseg)` — Calculates or retrieves the result being built and stores it under the name `output`. The right side, `copy(subcortical_aseg)`, describes how it is obtained.
2. `for cortical_voxel in ribbon:` — Starts a loop that performs the indented steps once for every listed item.
3. `hemisphere = determine_hemisphere(cortical_voxel)` — Calculates or retrieves the variable `hemisphere` and stores it under the name `hemisphere`. The right side, `determine_hemisphere(cortical_voxel)`, describes how it is obtained.
4. `vertex = nearest_valid_surface_vertex(cortical_voxel, hemisphere)` — Calculates or retrieves the variable `vertex` and stores it under the name `vertex`. The right side, `nearest_valid_surface_vertex(cortical_voxel, hemisphere)`, describes how it is obtained.
5. `output[cortical_voxel] = annotation[vertex]` — Represents the stated conceptual processing step; production software expands it into validated library operations.

## Walkthrough 23: Regional summaries with `mri_segstats`

Language: `bash`.

1. `mri_segstats \` — Calculates counts, volumes, and optional scalar summaries by anatomical label. The trailing backslash continues the same command on the next line.
2. `--seg aparc.DKTatlas+aseg.mgz \` — The `--seg` option selects the label image to summarize. The trailing backslash continues the same command.
3. `--sum dkt_volume_stats.txt` — The `--sum` option names the regional statistics output.

## Walkthrough 24: Regional summaries with `mri_segstats`

Language: `python`.

1. `for label in unique(segmentation):` — Starts a loop that performs the indented steps once for every listed item.
2. `mask = segmentation == label` — Calculates or retrieves the voxels included in a region or operation and stores it under the name `mask`. The right side, `segmentation == label`, describes how it is obtained.
3. `voxel_count = sum(mask)` — Calculates or retrieves the number of selected voxels and stores it under the name `voxel_count`. The right side, `sum(mask)`, describes how it is obtained.
4. `volume_mm3 = voxel_count * voxel_volume` — Calculates or retrieves the physical region volume and stores it under the name `volume_mm3`. The right side, `voxel_count * voxel_volume`, describes how it is obtained.
5. `mean_value = mean(measure_image[mask])` — Calculates or retrieves the average scalar value in the region and stores it under the name `mean_value`. The right side, `mean(measure_image[mask])`, describes how it is obtained.

## Walkthrough 25: BIDS discovery and Nipype workflow construction

Language: `python`.

1. `layout = BIDSLayout(bids_dir)` — Calculates or retrieves the searchable BIDS dataset index and stores it under the name `layout`. The right side, `BIDSLayout(bids_dir)`, describes how it is obtained.
2. `dwi = layout.get(subject=subject, suffix="dwi")` — Calculates or retrieves the selected diffusion images and stores it under the name `dwi`. The right side, `layout.get(subject=subject, suffix="dwi")`, describes how it is obtained.
3. `fmap = find_intended_fieldmaps(layout, dwi)` — Calculates or retrieves fieldmaps linked to the diffusion run and stores it under the name `fmap`. The right side, `find_intended_fieldmaps(layout, dwi)`, describes how it is obtained.
5. `workflow = Workflow("qsiprep")` — Calculates or retrieves the processing graph being assembled and stores it under the name `workflow`. The right side, `Workflow("qsiprep")`, describes how it is obtained.
6. `workflow.connect(denoise, "dwi", unring, "dwi")` — Draws a data-flow connection from one processing output to the next processing input.
7. `workflow.connect(unring, "dwi", motion_and_sdc, "dwi")` — Draws a data-flow connection from one processing output to the next processing input.
8. `workflow.connect(motion_and_sdc, "corrected", resample, "dwi")` — Draws a data-flow connection from one processing output to the next processing input.

## Walkthrough 26: MP-PCA denoising

Language: `bash`.

1. `dwidenoise dwi.nii.gz dwi_denoised.nii.gz \` — Removes noise using local MP-PCA while preserving structured diffusion signal. The trailing backslash continues the same command on the next line.
2. `-noise noise_map.nii.gz` — The `-noise` option writes the estimated noise map.

## Walkthrough 27: MP-PCA denoising

Language: `python`.

1. `for spatial_patch in image:` — Starts a loop that performs the indented steps once for every listed item.
2. `X = patch_as_voxels_by_volumes(spatial_patch)` — Calculates or retrieves the local data matrix and stores it under the name `X`. The right side, `patch_as_voxels_by_volumes(spatial_patch)`, describes how it is obtained.
3. `U, singular_values, Vt = svd(X)` — Calls `U, singular_values, Vt = svd` to perform the named conceptual operation using the values inside parentheses.
4. `threshold = marchenko_pastur_noise_edge(singular_values, X.shape)` — Calculates or retrieves the estimated noise boundary and stores it under the name `threshold`. The right side, `marchenko_pastur_noise_edge(singular_values, X.shape)`, describes how it is obtained.
5. `keep = singular_values > threshold` — Calculates or retrieves which components exceed the noise boundary and stores it under the name `keep`. The right side, `singular_values > threshold`, describes how it is obtained.
6. `denoised_patch = U[:, keep] @ diag(singular_values[keep]) @ Vt[keep]` — Calculates or retrieves the reconstructed low-noise patch and stores it under the name `denoised_patch`. The right side, `U[:, keep] @ diag(singular_values[keep]) @ Vt[keep]`, describes how it is obtained.
7. `aggregate_overlapping_patch_estimates(denoised_patch)` — Calls `aggregate_overlapping_patch_estimates` to perform the named conceptual operation using the values inside parentheses.

## Walkthrough 28: Gibbs-ringing correction

Language: `bash`.

1. `mrdegibbs dwi_denoised.nii.gz dwi_unringed.nii.gz` — Reduces Gibbs ringing caused by limited Fourier sampling.

## Walkthrough 29: Gibbs-ringing correction

Language: `python`.

1. `for line in each_image_direction:` — Starts a loop that performs the indented steps once for every listed item.
2. `candidates = [fourier_subvoxel_shift(line, delta) for delta in shifts]` — Calculates or retrieves the candidate corrected lines or paths and stores it under the name `candidates`. The right side, `[fourier_subvoxel_shift(line, delta) for delta in shifts]`, describes how it is obtained.
3. `score = [local_total_variation(candidate) for candidate in candidates]` — Calculates or retrieves the quality score for each candidate and stores it under the name `score`. The right side, `[local_total_variation(candidate) for candidate in candidates]`, describes how it is obtained.
4. `output_line = candidates[argmin(score)]` — Calculates or retrieves the variable `output_line` and stores it under the name `output_line`. The right side, `candidates[argmin(score)]`, describes how it is obtained.

## Walkthrough 30: Susceptibility correction with FSL `topup`

Language: `bash`.

1. `topup \` — Estimates susceptibility distortion from opposite phase-encoding images. The trailing backslash continues the same command on the next line.
2. `--imain=paired_b0s.nii.gz \` — The `--imain` option provides the main input image series. The trailing backslash continues the same command.
3. `--datain=acqparams.txt \` — The `--datain` option provides phase-encoding and readout metadata. The trailing backslash continues the same command.
4. `--config=b02b0.cnf \` — The `--config` option selects the program configuration. The trailing backslash continues the same command.
5. `--out=topup_results` — The `--out` option sets an output prefix.

## Walkthrough 31: Susceptibility correction with FSL `topup`

Language: `python`.

1. `field = initialize_smooth_off_resonance_field()` — Calculates or retrieves the current susceptibility field estimate and stores it under the name `field`. The right side, `initialize_smooth_off_resonance_field()`, describes how it is obtained.
2. `repeat:` — Conceptual loop marker: repeat the preceding operations until changes become small or the stated stopping rule is met.
3. `corrected_forward = unwarp(forward_b0, field, pe_direction=+1)` — Calculates or retrieves the variable `corrected_forward` and stores it under the name `corrected_forward`. The right side, `unwarp(forward_b0, field, pe_direction=+1)`, describes how it is obtained.
4. `corrected_reverse = unwarp(reverse_b0, field, pe_direction=-1)` — Calculates or retrieves the variable `corrected_reverse` and stores it under the name `corrected_reverse`. The right side, `unwarp(reverse_b0, field, pe_direction=-1)`, describes how it is obtained.
5. `loss = similarity(corrected_forward, corrected_reverse)` — Calculates or retrieves the total mismatch being minimized and stores it under the name `loss`. The right side, `similarity(corrected_forward, corrected_reverse)`, describes how it is obtained.
6. `loss += smoothness_penalty(field)` — Calls `loss += smoothness_penalty` to perform the named conceptual operation using the values inside parentheses.
7. `field = optimizer_update(field, loss)` — Calculates or retrieves the current susceptibility field estimate and stores it under the name `field`. The right side, `optimizer_update(field, loss)`, describes how it is obtained.
8. `until convergence` — Conceptual loop marker: repeat the preceding operations until changes become small or the stated stopping rule is met.

## Walkthrough 32: Motion and eddy-current correction with FSL `eddy`

Language: `bash`.

1. `eddy_openmp \` — Corrects motion and eddy-current distortion using multithreaded FSL eddy. The trailing backslash continues the same command on the next line.
2. `--imain=dwi.nii.gz \` — The `--imain` option provides the main input image series. The trailing backslash continues the same command.
3. `--mask=mask.nii.gz \` — The `--mask` option provides a brain mask. The trailing backslash continues the same command.
4. `--acqp=acqparams.txt \` — The `--acqp` option provides acquisition parameters. The trailing backslash continues the same command.
5. `--index=index.txt \` — The `--index` option maps each volume to its acquisition row. The trailing backslash continues the same command.
6. `--bvecs=bvecs \` — The `--bvecs` option provides diffusion-gradient directions. The trailing backslash continues the same command.
7. `--bvals=bvals \` — The `--bvals` option provides diffusion-weighting values. The trailing backslash continues the same command.
8. `--topup=topup_results \` — The `--topup` option provides the topup result prefix. The trailing backslash continues the same command.
9. `--out=eddy_corrected` — The `--out` option sets an output prefix.

## Walkthrough 33: Motion and eddy-current correction with FSL `eddy`

Language: `python`.

1. `repeat:` — Conceptual loop marker: repeat the preceding operations until changes become small or the stated stopping rule is met.
2. `prediction = gaussian_process_predict_each_volume(corrected_data, qspace)` — Calculates or retrieves the model prediction used as an alignment target and stores it under the name `prediction`. The right side, `gaussian_process_predict_each_volume(corrected_data, qspace)`, describes how it is obtained.
3. `transforms = register_each_volume_to_prediction(data, prediction)` — Calculates or retrieves the spatial alignments and stores it under the name `transforms`. The right side, `register_each_volume_to_prediction(data, prediction)`, describes how it is obtained.
4. `detect_and_replace_slice_outliers(data, prediction)` — Calls `detect_and_replace_slice_outliers` to perform the named conceptual operation using the values inside parentheses.
5. `corrected_data = resample_with_motion_eddy_and_susceptibility(transforms)` — Calculates or retrieves the variable `corrected_data` and stores it under the name `corrected_data`. The right side, `resample_with_motion_eddy_and_susceptibility(transforms)`, describes how it is obtained.
6. `rotated_bvecs = [rotation(T) @ g for T, g in zip(transforms, bvecs)]` — Calculates or retrieves the variable `rotated_bvecs` and stores it under the name `rotated_bvecs`. The right side, `[rotation(T) @ g for T, g in zip(transforms, bvecs)]`, describes how it is obtained.
7. `until convergence` — Conceptual loop marker: repeat the preceding operations until changes become small or the stated stopping rule is met.

## Walkthrough 34: ANTs registration and lesion cost-function masking

Language: `bash`.

1. `antsRegistration \` — Estimates image alignment using the requested metrics and transforms. The trailing backslash continues the same command on the next line.
2. `--dimensionality 3 \` — The `--dimensionality` option sets the number of spatial dimensions. The trailing backslash continues the same command.
3. `--metric "CC[fixed.nii.gz,moving.nii.gz,1,4,Regular,0.2]" \` — The `--metric` option defines how image similarity is scored. The trailing backslash continues the same command.
4. `--masks "[fixed_fit_mask.nii.gz,moving_fit_mask.nii.gz]" \` — The `--masks` option limits which voxels contribute to registration fitting. The trailing backslash continues the same command.
5. `--transform "SyN[0.1,3,0]"` — The `--transform` option selects a transform model and step parameters.

## Walkthrough 35: ANTs registration and lesion cost-function masking

Language: `python`.

1. `fit_mask = brain_mask & ~lesion_mask` — Calculates or retrieves healthy voxels permitted to influence registration and stores it under the name `fit_mask`. The right side, `brain_mask & ~lesion_mask`, describes how it is obtained.
2. `phi = initialize_affine()` — Calculates or retrieves a nonlinear transformation and stores it under the name `phi`. The right side, `initialize_affine()`, describes how it is obtained.
3. `for stage in [rigid, affine, nonlinear]:` — Starts a loop that performs the indented steps once for every listed item.
4. `phi = minimize(` — Calculates or retrieves a nonlinear transformation and stores it under the name `phi`. The right side, `minimize(`, describes how it is obtained.
5. `similarity(fixed, warp(moving, phi), domain=fit_mask)` — Calls `similarity` to perform the named conceptual operation using the values inside parentheses.
6. `+ regularization(phi)` — Calls `+ regularization` to perform the named conceptual operation using the values inside parentheses.
7. `)` — Calls `)` to perform the named conceptual operation using the values inside parentheses.

## Walkthrough 36: N4 bias-field correction

Language: `bash`.

1. `N4BiasFieldCorrection \` — Corrects smooth intensity nonuniformity with ANTs N4. The trailing backslash continues the same command on the next line.
2. `-d 3 \` — The `-d` option sets image dimensionality. The trailing backslash continues the same command.
3. `-i T1w.nii.gz \` — The `-i` option provides the input image. The trailing backslash continues the same command.
4. `-x brain_mask.nii.gz \` — The `-x` option provides a mask. The trailing backslash continues the same command.
5. `-o "[T1w_n4.nii.gz,bias_field.nii.gz]"` — The `-o` option names output files.

## Walkthrough 37: SHORELine and 3dSHORE signal prediction

Language: `python`.

1. `corrected = input_dwi` — Calculates or retrieves the current corrected image and stores it under the name `corrected`. The right side, `input_dwi`, describes how it is obtained.
2. `repeat:` — Conceptual loop marker: repeat the preceding operations until changes become small or the stated stopping rule is met.
3. `for volume in corrected:` — Starts a loop that performs the indented steps once for every listed item.
4. `model = fit_3dshore(corrected excluding volume, gradients)` — Calculates or retrieves the variable `model` and stores it under the name `model`. The right side, `fit_3dshore(corrected excluding volume, gradients)`, describes how it is obtained.
5. `predicted = model.predict(gradient_of(volume))` — Calculates or retrieves the variable `predicted` and stores it under the name `predicted`. The right side, `model.predict(gradient_of(volume))`, describes how it is obtained.
6. `transform = rigid_register(volume, predicted)` — Calculates or retrieves the variable `transform` and stores it under the name `transform`. The right side, `rigid_register(volume, predicted)`, describes how it is obtained.
7. `corrected[volume] = resample(volume, transform)` — Updates this selected output entry with the newly calculated value.
8. `gradients[volume] = rotation(transform) @ gradients[volume]` — Represents the stated conceptual processing step; production software expands it into validated library operations.
9. `until motion_parameters_stabilize` — Conceptual loop marker: repeat the preceding operations until changes become small or the stated stopping rule is met.

## Walkthrough 38: Resampling and transform composition

Language: `python`.

1. `composite = compose(susceptibility, eddy, motion, coregistration)` — Calculates or retrieves the combined spatial transformation and stores it under the name `composite`. The right side, `compose(susceptibility, eddy, motion, coregistration)`, describes how it is obtained.
2. `preprocessed_dwi = resample_once(` — Calculates or retrieves the final resampled diffusion series and stores it under the name `preprocessed_dwi`. The right side, `resample_once(`, describes how it is obtained.
3. `raw_dwi,` — Represents the stated conceptual processing step; production software expands it into validated library operations.
4. `transform=composite,` — Calculates or retrieves the variable `transform` and stores it under the name `transform`. The right side, `composite,`, describes how it is obtained.
5. `target_grid=t1w_or_requested_grid` — Calculates or retrieves the variable `target_grid` and stores it under the name `target_grid`. The right side, `t1w_or_requested_grid`, describes how it is obtained.
6. `)` — Calls `)` to perform the named conceptual operation using the values inside parentheses.

## Walkthrough 39: SynthStrip and SynthSeg

Language: `python`.

1. `brain_mask = synthstrip(t1w)` — Calculates or retrieves the predicted brain-only mask and stores it under the name `brain_mask`. The right side, `synthstrip(t1w)`, describes how it is obtained.
2. `tissue_labels = synthseg(t1w, mask=brain_mask)` — Calculates or retrieves the predicted anatomical labels and stores it under the name `tissue_labels`. The right side, `synthseg(t1w, mask=brain_mask)`, describes how it is obtained.

## Walkthrough 40: QSIPrep quality control

Language: `python`.

1. `qc = {` — Calculates or retrieves a collection of quality measurements and stores it under the name `qc`. The right side, `{`, describes how it is obtained.
2. `"mean_translation": mean(norm(motion[:, :3], axis=1)),` — Represents the stated conceptual processing step; production software expands it into validated library operations.
3. `"mean_rotation": mean(norm(motion[:, 3:], axis=1)),` — Represents the stated conceptual processing step; production software expands it into validated library operations.
4. `"outlier_fraction": outlier_slices / total_slices,` — Represents the stated conceptual processing step; production software expands it into validated library operations.
5. `"prediction_residual": norm(observed - predicted) / norm(predicted),` — Represents the stated conceptual processing step; production software expands it into validated library operations.
6. `}` — Represents the stated conceptual processing step; production software expands it into validated library operations.

## Walkthrough 41: YAML reconstruction specifications as executable graphs

Language: `yaml`.

1. `name: example_mrtrix_workflow` — Gives the entire reconstruction workflow a readable name.
2. `nodes:` — Begins the list of processing nodes.
3. `- name: estimate_fod` — Starts a new workflow node and gives it a unique name.
4. `software: MRTrix3` — Selects the software family that will perform this node.
5. `action: csd` — Selects the operation that the software interface should run.
6. `- name: tractography` — Starts a new workflow node and gives it a unique name.
7. `software: MRTrix3` — Selects the software family that will perform this node.
8. `action: tractography` — Selects the operation that the software interface should run.
9. `input: estimate_fod` — Connects this node to the named upstream node output.

## Walkthrough 42: YAML reconstruction specifications as executable graphs

Language: `python`.

1. `spec = load_yaml(path)` — Calculates or retrieves the loaded YAML reconstruction recipe and stores it under the name `spec`. The right side, `load_yaml(path)`, describes how it is obtained.
2. `graph = DirectedAcyclicGraph()` — Calculates or retrieves the directed processing graph and stores it under the name `graph`. The right side, `DirectedAcyclicGraph()`, describes how it is obtained.
3. `for node_spec in spec["nodes"]:` — Starts a loop that performs the indented steps once for every listed item.
4. `node = build_interface(node_spec["software"], node_spec["action"])` — Calculates or retrieves one processing operation and stores it under the name `node`. The right side, `build_interface(node_spec["software"], node_spec["action"])`, describes how it is obtained.
5. `graph.add(node)` — Adds the newly created processing node to the workflow graph.
6. `if "input" in node_spec:` — Tests a condition; the indented step runs only when it is true.
7. `graph.connect(node_spec["input"], node)` — Draws a data-flow connection from one processing output to the next processing input.
8. `assert graph.is_acyclic()` — Stops with an error if the required safety condition is not true.
9. `workflow = compile_to_nipype(graph)` — Calculates or retrieves the processing graph being assembled and stores it under the name `workflow`. The right side, `compile_to_nipype(graph)`, describes how it is obtained.

## Walkthrough 43: Diffusion tensor model and FA, MD, AD, RD

Language: `bash`.

1. `dwi2tensor dwi.mif tensor.mif` — Fits a diffusion tensor at each valid voxel.
2. `tensor2metric tensor.mif \` — Converts fitted tensors into scalar maps such as FA, MD, AD, and RD. The trailing backslash continues the same command on the next line.
3. `-fa fa.mif \` — The `-fa` option writes fractional anisotropy. The trailing backslash continues the same command.
4. `-adc md.mif \` — The `-adc` option writes mean diffusivity or apparent diffusion coefficient. The trailing backslash continues the same command.
5. `-ad ad.mif \` — The `-ad` option writes axial diffusivity. The trailing backslash continues the same command.
6. `-rd rd.mif` — The `-rd` option writes radial diffusivity.

## Walkthrough 44: Response functions and constrained spherical deconvolution

Language: `bash`.

1. `dwi2response dhollander dwi.mif \` — Estimates representative tissue response functions. The trailing backslash continues the same command on the next line.
2. `wm_response.txt gm_response.txt csf_response.txt` — Supplies an input, output, or positional file required by the command; its exact role follows the command syntax above.
4. `dwi2fod msmt_csd dwi.mif \` — Estimates tissue compartments and a white-matter FOD from diffusion data. The trailing backslash continues the same command on the next line.
5. `wm_response.txt wmfod.mif \` — Supplies an input, output, or positional file required by the command; its exact role follows the command syntax above.
6. `gm_response.txt gm.mif \` — Supplies an input, output, or positional file required by the command; its exact role follows the command syntax above.
7. `csf_response.txt csf.mif` — Supplies an input, output, or positional file required by the command; its exact role follows the command syntax above.

## Walkthrough 45: Single-shell three-tissue CSD

Language: `bash`.

1. `dwi2response dhollander dwi.mif wm.txt gm.txt csf.txt` — Estimates representative tissue response functions.
2. `# The exact SS3T operation depends on the MRtrix3Tissue/QSIRecon implementation.` — Comment for the reader: The exact SS3T operation depends on the MRtrix3Tissue/QSIRecon implementation.. It is not executed.
3. `ss3t_csd_beta1 dwi.mif wm.txt wmfod.mif gm.txt gm.mif csf.txt csf.mif` — Runs the version-specific single-shell three-tissue CSD implementation.

## Walkthrough 46: Multi-tissue intensity normalization with `mtnormalise`

Language: `bash`.

1. `mtnormalise \` — Jointly normalizes tissue amplitudes and corrects smooth residual bias. The trailing backslash continues the same command on the next line.
2. `wmfod.mif wmfod_norm.mif \` — Supplies an input, output, or positional file required by the command; its exact role follows the command syntax above.
3. `gm.mif gm_norm.mif \` — Supplies an input, output, or positional file required by the command; its exact role follows the command syntax above.
4. `csf.mif csf_norm.mif \` — Supplies an input, output, or positional file required by the command; its exact role follows the command syntax above.
5. `-mask brain_mask.mif` — The `-mask` option limits processing to a brain mask.

## Walkthrough 47: HSVS five-tissue-type image

Language: `bash`.

1. `5ttgen hsvs /subjects/sub-001 base_5tt.mif` — Builds a five-tissue-type image for ACT.
2. `5ttcheck base_5tt.mif` — Checks whether a 5TT image has the expected tissue organization.
3. `5tt2gmwmi base_5tt.mif gmwm_seed.mif` — Creates a gray–white matter interface image for seeding or QC.

## Walkthrough 48: HSVS five-tissue-type image

Language: `bash`.

1. `5ttedit base_5tt.mif lesion_aware_5tt.mif \` — Edits selected channels of an existing 5TT image. The trailing backslash continues the same command on the next line.
2. `-path lesion_in_5tt_space.mif` — The `-path` option places the supplied mask in the pathological 5TT channel.
3. `5ttcheck lesion_aware_5tt.mif` — Checks whether a 5TT image has the expected tissue organization.

## Walkthrough 49: Anatomically constrained tractography

Language: `python`.

1. `while streamline_is_active:` — Repeats the indented steps while this condition remains true.
2. `direction = tractography_model.sample_direction(position)` — Calculates or retrieves the current propagation direction and stores it under the name `direction`. The right side, `tractography_model.sample_direction(position)`, describes how it is obtained.
3. `next_position = integrate(position, direction)` — Calculates or retrieves the variable `next_position` and stores it under the name `next_position`. The right side, `integrate(position, direction)`, describes how it is obtained.
4. `tissue = five_tissue_image(next_position)` — Calculates or retrieves the five-tissue values at a proposed point and stores it under the name `tissue`. The right side, `five_tissue_image(next_position)`, describes how it is obtained.
6. `if transition_is_anatomically_valid(previous_tissue, tissue):` — Tests a condition; the indented step runs only when it is true.
7. `continue` — Represents the stated conceptual processing step; production software expands it into validated library operations.
8. `elif transition_is_valid_termination(previous_tissue, tissue):` — Tests another condition only if the earlier condition was false.
9. `terminate_and_accept()` — Calls `terminate_and_accept` to perform the named conceptual operation using the values inside parentheses.
10. `else:` — Runs the following step when none of the earlier conditions were true.
11. `reject_or_backtrack()` — Calls `reject_or_backtrack` to perform the named conceptual operation using the values inside parentheses.

## Walkthrough 50: Anatomically constrained tractography

Language: `bash`.

1. `tckgen wmfod.mif tracks.tck \` — Generates streamlines from the FOD under tractography and ACT rules. The trailing backslash continues the same command on the next line.
2. `-algorithm iFOD2 \` — The `-algorithm` option selects the tractography algorithm. The trailing backslash continues the same command.
3. `-act five_tissue.mif \` — The `-act` option provides the ACT five-tissue image. The trailing backslash continues the same command.
4. `-backtrack \` — The `-backtrack` option allows ACT to reverse a failed step. The trailing backslash continues the same command.
5. `-crop_at_gmwmi \` — The `-crop_at_gmwmi` option crops accepted endpoints at the gray–white interface. The trailing backslash continues the same command.
6. `-seed_dynamic wmfod.mif \` — The `-seed_dynamic` option seeds according to the white-matter FOD. The trailing backslash continues the same command.
7. `-select 10000000` — The `-select` option sets the target number of accepted streamlines.

## Walkthrough 51: iFOD2 probabilistic streamline integration

Language: `python`.

1. `position, direction = seed()` — Calls `position, direction = seed` to perform the named conceptual operation using the values inside parentheses.
2. `while valid:` — Repeats the indented steps while this condition remains true.
3. `arcs = propose_candidate_arcs(position, direction, step_size, max_angle)` — Calculates or retrieves candidate curved steps and stores it under the name `arcs`. The right side, `propose_candidate_arcs(position, direction, step_size, max_angle)`, describes how it is obtained.
4. `scores = [integrated_fod_amplitude(arc, wmfod) for arc in arcs]` — Calculates or retrieves FOD support for candidate steps and stores it under the name `scores`. The right side, `[integrated_fod_amplitude(arc, wmfod) for arc in arcs]`, describes how it is obtained.
5. `arc = probabilistic_sample(arcs, scores)` — Calculates or retrieves the variable `arc` and stores it under the name `arc`. The right side, `probabilistic_sample(arcs, scores)`, describes how it is obtained.
6. `position, direction = advance_along(arc)` — Calls `position, direction = advance_along` to perform the named conceptual operation using the values inside parentheses.
7. `apply_cutoff_length_mask_and_act_rules()` — Calls `apply_cutoff_length_mask_and_act_rules` to perform the named conceptual operation using the values inside parentheses.

## Walkthrough 52: SIFT2 streamline weighting

Language: `bash`.

1. `tcksift2 tracks.tck wmfod.mif sift2_weights.txt \` — Assigns one diffusion-informed weight to each streamline. The trailing backslash continues the same command on the next line.
2. `-act five_tissue.mif \` — The `-act` option provides the ACT five-tissue image. The trailing backslash continues the same command.
3. `-out_mu sift2_mu.txt` — The `-out_mu` option writes the global SIFT2 proportionality coefficient.

## Walkthrough 53: Connectome construction with `tck2connectome`

Language: `bash`.

1. `tck2connectome tracks.tck nodes.mif count.csv \` — Groups streamlines by endpoint regions to make a connectivity matrix. The trailing backslash continues the same command on the next line.
2. `-symmetric -zero_diagonal` — The `-zero_diagonal` option sets self-connections to zero.
4. `tck2connectome tracks.tck nodes.mif sift2.csv \` — Groups streamlines by endpoint regions to make a connectivity matrix. The trailing backslash continues the same command on the next line.
5. `-tck_weights_in sift2_weights.txt \` — The `-tck_weights_in` option uses supplied per-streamline weights. The trailing backslash continues the same command.
6. `-symmetric -zero_diagonal` — The `-zero_diagonal` option sets self-connections to zero.
8. `tck2connectome tracks.tck nodes.mif mean_length.csv \` — Groups streamlines by endpoint regions to make a connectivity matrix. The trailing backslash continues the same command on the next line.
9. `-scale_length -stat_edge mean \` — The `-scale_length` option uses streamline length as the edge contribution. The trailing backslash continues the same command.
10. `-symmetric -zero_diagonal` — The `-zero_diagonal` option sets self-connections to zero.

## Walkthrough 54: Sampling scalar maps along streamlines

Language: `bash`.

1. `tcksample tracks.tck fa.mif streamline_mean_fa.txt \` — Samples an image value repeatedly along each streamline. The trailing backslash continues the same command on the next line.
2. `-stat_tck mean` — The `-stat_tck` option selects the summary calculated along each streamline.

## Walkthrough 55: Atlas transformations and node assignment

Language: `bash`.

1. `antsApplyTransforms \` — Applies saved spatial transforms to an image. The trailing backslash continues the same command on the next line.
2. `-d 3 \` — The `-d` option sets image dimensionality. The trailing backslash continues the same command.
3. `-i dkt_labels.nii.gz \` — The `-i` option provides the input image. The trailing backslash continues the same command.
4. `-r dwiref.nii.gz \` — The `-r` option provides the target reference grid. The trailing backslash continues the same command.
5. `-o dkt_in_dwi.nii.gz \` — The `-o` option names output files. The trailing backslash continues the same command.
6. `-n NearestNeighbor \` — The `-n` option selects interpolation. The trailing backslash continues the same command.
7. `-t anatomical_to_dwi_transform.mat` — The `-t` option provides a transform to apply.
9. `labelconvert dkt_in_dwi.nii.gz \` — Converts segmentation label numbers using source and target lookup tables. The trailing backslash continues the same command on the next line.
10. `FreeSurferColorLUT.txt fs_dkt.txt nodes.mif` — Supplies an input, output, or positional file required by the command; its exact role follows the command syntax above.

## Walkthrough 56: End-to-end code sketch for our pipeline

Language: `bash`.

1. `# Preprocessing is performed by QSIPrep.` — Comment for the reader: Preprocessing is performed by QSIPrep.. It is not executed.
2. `qsiprep /bids /derivatives participant \` — Runs the QSIPrep BIDS application. The trailing backslash continues the same command on the next line.
3. `--participant-label 001 \` — The `--participant-label` option selects the participant. The trailing backslash continues the same command.
4. `--output-resolution 2` — The `--output-resolution` option sets output voxel size in millimeters.
6. `# Anatomical reconstruction uses the inpainted T1w.` — Comment for the reader: Anatomical reconstruction uses the inpainted T1w.. It is not executed.
7. `recon-all -all -s sub-001 -i inpainted_T1w.nii.gz` — Runs FreeSurfer anatomical reconstruction stages.
9. `# QSIRecon estimates FODs and runs standard ACT.` — Comment for the reader: QSIRecon estimates FODs and runs standard ACT.. It is not executed.
10. `qsirecon /derivatives/qsiprep /derivatives/qsirecon participant \` — Runs the QSIRecon reconstruction BIDS application. The trailing backslash continues the same command on the next line.
11. `--input-type qsiprep \` — The `--input-type` option declares the format of reconstruction inputs. The trailing backslash continues the same command.
12. `--recon-spec mrtrix_singleshell_ss3t_ACT-hsvs \` — The `--recon-spec` option selects the QSIRecon workflow recipe. The trailing backslash continues the same command.
13. `--fs-subjects-dir /subjects` — The `--fs-subjects-dir` option provides the FreeSurfer subjects directory.
15. `# Proposed lesion-aware branch.` — Comment for the reader: Proposed lesion-aware branch.. It is not executed.
16. `antsApplyTransforms \` — Applies saved spatial transforms to an image. The trailing backslash continues the same command on the next line.
17. `-i lesion_native_T1w.nii.gz \` — The `-i` option provides the input image. The trailing backslash continues the same command.
18. `-r base_5tt_reference.nii.gz \` — The `-r` option provides the target reference grid. The trailing backslash continues the same command.
19. `-o lesion_in_5tt_space.nii.gz \` — The `-o` option names output files. The trailing backslash continues the same command.
20. `-n NearestNeighbor \` — The `-n` option selects interpolation. The trailing backslash continues the same command.
21. `-t lesion_to_5tt_transforms` — The `-t` option provides a transform to apply.
23. `5ttedit base_5tt.mif lesion_aware_5tt.mif \` — Edits selected channels of an existing 5TT image. The trailing backslash continues the same command on the next line.
24. `-path lesion_in_5tt_space.nii.gz` — The `-path` option places the supplied mask in the pathological 5TT channel.
26. `tckgen wmfod.mif lesion_aware_tracks.tck \` — Generates streamlines from the FOD under tractography and ACT rules. The trailing backslash continues the same command on the next line.
27. `-algorithm iFOD2 \` — The `-algorithm` option selects the tractography algorithm. The trailing backslash continues the same command.
28. `-act lesion_aware_5tt.mif \` — The `-act` option provides the ACT five-tissue image. The trailing backslash continues the same command.
29. `-seed_dynamic wmfod.mif \` — The `-seed_dynamic` option seeds according to the white-matter FOD. The trailing backslash continues the same command.
30. `-select 10000000` — The `-select` option sets the target number of accepted streamlines.
32. `tcksift2 lesion_aware_tracks.tck wmfod.mif lesion_aware_weights.txt \` — Assigns one diffusion-informed weight to each streamline. The trailing backslash continues the same command on the next line.
33. `-act lesion_aware_5tt.mif` — The `-act` option provides the ACT five-tissue image.
35. `tck2connectome lesion_aware_tracks.tck dkt_nodes.mif dkt_sift2.csv \` — Groups streamlines by endpoint regions to make a connectivity matrix. The trailing backslash continues the same command on the next line.
36. `-tck_weights_in lesion_aware_weights.txt \` — The `-tck_weights_in` option uses supplied per-streamline weights. The trailing backslash continues the same command.
37. `-symmetric -zero_diagonal` — The `-zero_diagonal` option sets self-connections to zero.

<!-- END GENERATED CODE WALKTHROUGHS -->

# Selected references

## FreeSurfer

1. Dale AM, Fischl B, Sereno MI. Cortical surface-based analysis I:
   segmentation and surface reconstruction. *NeuroImage*. 1999;9:179–194.
2. Fischl B, Sereno MI, Dale AM. Cortical surface-based analysis II: inflation,
   flattening, and a surface-based coordinate system. *NeuroImage*.
   1999;9:195–207.
3. Fischl B, Dale AM. Measuring the thickness of the human cerebral cortex from
   magnetic resonance images. *PNAS*. 2000;97:11050–11055.
4. Fischl B, Liu A, Dale AM. Automated manifold surgery: constructing
   geometrically accurate and topologically correct models of the human
   cerebral cortex. *IEEE Transactions on Medical Imaging*. 2001.
5. Fischl B, Salat DH, Busa E, et al. Whole brain segmentation: automated
   labeling of neuroanatomical structures in the human brain. *Neuron*. 2002.
6. Fischl B, van der Kouwe A, Destrieux C, et al. Automatically parcellating
   the human cerebral cortex. *Cerebral Cortex*. 2004.
7. Ségonne F, Dale AM, Busa E, et al. A hybrid approach to the skull stripping
   problem in MRI. *NeuroImage*. 2004. DOI:
   `10.1016/j.neuroimage.2004.03.032`.
8. Reuter M, Rosas HD, Fischl B. Highly accurate inverse consistent
   registration: a robust approach. *NeuroImage*. 2010.
9. Reuter M, Schmansky NJ, Rosas HD, Fischl B. Within-subject template
   estimation for unbiased longitudinal image analysis. *NeuroImage*. 2012.
10. Sled JG, Zijdenbos AP, Evans AC. A nonparametric method for automatic
    correction of intensity nonuniformity in MRI data. *IEEE Transactions on
    Medical Imaging*. 1998.

## QSIPrep, QSIRecon, and workflow infrastructure

11. Cieslak M, Cook PA, He X, et al. QSIPrep: an integrative platform for
    preprocessing and reconstructing diffusion MRI data. *Nature Methods*.
    2021;18:775–778. DOI: `10.1038/s41592-021-01185-5`.
12. Gorgolewski KJ, Burns CD, Madison C, et al. Nipype: a flexible, lightweight
    and extensible neuroimaging data processing framework in Python.
    *Frontiers in Neuroinformatics*. 2011.
13. Gorgolewski KJ, Auer T, Calhoun VD, et al. The Brain Imaging Data Structure,
    a format for organizing and describing outputs of neuroimaging experiments.
    *Scientific Data*. 2016.
14. Esteban O, Markiewicz CJ, Blair RW, et al. fMRIPrep: a robust preprocessing
    pipeline for functional MRI. *Nature Methods*. 2019.

## Representative integrated diffusion and registration methods

15. Tournier JD, Smith R, Raffelt D, et al. MRtrix3: a fast, flexible and open
    software framework for medical image processing and visualisation.
    *NeuroImage*. 2019.
16. Smith RE, Tournier JD, Calamante F, Connelly A. Anatomically-constrained
    tractography. *NeuroImage*. 2012.
17. Smith RE, Tournier JD, Calamante F, Connelly A. SIFT2: enabling dense
    quantitative assessment of brain white matter connectivity using
    streamlines tractography. *NeuroImage*. 2015.
18. Avants BB, Tustison NJ, Song G, et al. A reproducible evaluation of ANTs
    similarity metric performance in brain image registration.
    *NeuroImage*. 2011.
19. Tustison NJ, Avants BB, Cook PA, et al. N4ITK: improved N3 bias correction.
    *IEEE Transactions on Medical Imaging*. 2010.

## Additional mathematical and implementation references

20. Brett M, Leff AP, Rorden C, Ashburner J. Spatial normalization of brain
    images with focal lesions using cost function masking. *NeuroImage*. 2001.
21. Veraart J, Novikov DS, Christiaens D, Ades-Aron B, Sijbers J, Fieremans E.
    Denoising of diffusion MRI using random matrix theory. *NeuroImage*. 2016.
    DOI: `10.1016/j.neuroimage.2016.08.016`.
22. Kellner E, Dhital B, Kiselev VG, Reisert M. Gibbs-ringing artifact removal
    based on local subvoxel-shifts. *Magnetic Resonance in Medicine*. 2016.
    DOI: `10.1002/mrm.26054`.
23. Andersson JLR, Skare S, Ashburner J. How to correct susceptibility
    distortions in spin-echo echo-planar images: application to diffusion
    tensor imaging. *NeuroImage*. 2003.
24. Andersson JLR, Sotiropoulos SN. An integrated approach to correction for
    off-resonance effects and subject movement in diffusion MR imaging.
    *NeuroImage*. 2016. DOI: `10.1016/j.neuroimage.2015.10.019`.
25. Özarslan E, Koay CG, Shepherd TM, Blackband SJ, Basser PJ. Simple harmonic
    oscillator based reconstruction and estimation for three-dimensional
    q-space MRI. *Proceedings of ISMRM*. 2009;17:1396. This is the original
    3dSHORE conference report.
26. Hoopes A, Mora JS, Dalca AV, Fischl B, Hoffmann M. SynthStrip:
    skull-stripping for any brain image. *NeuroImage*. 2022.
27. Billot B, Greve DN, Puonti O, et al. SynthSeg: segmentation of brain MRI
    scans of any contrast and resolution without retraining. *Medical Image
    Analysis*. 2023.
28. Basser PJ, Mattiello J, LeBihan D. MR diffusion tensor spectroscopy and
    imaging. *Biophysical Journal*. 1994.
29. Tournier JD, Calamante F, Connelly A. Robust determination of the fibre
    orientation distribution in diffusion MRI: non-negativity constrained
    super-resolved spherical deconvolution. *NeuroImage*. 2007.
30. Raffelt D, Dhollander T, Tournier JD, et al. Bias field correction and
    intensity normalisation for quantitative analysis of apparent fibre
    density. *Proceedings of ISMRM*. 2017;26:3541. The current `mtnormalise`
    implementation additionally uses a log-domain formulation and gradual
    outlier rejection documented by MRtrix3.
31. Smith RE, Tournier JD, Calamante F, Connelly A. Anatomically-constrained
    tractography: improved determination of streamline termination conditions.
    *NeuroImage*. 2012.
32. Smith RE, Tournier JD, Calamante F, Connelly A. SIFT2: enabling dense
    quantitative assessment of brain white matter connectivity using
    streamlines tractography. *NeuroImage*. 2015.
33. Smith RE, Skoch A, Bajada C, Caspers S, Connelly A. Hybrid surface-volume
    segmentation for improved anatomically constrained tractography.
    *Proceedings of the OHBM Annual Meeting*. 2020.
34. Jensen JH, Helpern JA, Ramani A, Lu H, Kaczynski K. Diffusional kurtosis
    imaging: the quantification of non-Gaussian water diffusion by means of
    magnetic resonance imaging. *Magnetic Resonance in Medicine*. 2005.
35. Yeh FC, Wedeen VJ, Tseng WYI. Generalized q-sampling imaging.
    *IEEE Transactions on Medical Imaging*. 2010.
36. Zhang H, Schneider T, Wheeler-Kingshott CA, Alexander DC. NODDI: practical
    in vivo neurite orientation dispersion and density imaging of the human
    brain. *NeuroImage*. 2012.
37. Özarslan E, Koay CG, Shepherd TM, et al. Mean apparent propagator MRI
    (MAP-MRI): a novel diffusion imaging method for mapping tissue
    microstructure. *NeuroImage*. 2013.
38. Klein A, Tourville J. 101 labeled brain images and a consistent human
    cortical labeling protocol. *Frontiers in Neuroscience*. 2012.

## Conclusion

FreeSurfer, QSIPrep, and QSIRecon all combine published methods with original
software engineering. The correct interpretation is:

- FreeSurfer developed many foundational segmentation and surface algorithms,
  but not every executable has a separate paper.
- QSIPrep integrates established preprocessing tools while contributing
  adaptive BIDS workflows, SHORELine, standardized transformations,
  derivatives, QC, and validation.
- QSIRecon primarily integrates independently published reconstruction methods
  through an original declarative workflow and interoperability framework.

Scientific credit should therefore be assigned at both levels: cite the
pipeline that organized the analysis and the specialized underlying method when
that method is central to the scientific claim.
