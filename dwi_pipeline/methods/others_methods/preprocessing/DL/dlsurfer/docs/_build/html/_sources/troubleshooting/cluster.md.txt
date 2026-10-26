# Cluster notes

- Source `env/cluster_containers.sh` in every job script.  
- Prefer `SLURM_SUBMIT_DIR` over `$0` (SLURM spool paths break relative `source`).  
- Bind `/mnt/nfs` (or your data roots) in Apptainer wrappers.  
- LIT on CPU can take **days** — use GPU for fill.  
- Job examples: `hpc/sbatch_*.sh`. Ops checklist: [lab/LIVE_RUNS.md](../lab/LIVE_RUNS.md).
