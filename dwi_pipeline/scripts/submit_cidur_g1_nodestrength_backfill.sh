#!/bin/bash
# Submit nodestrength-only backfill for CIDUR G1 subjects with existing connectomes.

set -euo pipefail

DWI_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
REPO_ROOT="$(cd "${DWI_ROOT}/.." && pwd)"

export BIDS_DIR="${BIDS_DIR:-/mnt/nfs/home/urmc-sh.rochester.edu/pndagiji/Documents/CIDUR_BIDS/data_bids}"
export RESULTS_ROOT="${RESULTS_ROOT:-/mnt/nfs/Gugger_Lab/NIR/dwi_CIDUR/results}"
export SUBJECT_LIST_FILE="${DWI_ROOT}/subject_list_cidur_g1_nodestrength_14.txt"
export SUBJECT_LIST_USE_EXISTING=1
export ARRAY_SCRIPT="${DWI_ROOT}/scripts/array_cidur_g1_nodestrength_only.sh"
export ARRAY_CONCURRENCY="${ARRAY_CONCURRENCY:-4}"
export PIPELINE_ENGINE=snakemake
export PIPELINE_MODE=nodestrength
export RUN_RECON=0
export RUN_INPAINT=0
export NTHREADS=4
export OMP_NTHREADS=4
export SBATCH_TIME="${SBATCH_TIME:-00:45:00}"
export SBATCH_PARTITION="${SBATCH_PARTITION:-interactive}"
export SBATCH_CPUS=4
export SBATCH_MEM=16G
export SBATCH_JOB_NAME=cidur_ns
export EXCLUDE_NODES="${EXCLUDE_NODES-}"

[[ -s "${SUBJECT_LIST_FILE}" ]] || {
  echo "Missing subject list: ${SUBJECT_LIST_FILE}" >&2
  exit 1
}

chmod +x "${ARRAY_SCRIPT}"

cd "${DWI_ROOT}"
exec ./submit.sh --no-inpaint --no-recon
