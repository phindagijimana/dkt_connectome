#!/usr/bin/env bash
#SBATCH --job-name=lqt_templates
#SBATCH --partition=interactive
#SBATCH --cpus-per-task=4
#SBATCH --mem=32G
#SBATCH --time=08:00:00
#SBATCH --output=/mnt/nfs/home/URMC-SH/pndagiji/Documents/TrackTBI-Sub/dwi_pipeline/analysis/paper2b/logs/lqt_templates_%j.out
#SBATCH --error=/mnt/nfs/home/URMC-SH/pndagiji/Documents/TrackTBI-Sub/dwi_pipeline/analysis/paper2b/logs/lqt_templates_%j.err

# One-time Figshare download for jdwor/LQT (run after submit_lqt_install_r.slurm).
# After OK, run submit_lqt_batch.slurm (array tasks must not download in parallel).
#
#   sbatch dwi_pipeline/analysis/paper2b/submit_lqt_install_templates.slurm
#
# Retry after failed parallel batch (173882-style unzip errors):
#   LQT_CLEAN_TEMPLATES=1 sbatch --export=ALL,LQT_CLEAN_TEMPLATES=1 \
#     dwi_pipeline/analysis/paper2b/submit_lqt_install_templates.slurm

set -euo pipefail

REPO="/mnt/nfs/home/URMC-SH/pndagiji/Documents/TrackTBI-Sub"
export EXPERIMENT_ROOT="${EXPERIMENT_ROOT:-/mnt/nfs/Gugger_Lab/NIR/dwi_test_TBI_experiment}"
bash "${REPO}/dwi_pipeline/analysis/paper2b/install_lqt_templates.sh"
echo "Templates install complete: $(date)"
