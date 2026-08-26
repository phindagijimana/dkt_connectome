#!/bin/bash
# Submit sub-009 session-aware connectome + nodestrength repair (ses-1, ses-2).
#
# Usage:
#   bash dwi_pipeline/scripts/submit_cidur_rerun_009.sh

set -euo pipefail

DWI_ROOT="$(cd "$(dirname "$0")/.." && pwd)"

export BIDS_DIR="${BIDS_DIR:-/mnt/nfs/home/urmc-sh.rochester.edu/pndagiji/Documents/CIDUR_BIDS/data_bids}"
export RESULTS_ROOT="${RESULTS_ROOT:-${DWI_ROOT}/results}"
export SESSION_AWARE_ROOT="${SESSION_AWARE_ROOT:-${RESULTS_ROOT}/session_aware}"
# submit.sh preflight checks FS_SUBJECTS_DIR/sub-009; session-aware recon lives under ses-1.
export FS_SUBJECTS_DIR="${FS_SUBJECTS_DIR:-${SESSION_AWARE_ROOT}/sub-009/ses-1/freesurfer}"
export RECON_OUT="${RECON_OUT:-${FS_SUBJECTS_DIR}}"
export SUBJECT_LIST_FILE="${SUBJECT_LIST_FILE:-${DWI_ROOT}/subject_list_cidur_rerun_009_only.txt}"
export SUBJECT_LIST_USE_EXISTING=1
export ARRAY_SCRIPT="${DWI_ROOT}/scripts/array_cidur_rerun4.sh"
export ARRAY_CONCURRENCY=1
export PIPELINE_ENGINE=snakemake
export PIPELINE_MODE=connectome
export RUN_RECON=0
export RUN_INPAINT=0
export CONNECTOME_SIFT2=1
export TRACTOGRAPHY_MODEL=both
export NTHREADS=8
export OMP_NTHREADS=8
export SBATCH_TIME="${SBATCH_TIME:-12:00:00}"
export SBATCH_PARTITION="${SBATCH_PARTITION:-interactive}"
export SBATCH_CPUS=8
export SBATCH_MEM=48G
export SBATCH_JOB_NAME=cidur_rerun_009
export EXCLUDE_NODES="${EXCLUDE_NODES-smdodwork05}"

chmod +x "${ARRAY_SCRIPT}"

cd "${DWI_ROOT}"
exec ./submit.sh --no-inpaint --connectome-sift2 --tractography-model both
