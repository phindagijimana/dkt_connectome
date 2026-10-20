#!/bin/bash
# C2 per-endpoint soft radial_4 under measured V1 sigma. Planted y only. Not hat{U}.
#SBATCH --job-name=uhat_C2_soft
#SBATCH --partition=interactive
#SBATCH --time=06:00:00
#SBATCH --cpus-per-task=4
#SBATCH --mem=48G
#SBATCH --array=1-6
#SBATCH --exclude=smdodwork05
#SBATCH --output=/mnt/nfs/home/urmc-sh.rochester.edu/pndagiji/Documents/TrackTBI-Sub/dwi_pipeline/methods/mapping_uhat/work/C2/logs/C2_%A_%a.out
#SBATCH --error=/mnt/nfs/home/urmc-sh.rochester.edu/pndagiji/Documents/TrackTBI-Sub/dwi_pipeline/methods/mapping_uhat/work/C2/logs/C2_%A_%a.err
set -euo pipefail
UHAT=/mnt/nfs/home/urmc-sh.rochester.edu/pndagiji/Documents/TrackTBI-Sub/dwi_pipeline/methods/mapping_uhat
SESSIONS=(
  ideas-sub-1-ses-1
  ideas-sub-6-ses-1
  btc-sub-PAT20-ses-preop
  tbi-011011-neurolit-lesion
  tbi-011021-neurolit-lesion
  tbi-011204-neurolit-lesion
)
SID="${SESSIONS[$((SLURM_ARRAY_TASK_ID - 1))]}"
export OMP_NUM_THREADS="${SLURM_CPUS_PER_TASK:-4}"
mkdir -p "${UHAT}/work/C2/logs"
echo "[C2] task=${SLURM_ARRAY_TASK_ID} session=${SID} $(date -Is)"
python3 -u "${UHAT}/c2_soft.py" --session-id "${SID}" ${C2_EXTRA:-}
echo "[C2] done ${SID} $(date -Is)"
