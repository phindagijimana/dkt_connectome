#!/usr/bin/env bash
#SBATCH --job-name=lqt_r_install
#SBATCH --partition=interactive
#SBATCH --cpus-per-task=2
#SBATCH --mem=8G
#SBATCH --time=04:00:00
#SBATCH --output=/mnt/nfs/home/URMC-SH/pndagiji/Documents/TrackTBI-Sub/dwi_pipeline/analysis/paper2b/logs/lqt_install_%j.out
#SBATCH --error=/mnt/nfs/home/URMC-SH/pndagiji/Documents/TrackTBI-Sub/dwi_pipeline/analysis/paper2b/logs/lqt_install_%j.err

# Pull rocker/r-ver (if needed) and install jdwor/LQT into $EXPERIMENT_ROOT/lqt_batch/r_library
set -euo pipefail

REPO="/mnt/nfs/home/URMC-SH/pndagiji/Documents/TrackTBI-Sub"
export EXPERIMENT_ROOT="${EXPERIMENT_ROOT:-/mnt/nfs/Gugger_Lab/NIR/dwi_test_TBI_experiment}"
bash "${REPO}/dwi_pipeline/analysis/paper2b/install_lqt_r.sh"
touch "${EXPERIMENT_ROOT}/lqt_batch/.lqt_r_package_ready"
echo "Install complete: $(date)"
