# DKT Connectome

**BIDS App** for lesion-aware structural connectomics: QSIPrep → optional neuroLIT inpainting → FreeSurfer/FastSurfer → QSIRecon ACT-HSVS tractography → DKT connectome → optional disconnectome → node-strength report.

The pipeline is **study-agnostic** — it runs on any BIDS DWI dataset with optional lesion masks. Primary validation cohorts include the **TRACK-TBI study (~14 centers)** and **URMC clinical MRI**; those are data sources, not the pipeline name.

**Hosted site:** [dkt-connectome.readthedocs.io](https://dkt-connectome.readthedocs.io/en/latest/)

![DKT Connectome pipeline overview](img/pipeline_overview.svg)

---

## About

The DKT Connectome is a **BIDS App orchestrator** for lesion-aware structural connectomics. Main features:

1. **BIDS-native workflow** — participant-level runs from standard `dwi/`, `anat/T1w`, and optional `fmap/` inputs.
2. **QSIPrep preprocessing** — motion correction, denoising, brain extraction, T1w–DWI coregistration, and susceptibility distortion correction (fieldmap TOPUP or SyN).
3. **Optional lesion inpainting (Step 1.5)** — neuroLIT fills lesion regions on T1w before cortical reconstruction when a BIDS lesion mask is present.
4. **Cortical reconstruction** — FreeSurfer `recon-all` or FastSurfer → DKT parcellation for connectome nodes.
5. **QSIRecon tractography** — single-shell SS3T-CSD with ACT-HSVS and SIFT2 weights.
6. **DKT structural connectome** — 78-node matrix (default: streamline counts).
7. **Optional disconnectome (Step 4.5)** — parcellation excision, streamline exclusion, and disconnection matrix when `--disconnection` is passed and a lesion mask exists.
8. **Node-strength report** — graph metrics and ENIGMA-style cortical/subcortical panel.

---

## Note

This pipeline **orchestrates** [QSIPrep](https://qsiprep.readthedocs.io/), [QSIRecon](https://qsirecon.readthedocs.io/), FreeSurfer/FastSurfer, MRtrix3, neuroLIT, and other upstream tools. Similarities in workflow design or documentation layout **do not imply** that PennLINC, Deep-MI, FreeSurfer, or any upstream authors endorse this software or its processing choices. Always cite the primary method papers — see [References by step](references.md).

---

## Pipeline overview

```text
Step 1    QSIPrep           DWI + T1w preprocessing, SDC (fmap or SyN)
Step 1.5  Inpaint (auto)    neuroLIT lesion fill when BIDS lesion mask exists
Step 2    Recon             FreeSurfer or FastSurfer → DKT parcellation
Step 3    QSIRecon          SS3T-CSD, ACT-HSVS tractography, SIFT2 weights
Step 4    Connectome        DKT 78-node matrix (default: streamline counts)
Step 4.5  Disconnectome     Options A/B/C + disconnection matrix (--disconnection flag)
Step 5    Node strength     ENIGMA-style report (auto after Step 4)
```

Operational detail: [Pipeline steps](pipeline_steps.md) · Theory: [Methods](methods/index.md) · Developer notes: [pipeline_science.md](https://github.com/phindagijimana/dkt_connectome/blob/main/dwi_pipeline/pipeline_science.md).

---

## Before your first run

**FreeSurfer license (required):** This pipeline does not ship a license. Each user registers at [FreeSurfer](https://surfer.nmr.mgh.harvard.edu/registration.html), saves `license.txt`, and exports:

```bash
export FS_LICENSE=/path/to/your/license.txt
```

Full steps: [Installation → FreeSurfer license](installation.md#freesurfer-license-you-must-obtain-this).

---

## Quick start

**New users:** follow the [Tutorial](tutorial.md) with [IDEAS sample data](datasets/ideas.md) or bundled TBI test outputs.

```bash
cd dwi_pipeline
./run /path/to/BIDS /path/to/derivatives participant \
  --participant-label 009 \
  --session-filter ses-1 \
  --n-cpus 8
```

HPC / Slurm:

```bash
export BIDS_DIR=/path/to/BIDS
export RESULTS_ROOT=/path/to/results
bash dwi_pipeline/submit.sh
```

---

## Help

- [FAQ](faq.md) · [Troubleshooting](troubleshooting.md)
- [GitHub Issues](https://github.com/phindagijimana/dkt_connectome/issues)
- [NeuroStars](https://neurostars.org/) (tag `qsiprep`, `qsirecon`, or link this repo)
