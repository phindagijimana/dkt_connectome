#!/bin/bash
# -----------------------------------------------------------------------------
# Submit Slurm array: QSIRecon only (QSIPrep outputs must already exist under QSIPREP_OUT).
# Uses subject_list_qsirecon_after_qsiprep_ok.txt — participants whose QSIPrep completed in the
# prior run (excludes the 15 that failed at gather_inputs / fmap EPI).
#
# Requires: pipeline_qsiprep_qsirecon_single_run_per_subject.sh run_qsirecon_one with
#   --fs-license-file (see recent script update).
#
# Usage
#   ./submit_qsirecon_array.sh
#
# Optional
#   SUBJECT_LIST_FILE=/path/to/list.txt     (default: subject_list_qsirecon_after_qsiprep_ok.txt)
#   ARRAY_CONCURRENCY=5
#   NTHREADS=8 OMP_NTHREADS=8
#   RESULTS_ROOT=...   (must match QSIPrep run so /qsiprep_input finds prior outputs)
# -----------------------------------------------------------------------------

set -euo pipefail
set +H

PROJECT_ROOT="$(cd "$(dirname "$0")" && pwd)"

SUBJECT_LIST_FILE="${SUBJECT_LIST_FILE:-${PROJECT_ROOT}/subject_list_qsirecon_after_qsiprep_ok.txt}"
ARRAY_SCRIPT="${PROJECT_ROOT}/pipeline_qsiprep_qsirecon_single_run_array.sh"
ARRAY_CONCURRENCY="${ARRAY_CONCURRENCY:-5}"
NTHREADS="${NTHREADS:-8}"
OMP_NTHREADS="${OMP_NTHREADS:-8}"

RESULTS_ROOT="${RESULTS_ROOT:-/mnt/nfs/home/urmc-sh.rochester.edu/pndagiji/Documents/CIDUR_BIDS/data_results}"
BIDS_DIR="${BIDS_DIR:-/mnt/nfs/home/urmc-sh.rochester.edu/pndagiji/Documents/CIDUR_BIDS/data_bids}"

[[ -f "${ARRAY_SCRIPT}" ]] || { echo "Missing ${ARRAY_SCRIPT}"; exit 1; }
[[ -f "${SUBJECT_LIST_FILE}" ]] || {
  echo "Missing ${SUBJECT_LIST_FILE}"
  exit 1
}

mkdir -p "${PROJECT_ROOT}/logs"

N=$(wc -l < "${SUBJECT_LIST_FILE}")
[[ "${N}" -ge 1 ]] || { echo "Empty subject list."; exit 1; }

echo "QSIRecon-only array: ${N} subject(s) from ${SUBJECT_LIST_FILE}"
echo "PIPELINE_MODE=qsirecon RESULTS_ROOT=${RESULTS_ROOT}"

export PIPELINE_MODE=qsirecon
export SUBJECT_LIST_FILE
export NTHREADS
export OMP_NTHREADS
export RESULTS_ROOT
export BIDS_DIR

exec sbatch \
  --job-name=qsirecon_arr \
  --output="${PROJECT_ROOT}/logs/qsirecon_arr_%A_%a.out" \
  --error="${PROJECT_ROOT}/logs/qsirecon_arr_%A_%a.err" \
  --array="1-${N}%${ARRAY_CONCURRENCY}" \
  --export=ALL \
  "${ARRAY_SCRIPT}"
