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

## vs legacy root `dk_connectome` (this repo)

The **canonical** pipeline lives under [`dwi_pipeline/workflow/`](https://github.com/phindagijimana/dkt_connectome/tree/main/dwi_pipeline/workflow). Use it for all new cohort work:

- BIDS App: [`dwi_pipeline/run`](https://github.com/phindagijimana/dkt_connectome/blob/main/dwi_pipeline/run)
- Snakemake: [`workflow/Snakefile`](https://github.com/phindagijimana/dkt_connectome/blob/main/dwi_pipeline/workflow/Snakefile)
- HPC: [`submit.sh`](https://github.com/phindagijimana/dkt_connectome/blob/main/dwi_pipeline/submit.sh)

The **repository root** still contains the original **4-stage** plugin workflow:

| Path | Purpose |
|------|---------|
| [`Snakefile`](https://github.com/phindagijimana/dkt_connectome/blob/main/Snakefile) | qsiprep → recon → qsirecon → connectome only |
| [`plugins/`](https://github.com/phindagijimana/dkt_connectome/tree/main/plugins) | Stage plugins for the root Snakefile |
| [`.dockstore.yml`](https://github.com/phindagijimana/dkt_connectome/blob/main/.dockstore.yml) | Registers both canonical and legacy workflows |

The root stack does **not** include Step 1.5 inpainting, Step 5 node strength, Step 4.5 disconnectome, or the full `./run` BIDS App surface.

**Dockstore / WorkflowHub:**

| Name | Snakefile | Status |
|------|-----------|--------|
| `dkt_connectome` | `dwi_pipeline/workflow/Snakefile` | **Primary** |
| `dk_connectome` | root `Snakefile` | Legacy |

After Slurm array jobs on an existing `RESULTS_ROOT`, cohort QC + BIDS export without reprocessing:

```bash
bash dwi_pipeline/scripts/batch_postprocess.sh
# same as: ./run BIDS OUT group
```

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
