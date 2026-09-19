#!/bin/bash
# Submit subject_qc backfill for CIDUR G1 (after connectome/nodestrength complete).
#
# Usage:
#   bash dwi_pipeline/scripts/submit_cidur_g1_subject_qc.sh

set -euo pipefail

DWI_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
REPO_ROOT="$(dirname "${DWI_ROOT}")"

export BIDS_DIR="${BIDS_DIR:-/mnt/nfs/home/urmc-sh.rochester.edu/pndagiji/Documents/CIDUR_BIDS/data_bids}"
export RESULTS_ROOT="${RESULTS_ROOT:-/mnt/nfs/Gugger_Lab/NIR/dwi_CIDUR/results}"
export DWI_SELECT_JSON="${DWI_SELECT_JSON:-${DWI_ROOT}/config/dwi_select_64dirax_with_fmap.json}"
export SUBJECT_LIST_FILE="${SUBJECT_LIST_FILE:-${DWI_ROOT}/subject_list_cidur_g1_rigid_reg_rerun.txt}"
export SUBJECT_LIST_USE_EXISTING=1
export ARRAY_SCRIPT="${DWI_ROOT}/scripts/array_cidur_g1_subject_qc.sh"
export ARRAY_CONCURRENCY="${ARRAY_CONCURRENCY:-10}"
export PIPELINE_ENGINE=snakemake
export RUN_RECON=0
export RUN_INPAINT=0
export RECON_TOOL=fastsurfer
export SBATCH_TIME="${SBATCH_TIME:-00:30:00}"
export SBATCH_PARTITION="${SBATCH_PARTITION:-interactive}"
export SBATCH_CPUS=2
export SBATCH_MEM=8G
export SBATCH_JOB_NAME=cidur_g1_qc

[[ -s "${SUBJECT_LIST_FILE}" ]] || {
  echo "Missing subject list: ${SUBJECT_LIST_FILE}" >&2
  exit 1
}

N="$(wc -l < "${SUBJECT_LIST_FILE}")"
echo "CIDUR G1 subject_qc backfill: ${N} subjects"
echo "  RESULTS_ROOT=${RESULTS_ROOT}"

chmod +x "${ARRAY_SCRIPT}"

cd "${DWI_ROOT}"
exec ./submit.sh --fastsurfer --no-inpaint --connectome-sift2 --tractography-model both \
  --dwi-select "${DWI_SELECT_JSON}"
