#!/bin/bash
# Standalone package vs frozen U / C2 outputs on public dev session ideas-sub-1-ses-1.
#SBATCH --job-name=uhat_pkg_parity
#SBATCH --partition=interactive
#SBATCH --time=08:00:00
#SBATCH --cpus-per-task=4
#SBATCH --mem=48G
#SBATCH --exclude=smdodwork05
#SBATCH --output=/mnt/nfs/home/urmc-sh.rochester.edu/pndagiji/Documents/TrackTBI-Sub/dwi_pipeline/methods/mapping_uhat/work/logs/pkg_parity_%j.out
#SBATCH --error=/mnt/nfs/home/urmc-sh.rochester.edu/pndagiji/Documents/TrackTBI-Sub/dwi_pipeline/methods/mapping_uhat/work/logs/pkg_parity_%j.err
set -euo pipefail
UHAT=/mnt/nfs/home/urmc-sh.rochester.edu/pndagiji/Documents/TrackTBI-Sub/dwi_pipeline/methods/mapping_uhat
export OMP_NUM_THREADS="${SLURM_CPUS_PER_TASK:-4}"
python3 -u "${UHAT}/package_parity.py" u
python3 -u "${UHAT}/package_parity.py" c2
