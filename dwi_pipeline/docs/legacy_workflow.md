# Legacy root workflow (4-stage dk_connectome)

The **canonical DKT Connectome** (Steps 1–5 + optional 4.5 disconnectome + inpainting) lives under:

**[`dwi_pipeline/workflow/`](https://github.com/phindagijimana/dkt_connectome/tree/main/dwi_pipeline/workflow)**

Use:

- BIDS App: [`dwi_pipeline/run`](https://github.com/phindagijimana/dkt_connectome/blob/main/dwi_pipeline/run)
- Snakemake: [`dwi_pipeline/workflow/Snakefile`](https://github.com/phindagijimana/dkt_connectome/blob/main/dwi_pipeline/workflow/Snakefile)
- HPC: [`dwi_pipeline/submit.sh`](https://github.com/phindagijimana/dkt_connectome/blob/main/dwi_pipeline/submit.sh) with `PIPELINE_ENGINE=snakemake` (default)

---

## What remains at the repository root

| Path | Purpose |
|------|---------|
| [`Snakefile`](https://github.com/phindagijimana/dkt_connectome/blob/main/Snakefile) | Original **4-stage** plugin workflow (qsiprep → recon → qsirecon → connectome) |
| [`plugins/`](https://github.com/phindagijimana/dkt_connectome/tree/main/plugins) | Stage plugins for the root Snakefile |
| [`.dockstore.yml`](https://github.com/phindagijimana/dkt_connectome/blob/main/.dockstore.yml) | Registers both canonical and legacy workflows |
| [`workflowhub.yml`](https://github.com/phindagijimana/dkt_connectome/blob/main/workflowhub.yml) | WorkflowHub metadata |

This stack does **not** include:

- Step 1.5 neuroLIT inpainting
- Step 5 node-strength / ENIGMA report
- Step 4.5 disconnectome
- Session-filter / multi-session handling in `dwi_pipeline/run`

---

## Migration

For new cohort work, use [index.md](index.md).

The root workflow remains for backward compatibility with published `dk-connectome` container demos and Dockstore entries. **Dockstore** registers both workflows:

| Dockstore name | Snakefile | Status |
|----------------|-----------|--------|
| `dkt_connectome` | `dwi_pipeline/workflow/Snakefile` | **Primary** |
| `dk_connectome` | root `Snakefile` | Legacy |

See [`.dockstore.yml`](https://github.com/phindagijimana/dkt_connectome/blob/main/.dockstore.yml) and [`workflowhub.yml`](https://github.com/phindagijimana/dkt_connectome/blob/main/workflowhub.yml).

---

## Cohort post-processing (existing RESULTS_ROOT)

After Slurm array jobs finish, run group-level QC + BIDS export without reprocessing:

```bash
export RESULTS_ROOT=/path/to/cohort_output
export BIDS_DIR=/path/to/BIDS
bash dwi_pipeline/scripts/batch_postprocess.sh
```

Same as `./run BIDS OUT group`.
