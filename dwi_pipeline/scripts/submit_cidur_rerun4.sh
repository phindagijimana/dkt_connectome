#!/bin/bash
# Submit CIDUR rerun batch for subjects 001, 002, 009, 076.
#
# Usage:
#   bash dwi_pipeline/scripts/submit_cidur_rerun4.sh
#
#   001, 002 — connectome + nodestrength (flat results tree)
#   009      — connectome + nodestrength per session (session_aware/)
#   076      — full pipeline with --no-sdc (GE, no fieldmap)

set -euo pipefail

DWI_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
REPO_ROOT="$(cd "${DWI_ROOT}/.." && pwd)"

export BIDS_DIR="${BIDS_DIR:-/mnt/nfs/home/urmc-sh.rochester.edu/pndagiji/Documents/CIDUR_BIDS/data_bids}"
export RESULTS_ROOT="${RESULTS_ROOT:-/mnt/nfs/Gugger_Lab/NIR/dwi_CIDUR/results}"
export SESSION_AWARE_ROOT="${SESSION_AWARE_ROOT:-${RESULTS_ROOT}/session_aware}"
export SUBJECT_LIST_FILE="${SUBJECT_LIST_FILE:-${DWI_ROOT}/subject_list_cidur_rerun4.txt}"
export SUBJECT_LIST_USE_EXISTING=1
export ARRAY_SCRIPT="${DWI_ROOT}/scripts/array_cidur_rerun4.sh"
unset ARRAY_CONCURRENCY EXCLUDE_NODES 2>/dev/null || true
export ARRAY_CONCURRENCY="${ARRAY_CONCURRENCY:-4}"
export PIPELINE_ENGINE=snakemake
export PIPELINE_MODE=connectome
export RUN_RECON="${RUN_RECON:-0}"
export RUN_INPAINT=0
export RECON_TOOL=fastsurfer
export RECON_FASTSURFER_DEVICE="${RECON_FASTSURFER_DEVICE:-cpu}"
export CONNECTOME_SIFT2=1
export TRACTOGRAPHY_MODEL=both
export NTHREADS=8
export OMP_NTHREADS=8
export SBATCH_TIME="${SBATCH_TIME:-12:00:00}"
export SBATCH_PARTITION="${SBATCH_PARTITION:-interactive}"
export SBATCH_CPUS=8
export SBATCH_MEM=48G
export SBATCH_JOB_NAME=cidur_rerun4
export EXCLUDE_NODES="${CIDUR_EXCLUDE_NODES:-smdodwork01}"

[[ -s "${SUBJECT_LIST_FILE}" ]] || {
  echo "Missing subject list: ${SUBJECT_LIST_FILE}"
  exit 1
}

chmod +x "${ARRAY_SCRIPT}"

cd "${DWI_ROOT}"
exec ./submit.sh --fastsurfer --no-inpaint --connectome-sift2 --tractography-model both
