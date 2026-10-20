#!/bin/bash
# V2 CPU smoke. Code check only. Not a posterior. Not hat{U}.
#SBATCH --job-name=uhat_V2_smoke
#SBATCH --partition=interactive
#SBATCH --time=01:00:00
#SBATCH --cpus-per-task=4
#SBATCH --mem=16G
#SBATCH --exclude=smdodwork05
#SBATCH --output=/mnt/nfs/home/urmc-sh.rochester.edu/pndagiji/Documents/TrackTBI-Sub/dwi_pipeline/methods/mapping_uhat/work/V2/logs/smoke_%j.out
#SBATCH --error=/mnt/nfs/home/urmc-sh.rochester.edu/pndagiji/Documents/TrackTBI-Sub/dwi_pipeline/methods/mapping_uhat/work/V2/logs/smoke_%j.err
set -euo pipefail
UHAT=/mnt/nfs/home/urmc-sh.rochester.edu/pndagiji/Documents/TrackTBI-Sub/dwi_pipeline/methods/mapping_uhat
VENV="${UHAT}/work/V2/venv/bin/python"
mkdir -p "${UHAT}/work/V2/logs" "${UHAT}/work/V2/smoke"
echo "[SMOKE] host=$(hostname) job=${SLURM_JOB_ID:-none} $(date -Is)"
"${VENV}" -u "${UHAT}/v2_cpu_smoke.py"
echo "[SMOKE] done $(date -Is)"
