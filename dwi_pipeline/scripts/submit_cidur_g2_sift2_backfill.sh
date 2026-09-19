#!/bin/bash
# Build missing iFOD2 SIFT2 connectomes for sub-044 and sub-059 (IFOD2-only finish).
#
# Usage:
#   bash dwi_pipeline/scripts/submit_cidur_g2_sift2_backfill.sh

set -euo pipefail

DWI_ROOT="$(cd "$(dirname "$0")/.." && pwd)"

export BIDS_DIR="/mnt/nfs/home/urmc-sh.rochester.edu/pndagiji/Documents/CIDUR_BIDS/data_bids"
export RESULTS_ROOT="/mnt/nfs/Gugger_Lab/NIR/dwi_CIDUR/results"
export FS_LICENSE="/mnt/nfs/home/urmc-sh.rochester.edu/pndagiji/Documents/others/data_mining/freesurfer/license.txt"
export APPTAINER_TMPDIR="${HOME}/.cache/dkt-connectome/apptainer_tmp"
mkdir -p "${APPTAINER_TMPDIR}"
export DWI_SELECT_JSON="${DWI_SELECT_JSON:-${DWI_ROOT}/config/dwi_select_50dirax_no_fmap.json}"
export SUBJECT_LIST_FILE="${SUBJECT_LIST_FILE:-${DWI_ROOT}/subject_list_cidur_g2_sift2_backfill.txt}"
export SUBJECT_LIST_USE_EXISTING=1
export ARRAY_CONCURRENCY=2
export PIPELINE_ENGINE=snakemake
export PIPELINE_MODE=connectome
export RUN_RECON=0
export RUN_INPAINT=0
export RUN_CONNECTOME=1
export RUN_NODESTRENGTH=0
export RECON_TOOL=fastsurfer
export CONNECTOME_SIFT2=1
export TRACTOGRAPHY_MODEL=ifod2
export QSIPREP_NO_SDC=1
export NTHREADS=8
export OMP_NTHREADS=8
export SBATCH_TIME="${SBATCH_TIME:-12:00:00}"
export SBATCH_PARTITION="${SBATCH_PARTITION:-interactive}"
export SBATCH_CPUS=8
export SBATCH_MEM="${SBATCH_MEM:-128G}"
export SBATCH_JOB_NAME="${SBATCH_JOB_NAME:-cidur_g2_sift2}"
export EXCLUDE_NODES="${EXCLUDE_NODES-}"

echo "CIDUR G2 iFOD2 SIFT2 backfill (connectome mode)"
echo "  SUBJECT_LIST_FILE=${SUBJECT_LIST_FILE}"
echo "  PARTITION=${SBATCH_PARTITION} TIME=${SBATCH_TIME}"

cd "${DWI_ROOT}"
exec ./submit.sh --no-recon --no-inpaint --connectome-sift2 \
  --tractography-model ifod2 --no-node-strength --no-sdc \
  --dwi-select "${DWI_SELECT_JSON}"
