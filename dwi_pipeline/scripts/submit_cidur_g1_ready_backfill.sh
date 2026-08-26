#!/bin/bash
# Submit Group 1 connectome-only backfill (6 subjects with recon already on Gugger).
#
# Usage:
#   bash dwi_pipeline/scripts/submit_cidur_g1_ready_backfill.sh

set -euo pipefail

DWI_ROOT="$(cd "$(dirname "$0")/.." && pwd)"

export BIDS_DIR="${BIDS_DIR:-/mnt/nfs/home/urmc-sh.rochester.edu/pndagiji/Documents/CIDUR_BIDS/data_bids}"
export RESULTS_ROOT="${RESULTS_ROOT:-/mnt/nfs/Gugger_Lab/NIR/dwi_CIDUR/results}"
export SUBJECT_LIST_FILE="${SUBJECT_LIST_FILE:-${DWI_ROOT}/subject_list_cidur_g1_ready.txt}"
export SUBJECT_LIST_USE_EXISTING=1
export ARRAY_CONCURRENCY="${ARRAY_CONCURRENCY:-3}"
export SBATCH_JOB_NAME=cidur_g1_ready
export EXCLUDE_NODES="${EXCLUDE_NODES-smdodwork01}"

exec bash "${DWI_ROOT}/scripts/submit_cidur_backfill.sh"
