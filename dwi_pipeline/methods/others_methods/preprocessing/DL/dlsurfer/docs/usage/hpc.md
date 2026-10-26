# Devices and HPC

## Device

| `--device` | Use |
|-----------|-----|
| `auto` | Prefer CUDA if `nvidia-smi` present |
| `cuda` | Force GPU for VINN / LIT |
| `cpu` | CPU (TopoFit on FS 7.4.1 SIF recommended here) |

FastSurfer on small GPUs:

```bash
--batch-size 1 --viewagg-device cpu
```

(CLI flag maps to FastSurfer **`--batch`**, not `--batch_size`.)

## Split jobs

`core` / `core-lesion` plan **`--seg_only`** (GPU) then **`--surf_only`** (CPU). Example SLURM scripts live under `hpc/`.

```bash
sbatch hpc/sbatch_eg_gpu_core_lesion.sh
sbatch hpc/sbatch_phase3_topofit_tbi_lit.sh
```

Optional planner flag: `--hpc srun|brun` for FastSurfer’s bundled launchers.
