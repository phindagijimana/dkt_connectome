#!/bin/bash
# Submit dwi_connect_default for the same 5 subjects as dwi_test2 (NIR share).
#
#   ./submit_dwi_test2.sh                    # all CIDUR + TBI on general (48 h)
#   ./submit_dwi_test2.sh --mixed-interactive # interactive: CIDUR 001/006 + TBI011011
#                                             # general: CIDUR 007 + TBI011204
#   ./submit_dwi_test2.sh --dry-run
#
# Results -> CIDUR_BIDS/dwi_test_default (atlas connectome via QSIRecon, no DK).

set -euo pipefail

CONNECT_ROOT="$(cd "$(dirname "$0")" && pwd)"
TRACKTBI_ROOT="$(cd "${CONNECT_ROOT}/.." && pwd)"
RESULTS_ROOT="${RESULTS_ROOT:-/mnt/nfs/home/urmc-sh.rochester.edu/pndagiji/Documents/CIDUR_BIDS/dwi_test_default}"
DWI_SELECT_B1000="${TRACKTBI_ROOT}/dwi_pipeline/config/dwi_select_b1000.json"

DRY=0
MODE=general
while [[ $# -gt 0 ]]; do
  case "$1" in
    --dry-run) DRY=1 ;;
    --mixed-interactive) MODE=mixed ;;
    --interactive-cidur) MODE=interactive-all-cidur ;;  # legacy alias
    *) echo "Unknown option: $1"; exit 1 ;;
  esac
  shift
done

run_submit() {
  local desc="$1"
  shift
  echo ""
  echo "=== ${desc} ==="
  echo "$*"
  if [[ "${DRY}" -eq 0 ]]; then
    env "$@" "${CONNECT_ROOT}/submit.sh"
  fi
}

INTERACTIVE=(
  RESULTS_ROOT="${RESULTS_ROOT}"
  SUBJECT_LIST_USE_EXISTING=1
  SBATCH_PARTITION=interactive
  SBATCH_TIME=12:00:00
  SBATCH_CPUS=8
  SBATCH_MEM=32G
  NTHREADS=8
  OMP_NTHREADS=8
)

GENERAL=(
  RESULTS_ROOT="${RESULTS_ROOT}"
  SUBJECT_LIST_USE_EXISTING=1
  SBATCH_PARTITION=general
  SBATCH_TIME=48:00:00
  SBATCH_CPUS=8
  SBATCH_MEM=48G
  NTHREADS=8
  OMP_NTHREADS=8
)

if [[ "${MODE}" == "mixed" ]]; then
  run_submit "CIDUR sub-001, 006 (interactive)" \
    "${INTERACTIVE[@]}" \
    ARRAY_CONCURRENCY=2 \
    BIDS_DIR=/mnt/nfs/home/urmc-sh.rochester.edu/pndagiji/Documents/CIDUR_BIDS/data_bids \
    SUBJECT_LIST_FILE="${CONNECT_ROOT}/subjects_dwi_test2_cidur_interactive.txt" \
    SBATCH_JOB_NAME=dwi_test_def_cidur_int

  run_submit "TrackTBI sub-TBI011011 (interactive, SyN SDC)" \
    "${INTERACTIVE[@]}" \
    ARRAY_CONCURRENCY=1 \
    BIDS_DIR=/mnt/nfs/home/urmc-sh.rochester.edu/pndagiji/Documents/TrackTBI \
    SUBJECT_LIST_FILE="${TRACKTBI_ROOT}/dwi_pipeline/subjects_tbi011011.txt" \
    QSIPREP_USE_SYN_SDC=1 \
    SBATCH_JOB_NAME=dwi_test_def_tbi011011

  run_submit "CIDUR sub-007 (general)" \
    "${GENERAL[@]}" \
    ARRAY_CONCURRENCY=1 \
    BIDS_DIR=/mnt/nfs/home/urmc-sh.rochester.edu/pndagiji/Documents/CIDUR_BIDS/data_bids \
    SUBJECT_LIST_FILE="${CONNECT_ROOT}/subjects_dwi_test2_cidur_general.txt" \
    SBATCH_JOB_NAME=dwi_test_def_cidur_gen

  run_submit "TrackTBI phase2 sub-TBI011204 (general, b1000 select)" \
    "${GENERAL[@]}" \
    ARRAY_CONCURRENCY=1 \
    BIDS_DIR=/mnt/nfs/home/urmc-sh.rochester.edu/pndagiji/Documents/TrackTBI/phase2_test_bids \
    SUBJECT_LIST_FILE="${TRACKTBI_ROOT}/dwi_pipeline/subjects_tbi011204.txt" \
    DWI_SELECT_JSON="${DWI_SELECT_B1000}" \
    SBATCH_JOB_NAME=dwi_test_def_tbi011204

