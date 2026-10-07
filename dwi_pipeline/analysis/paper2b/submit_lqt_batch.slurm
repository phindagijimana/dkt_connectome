#!/usr/bin/env bash
#SBATCH --job-name=paper2b_lqt
#SBATCH --partition=interactive
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=4
#SBATCH --mem=32G
#SBATCH --time=08:00:00
#SBATCH --array=1-7%3
#SBATCH --output=/mnt/nfs/home/URMC-SH/pndagiji/Documents/TrackTBI-Sub/dwi_pipeline/analysis/paper2b/logs/lqt_%A_%a.out
#SBATCH --error=/mnt/nfs/home/URMC-SH/pndagiji/Documents/TrackTBI-Sub/dwi_pipeline/analysis/paper2b/logs/lqt_%A_%a.err

# Paper 2B — LQT comparator batch (pilot cohort = fMRI neurolit-inpaint 7 × 2WK).
#
# R LQT (recommended):
#   sbatch --export=ALL,LQT_BACKEND=r dwi_pipeline/analysis/paper2b/submit_lqt_batch.slurm
# Optional: LQT_R_MODULE=gcc/13.1.0 (site-specific) before sbatch.
#
# After array completes:
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
# shellcheck source=ensure_r_for_lqt.sh
source "${SCRIPT_DIR}/ensure_r_for_lqt.sh"

export EXPERIMENT_ROOT SESSION
export DWI_CONNECTOMES="${DWI_CONNECTOMES:-${EXPERIMENT_ROOT}/validation_v030/arms/neurolit-lesion/connectomes}"
export FMRIPREP_DIR="${FMRIPREP_DIR:-${EXPERIMENT_ROOT}/fmri_derivatives_inpaint/fmriprep}"
export LQT_STAGING="${LQT_STAGING:-${EXPERIMENT_ROOT}/lqt_batch/staging}"
export LQT_DIR="${LQT_DIR:-${EXPERIMENT_ROOT}/lqt_batch/outputs}"
export LQT_ATLAS_DIR="${LQT_ATLAS_DIR:-${EXPERIMENT_ROOT}/lqt_batch/atlas}"
DEFAULT_PARCEL="${LQT_ATLAS_DIR}/dkt78_mni152nlin6asym_res-2.nii.gz"
if [[ -z "${LQT_PARCEL_NII:-}" && -f "${DEFAULT_PARCEL}" ]]; then
    export LQT_PARCEL_NII="${DEFAULT_PARCEL}"
fi

mkdir -p "${SCRIPT_DIR}/logs" "${LQT_DIR}"

export LQT_BACKEND="${LQT_BACKEND:-r}"
LQT_R_MARKER="${EXPERIMENT_ROOT}/lqt_batch/.lqt_r_package_ready"
LQT_TEMPLATES_MARKER="${EXPERIMENT_ROOT}/lqt_batch/.lqt_templates_ready"

_templates_ok_quick() {
    export LQT_SCRIPT_DIR="${SCRIPT_DIR}"
    paper2b_Rscript -e "
      source('${SCRIPT_DIR}/lqt_templates_ok.R');
      quit(status=if (lqt_templates_ok()) 0 else 1)
    " 2>/dev/null
}

_ensure_lqt_templates() {
    if [[ "$(uname -s)" == "Linux" ]]; then
        # shellcheck source=ensure_dsi_studio_for_lqt.sh
        source "${SCRIPT_DIR}/ensure_dsi_studio_for_lqt.sh" || true
    fi
    if [[ -f "${LQT_TEMPLATES_MARKER}" ]]; then
        _templates_ok_quick && return 0
    fi
    if [[ "${SLURM_ARRAY_TASK_ID}" == "1" ]]; then
        echo "=== LQT Figshare templates (array task 1, serial) ==="
        bash "${SCRIPT_DIR}/install_lqt_templates.sh"
    else
        echo "Waiting for LQT templates (task 1)..."
        for _ in $(seq 1 240); do
            [[ -f "${LQT_TEMPLATES_MARKER}" ]] && break
            sleep 30
        done
    fi
    [[ -f "${LQT_TEMPLATES_MARKER}" ]] || {
        echo "ERROR: LQT templates not ready; run submit_lqt_install_templates.slurm first" >&2
        return 1
    }
}

_ensure_r_lqt() {
    if paper2b_Rscript -e 'quit(status=if (requireNamespace("LQT", quietly=TRUE)) 0 else 1)' 2>/dev/null; then
        touch "${LQT_R_MARKER}" 2>/dev/null || true
        return 0
    fi
    if [[ "${LQT_BACKEND}" != "r" ]]; then
        return 0
    fi
    if [[ "${SLURM_ARRAY_TASK_ID}" == "1" ]]; then
        echo "=== Installing jdwor/LQT (array task 1) ==="
        bash "${SCRIPT_DIR}/install_lqt_r.sh"
        touch "${LQT_R_MARKER}"
    else
        echo "Waiting for R LQT install (task 1)..."
        for _ in $(seq 1 120); do
            [[ -f "${LQT_R_MARKER}" ]] && break
            sleep 30
        done
    fi
    paper2b_Rscript -e 'quit(status=if (requireNamespace("LQT", quietly=TRUE)) 0 else 1)'
}

if [[ "${LQT_BACKEND}" == "r" ]]; then
    _ensure_r_lqt || {
        echo "ERROR: R LQT not available after install wait" >&2
        exit 1
    }
    _ensure_lqt_templates || exit 1
fi

echo "=== LQT batch task ${SLURM_ARRAY_TASK_ID}: sub-${SUBJECT} ses-${SESSION} ==="
echo "  Node:  $(hostname)"
echo "  Start: $(date)"
echo "  LQT_BACKEND: ${LQT_BACKEND}"
echo "  LQT_PARCEL_NII: ${LQT_PARCEL_NII:-<unset>}"
echo

bash "${SCRIPT_DIR}/run_lqt_one_subject.sh" "${SUBJECT}"

echo "Done: $(date)"
