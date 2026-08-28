#!/bin/bash
# Submit CIDUR Step 4+5 backfill array (connectome + nodestrength per subject).
#
# Usage:
#   bash dwi_pipeline/scripts/submit_cidur_backfill.sh
#
# CIDUR Step 2 was run with FastSurfer (trees under results/freesurfer/sub-XXX/).
# Excludes sub-001 (Step 5 only), sub-002 (done), sub-009/sub-076 (repair batch).

set -euo pipefail

DWI_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
REPO_ROOT="$(cd "${DWI_ROOT}/.." && pwd)"

export BIDS_DIR="${BIDS_DIR:-/mnt/nfs/home/urmc-sh.rochester.edu/pndagiji/Documents/CIDUR_BIDS/data_bids}"
export RESULTS_ROOT="${RESULTS_ROOT:-/mnt/nfs/Gugger_Lab/NIR/dwi_CIDUR/results}"
unset RECON_SESSION
export DWI_SELECT_JSON="${DWI_SELECT_JSON:-${DWI_ROOT}/config/dwi_select_64dirax_with_fmap.json}"
export DWI_SHELL_B="${DWI_SHELL_B:-1000}"
export SUBJECT_LIST_FILE="${SUBJECT_LIST_FILE:-${DWI_ROOT}/subject_list_cidur_backfill.txt}"
export SUBJECT_LIST_USE_EXISTING=1
export ARRAY_SCRIPT="${DWI_ROOT}/scripts/array_cidur_backfill.sh"
export ARRAY_CONCURRENCY="${ARRAY_CONCURRENCY:-8}"
export PIPELINE_ENGINE=snakemake
export PIPELINE_MODE=connectome
# Connectome needs aparc+aseg.mgz; Snakemake resumes FastSurfer when missing.
export RUN_RECON=0
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
export SBATCH_MEM=32G
export SBATCH_JOB_NAME=cidur_conn_ns
export EXCLUDE_NODES="${EXCLUDE_NODES-smdodwork05}"

[[ -s "${SUBJECT_LIST_FILE}" ]] || {
  echo "Missing subject list: ${SUBJECT_LIST_FILE}"
  echo "Run: grep -v -E '^(001|002|009|076)$' subject_list_cidur_all.txt > subject_list_cidur_backfill.txt"
  exit 1
}

chmod +x "${ARRAY_SCRIPT}"

cd "${DWI_ROOT}"
exec ./submit.sh --fastsurfer --no-inpaint --connectome-sift2 --tractography-model both
