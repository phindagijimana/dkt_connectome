#!/bin/bash
# Finish sub-044 on Gugger using IFOD2 only (skip SD_STREAM; tractogram in qsirecon).
#
# Usage:
#   bash dwi_pipeline/scripts/submit_cidur_g2_044_ifod2.sh

set -euo pipefail

DWI_ROOT="$(cd "$(dirname "$0")/.." && pwd)"

export BIDS_DIR="/mnt/nfs/home/urmc-sh.rochester.edu/pndagiji/Documents/CIDUR_BIDS/data_bids"
export RESULTS_ROOT="/mnt/nfs/Gugger_Lab/NIR/dwi_CIDUR/results"
export FS_LICENSE="/mnt/nfs/home/urmc-sh.rochester.edu/pndagiji/Documents/others/data_mining/freesurfer/license.txt"
export APPTAINER_TMPDIR="${HOME}/.cache/dkt-connectome/apptainer_tmp"
mkdir -p "${APPTAINER_TMPDIR}"
export DWI_SELECT_JSON="${DWI_SELECT_JSON:-${DWI_ROOT}/config/dwi_select_50dirax_no_fmap.json}"
export SUBJECT_LIST_FILE="${SUBJECT_LIST_FILE:-${DWI_ROOT}/subject_list_cidur_g2_wave3_044.txt}"
export SUBJECT_LIST_USE_EXISTING=1
export ARRAY_CONCURRENCY=1
export PIPELINE_ENGINE=snakemake
export PIPELINE_MODE=all
export RUN_RECON=1
export RUN_INPAINT=0
export RECON_TOOL=fastsurfer
export RECON_FASTSURFER_DEVICE="${RECON_FASTSURFER_DEVICE:-cpu}"
export CONNECTOME_SIFT2=1
export TRACTOGRAPHY_MODEL=ifod2
export RUN_NODESTRENGTH=1
export QSIPREP_NO_SDC=1
export NTHREADS=8
export OMP_NTHREADS=8
export SBATCH_TIME="${SBATCH_TIME:-12:00:00}"
export SBATCH_PARTITION="${SBATCH_PARTITION:-interactive}"
export SBATCH_CPUS=8
export SBATCH_MEM="${SBATCH_MEM:-64G}"
export SBATCH_JOB_NAME="${SBATCH_JOB_NAME:-cidur_g2_044_ifod2}"
export EXCLUDE_NODES="${EXCLUDE_NODES-}"

[[ -s "${SUBJECT_LIST_FILE}" ]] || {
  echo "Missing subject list: ${SUBJECT_LIST_FILE}" >&2
  exit 1
}

echo "CIDUR G2 sub-044 IFOD2 finish (connectome + nodestrength + QC)"
echo "  RESULTS_ROOT=${RESULTS_ROOT}"
echo "  TRACTOGRAPHY_MODEL=${TRACTOGRAPHY_MODEL}"
echo "  SBATCH_TIME=${SBATCH_TIME} PARTITION=${SBATCH_PARTITION}"

cd "${DWI_ROOT}"
exec ./submit.sh --fastsurfer --no-inpaint --no-sdc --connectome-sift2 \
  --tractography-model ifod2 --dwi-select "${DWI_SELECT_JSON}"
