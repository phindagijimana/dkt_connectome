#!/usr/bin/env bash
# Submit templates → LQT array → Paper 2B stats with SLURM dependencies.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
export EXPERIMENT_ROOT="${EXPERIMENT_ROOT:-/mnt/nfs/Gugger_Lab/NIR/dwi_test_TBI_experiment}"
export LQT_BACKEND="${LQT_BACKEND:-r}"

CLEAN="${LQT_CLEAN_TEMPLATES:-0}"
if [[ "${CLEAN}" == "1" ]]; then
    TPL=$(sbatch --parsable --export=ALL,LQT_CLEAN_TEMPLATES=1 \
        "${SCRIPT_DIR}/submit_lqt_install_templates.slurm")
else
    TPL=$(sbatch --parsable "${SCRIPT_DIR}/submit_lqt_install_templates.slurm")
fi
echo "Templates job: ${TPL}"

BATCH=$(sbatch --parsable --dependency="afterok:${TPL}" --export=ALL,LQT_BACKEND="${LQT_BACKEND}" \
    "${SCRIPT_DIR}/submit_lqt_batch.slurm")
echo "LQT batch job: ${BATCH}"

STATS=$(sbatch --parsable --dependency="afterok:${BATCH}" \
    "${SCRIPT_DIR}/submit_paper2b_after_lqt.slurm")
echo "Paper 2B stats job: ${STATS}"
