#!/bin/bash
# Example: submit connectome + nodestrength for one subject (partial rerun).
#
# Copy and customize paths; do not commit site-specific values.
#
# Usage:
#   export CIDUR_BIDS_DIR=/path/to/data_bids
#   export CIDUR_RESULTS_ROOT=/path/to/results
#   export SUBJECT_LIST_FILE=dwi_pipeline/subject_list.example.txt
#   bash dwi_pipeline/scripts/submit_connectome_finish.example.sh

set -euo pipefail

DWI_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
REPO_ROOT="$(dirname "${DWI_ROOT}")"
ARRAY="${DWI_ROOT}/scripts/array_cidur_g1_connectome_finish.sh"

: "${CIDUR_BIDS_DIR:?Set CIDUR_BIDS_DIR}"
: "${CIDUR_RESULTS_ROOT:?Set CIDUR_RESULTS_ROOT}"
: "${SUBJECT_LIST_FILE:?Set SUBJECT_LIST_FILE}"

export BIDS_DIR="${CIDUR_BIDS_DIR}"
export RESULTS_ROOT="${CIDUR_RESULTS_ROOT}"
export DWI_ROOT REPO_ROOT
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
export SBATCH_JOB_NAME="${SBATCH_JOB_NAME:-conn_finish}"

chmod +x "${ARRAY}"
cd "${DWI_ROOT}"

SBATCH_EXTRA=(--export=ALL --array=1)
[[ -n "${EXCLUDE_NODES:-}" ]] && SBATCH_EXTRA+=(--exclude="${EXCLUDE_NODES}")
[[ -n "${SBATCH_PARTITION}" ]] && SBATCH_EXTRA+=(--partition="${SBATCH_PARTITION}")
[[ -n "${SBATCH_TIME}" ]] && SBATCH_EXTRA+=(--time="${SBATCH_TIME}")
[[ -n "${SBATCH_CPUS}" ]] && SBATCH_EXTRA+=(--cpus-per-task="${SBATCH_CPUS}")
[[ -n "${SBATCH_MEM}" ]] && SBATCH_EXTRA+=(--mem="${SBATCH_MEM}")
SBATCH_EXTRA+=(--job-name="${SBATCH_JOB_NAME}"
               --output="${REPO_ROOT}/logs/${SBATCH_JOB_NAME}_%A_%a.out"
               --error="${REPO_ROOT}/logs/${SBATCH_JOB_NAME}_%A_%a.err")

echo "Submitting connectome finish: ${SUBJECT_LIST_FILE}"
echo "  RESULTS_ROOT=${RESULTS_ROOT}"
echo "  SBATCH_TIME=${SBATCH_TIME} MEM=${SBATCH_MEM} PARTITION=${SBATCH_PARTITION}"
sbatch "${SBATCH_EXTRA[@]}" "${ARRAY}"
