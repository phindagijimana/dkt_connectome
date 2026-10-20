#!/bin/bash
# P1 baselines + cut sensitivity for locked U (planted 1 mm). Descriptive. Not hat{U}.
#SBATCH --job-name=uhat_P1_base
#SBATCH --partition=interactive
#SBATCH --time=02:00:00
#SBATCH --cpus-per-task=4
#SBATCH --mem=48G
#SBATCH --exclude=smdodwork05
#SBATCH --output=/mnt/nfs/home/urmc-sh.rochester.edu/pndagiji/Documents/TrackTBI-Sub/dwi_pipeline/methods/mapping_uhat/work/P1/logs/P1_%j.out
#SBATCH --error=/mnt/nfs/home/urmc-sh.rochester.edu/pndagiji/Documents/TrackTBI-Sub/dwi_pipeline/methods/mapping_uhat/work/P1/logs/P1_%j.err
set -euo pipefail
UHAT=/mnt/nfs/home/urmc-sh.rochester.edu/pndagiji/Documents/TrackTBI-Sub/dwi_pipeline/methods/mapping_uhat
export OMP_NUM_THREADS="${SLURM_CPUS_PER_TASK:-4}"
python3 -u "${UHAT}/p1_baselines.py"
