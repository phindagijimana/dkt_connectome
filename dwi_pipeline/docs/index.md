# DKT Connectome

**BIDS App** for lesion-aware structural connectomics: QSIPrep → optional neuroLIT inpainting → FreeSurfer/FastSurfer → QSIRecon ACT-HSVS tractography → DKT connectome → optional disconnectome → node-strength report.

The pipeline is **study-agnostic** — it runs on any BIDS DWI dataset with optional lesion masks. Primary validation cohorts include the **TRACK-TBI study (~14 centers)** and **URMC clinical MRI** (including CIDUR); those are data sources, not the pipeline name.

This documentation follows the layout of [QSIPrep](https://qsiprep.readthedocs.io/) — installation, quick start, usage, outputs, and method-specific pages.

**Hosted site:** [dkt-connectome.readthedocs.io](https://dkt-connectome.readthedocs.io/en/latest/)

---

## About

The DKT Connectome is a **BIDS App orchestrator** for lesion-aware structural connectomics. Main features:

1. **BIDS-native workflow** — participant-level runs from standard `dwi/`, `anat/T1w`, and optional `fmap/` inputs.
2. **QSIPrep preprocessing** — motion correction, denoising, brain extraction, T1w–DWI coregistration, and susceptibility distortion correction (fieldmap TOPUP or SyN).
3. **Optional lesion inpainting (Step 1.5)** — neuroLIT fills lesion regions on T1w before cortical reconstruction when a BIDS lesion mask is present.
4. **Cortical reconstruction** — FreeSurfer `recon-all` or FastSurfer → DKT parcellation for connectome nodes.
5. **QSIRecon tractography** — single-shell SS3T-CSD with ACT-HSVS and SIFT2 weights (`mrtrix_singleshell_ss3t_ACT-hsvs`).
6. **DKT structural connectome** — 78-node matrix (default: streamline counts).
7. **Optional disconnectome (Step 4.5)** — parcellation excision, streamline exclusion, and disconnection matrix when `--disconnection` is passed and a lesion mask exists.
8. **Node-strength report** — graph metrics and ENIGMA-style cortical/subcortical panel.

Validated on the **TRACK-TBI study (~14 centers)** and **URMC clinical MRI** cohorts; the pipeline itself is study-agnostic.

---

## Note

This pipeline **orchestrates** [QSIPrep](https://qsiprep.readthedocs.io/), [QSIRecon](https://qsirecon.readthedocs.io/), FreeSurfer/FastSurfer, MRtrix3, neuroLIT, and other upstream tools. Similarities in workflow design or documentation layout **do not imply** that PennLINC, Deep-MI, FreeSurfer, or any upstream authors endorse this software or its processing choices. Always cite the primary method papers — see [References by step](references.md).

---

## Contents

| Page | Description |
|------|-------------|
| [Installation](installation.md) | Requirements, Apptainer images, licenses, config |
| [Containers](containers.md) | All step `.sif` images and env vars |
| [Quick start](quickstart.md) | First run in three commands |
| [Usage](usage.md) | Full command-line reference (QSIPrep-style) |
| [Preparing your data](preparing_data.md) | BIDS inputs, SDC, lesion masks |
| [Pipeline steps](pipeline_steps.md) | What happens in each step |
| [Snakemake workflow](snakemake_workflow.md) | Full DAG engine (`workflow/Snakefile`, all `target_*` rules) |
| [BIDS App](bids_app.md) | `./run <bids> <out> participant` — official entrypoint |
| [Configuration](configuration.md) | Config keys, env vars, container paths |
| [Outputs](outputs.md) | Derivatives layout under `RESULTS_ROOT` |
| [Derivatives policy](derivatives.md) | BIDS export, container pins, provenance |
| [FAQ](faq.md) | Common questions |
| [Troubleshooting](troubleshooting.md) | Errors and fixes |
| [Preprocessing inputs](preprocessing.md) | BIDS repair, fieldmaps, dwi-select |
| [Disconnectome (Step 4.5)](disconnectome.md) | Options A/B/C, disconnection matrix |
| [QC dashboard](qc_dashboard.md) | Unified HTML QC (Steps 1-5) |
| [Lesion segmentation](lesion_segmentation.md) | Manual masks, inpainting, excision index |
| [Integrity QC](integrity_qc.md) | Connectome / disconnectome sanity checks |
| [Legacy root workflow](legacy_workflow.md) | Root 4-stage Snakefile vs `dwi_pipeline/workflow` |
| [Comparisons](comparisons.md) | vs QSIPrep, MRtrix3_connectome, micapipe |
| [References by step](references.md) | Papers and resources for each pipeline step |
| [Citation](citation.md) | Acknowledgements, BibTeX, and how to cite |
| [License](license.md) | Apache 2.0 and upstream licenses |
| [Changelog](changelog.md) | Version history (v0.2.0) |
| [Getting help](getting_help.md) | GitHub issues, NeuroStars, upstream docs |

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

See also the developer-oriented [README.md](https://github.com/phindagijimana/dkt_connectome/blob/main/dwi_pipeline/README.md) and science notes in [pipeline_science.md](https://github.com/phindagijimana/dkt_connectome/blob/main/dwi_pipeline/pipeline_science.md).

---

## Quick start (BIDS App)

From the repository root:

```bash
cd dwi_pipeline
./run /path/to/BIDS /path/to/derivatives participant \
  --participant-label 009 \
  --session-filter ses-1 \
  --n-cpus 8
```

## Quick start (HPC / `subject.sh`)

```bash
export BIDS_DIR=/path/to/CIDUR_BIDS/data_bids
export RESULTS_ROOT=/path/to/results
bash dwi_pipeline/subject.sh all 009 --session-filter ses-1
```

---

## Related documentation (outside `docs/`)

| Resource | Link |
|----------|------|
| Full Step 4.5 method | [Inpainting/disconnection.md](https://github.com/phindagijimana/dkt_connectome/blob/main/dwi_pipeline/Inpainting/disconnection.md) |
| Lesion mask index | [Inpainting/lesion_masks.md](https://github.com/phindagijimana/dkt_connectome/blob/main/dwi_pipeline/Inpainting/lesion_masks.md) |
| BIDS PE metadata | [bids.md](https://github.com/phindagijimana/dkt_connectome/blob/main/bids.md) |
| Field maps / SDC | [fmaps.md](https://github.com/phindagijimana/dkt_connectome/blob/main/fmaps.md) |
| Step 4 container | [containers/connectome/README.md](https://github.com/phindagijimana/dkt_connectome/blob/main/dwi_pipeline/containers/connectome/README.md) |
| Step 1.5 container | [containers/lit/README.md](https://github.com/phindagijimana/dkt_connectome/blob/main/dwi_pipeline/containers/lit/README.md) |
| TBI test data layout | [dwi_test_TBI/README.md](https://github.com/phindagijimana/dkt_connectome/blob/main/dwi_pipeline/dwi_test_TBI/README.md) |
