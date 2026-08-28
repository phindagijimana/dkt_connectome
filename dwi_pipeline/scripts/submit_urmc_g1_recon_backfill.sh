#!/bin/bash
# Submit Group 1 recon + connectome + SD_STREAM backfill (local RESULTS_ROOT).
#
# Usage:
#   bash dwi_pipeline/scripts/submit_urmc_g1_recon_backfill.sh

set -euo pipefail

DWI_ROOT="$(cd "$(dirname "$0")/.." && pwd)"

export BIDS_DIR="${BIDS_DIR:-/mnt/nfs/home/urmc-sh.rochester.edu/pndagiji/Documents/CIDUR_BIDS/data_bids}"
export RESULTS_ROOT="${RESULTS_ROOT:-${DWI_ROOT}/results}"
unset RECON_SESSION
export DWI_SELECT_JSON="${DWI_SELECT_JSON:-${DWI_ROOT}/config/dwi_select_64dirax_with_fmap.json}"
export DWI_SHELL_B="${DWI_SHELL_B:-1000}"
# Always use the G1 recon backfill list (ignore stale SUBJECT_LIST_FILE in env).
export SUBJECT_LIST_FILE="${URMC_G1_RECON_LIST:-${DWI_ROOT}/subject_list_cidur_g1_need_recon.txt}"
export SUBJECT_LIST_USE_EXISTING=1
export ARRAY_SCRIPT="${DWI_ROOT}/scripts/array_urmc_g1_recon_backfill.sh"
export ARRAY_CONCURRENCY="${ARRAY_CONCURRENCY:-2}"
export PIPELINE_ENGINE=snakemake
export PIPELINE_MODE=all
export RUN_RECON=1
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
export SBATCH_JOB_NAME=urmc_g1_recon
export EXCLUDE_NODES="${EXCLUDE_NODES-smdodwork05}"

[[ -s "${SUBJECT_LIST_FILE}" ]] || {
  echo "Missing subject list: ${SUBJECT_LIST_FILE}" >&2
  exit 1
}

chmod +x "${ARRAY_SCRIPT}"

cd "${DWI_ROOT}"
exec ./submit.sh --fastsurfer --no-inpaint --connectome-sift2 --tractography-model both
