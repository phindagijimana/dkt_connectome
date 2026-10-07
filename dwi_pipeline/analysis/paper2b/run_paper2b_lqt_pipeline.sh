#!/usr/bin/env bash
# Paper 2B LQT end-to-end: install R LQT → 7-subject batch → stats (manual sbatch chain).
set -euo pipefail

REPO="$(cd "$(dirname "$0")/../../.." && pwd)"
SCRIPT_DIR="${REPO}/dwi_pipeline/analysis/paper2b"
export EXPERIMENT_ROOT="${EXPERIMENT_ROOT:-/mnt/nfs/Gugger_Lab/NIR/dwi_test_TBI_experiment}"
export LQT_BACKEND="${LQT_BACKEND:-r}"

echo "1) Install R LQT (Apptainer rocker if needed):"
echo "   sbatch ${SCRIPT_DIR}/submit_lqt_install_r.slurm"
echo
echo "2) After install OK, LQT per subject:"
echo "   sbatch --export=ALL,LQT_BACKEND=${LQT_BACKEND} ${SCRIPT_DIR}/submit_lqt_batch.slurm"
echo
echo "3) After LQT array, Paper 2B stats:"
echo "   bash ${SCRIPT_DIR}/run_paper2b_analysis.sh"
echo
echo "Or chain 2+3:"
echo "   JOB=\$(sbatch --parsable --export=ALL,LQT_BACKEND=${LQT_BACKEND} ${SCRIPT_DIR}/submit_lqt_batch.slurm)"
echo "   sbatch --dependency=afterok:\${JOB} ${SCRIPT_DIR}/submit_paper2b_after_lqt.slurm"
