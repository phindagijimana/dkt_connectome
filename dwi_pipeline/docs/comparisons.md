# Comparisons to other pipelines

How the DKT Connectome relates to other BIDS Apps and connectome tools.

---

## vs QSIPrep / QSIRecon alone

| | QSIPrep + QSIRecon | DKT Connectome |
|--|-------------------|----------------|
| Scope | Preprocessing + reconstruction | Full connectome through DKT matrix + optional disconnectome |
| Parcellation | Atlas connectomes (e.g. 4S156) | **DKT 78-node** structural connectome (Step 4) |
| Lesion handling | Cost-function masking only | Inpainting (1.5) + disconnectome (4.5) |
| Output | `derivatives/qsiprep`, `qsirecon` | Custom `RESULTS_ROOT` + optional BIDS export |

This pipeline **uses** QSIPrep and QSIRecon as Steps 1 and 3.

---

## vs MRtrix3_connectome (BIDS App)

| | MRtrix3_connectome | DKT Connectome |
|--|-------------------|----------------|
| Tractography | User-supplied or built-in | ACT-HSVS via QSIRecon |
| Parcellation | User atlas | DKT (FreeSurfer/FastSurfer) |
| Lesion / TBI | Not built-in | Inpaint + disconnectome |
| Containers | Single MRtrix3 image | Multi-container orchestrator |

---

## vs connectomemapper3 / micapipe

| | connectomemapper3 / micapipe | DKT Connectome |
|--|------------------------------|----------------|
| Focus | General multi-modal connectomics | Lesion-aware structural connectome + disconnectome |
| Lesion inpainting | No | neuroLIT Step 1.5 |
| Disconnection index | No | Step 4.5 (Griffis-style) |
| HPC | Docker-first | Apptainer + Slurm native |

---

## vs legacy root `dk_connectome` (this repo only)

> **New work:** use [`dwi_pipeline/run`](https://github.com/phindagijimana/dkt_connectome/blob/main/dwi_pipeline/run) and [`dwi_pipeline/workflow/Snakefile`](https://github.com/phindagijimana/dkt_connectome/tree/main/dwi_pipeline/workflow) only.

The repository root still ships an older **4-stage** Snakefile (`qsiprep → recon → qsirecon → connectome`) for Dockstore backward compatibility (`.dockstore.yml` entry `dk_connectome`). It has no inpainting, disconnectome, node strength, or BIDS App `./run`. Do not start new cohorts on the root workflow; it may be removed in a future release (see [readiness checklist on GitHub](https://github.com/phindagijimana/dkt_connectome/blob/main/dwi_pipeline/docs/maintainer/readiness_checklist.md) P3.3).

---

## When to use this pipeline

**Good fit:**

- BIDS DWI + T1w cohorts needing DKT structural connectomes
- Studies with manual lesion masks and disconnectome analysis
- HPC sites with cached QSIPrep / FreeSurfer Apptainer images

**Consider alternatives:**

- Need only preprocessing → [QSIPrep](https://qsiprep.readthedocs.io/) alone
- Need only tractography + custom atlas → [QSIRecon](https://qsirecon.readthedocs.io/) alone
- Need single Docker pull, no HPC → micapipe, connectomemapper3, or a monolithic image (not yet published for this pipeline)
