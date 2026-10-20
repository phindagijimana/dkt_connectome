#!/bin/bash
# Convert remaining Kirby/Boekel to BIDS. Not leftover y. Not gold.
#SBATCH --job-name=retest_bids
#SBATCH --partition=interactive
#SBATCH --time=2:00:00
#SBATCH --cpus-per-task=2
#SBATCH --mem=8G
#SBATCH --output=/mnt/nfs/home/urmc-sh.rochester.edu/pndagiji/Documents/TrackTBI-Sub/dwi_pipeline/sample_data/_download_logs/convert_retest_%j.out
#SBATCH --error=/mnt/nfs/home/urmc-sh.rochester.edu/pndagiji/Documents/TrackTBI-Sub/dwi_pipeline/sample_data/_download_logs/convert_retest_%j.err
set -euo pipefail
python3 /mnt/nfs/home/urmc-sh.rochester.edu/pndagiji/Documents/TrackTBI-Sub/dwi_pipeline/methods/mapping_uhat/work/sites_v1/convert_retest_bids.py
