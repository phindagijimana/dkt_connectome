#!/bin/bash
# -----------------------------------------------------------------------------
# Slurm array: same as submit_qsiprep_fmap_retry_array.sh — QSIPrep + QSIRecon with
#   QSIPREP_FMAP_RETRY=1  →  --ignore fieldmaps --use-syn-sdc
# for the 5 subjects that had anat-only QSIPrep (gather_inputs EPI fmap / bvec issue).
#
# Usage
#   ./submit_qsiprep_fmap_retry_extra5_array.sh
#
# Optional: SUBJECT_LIST_FILE, ARRAY_CONCURRENCY, RESULTS_ROOT, BIDS_DIR, NTHREADS
# -----------------------------------------------------------------------------

set -euo pipefail
set +H

PROJECT_ROOT="$(cd "$(dirname "$0")" && pwd)"

SUBJECT_LIST_FILE="${SUBJECT_LIST_FILE:-${PROJECT_ROOT}/subject_list_qsiprep_fmap_retry_extra5.txt}"
ARRAY_SCRIPT="${PROJECT_ROOT}/pipeline_qsiprep_qsirecon_single_run_array.sh"
ARRAY_CONCURRENCY="${ARRAY_CONCURRENCY:-5}"
NTHREADS="${NTHREADS:-8}"
OMP_NTHREADS="${OMP_NTHREADS:-8}"

RESULTS_ROOT="${RESULTS_ROOT:-/path/to/results}"
BIDS_DIR="${BIDS_DIR:-/path/to/BIDS}"

[[ -f "${ARRAY_SCRIPT}" ]] || { echo "Missing ${ARRAY_SCRIPT}"; exit 1; }
[[ -f "${SUBJECT_LIST_FILE}" ]] || { echo "Missing ${SUBJECT_LIST_FILE}"; exit 1; }

mkdir -p "${PROJECT_ROOT}/logs"

N=$(wc -l < "${SUBJECT_LIST_FILE}")
[[ "${N}" -ge 1 ]] || { echo "Empty subject list."; exit 1; }

echo "FMAP retry (extra 5): ${N} subject(s), QSIPREP_FMAP_RETRY=1 (ignore fieldmaps + SyN SDC)"
echo "List: ${SUBJECT_LIST_FILE}"

export PIPELINE_MODE="${PIPELINE_MODE:-all}"
export QSIPREP_FMAP_RETRY=1
export SUBJECT_LIST_FILE
export NTHREADS
export OMP_NTHREADS
export RESULTS_ROOT
export BIDS_DIR

exec sbatch \
  --job-name=qsiprep_fmap_r5 \
  --output="${PROJECT_ROOT}/logs/qsiprep_fmap_retry_extra5_%A_%a.out" \
  --error="${PROJECT_ROOT}/logs/qsiprep_fmap_retry_extra5_%A_%a.err" \
  --array="1-${N}%${ARRAY_CONCURRENCY}" \
  --export=ALL \
  "${ARRAY_SCRIPT}"
