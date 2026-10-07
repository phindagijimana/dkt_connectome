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
echo "2) One-time Figshare templates (serial; do not skip before batch):"
echo "   sbatch ${SCRIPT_DIR}/submit_lqt_install_templates.slurm"
echo
echo "3) LQT per subject (after templates OK):"
echo "   sbatch --export=ALL,LQT_BACKEND=${LQT_BACKEND} ${SCRIPT_DIR}/submit_lqt_batch.slurm"
echo
echo "4) After LQT array, Paper 2B stats:"
echo "   bash ${SCRIPT_DIR}/run_paper2b_analysis.sh"
echo
echo "Or chain templates + batch + stats:"
echo "   bash ${SCRIPT_DIR}/submit_lqt_pipeline_chain.sh"
