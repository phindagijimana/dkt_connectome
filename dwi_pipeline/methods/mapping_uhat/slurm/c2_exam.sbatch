#!/bin/bash
# C2 development exam on planted 1 mm y. Locked cuts. Not leftover. Not hat{U}.
#SBATCH --job-name=uhat_C2_exam
#SBATCH --partition=interactive
#SBATCH --time=00:30:00
#SBATCH --cpus-per-task=1
#SBATCH --mem=8G
#SBATCH --output=/mnt/nfs/home/urmc-sh.rochester.edu/pndagiji/Documents/TrackTBI-Sub/dwi_pipeline/methods/mapping_uhat/work/C2/logs/C2_exam_%j.out
#SBATCH --error=/mnt/nfs/home/urmc-sh.rochester.edu/pndagiji/Documents/TrackTBI-Sub/dwi_pipeline/methods/mapping_uhat/work/C2/logs/C2_exam_%j.err
set -euo pipefail
UHAT=/mnt/nfs/home/urmc-sh.rochester.edu/pndagiji/Documents/TrackTBI-Sub/dwi_pipeline/methods/mapping_uhat
python3 -u "${UHAT}/c2_soft.py" --exam
