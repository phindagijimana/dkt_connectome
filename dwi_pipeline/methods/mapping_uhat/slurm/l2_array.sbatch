#!/bin/bash
# L2 leftover-sized endpoint plant. Same (t,ehat) as L. Not hat{U}.
#SBATCH --job-name=uhat_L2_plant
#SBATCH --partition=interactive
#SBATCH --time=04:00:00
#SBATCH --cpus-per-task=4
#SBATCH --mem=32G
#SBATCH --array=1-3
#SBATCH --exclude=smdodwork05
#SBATCH --output=/mnt/nfs/home/urmc-sh.rochester.edu/pndagiji/Documents/TrackTBI-Sub/dwi_pipeline/methods/mapping_uhat/work/L2/logs/L2_%A_%a.out
#SBATCH --error=/mnt/nfs/home/urmc-sh.rochester.edu/pndagiji/Documents/TrackTBI-Sub/dwi_pipeline/methods/mapping_uhat/work/L2/logs/L2_%A_%a.err
set -euo pipefail
UHAT=/mnt/nfs/home/urmc-sh.rochester.edu/pndagiji/Documents/TrackTBI-Sub/dwi_pipeline/methods/mapping_uhat
LIST="${UHAT}/work/L/sessions.txt"
SID="$(sed -n "${SLURM_ARRAY_TASK_ID}p" "${LIST}")"
export OMP_NUM_THREADS="${SLURM_CPUS_PER_TASK:-4}"
mkdir -p "${UHAT}/work/L2/logs"
echo "[L2] task=${SLURM_ARRAY_TASK_ID} session=${SID} $(date -Is)"
python3 -u "${UHAT}/l2_plant.py" --session-id "${SID}"
echo "[L2] done ${SID} $(date -Is)"
