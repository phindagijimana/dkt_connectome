#!/bin/bash
# =============================================================================
# array.sh — Slurm job array: one array task = one subject
# =============================================================================
#
# Do not run this directly unless testing. Normally launched by submit.sh via:
#   sbatch --array=1-N%5 array.sh
#
# For each SLURM_ARRAY_TASK_ID:
#   1. Read subject ID from line N of subjects.txt (or SUBJECT_LIST_FILE)
#   2. Call subject.sh with PIPELINE_MODE (all | qsiprep | qsirecon | dk)
#
# %5 in the array (set by submit.sh) limits concurrent subjects to 5.
# =============================================================================

# --- Slurm resource requests (override array range via sbatch --array=...) ---
#SBATCH --job-name=dwi_act_arr
#SBATCH --output=/mnt/nfs/home/urmc-sh.rochester.edu/pndagiji/Documents/TrackTBI-Sub/logs/dwi_act_%A_%a.out
#SBATCH --error=/mnt/nfs/home/urmc-sh.rochester.edu/pndagiji/Documents/TrackTBI-Sub/logs/dwi_act_%A_%a.err
#SBATCH --time=12:00:00
#SBATCH --partition=interactive
#SBATCH --cpus-per-task=4
#SBATCH --mem=24G
#SBATCH --mail-type=END,FAIL
#SBATCH --mail-user=philbert_ndagijimana@urmc.rochester.edu
#SBATCH --array=1-76%5

set -euo pipefail
set +H

# Inside sbatch $0 points to Slurm's spool copy (/var/spool/slurmd/job<id>/slurm_script),
# so deriving paths from $0 would write into /var/spool/slurmd (Permission denied).
# Prefer values exported by submit.sh; fall back to SLURM_SUBMIT_DIR/dirname($0).
DWI_ROOT="${DWI_ROOT:-${SLURM_SUBMIT_DIR:-$(cd "$(dirname "$0")" && pwd)}/dwi_pipeline}"
if [[ ! -d "${DWI_ROOT}" ]]; then
  DWI_ROOT="${SLURM_SUBMIT_DIR:-$(cd "$(dirname "$0")" && pwd)}"
fi
TRACKTBI_ROOT="${TRACKTBI_ROOT:-$(cd "${DWI_ROOT}/.." && pwd)}"
PIPELINE="${PIPELINE:-${DWI_ROOT}/subject.sh}"
SUBJECT_LIST_FILE="${SUBJECT_LIST_FILE:-${DWI_ROOT}/subjects.txt}"

# Threading inside each container (should match --cpus-per-task)
export NTHREADS="${NTHREADS:-4}"
export OMP_NTHREADS="${OMP_NTHREADS:-4}"

mkdir -p "${TRACKTBI_ROOT}/logs"

[[ -f "${PIPELINE}" ]] || { echo "Missing ${PIPELINE}"; exit 1; }
[[ -f "${SUBJECT_LIST_FILE}" ]] || { echo "Missing subject list: ${SUBJECT_LIST_FILE}"; exit 1; }
[[ -n "${SLURM_ARRAY_TASK_ID:-}" ]] || { echo "Need SLURM_ARRAY_TASK_ID"; exit 1; }

# Map array index -> subject ID (one line per subject, no "sub-" prefix in file)
SUBJECT="$(sed -n "${SLURM_ARRAY_TASK_ID}p" "${SUBJECT_LIST_FILE}" | tr -d '\r')"
SUBJECT="${SUBJECT#"${SUBJECT%%[![:space:]]*}"}"
SUBJECT="${SUBJECT%"${SUBJECT##*[![:space:]]}"}"
[[ -n "${SUBJECT}" ]] || { echo "Task ${SLURM_ARRAY_TASK_ID}: empty line"; exit 0; }
[[ "${SUBJECT}" != \#* ]] || { echo "Task ${SLURM_ARRAY_TASK_ID}: comment line"; exit 0; }
SUBJECT="${SUBJECT#sub-}"

PIPELINE_MODE="${PIPELINE_MODE:-all}"
case "${PIPELINE_MODE}" in
  all|qsiprep|recon|qsirecon|dk) ;;
  *) echo "Invalid PIPELINE_MODE=${PIPELINE_MODE} (use all|qsiprep|recon|qsirecon|dk)"; exit 1 ;;
esac

# Optional flags forwarded to subject.sh (set by submit.sh or export before sbatch)
SUBJECT_ARGS=()
[[ "${QSIPREP_USE_SYN_SDC:-0}" == "1" ]] && SUBJECT_ARGS+=(--syn)
[[ "${QSIPREP_FMAP_RETRY:-0}" == "1" ]] && SUBJECT_ARGS+=(--fmap-retry)
[[ "${RECON_TOOL:-freesurfer}" == "fastsurfer" ]] && SUBJECT_ARGS+=(--fastsurfer)
[[ "${RUN_RECON:-1}" == "0" ]] && SUBJECT_ARGS+=(--no-recon)
[[ "${RUN_DK_CONNECTOME:-1}" == "0" && "${PIPELINE_MODE}" == "all" ]] && SUBJECT_ARGS+=(--no-dk)

echo "ACT array task ${SLURM_ARRAY_TASK_ID}: sub-${SUBJECT} mode=${PIPELINE_MODE} \
recon=${RECON_TOOL:-freesurfer} run_recon=${RUN_RECON:-1} \
NTHREADS=${NTHREADS} syn=${QSIPREP_USE_SYN_SDC:-0}"
exec bash "${PIPELINE}" "${PIPELINE_MODE}" "${SUBJECT}" "${SUBJECT_ARGS[@]}"
