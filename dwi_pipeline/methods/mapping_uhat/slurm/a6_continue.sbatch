#!/bin/bash
# Overnight continue if the first 12 h dies. Skips finished C*.npy. Not hat{U}.
#SBATCH --job-name=uhat_w3_a6c
#SBATCH --partition=interactive
#SBATCH --time=12:00:00
#SBATCH --cpus-per-task=4
#SBATCH --mem=32G
#SBATCH --array=1-6
#SBATCH --exclude=smdodwork05
#SBATCH --output=/mnt/nfs/home/urmc-sh.rochester.edu/pndagiji/Documents/TrackTBI-Sub/dwi_pipeline/methods/mapping_uhat/work/a6/logs/a6c_%A_%a.out
#SBATCH --error=/mnt/nfs/home/urmc-sh.rochester.edu/pndagiji/Documents/TrackTBI-Sub/dwi_pipeline/methods/mapping_uhat/work/a6/logs/a6c_%A_%a.err
set -euo pipefail
UHAT=/mnt/nfs/home/urmc-sh.rochester.edu/pndagiji/Documents/TrackTBI-Sub/dwi_pipeline/methods/mapping_uhat
LIST="${UHAT}/work/a6_sessions.txt"
SID="$(sed -n "${SLURM_ARRAY_TASK_ID}p" "${LIST}")"
export OMP_NUM_THREADS="${SLURM_CPUS_PER_TASK:-4}"
export ITK_GLOBAL_DEFAULT_NUMBER_OF_THREADS="${OMP_NUM_THREADS}"
mkdir -p "${UHAT}/work/a6/logs"
echo "[A6c] task=${SLURM_ARRAY_TASK_ID} session=${SID} $(date -Is)"
python3 -u "${UHAT}/a6_labels.py" --session-id "${SID}" --skip-if-done
echo "[A6c] done ${SID} $(date -Is)"
