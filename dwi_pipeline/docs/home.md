---
orphan: true
---

# DKT Connectome

**BIDS App** for **lesion-aware structural connectomics** — from raw diffusion MRI to DKT connectomes and optional disconnectome mapping.

The pipeline is **study-agnostic** (any BIDS DWI + T1w cohort). It was developed and validated in **TBI** settings where manual lesion masks and explicit distortion correction matter.

**Hosted site:** [dkt-connectome.readthedocs.io](https://dkt-connectome.readthedocs.io/en/latest/)

![DKT Connectome pipeline workflow](img/pipeline_overview.svg)

---

## Start here

| If you want… | Read… |
|--------------|--------|
| **Why** the workflow exists (science, lesions, SDC) | [How it works — science & theory](science_overview.md) |
| **First run** (install, tutorial, sample data) | [Installation](installation.md) → [Tutorial](tutorial.md) |
| **Prepare BIDS** (fieldmaps, masks, sidecars) | [Preparing your data](preparing_data.md) |
| **Run** (`./run`, HPC, flags) | [Usage](usage.md) · [BIDS App spec](bids_app.md) |
| **Methods & citations** | [Methods overview](methods/index.md) · [References](references.md) |

```{note} Upstream tools
This pipeline **orchestrates** [QSIPrep](https://qsiprep.readthedocs.io/), [QSIRecon](https://qsirecon.readthedocs.io/), FreeSurfer/FastSurfer, MRtrix3, and neuroLIT. Cite the primary method papers — [References by step](references.md).
```

---

## Before your first run

Each user needs a **FreeSurfer license** (not shipped with the app):

```bash
export FS_LICENSE=/path/to/your/license.txt
```

Register at [FreeSurfer](https://surfer.nmr.mgh.harvard.edu/registration.html) — full steps: [Installation → FreeSurfer license](installation.md#freesurfer-license-you-must-obtain-this).

---

## Quick start

**New users:** [Tutorial](tutorial.md) with [IDEAS sample data](datasets/ideas.md) or bundled TBI test outputs.

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

## Contact

<a id="contact"></a>

- **GitHub:** [github.com/phindagijimana/dkt_connectome](https://github.com/phindagijimana/dkt_connectome) · [open an issue](https://github.com/phindagijimana/dkt_connectome/issues)
- **Email:** [phindagiji@gmail.com](mailto:phindagiji@gmail.com)

For usage questions, also see [FAQ](faq.md) and [NeuroStars](https://neurostars.org/) (tag `qsiprep`, `qsirecon`, or link this repo).

---

## Help

- [FAQ](faq.md) · [Troubleshooting](troubleshooting.md)
