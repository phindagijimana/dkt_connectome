#!/usr/bin/env bash
#SBATCH --job-name=paper2b_lqt
#SBATCH --partition=interactive
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=4
#SBATCH --mem=16G
#SBATCH --time=04:00:00
#SBATCH --array=1-7%3
#SBATCH --output=/mnt/nfs/home/URMC-SH/pndagiji/Documents/TrackTBI-Sub/dwi_pipeline/analysis/paper2b/logs/lqt_%A_%a.out
#SBATCH --error=/mnt/nfs/home/URMC-SH/pndagiji/Documents/TrackTBI-Sub/dwi_pipeline/analysis/paper2b/logs/lqt_%A_%a.err

# Paper 2B — LQT comparator batch (pilot cohort = fMRI neurolit-inpaint 7 × 2WK).
#
# Default: MNI lesion staging only (LQT_ROOT unset). After LQT install:
#   sbatch --export=ALL,LQT_ROOT=/path/to/lesion-quantification-toolkit \
#     dwi_pipeline/analysis/paper2b/submit_lqt_batch.slurm
#
# Then rerun Paper 2B stats:
#   export LQT_DIR=$EXPERIMENT_ROOT/lqt_batch/outputs
#   bash dwi_pipeline/analysis/paper2b/run_paper2b_analysis.sh

set -euo pipefail

declare -a PILOT_LIST=(
    TBI011011
    TBI011204
    TBI011007
    TBI011021
    TBI011029
    TBI011140
    TBI021030
)

IDX=$((SLURM_ARRAY_TASK_ID - 1))
if (( IDX < 0 || IDX >= ${#PILOT_LIST[@]} )); then
    echo "ERROR: array task ${SLURM_ARRAY_TASK_ID} out of range" >&2
    exit 2
fi

SUBJECT="${PILOT_LIST[$IDX]}"
SESSION="${SESSION:-2WK}"

REPO="/mnt/nfs/home/URMC-SH/pndagiji/Documents/TrackTBI-Sub"
SCRIPT_DIR="${REPO}/dwi_pipeline/analysis/paper2b"
DWI="${REPO}/dwi_pipeline"
EXPERIMENT_ROOT="${EXPERIMENT_ROOT:-/mnt/nfs/Gugger_Lab/NIR/dwi_test_TBI_experiment}"

# shellcheck source=/dev/null
source "${DWI}/workflow/lib/slurm_env.sh"
# shellcheck source=ensure_pipeline_ants.sh
source "${SCRIPT_DIR}/ensure_pipeline_ants.sh"

export EXPERIMENT_ROOT SESSION
export DWI_CONNECTOMES="${DWI_CONNECTOMES:-${EXPERIMENT_ROOT}/validation_v030/arms/neurolit-lesion/connectomes}"
export FMRIPREP_DIR="${FMRIPREP_DIR:-${EXPERIMENT_ROOT}/fmri_derivatives_inpaint/fmriprep}"
export LQT_STAGING="${LQT_STAGING:-${EXPERIMENT_ROOT}/lqt_batch/staging}"
export LQT_DIR="${LQT_DIR:-${EXPERIMENT_ROOT}/lqt_batch/outputs}"

mkdir -p "${SCRIPT_DIR}/logs"

echo "=== LQT batch task ${SLURM_ARRAY_TASK_ID}: sub-${SUBJECT} ses-${SESSION} ==="
echo "  Node:  $(hostname)"
echo "  Start: $(date)"
echo "  LQT_ROOT: ${LQT_ROOT:-<unset — staging only>}"
echo

bash "${SCRIPT_DIR}/run_lqt_one_subject.sh" "${SUBJECT}"

echo "Done: $(date)"
