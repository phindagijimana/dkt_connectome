#!/bin/bash
# L leftover-sized label plant. Held-out TBI only. Not hat{U}.
#SBATCH --job-name=uhat_L_plant
#SBATCH --partition=interactive
#SBATCH --time=04:00:00
#SBATCH --cpus-per-task=4
#SBATCH --mem=32G
#SBATCH --array=1-3
#SBATCH --exclude=smdodwork05
#SBATCH --output=/mnt/nfs/home/urmc-sh.rochester.edu/pndagiji/Documents/TrackTBI-Sub/dwi_pipeline/methods/mapping_uhat/work/L/logs/L_%A_%a.out
#SBATCH --error=/mnt/nfs/home/urmc-sh.rochester.edu/pndagiji/Documents/TrackTBI-Sub/dwi_pipeline/methods/mapping_uhat/work/L/logs/L_%A_%a.err
set -euo pipefail
UHAT=/mnt/nfs/home/urmc-sh.rochester.edu/pndagiji/Documents/TrackTBI-Sub/dwi_pipeline/methods/mapping_uhat
LIST="${UHAT}/work/L/sessions.txt"
SID="$(sed -n "${SLURM_ARRAY_TASK_ID}p" "${LIST}")"
export OMP_NUM_THREADS="${SLURM_CPUS_PER_TASK:-4}"
mkdir -p "${UHAT}/work/L/logs"
echo "[L] task=${SLURM_ARRAY_TASK_ID} session=${SID} $(date -Is)"
python3 -u "${UHAT}/l_plant.py" --session-id "${SID}"
echo "[L] done ${SID} $(date -Is)"
