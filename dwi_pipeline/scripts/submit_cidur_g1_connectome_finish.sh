#!/bin/bash
# Finish connectome + nodestrength for subjects with tractography already on disk.
#
# Usage:
#   bash dwi_pipeline/scripts/submit_cidur_g1_connectome_finish.sh 074
#   bash dwi_pipeline/scripts/submit_cidur_g1_connectome_finish.sh 009 \
#     --results-root /mnt/nfs/Gugger_Lab/NIR/dwi_CIDUR/results/session_aware/sub-009/ses-2 \
#     --recon-session 2
#
# Default batch (074 + 009 ses-2):
#   bash dwi_pipeline/scripts/submit_cidur_g1_connectome_finish.sh

set -euo pipefail

DWI_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
REPO_ROOT="$(dirname "${DWI_ROOT}")"
GUGGER="${CIDUR_RESULTS_ROOT:-/mnt/nfs/Gugger_Lab/NIR/dwi_CIDUR/results}"
ARRAY="${DWI_ROOT}/scripts/array_cidur_g1_connectome_finish.sh"

submit_one() {
  local subject="$1"
  local results_root="$2"
  local session="${3:-}"
  local list="${DWI_ROOT}/subject_list_cidur_g1_sub${subject}_connectome.txt"
  if [[ "${subject}" == "009" && -n "${session}" ]]; then
    list="${DWI_ROOT}/subject_list_cidur_g1_sub009_ses2_connectome.txt"
  fi
  [[ -f "${list}" ]] || {
    echo "Missing subject list: ${list}" >&2
    exit 1
  }

  unset BIDS_DIR RESULTS_ROOT RECON_SESSION SUBJECT_LIST_FILE
  export BIDS_DIR="${CIDUR_BIDS_DIR:-/mnt/nfs/home/urmc-sh.rochester.edu/pndagiji/Documents/CIDUR_BIDS/data_bids}"
  export RESULTS_ROOT="${results_root}"
  export SUBJECT_LIST_FILE="${list}"
  export DWI_ROOT REPO_ROOT
  export RECON_SESSION="${session}"
  export PIPELINE_ENGINE=snakemake
  export RUN_RECON=0
  export RUN_INPAINT=0
  export RECON_TOOL=fastsurfer
  export CONNECTOME_SIFT2=1
  export TRACTOGRAPHY_MODEL=both
  export NTHREADS=8
  export OMP_NTHREADS=8
  export SBATCH_TIME="${SBATCH_TIME:-12:00:00}"
  export SBATCH_PARTITION="${SBATCH_PARTITION:-interactive}"
  export SBATCH_CPUS="${SBATCH_CPUS:-8}"
  export SBATCH_MEM="${SBATCH_MEM:-128G}"
  export SBATCH_JOB_NAME="cidur_conn_${subject}"
  export EXCLUDE_NODES="${EXCLUDE_NODES-}"

  chmod +x "${ARRAY}"
  cd "${DWI_ROOT}"
  SBATCH_EXTRA=(--export=ALL --array=1)
  [[ -n "${EXCLUDE_NODES}" ]] && SBATCH_EXTRA+=(--exclude="${EXCLUDE_NODES}")
  [[ -n "${SBATCH_PARTITION}" ]] && SBATCH_EXTRA+=(--partition="${SBATCH_PARTITION}")
  [[ -n "${SBATCH_TIME}" ]] && SBATCH_EXTRA+=(--time="${SBATCH_TIME}")
  [[ -n "${SBATCH_CPUS}" ]] && SBATCH_EXTRA+=(--cpus-per-task="${SBATCH_CPUS}")
  [[ -n "${SBATCH_MEM}" ]] && SBATCH_EXTRA+=(--mem="${SBATCH_MEM}")
  SBATCH_EXTRA+=(--job-name="${SBATCH_JOB_NAME}"
                 --output="${REPO_ROOT}/logs/${SBATCH_JOB_NAME}_%A_%a.out"
                 --error="${REPO_ROOT}/logs/${SBATCH_JOB_NAME}_%A_%a.err")
  sbatch "${SBATCH_EXTRA[@]}" "${ARRAY}"
}

if (($# == 0)); then
  submit_one 074 "${GUGGER}" ""
  submit_one 009 "${GUGGER}/session_aware/sub-009/ses-2" "2"
  exit 0
fi

subject="${1#sub-}"
shift
results_root="${GUGGER}"
session=""
while (($#)); do
  case "$1" in
    --results-root) results_root="$2"; shift 2 ;;
    --recon-session) session="$2"; shift 2 ;;
    *) echo "Unknown option: $1" >&2; exit 2 ;;
  esac
done
submit_one "${subject}" "${results_root}" "${session}"
