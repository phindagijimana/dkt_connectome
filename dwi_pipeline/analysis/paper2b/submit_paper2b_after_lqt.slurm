#!/usr/bin/env bash
#SBATCH --job-name=paper2b_stats
#SBATCH --partition=interactive
#SBATCH --cpus-per-task=4
#SBATCH --mem=8G
#SBATCH --time=01:00:00
#SBATCH --dependency=singleton
#SBATCH --output=/mnt/nfs/home/URMC-SH/pndagiji/Documents/TrackTBI-Sub/dwi_pipeline/analysis/paper2b/logs/paper2b_stats_%j.out
#SBATCH --error=/mnt/nfs/home/URMC-SH/pndagiji/Documents/TrackTBI-Sub/dwi_pipeline/analysis/paper2b/logs/paper2b_stats_%j.err

# Run Paper 2B compare scripts after LQT array (submit with same job name dependency or manually).
#
#   LQT_JOB=173243
#   sbatch --dependency=afterok:${LQT_JOB} dwi_pipeline/analysis/paper2b/submit_paper2b_after_lqt.slurm

set -euo pipefail

REPO="/mnt/nfs/home/URMC-SH/pndagiji/Documents/TrackTBI-Sub"
EXPERIMENT_ROOT="${EXPERIMENT_ROOT:-/mnt/nfs/Gugger_Lab/NIR/dwi_test_TBI_experiment}"

export EXPERIMENT_ROOT
export DWI_CONNECTOMES="${DWI_CONNECTOMES:-${EXPERIMENT_ROOT}/validation_v030/arms/neurolit-lesion/connectomes}"
export OUT_ROOT="${OUT_ROOT:-${EXPERIMENT_ROOT}/fmri_derivatives_inpaint}"
export LQT_DIR="${LQT_DIR:-${EXPERIMENT_ROOT}/lqt_batch/outputs}"

bash "${REPO}/dwi_pipeline/analysis/paper2b/run_paper2b_analysis.sh"
echo "Done: $(date)"
