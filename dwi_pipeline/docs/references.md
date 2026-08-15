# Methods references

Peer-reviewed papers and credible resources underpinning each step of the DKT Connectome. For **theory and rationale** per step, see the [Methods](methods/index.md) section. For copy-paste BibTeX and acknowledgment text, see [Citation](citation.md).

Layout follows the [QSIPrep citing guide](https://qsiprep.readthedocs.io/en/0.22.1/citing.html): cite the **primary method paper** for every tool that contributes to your scientific claim.

---

## Quick map (step → primary citations)

| Step | Tool / method | Primary references |
|------|---------------|-------------------|
| **1** | QSIPrep preprocessing & SDC | Cieslak et al. 2021; Andersson et al. 2003/2016 |
| **1.5** | neuroLIT lesion inpainting | Pollak et al. 2025; Ho et al. 2020 |
| **2** | FreeSurfer / FastSurfer recon | Fischl 2012; Henschel et al. 2020; Klein & Tourville 2015 |
| **3** | QSIRecon + SS3T-CSD + ACT-HSVS | Cieslak et al. 2024; Jeurissen et al. 2014; Smith et al. 2012/2020 |
| **4** | DKT structural connectome | Tournier et al. 2019; Smith et al. 2015; Desikan et al. 2006 |
| **4.5** | Disconnectome | Griffis et al. 2019; Kuceyeski et al. 2013 |
| **5** | Node strength / report | Rubinov & Sporns 2010; Piper et al. 2026 |
| **All** | BIDS layout & BIDS App | Gorgolewski et al. 2016; Gorgolewski et al. 2017 |

---

## Step 1 — QSIPrep (preprocessing)

**What we use:** [QSIPrep](https://qsiprep.readthedocs.io/) (`pennlinc/qsiprep:1.0.0`) for BIDS validation, motion correction, denoising, brain extraction, T1w–DWI coregistration, and susceptibility distortion correction (fieldmap TOPUP or SyN).

| Topic | Reference | DOI / link |
|-------|-----------|------------|
| **QSIPrep (required)** | Cieslak M, Cook PA, He X, et al. QSIPrep: an integrative platform for preprocessing and reconstructing diffusion MRI data. *Nature Methods* 2021;18(7):775–778. | [10.1038/s41592-021-01185-5](https://doi.org/10.1038/s41592-021-01185-5) |
| Fieldmap SDC (TOPUP) | Andersson JLR, Skare S, Ashburner J. How to correct susceptibility distortions in spin-echo echo-planar imaging: application to diffusion tensor imaging. *NeuroImage* 2003;20(2):870–888. | [10.1016/S1053-8119(03)00336-7](https://doi.org/10.1016/S1053-8119(03)00336-7) |
| SyN SDC (when no fmap) | Andersson JLR, Graham MS, Zsoldos E, Sotiropoulos SN. Incorporating outlier detection and replacement into a non-parametric framework for movement and distortion correction of diffusion MR images. *NeuroImage* 2016;141:556–572. | [10.1016/j.neuroimage.2016.06.058](https://doi.org/10.1016/j.neuroimage.2016.06.058) |
| Eddy/motion (via QSIPrep) | Andersson JLR, Sotiropoulos SN. An integrated approach to correction for off-resonance effects and subject movement in diffusion MR imaging. *NeuroImage* 2016;125:1063–1078. | [10.1016/j.neuroimage.2015.10.019](https://doi.org/10.1016/j.neuroimage.2015.10.019) |
| Brain extraction (FAST) | Zhang Y, Brady M, Smith S. Segmentation of brain MR images through a hidden Markov random field model and the expectation-maximization algorithm. *IEEE TMI* 2001;20(1):45–57. | [10.1109/42.906424](https://doi.org/10.1109/42.906424) |

**Docs:** [QSIPrep documentation](https://qsiprep.readthedocs.io/) · [Step 1 theory](methods/step1_qsiprep.md) · [Step 1 operations](pipeline_steps.md#step-1-qsiprep)

---

## Step 1.5 — neuroLIT inpainting (optional)

**What we use:** [neuroLIT / FastSurfer-LIT](https://github.com/Deep-MI/lit) (`deepmi/lit:0.6.0`) to inpaint lesion regions on the T1w before cortical reconstruction when a BIDS lesion mask is present.

| Topic | Reference | DOI / link |
|-------|-----------|------------|
| **neuroLIT (required when inpainting)** | Pollak TA, et al. FastSurfer-LIT: Lesion inpainting tool for whole brain MRI segmentation with tumors, cavities and abnormalities. *Imaging Neuroscience* 2025. | [10.1162/imag_a_00446](https://doi.org/10.1162/imag_a_00446) |
| DDPM foundation | Ho J, Jain A, Abbeel P. Denoising diffusion probabilistic models. *NeurIPS* 2020. | [arXiv:2006.11239](https://arxiv.org/abs/2006.11239) |
| VINN layers (resolution-agnostic) | Henschel L, et al. FastSurferVINN: Building resolution-independent deep segmentation networks. *Medical Image Analysis* 2022. | [10.1016/j.media.2022.102313](https://doi.org/10.1016/j.media.2022.102313) |
| Inpainting strategy | Lugmayr A, et al. RePaint: Inpainting using denoising diffusion probabilistic models. *CVPR* 2022. | [10.1109/CVPR52688.2022.01175](https://doi.org/10.1109/CVPR52688.2022.01175) |

**Docs:** [Step 1.5 theory](methods/step1_5_inpaint.md) · [Lesion segmentation](lesion_segmentation.md)

---

## Step 2 — Cortical reconstruction (FreeSurfer / FastSurfer)

**What we use:** FreeSurfer `recon-all` or [FastSurfer](https://github.com/Deep-MI/FastSurfer) to produce DKT parcellation (`aparc.DKTatlas+aseg.mgz`) for Step 4.

| Topic | Reference | DOI / link |
|-------|-----------|------------|
| **FreeSurfer (recon-all)** | Fischl B. FreeSurfer. *NeuroImage* 2012;62(2):782–795. | [10.1016/j.neuroimage.2012.03.001](https://doi.org/10.1016/j.neuroimage.2012.03.001) |
| FreeSurfer cortical reconstruction | Dale AM, Fischl B, Sereno MI. Cortical surface-based analysis I: segmentation and surface reconstruction. *NeuroImage* 1999;9(2):179–194. | [10.1006/nimg.1998.0395](https://doi.org/10.1006/nimg.1998.0395) |
| **FastSurfer** | Henschel L, et al. FastSurfer — A fast and accurate deep learning based neuroimaging pipeline. *NeuroImage* 2020;219:117357. | [10.1016/j.neuroimage.2020.117357](https://doi.org/10.1016/j.neuroimage.2020.117357) |
| **DKT atlas (78 nodes)** | Klein A, Tourville J. 101 labeled brain images and a consistent human cortical labeling protocol. *Frontiers in Neuroscience* 2012;6:171. | [10.3389/fnins.2012.00171](https://doi.org/10.3389/fnins.2012.00171) |
| DK atlas (84 nodes, optional) | Desikan RS, et al. An automated labeling system for subdividing the human cerebral cortex on MRI scans into gyral based regions of interest. *NeuroImage* 2006;31(3):968–980. | [10.1016/j.neuroimage.2006.01.021](https://doi.org/10.1016/j.neuroimage.2006.01.021) |

**Docs:** [Step 2 theory](methods/step2_recon.md) · [Step 2 operations](pipeline_steps.md#step-2-recon)

---

## Step 3 — QSIRecon (tractography)

**What we use:** [QSIRecon](https://qsirecon.readthedocs.io/) with spec `mrtrix_singleshell_ss3t_ACT-hsvs`: single-shell SS3T-CSD, anatomically constrained tractography with hybrid surface/volume segmentation (ACT-HSVS), and SIFT2 weights.

| Topic | Reference | DOI / link |
|-------|-----------|------------|
| **QSIRecon (required)** | Cieslak M, et al. QSIRecon: A robust workflow for reconstructing diffusion MRI data. *bioRxiv* 2024. | [10.1101/2024.05.30.596511](https://doi.org/10.1101/2024.05.30.596511) |
| **MRtrix3 framework** | Tournier JD, et al. MRtrix3: A fast, flexible and open software framework for analysing medical MR diffusion imaging data. *NeuroImage* 2019;202:116137. | [10.1016/j.neuroimage.2019.01.066](https://doi.org/10.1016/j.neuroimage.2019.01.066) |
| SS3T-CSD (single-shell) | Jeurissen B, et al. Multi-tissue constrained spherical deconvolution for improved analysis of multi-shell diffusion MRI data. *NeuroImage* 2014;103:411–426. | [10.1016/j.neuroimage.2014.07.061](https://doi.org/10.1016/j.neuroimage.2014.07.061) |
| ACT tractography | Smith RE, et al. Anatomically-constrained tractography: Improved diffusion MRI streamlines tractography through effective use of anatomical information. *NeuroImage* 2012;62(3):1924–1938. | [10.1016/j.neuroimage.2012.02.004](https://doi.org/10.1016/j.neuroimage.2012.02.004) |
| HSVS segmentation | Smith RE, et al. Hybrid surface/volume segmentation for improved cortical gray matter classification in single voxel diffusion analysis. *NeuroImage* 2020;223:117345. | [10.1016/j.neuroimage.2020.117345](https://doi.org/10.1016/j.neuroimage.2020.117345) |
| **SIFT2 weights** | Smith RE, et al. SIFT2: Enabling dense quantitative assessment of brain white matter connectivity using streamlines tractography. *NeuroImage* 2015;119:338–351. | [10.1016/j.neuroimage.2015.02.069](https://doi.org/10.1016/j.neuroimage.2015.02.069) |

**Docs:** [QSIRecon documentation](https://qsirecon.readthedocs.io/) · [Step 3 theory](methods/step3_qsirecon.md) · [Step 3 operations](pipeline_steps.md#step-3-qsirecon)

---

## Step 4 — DKT structural connectome

**What we use:** Subject-native FreeSurfer DKT labels warped to the DWI reference grid; MRtrix3 `tck2connectome` with streamline **counts** by default (optional SIFT2 weighting).

| Topic | Reference | DOI / link |
|-------|-----------|------------|
| Connectome construction | Tournier JD, et al. MRtrix3 (see Step 3). | [10.1016/j.neuroimage.2019.01.066](https://doi.org/10.1016/j.neuroimage.2019.01.066) |
| SIFT2 weighting (optional) | Smith RE, et al. SIFT2 (see Step 3). | [10.1016/j.neuroimage.2015.02.069](https://doi.org/10.1016/j.neuroimage.2015.02.069) |
| Parcellation (DKT) | Klein & Tourville 2012 (see Step 2). | [10.3389/fnins.2012.00171](https://doi.org/10.3389/fnins.2012.00171) |
| Registration (ANTs) | Avants BB, et al. A reproducible evaluation of ANTs similarity metric performance in brain image registration. *NeuroImage* 2011;54(3):2033–2044. | [10.1016/j.neuroimage.2010.09.025](https://doi.org/10.1016/j.neuroimage.2010.09.025) |
| FreeSurfer label volume | Fischl B, et al. Automatically parcellating the human cerebral cortex. *Cerebral Cortex* 2004;14(1):11–22. | [10.1093/cercor/bhg087](https://doi.org/10.1093/cercor/bhg087) |

**Docs:** [Step 4 theory](methods/step4_connectome.md) · [Outputs](outputs.md) · [Step 4 operations](pipeline_steps.md#step-4-connectome)

---

## Step 4.5 — Disconnectome (optional)

**What we use:** Lesion-aware structural disconnectome with Options A (parcellation excision), B (streamline exclusion), and C (both); disconnection matrix **D = 1 − spared/primary**.

| Topic | Reference | DOI / link |
|-------|-----------|------------|
| **Structural disconnectome (primary)** | Griffis JC, et al. Structural disconnectome mapping in patients with brain injury. *Cell Reports* 2019;29(9):2667–2678.e5. | [10.1016/j.celrep.2019.10.058](https://doi.org/10.1016/j.celrep.2019.10.058) |
| Virtual lesion / disconnection index | Kuceyeski R, et al. The Network Modification (NeMo) Tool: a structural connectivity-based tool for lesion localization. *NeuroImage: Clinical* 2013;2:1–8. | [10.1016/j.nicl.2012.10.003](https://doi.org/10.1016/j.nicl.2012.10.003) |
| Connectome excision literature | Internal synthesis | [Inpainting/connectome_excision_literature.md](https://github.com/phindagijimana/dkt_connectome/blob/main/dwi_pipeline/Inpainting/connectome_excision_literature.md) |

**Docs:** [Step 4.5 theory](methods/step4_5_disconnectome.md) · [Disconnectome](disconnectome.md) · [Integrity QC](integrity_qc.md)

---

## Step 5 — Node strength report

**What we use:** Graph-theory node strength metrics and ENIGMA-style cortical/subcortical reporting from the connectome matrix.

| Topic | Reference | DOI / link |
|-------|-----------|------------|
| **Graph strength metric** | Rubinov M, Sporns O. Complex network measures of brain connectivity: Uses and interpretations. *NeuroImage* 2010;52(3):1059–1069. | [10.1016/j.neuroimage.2009.10.003](https://doi.org/10.1016/j.neuroimage.2009.10.003) |
| Clinical connectomics report (method basis) | Piper RJ, Feng X, et al., Taylor PN. Thalamocortical structural connectivity in children with focal epilepsy. *Epilepsia* 2026;67(4):1901–1915. | [10.1002/epi.70099](https://doi.org/10.1002/epi.70099) |
| ENIGMA consortium (normative context) | Thompson PM, et al. ENIGMA and the individual: Predicting factors that affect the brain in 35 countries worldwide. *NeuroImage* 2020;215:116689. | [10.1016/j.neuroimage.2020.116689](https://doi.org/10.1016/j.neuroimage.2020.116689) |

**Docs:** [Step 5 theory](methods/step5_node_strength.md) · [Step 5 operations](pipeline_steps.md#step-5-node-strength)

---

## Data standards and workflow framework

| Topic | Reference | DOI / link |
|-------|-----------|------------|
| **BIDS** | Gorgolewski KJ, et al. The brain imaging data structure, a format for organizing and describing outputs of neuroimaging experiments. *Scientific Data* 2016;3:160044. | [10.1038/sdata.2016.44](https://doi.org/10.1038/sdata.2016.44) |
| BIDS derivatives | Gorgolewski KJ, et al. BIDS Derivatives. *Scientific Data* 2024 (concept). | [BIDS Derivatives spec](https://bids-specification.readthedocs.io/en/stable/derivations/index.html) |
| **BIDS Apps** | Gorgolewski KJ, et al. BIDS apps: Improving ease of use, accessibility, and reproducibility of neuroimaging data analysis methods. *PLOS Computational Biology* 2017;13(3):e1005209. | [10.1371/journal.pcbi.1005209](https://doi.org/10.1371/journal.pcbi.1005209) |
| Snakemake workflow engine | Köster J, Rahmann S. Snakemake — a scalable bioinformatics workflow engine. *Bioinformatics* 2012;28(14):1900–1902. | [10.1093/bioinformatics/bts480](https://doi.org/10.1093/bioinformatics/bts480) |
| Reproducible containers | Nüst D, et al. Ten simple rules for writing Dockerfiles for reproducible data science. *PLOS Computational Biology* 2020;16(11):e1008316. | [10.1371/journal.pcbi.1008316](https://doi.org/10.1371/journal.pcbi.1008316) |

---

## Sample tutorial data — IDEAS II (OpenNeuro)

**What we ship:** a two-subject BIDS subset (`sub-1`, `sub-6`) downloaded from [OpenNeuro ds007401](https://openneuro.org/datasets/ds007401) via [`scripts/download_ideas_sample.sh`](https://github.com/phindagijimana/dkt_connectome/blob/main/dwi_pipeline/scripts/download_ideas_sample.sh). NIfTI files are gitignored; provenance READMEs are tracked under `sample_data/ideas/`.

| Topic | Reference | DOI / link |
|-------|-----------|------------|
| **IDEAS II (required when using sample DWI)** | Taylor PN, Hall G, Horsley J, Wang Y, Vos SB, Winston GP, McEvoy AW, Miserocchi A, de Tisi J, Duncan JS. Open diffusion magnetic resonance imaging and connectivity data for epilepsy and surgery: The IDEAS II release. *Epilepsia* 2026;67(6):2912–2923. | [10.1002/epi.70186](https://doi.org/10.1002/epi.70186) |
| OpenNeuro dataset record | Same release on OpenNeuro (ds007401) | [10.18112/openneuro.ds007401.v1.0.0](https://doi.org/10.18112/openneuro.ds007401.v1.0.0) |
| IDEAS I (T1w/FLAIR + outcomes; same subject IDs) | Taylor PN, et al. Open MRI data for epilepsy and surgery: The IDEAS release. *Epilepsia* 2025. | [10.1111/epi.18192](https://doi.org/10.1111/epi.18192) |
| CNNP Lab data index | IDEAS / IDEAS II landing page | [CNNP Lab IDEAS data](https://sites.google.com/view/cnnp-lab//ideas-data) |

**Docs:** [Sample data (IDEAS II)](datasets/ideas.md) · [Tutorial](tutorial.md)

---

## TBI / clinical context (optional)

These resources informed cohort design and QC; cite separately when discussing TBI outcomes or study populations.

| Resource | Link |
|----------|------|
| TRACK-TBI study | [tracktbi.ucsf.edu](https://tracktbi.ucsf.edu/) |
| Maas et al. 2022 Lancet Neurology TRACK-TBI review | [10.1016/S1474-4422(22)00309-X](https://doi.org/10.1016/S1474-4422(22)00309-X) |
| Hayes et al. 2016 TBI connectivity review | [10.1017/S1355617715000740](https://doi.org/10.1017/S1355617715000740) |

---

## Internal deep-dive

For implementation-level method notes (warp chains, QC thresholds, container pins), see [pipeline_science.md](https://github.com/phindagijimana/dkt_connectome/blob/main/dwi_pipeline/pipeline_science.md) in the repository.
