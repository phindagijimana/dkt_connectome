#!/bin/bash
# =============================================================================
# array.sh — Slurm job array for dwi_connect_default (one subject per task)
# =============================================================================

#SBATCH --job-name=dwi_connect_def
#SBATCH --output=/mnt/nfs/home/urmc-sh.rochester.edu/pndagiji/Documents/TrackTBI-Sub/logs/dwi_connect_default_%A_%a.out
#SBATCH --error=/mnt/nfs/home/urmc-sh.rochester.edu/pndagiji/Documents/TrackTBI-Sub/logs/dwi_connect_default_%A_%a.err
#SBATCH --time=12:00:00
#SBATCH --partition=interactive
#SBATCH --cpus-per-task=8
#SBATCH --mem=32G
#SBATCH --mail-type=END,FAIL
#SBATCH --mail-user=philbert_ndagijimana@urmc.rochester.edu
#SBATCH --array=1-1%1

set -euo pipefail
set +H

CONNECT_ROOT="${CONNECT_ROOT:-${SLURM_SUBMIT_DIR:-$(cd "$(dirname "$0")" && pwd)}}"
if [[ ! -d "${CONNECT_ROOT}" || "$(basename "${CONNECT_ROOT}")" != "dwi_connect_default" ]]; then
  CONNECT_ROOT="${SLURM_SUBMIT_DIR:-$(cd "$(dirname "$0")" && pwd)}/dwi_connect_default"
fi
TRACKTBI_ROOT="${TRACKTBI_ROOT:-$(cd "${CONNECT_ROOT}/.." && pwd)}"
PIPELINE="${PIPELINE:-${CONNECT_ROOT}/subject.sh}"
SUBJECT_LIST_FILE="${SUBJECT_LIST_FILE:-${CONNECT_ROOT}/subjects.txt}"

export NTHREADS="${NTHREADS:-8}"
export OMP_NTHREADS="${OMP_NTHREADS:-8}"
export RUN_DK_CONNECTOME="${RUN_DK_CONNECTOME:-0}"

mkdir -p "${TRACKTBI_ROOT}/logs"

[[ -f "${PIPELINE}" ]] || { echo "Missing ${PIPELINE}"; exit 1; }
[[ -f "${SUBJECT_LIST_FILE}" ]] || { echo "Missing subject list: ${SUBJECT_LIST_FILE}"; exit 1; }
[[ -n "${SLURM_ARRAY_TASK_ID:-}" ]] || { echo "Need SLURM_ARRAY_TASK_ID"; exit 1; }

SUBJECT="$(sed -n "${SLURM_ARRAY_TASK_ID}p" "${SUBJECT_LIST_FILE}" | tr -d '\r')"
SUBJECT="${SUBJECT#"${SUBJECT%%[![:space:]]*}"}"
SUBJECT="${SUBJECT%"${SUBJECT##*[![:space:]]}"}"
[[ -n "${SUBJECT}" ]] || { echo "Task ${SLURM_ARRAY_TASK_ID}: empty line"; exit 0; }
[[ "${SUBJECT}" != \#* ]] || { echo "Task ${SLURM_ARRAY_TASK_ID}: comment line"; exit 0; }
SUBJECT="${SUBJECT#sub-}"

PIPELINE_MODE="${PIPELINE_MODE:-all}"
case "${PIPELINE_MODE}" in
  all|qsiprep|recon|qsirecon) ;;
  dk)
    echo "Invalid PIPELINE_MODE=dk for dwi_connect_default (use dwi_pipeline for DK connectomes)"
    exit 1
    ;;
  *)
    echo "Invalid PIPELINE_MODE=${PIPELINE_MODE} (use all|qsiprep|recon|qsirecon)"
    exit 1
    ;;
esac

SUBJECT_ARGS=()
[[ "${QSIPREP_USE_SYN_SDC:-0}" == "1" ]] && SUBJECT_ARGS+=(--syn)
[[ "${QSIPREP_FMAP_RETRY:-0}" == "1" ]] && SUBJECT_ARGS+=(--fmap-retry)
[[ "${RECON_TOOL:-freesurfer}" == "fastsurfer" ]] && SUBJECT_ARGS+=(--fastsurfer)
[[ "${RUN_RECON:-1}" == "0" ]] && SUBJECT_ARGS+=(--no-recon)
SUBJECT_ARGS+=(--no-dk)

echo "dwi_connect_default task ${SLURM_ARRAY_TASK_ID}: sub-${SUBJECT} mode=${PIPELINE_MODE} \
recon=${RECON_TOOL:-freesurfer} atlases=${QSIRECON_ATLASES:-4S156Parcels} NTHREADS=${NTHREADS}"
exec bash "${PIPELINE}" "${PIPELINE_MODE}" "${SUBJECT}" "${SUBJECT_ARGS[@]}"
