#!/bin/bash
# Retest pack on run-1: U, calibrated U, C2 leakage. No leftover numbers (exam is separate and gated). Not hat{U}.
#SBATCH --job-name=uhat_R_pack
#SBATCH --partition=general
#SBATCH --time=1-00:00:00
#SBATCH --cpus-per-task=4
#SBATCH --mem=48G
#SBATCH --exclude=smdodwork05
#SBATCH --output=/mnt/nfs/home/urmc-sh.rochester.edu/pndagiji/Documents/TrackTBI-Sub/dwi_pipeline/methods/mapping_uhat/work/R/logs/R_%j.out
#SBATCH --error=/mnt/nfs/home/urmc-sh.rochester.edu/pndagiji/Documents/TrackTBI-Sub/dwi_pipeline/methods/mapping_uhat/work/R/logs/R_%j.err
set -euo pipefail
UHAT=/mnt/nfs/home/urmc-sh.rochester.edu/pndagiji/Documents/TrackTBI-Sub/dwi_pipeline/methods/mapping_uhat
export OMP_NUM_THREADS="${SLURM_CPUS_PER_TASK:-4}"
: "${RETEST_DATASET:?}" "${RETEST_SID:?}"
python3 -u "${UHAT}/retest_pack.py" --dataset "${RETEST_DATASET}" --subject "${RETEST_SID}" --session 1
