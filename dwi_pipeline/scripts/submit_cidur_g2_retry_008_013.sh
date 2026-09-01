#!/bin/bash
# Retry CIDUR Group 2 subjects that hit the 12 h wall-time limit on job 49773.
# QSIPrep + FastSurfer recon are already done; Snakemake resumes at qsirecon.
#
# Usage:
#   bash dwi_pipeline/scripts/submit_cidur_g2_retry_008_013.sh

set -euo pipefail

DWI_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
REPO_ROOT="$(dirname "${DWI_ROOT}")"

export BIDS_DIR="${BIDS_DIR:-/mnt/nfs/home/urmc-sh.rochester.edu/pndagiji/Documents/CIDUR_BIDS/data_bids}"
export RESULTS_ROOT="${RESULTS_ROOT:-/mnt/nfs/Gugger_Lab/NIR/dwi_CIDUR/results}"
export SUBJECT_LIST_FILE="${SUBJECT_LIST_FILE:-${DWI_ROOT}/subject_list_g2_retry_008_013.txt}"
export SUBJECT_LIST_USE_EXISTING=1
export DWI_SELECT_JSON="${DWI_SELECT_JSON:-${DWI_ROOT}/config/dwi_select_50dirax_no_fmap.json}"
export QSIPREP_NO_SDC=1
export PIPELINE_MODE=all
export RUN_RECON=1
export RUN_INPAINT=0
export RECON_TOOL=fastsurfer
export RECON_FASTSURFER_DEVICE="${RECON_FASTSURFER_DEVICE:-cpu}"
export CONNECTOME_SIFT2=1
export TRACTOGRAPHY_MODEL=both
export RUN_NODESTRENGTH=1
export NTHREADS=8
export OMP_NTHREADS=8
export ARRAY_CONCURRENCY=2
export SBATCH_TIME="${SBATCH_TIME:-12:00:00}"
export SBATCH_MEM=64G
export SBATCH_CPUS=8
export SBATCH_PARTITION="${SBATCH_PARTITION:-interactive}"
export SBATCH_JOB_NAME=cidur_g2_retry
export EXCLUDE_NODES="${EXCLUDE_NODES-smdodwork05}"

[[ -s "${SUBJECT_LIST_FILE}" ]] || {
  echo "Missing subject list: ${SUBJECT_LIST_FILE}" >&2
  exit 1
}

N="$(wc -l < "${SUBJECT_LIST_FILE}")"
echo "CIDUR G2 retry (timed-out subjects): ${N} subjects"
echo "  SUBJECT_LIST_FILE=${SUBJECT_LIST_FILE}"
echo "  RESULTS_ROOT=${RESULTS_ROOT}"

cd "${DWI_ROOT}"
exec ./submit.sh --fastsurfer --no-inpaint --no-sdc --connectome-sift2 \
  --tractography-model both --dwi-select "${DWI_SELECT_JSON}"
