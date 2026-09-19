#!/bin/bash
# Group 2 wave 2: full pipeline (10 subjects) + sub-022 (qsiprep done, needs recon).
# Excludes sub-019/sub-021 while batch-10 job 49997 may still be running.
#
# Usage:
#   bash dwi_pipeline/scripts/submit_cidur_g2_wave2.sh

set -euo pipefail

DWI_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
REPO_ROOT="$(dirname "${DWI_ROOT}")"

export BIDS_DIR="/mnt/nfs/home/urmc-sh.rochester.edu/pndagiji/Documents/CIDUR_BIDS/data_bids"
export RESULTS_ROOT="/mnt/nfs/Gugger_Lab/NIR/dwi_CIDUR/results"
export FS_LICENSE="/mnt/nfs/home/urmc-sh.rochester.edu/pndagiji/Documents/others/data_mining/freesurfer/license.txt"
export APPTAINER_TMPDIR="${HOME}/.cache/dkt-connectome/apptainer_tmp"
mkdir -p "${APPTAINER_TMPDIR}"
export DWI_SELECT_JSON="${DWI_SELECT_JSON:-${DWI_ROOT}/config/dwi_select_50dirax_no_fmap.json}"
export SUBJECT_LIST_FILE="${SUBJECT_LIST_FILE:-${DWI_ROOT}/subject_list_cidur_g2_wave2.txt}"
export SUBJECT_LIST_USE_EXISTING=1
export ARRAY_CONCURRENCY="${ARRAY_CONCURRENCY:-4}"
export PIPELINE_ENGINE=snakemake
export PIPELINE_MODE=all
export RUN_RECON=1
export RUN_INPAINT=0
export RECON_TOOL=fastsurfer
export RECON_FASTSURFER_DEVICE="${RECON_FASTSURFER_DEVICE:-cpu}"
export CONNECTOME_SIFT2=1
export TRACTOGRAPHY_MODEL=both
export RUN_NODESTRENGTH=1
export QSIPREP_NO_SDC=1
export NTHREADS=8
export OMP_NTHREADS=8
export SBATCH_TIME="${SBATCH_TIME:-12:00:00}"
export SBATCH_PARTITION="${SBATCH_PARTITION:-interactive}"
export SBATCH_CPUS=8
export SBATCH_MEM=64G
export SBATCH_JOB_NAME=cidur_g2_w2
export EXCLUDE_NODES="${EXCLUDE_NODES:-smdodwork05,smdodwork02}"

[[ -s "${SUBJECT_LIST_FILE}" ]] || {
  echo "Missing subject list: ${SUBJECT_LIST_FILE}" >&2
  exit 1
}

N="$(wc -l < "${SUBJECT_LIST_FILE}")"
echo "CIDUR G2 wave 2 (full pipeline): ${N} subjects"
echo "  RESULTS_ROOT=${RESULTS_ROOT}"
echo "  SUBJECT_LIST_FILE=${SUBJECT_LIST_FILE}"
echo "  DWI_SELECT_JSON=${DWI_SELECT_JSON}"
echo "  SBATCH_TIME=${SBATCH_TIME} PARTITION=${SBATCH_PARTITION} CONCURRENCY=${ARRAY_CONCURRENCY}"
echo "  Note: sub-019/sub-021 excluded (batch-10 may still be running)"

cd "${DWI_ROOT}"
exec ./submit.sh --fastsurfer --no-inpaint --no-sdc --connectome-sift2 \
  --tractography-model both --dwi-select "${DWI_SELECT_JSON}"
