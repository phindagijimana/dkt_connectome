#!/bin/bash
# ---------------------------------------------------------------------------
# Slurm: job array + OpenMP-style threading (NTHREADS / OMP_NTHREADS)
# ---------------------------------------------------------------------------
# Cross-subject parallelism = Slurm array (one subject per array task).
# Within each subject, QSIPrep/QSIRecon use --nthreads / --omp-nthreads (OpenMP-style
# threading inside the container). Set #SBATCH --cpus-per-task to match NTHREADS.
#
# Recommended: one command builds the list, sets N, and submits (overrides --array via sbatch):
#      ./submit_qsiprep_array.sh
# Default submit list = only IDs with DWI NIfTI. All sub-* folders: SUBJECT_LIST_ONLY_DWI=0 ./submit_qsiprep_array.sh
#
# QSIRecon only (after QSIPrep already ran), for subjects in subject_list_qsirecon_after_qsiprep_ok.txt:
#      ./submit_qsirecon_array.sh
# Uses PIPELINE_MODE=qsirecon → pipeline ... qsirecon <id> (needs FS license in container; see per_subject script).
#
# QSIPrep fmap EPI failures — ignore measured fmaps + SyN SDC, then QSIRecon:
#      ./submit_qsiprep_fmap_retry_array.sh
# Sets QSIPREP_FMAP_RETRY=1 (see pipeline_qsiprep_qsirecon_single_run_per_subject.sh).
#
# Manual: build subject_list_for_array.txt (one ID per line, no "sub-"), then either
#      sbatch --array=1-$(wc -l < subject_list_for_array.txt)%5 pipeline_qsiprep_qsirecon_single_run_array.sh
# or edit #SBATCH --array=1-N%K below (N = wc -l on the list).
#
# Environment (optional):
#   PIPELINE_MODE=all|qsiprep|qsirecon   (default: all)
#   SUBJECT_LIST_FILE=/path/to/list.txt
#   NTHREADS=8 OMP_NTHREADS=8   (must stay in line with --cpus-per-task)
#   BIDS_DIR=...  (passed through to the pipeline if needed)
#   RESULTS_ROOT=.../results_fmaps  (per-subject script output root; see submit scripts)
#   QSIPREP_FMAP_RETRY=0|1  (1 = ignore fieldmaps + SyN)
#   QSIPREP_USE_SYN_SDC=0|1  (1 = --use-syn-sdc warn when no BIDS fmap; default 0 = no SyN)
# ---------------------------------------------------------------------------

#SBATCH --job-name=qsiprep_qsir_arr
#SBATCH --output=/mnt/nfs/home/urmc-sh.rochester.edu/pndagiji/Documents/TrackTBI-Sub/logs/qsiprep_qsir_arr_%A_%a.out
#SBATCH --error=/mnt/nfs/home/urmc-sh.rochester.edu/pndagiji/Documents/TrackTBI-Sub/logs/qsiprep_qsir_arr_%A_%a.err
#SBATCH --time=96:00:00
#SBATCH --partition=general
#SBATCH --cpus-per-task=8
#SBATCH --mem=32G
#SBATCH --mail-type=END,FAIL
#SBATCH --mail-user=philbert_ndagijimana@urmc.rochester.edu
#SBATCH --array=1-76%5
# ^ Overridden by submit: --array=1-$(wc -l < list). N = all BIDS subs (76) or DWI-only if rebuilt.
#   %5 = at most 5 array tasks at once (tune for cluster load / fair-share).

set -euo pipefail
set +H

PROJECT_ROOT=/mnt/nfs/home/urmc-sh.rochester.edu/pndagiji/Documents/TrackTBI-Sub
PIPELINE="${PROJECT_ROOT}/pipeline_qsiprep_qsirecon_single_run_per_subject.sh"
SUBJECT_LIST_FILE="${SUBJECT_LIST_FILE:-${PROJECT_ROOT}/subject_list_for_array.txt}"

# One subject per array task — do not use multi-subject bash parallelism here.
export MAX_PARALLEL=1

# OpenMP-style threading inside each QSIPrep/QSIRecon process (match --cpus-per-task above).
export NTHREADS="${NTHREADS:-8}"
export OMP_NTHREADS="${OMP_NTHREADS:-8}"

mkdir -p "${PROJECT_ROOT}/logs"

[[ -f "${PIPELINE}" ]] || { echo "Missing ${PIPELINE}"; exit 1; }
[[ -f "${SUBJECT_LIST_FILE}" ]] || {
  echo "Missing subject list: ${SUBJECT_LIST_FILE}"
  echo "Create it (one ID per line) or set SUBJECT_LIST_FILE."
  exit 1
}

[[ -n "${SLURM_ARRAY_TASK_ID:-}" ]] || {
  echo "This script is meant to be submitted with sbatch (needs SLURM_ARRAY_TASK_ID)."
  exit 1
}

SUBJECT=""
SUBJECT=$(sed -n "${SLURM_ARRAY_TASK_ID}p" "${SUBJECT_LIST_FILE}" | tr -d '\r')
SUBJECT="${SUBJECT#"${SUBJECT%%[![:space:]]*}"}"
SUBJECT="${SUBJECT%"${SUBJECT##*[![:space:]]}"}"
[[ -n "${SUBJECT}" ]] || { echo "Task ${SLURM_ARRAY_TASK_ID}: empty line in ${SUBJECT_LIST_FILE}"; exit 0; }
[[ "${SUBJECT}" != \#* ]] || { echo "Task ${SLURM_ARRAY_TASK_ID}: skipped comment line"; exit 0; }
SUBJECT="${SUBJECT#sub-}"

PIPELINE_MODE="${PIPELINE_MODE:-all}"
case "${PIPELINE_MODE}" in
  all|qsiprep|qsirecon) ;;
  *)
    echo "Invalid PIPELINE_MODE=${PIPELINE_MODE} (use all, qsiprep, or qsirecon)"
    exit 1
    ;;
esac

QSIPREP_SYN_ARGS=()
[[ "${QSIPREP_USE_SYN_SDC:-0}" == "1" ]] && QSIPREP_SYN_ARGS+=(--syn)
[[ "${QSIPREP_FMAP_RETRY:-0}" == "1" ]] && QSIPREP_SYN_ARGS+=(--fmap-retry)

echo "Array task ${SLURM_ARRAY_TASK_ID}: sub-${SUBJECT} mode=${PIPELINE_MODE} (NTHREADS=${NTHREADS}, syn=${QSIPREP_USE_SYN_SDC:-0})"

exec bash "${PIPELINE}" "${PIPELINE_MODE}" "${SUBJECT}" "${QSIPREP_SYN_ARGS[@]}"
