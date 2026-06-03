#!/bin/bash
# -----------------------------------------------------------------------------
# Slurm array: full pipeline per subject = QSIPrep + QSIrecon (PIPELINE_MODE=all).
# 11 DWI participants with BIDS fmaps to use measured TOPUP (not SyN retry).
#
#   ./submit_dwi_11.sh
#
# List: subject_list_rerun_bids_fmap_topup_11.txt
# Throttle: ARRAY_CONCURRENCY=5  ->  Slurm  --array=1-11%5
# -----------------------------------------------------------------------------

set -euo pipefail
set +H

PROJECT_ROOT="$(cd "$(dirname "$0")" && pwd)"

SUBJECT_LIST_FILE="${SUBJECT_LIST_FILE:-${PROJECT_ROOT}/subject_list_rerun_bids_fmap_topup_11.txt}"
ARRAY_SCRIPT="${PROJECT_ROOT}/pipeline_qsiprep_qsirecon_single_run_array.sh"
ARRAY_CONCURRENCY="${ARRAY_CONCURRENCY:-5}"
NTHREADS="${NTHREADS:-8}"
OMP_NTHREADS="${OMP_NTHREADS:-8}"

RESULTS_ROOT="${RESULTS_ROOT:-/mnt/nfs/home/urmc-sh.rochester.edu/pndagiji/Documents/CIDUR_BIDS/results_fmaps}"
BIDS_DIR="${BIDS_DIR:-/mnt/nfs/home/urmc-sh.rochester.edu/pndagiji/Documents/CIDUR_BIDS/data_bids}"

[[ -f "${ARRAY_SCRIPT}" ]] || { echo "Missing ${ARRAY_SCRIPT}"; exit 1; }
[[ -f "${SUBJECT_LIST_FILE}" ]] || { echo "Missing ${SUBJECT_LIST_FILE}"; exit 1; }

N=$(wc -l < "${SUBJECT_LIST_FILE}")
[[ "${N}" -ge 1 ]] || { echo "Empty subject list."; exit 1; }

mkdir -p "${PROJECT_ROOT}/logs"

echo "submit_dwi_11: ${N} subject(s) | PIPELINE_MODE=all (QSIPrep+QSIrecon) | %${ARRAY_CONCURRENCY}"
echo "RESULTS_ROOT=${RESULTS_ROOT}"
echo "List: ${SUBJECT_LIST_FILE}"

export PIPELINE_MODE=all
export QSIPREP_FMAP_RETRY=0
export QSIPREP_NO_SYN_SDC=0
export SUBJECT_LIST_FILE
export NTHREADS
export OMP_NTHREADS
export RESULTS_ROOT
export BIDS_DIR

exec sbatch \
  --job-name=dwi_11 \
  --output="${PROJECT_ROOT}/logs/dwi_11_%A_%a.out" \
  --error="${PROJECT_ROOT}/logs/dwi_11_%A_%a.err" \
  --array="1-${N}%${ARRAY_CONCURRENCY}" \
  --export=ALL \
  "${ARRAY_SCRIPT}"
