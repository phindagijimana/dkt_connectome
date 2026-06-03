#!/bin/bash
# -----------------------------------------------------------------------------
# One-shot submit for QSIPrep+QSIRecon (Slurm array): builds subject list, sets N,
# runs sbatch with --array=1-N%K. All defaults match pipeline_qsiprep_qsirecon_single_run_array.sh.
#
# Usage
#   ./submit_qsiprep_array.sh
#   ./submit_qsiprep_array.sh --syn    # no BIDS fmap -> --use-syn-sdc warn
#
# Default: subject list includes only participants with a DWI NIfTI (SUBJECT_LIST_ONLY_DWI=1).
# For every sub-* folder regardless of DWI: SUBJECT_LIST_ONLY_DWI=0 ./submit_qsiprep_array.sh
#
# Optional environment (override defaults)
#   BIDS_DIR=/path/to/data_bids
#   SUBJECT_LIST_FILE=/path/to/list.txt   (written here; read by the array job)
#   ARRAY_CONCURRENCY=5                   (%K in Slurm; max simultaneous array tasks)
#   NTHREADS=8 OMP_NTHREADS=8             forwarded via export (see sbatch --export below)
#
# Then check: squeue -u $USER
# -----------------------------------------------------------------------------

set -euo pipefail
set +H

QSIPREP_USE_SYN_SDC="${QSIPREP_USE_SYN_SDC:-0}"
QSIPREP_FMAP_RETRY="${QSIPREP_FMAP_RETRY:-0}"
while [[ $# -gt 0 ]]; do
  case "$1" in
    --syn|--use-syn-sdc) QSIPREP_USE_SYN_SDC=1 ;;
    --fmap-retry) QSIPREP_FMAP_RETRY=1 ;;
    *) echo "Unknown option: $1"; exit 1 ;;
  esac
  shift
done

PROJECT_ROOT="$(cd "$(dirname "$0")" && pwd)"

BIDS_DIR="${BIDS_DIR:-/mnt/nfs/home/urmc-sh.rochester.edu/pndagiji/Documents/CIDUR_BIDS/data_bids}"
SUBJECT_LIST_FILE="${SUBJECT_LIST_FILE:-${PROJECT_ROOT}/subject_list_for_array.txt}"
ARRAY_SCRIPT="${PROJECT_ROOT}/pipeline_qsiprep_qsirecon_single_run_array.sh"
ARRAY_CONCURRENCY="${ARRAY_CONCURRENCY:-5}"
SUBJECT_LIST_ONLY_DWI="${SUBJECT_LIST_ONLY_DWI:-1}"

NTHREADS="${NTHREADS:-8}"
OMP_NTHREADS="${OMP_NTHREADS:-8}"

[[ -d "${BIDS_DIR}" ]] || { echo "Not a directory: ${BIDS_DIR}"; exit 1; }
[[ -f "${ARRAY_SCRIPT}" ]] || { echo "Missing ${ARRAY_SCRIPT}"; exit 1; }

mkdir -p "${PROJECT_ROOT}/logs"

if [[ "${SUBJECT_LIST_ONLY_DWI}" == "1" ]]; then
  tmp="${SUBJECT_LIST_FILE}.$$"
  : > "${tmp}"
  shopt -s nullglob
  for d in "${BIDS_DIR}"/sub-*; do
    [[ -d "$d" ]] || continue
    base="${d##*/}"
    id="${base#sub-}"
    if find "$d" -type f \( -name '*.nii.gz' -o -name '*.nii' \) -path '*/dwi/*' -print -quit 2>/dev/null | grep -q .; then
      echo "${id}" >> "${tmp}"
    fi
  done
  shopt -u nullglob
  sort -u "${tmp}" > "${SUBJECT_LIST_FILE}"
  rm -f "${tmp}"
else
  find "${BIDS_DIR}" -maxdepth 1 -mindepth 1 -type d -name 'sub-*' -printf '%f\n' 2>/dev/null \
    | sed 's/^sub-//' | sort -u > "${SUBJECT_LIST_FILE}"
fi

N=$(wc -l < "${SUBJECT_LIST_FILE}")
[[ "${N}" -ge 1 ]] || { echo "Empty subject list after generation."; exit 1; }

echo "Wrote ${N} line(s) -> ${SUBJECT_LIST_FILE}"
echo "Submitting array 1-${N}%${ARRAY_CONCURRENCY} -> ${ARRAY_SCRIPT}"

# Command-line --array overrides #SBATCH --array in the batch script.
export BIDS_DIR SUBJECT_LIST_FILE NTHREADS OMP_NTHREADS QSIPREP_USE_SYN_SDC QSIPREP_FMAP_RETRY
exec sbatch --array="1-${N}%${ARRAY_CONCURRENCY}" --export=ALL "${ARRAY_SCRIPT}"