elif [[ "${MODE}" == "interactive-all-cidur" ]]; then
  run_submit "CIDUR sub-001, 006, 007 (interactive)" \
    "${INTERACTIVE[@]}" \
    ARRAY_CONCURRENCY=3 \
    BIDS_DIR=/mnt/nfs/home/urmc-sh.rochester.edu/pndagiji/Documents/CIDUR_BIDS/data_bids \
    SUBJECT_LIST_FILE="${CONNECT_ROOT}/subjects_dwi_test2_cidur.txt" \
    SBATCH_JOB_NAME=dwi_test_def_cidur

  run_submit "TrackTBI sub-TBI011011 (general)" \
    "${GENERAL[@]}" \
    ARRAY_CONCURRENCY=1 \
    BIDS_DIR=/mnt/nfs/home/urmc-sh.rochester.edu/pndagiji/Documents/TrackTBI \
    SUBJECT_LIST_FILE="${TRACKTBI_ROOT}/dwi_pipeline/subjects_tbi011011.txt" \
    QSIPREP_USE_SYN_SDC=1 \
    SBATCH_JOB_NAME=dwi_test_def_tbi011011

  run_submit "TrackTBI phase2 sub-TBI011204 (general)" \
    "${GENERAL[@]}" \
    ARRAY_CONCURRENCY=1 \
    BIDS_DIR=/mnt/nfs/home/urmc-sh.rochester.edu/pndagiji/Documents/TrackTBI/phase2_test_bids \
    SUBJECT_LIST_FILE="${TRACKTBI_ROOT}/dwi_pipeline/subjects_tbi011204.txt" \
    DWI_SELECT_JSON="${DWI_SELECT_B1000}" \
    SBATCH_JOB_NAME=dwi_test_def_tbi011204

else
  run_submit "CIDUR sub-001, 006, 007 (general)" \
    "${GENERAL[@]}" \
    ARRAY_CONCURRENCY=3 \
    BIDS_DIR=/mnt/nfs/home/urmc-sh.rochester.edu/pndagiji/Documents/CIDUR_BIDS/data_bids \
    SUBJECT_LIST_FILE="${CONNECT_ROOT}/subjects_dwi_test2_cidur.txt" \
    SBATCH_JOB_NAME=dwi_test_def_cidur

  run_submit "TrackTBI sub-TBI011011 (general)" \
    "${GENERAL[@]}" \
    ARRAY_CONCURRENCY=1 \
    BIDS_DIR=/mnt/nfs/home/urmc-sh.rochester.edu/pndagiji/Documents/TrackTBI \
    SUBJECT_LIST_FILE="${TRACKTBI_ROOT}/dwi_pipeline/subjects_tbi011011.txt" \
    QSIPREP_USE_SYN_SDC=1 \
    SBATCH_JOB_NAME=dwi_test_def_tbi011011

  run_submit "TrackTBI phase2 sub-TBI011204 (general)" \
    "${GENERAL[@]}" \
    ARRAY_CONCURRENCY=1 \
    BIDS_DIR=/mnt/nfs/home/urmc-sh.rochester.edu/pndagiji/Documents/TrackTBI/phase2_test_bids \
    SUBJECT_LIST_FILE="${TRACKTBI_ROOT}/dwi_pipeline/subjects_tbi011204.txt" \
    DWI_SELECT_JSON="${DWI_SELECT_B1000}" \
    SBATCH_JOB_NAME=dwi_test_def_tbi011204
fi

echo ""
echo "Results root: ${RESULTS_ROOT}"
