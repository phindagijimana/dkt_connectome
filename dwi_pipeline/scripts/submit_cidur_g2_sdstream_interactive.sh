#!/bin/bash
# SD_STREAM backfill for sub-044 and sub-059 (IFOD2-only finishes) on interactive.
#
# Usage:
#   bash dwi_pipeline/scripts/submit_cidur_g2_sdstream_interactive.sh

set -euo pipefail

export SBATCH_PARTITION="${SBATCH_PARTITION:-interactive}"
export SBATCH_TIME="${SBATCH_TIME:-12:00:00}"
export SBATCH_MEM="${SBATCH_MEM:-128G}"
export ARRAY_CONCURRENCY="${ARRAY_CONCURRENCY:-2}"
export SBATCH_JOB_NAME="${SBATCH_JOB_NAME:-cidur_g2_sd_int}"
export SUBJECT_LIST_FILE="${SUBJECT_LIST_FILE:-$(cd "$(dirname "$0")/.." && pwd)/subject_list_cidur_g2_sdstream_backfill.txt}"

DWI_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
RESULTS_ROOT="/mnt/nfs/Gugger_Lab/NIR/dwi_CIDUR/results"

preclean_stale_sdstream() {
  local subj="$1"
  local tract_dir="${RESULTS_ROOT}/tractography/sub-${subj}"
  local tck="${tract_dir}/model-SDSTREAM_streamlines.tck"
  local weights="${tract_dir}/model-SDSTREAM_sift2weights.csv"
  if [[ -f "${tck}" && ! -f "${weights}" ]]; then
    echo "Removing incomplete SD_STREAM tractography: ${tck}"
    rm -f "${tck}"
  fi
}

preclean_stale_sdstream 044
preclean_stale_sdstream 059

export BIDS_DIR="/mnt/nfs/home/urmc-sh.rochester.edu/pndagiji/Documents/CIDUR_BIDS/data_bids"
export RESULTS_ROOT
export FS_LICENSE="/mnt/nfs/home/urmc-sh.rochester.edu/pndagiji/Documents/others/data_mining/freesurfer/license.txt"
export APPTAINER_TMPDIR="${HOME}/.cache/dkt-connectome/apptainer_tmp"
mkdir -p "${APPTAINER_TMPDIR}"
export DWI_SELECT_JSON="${DWI_SELECT_JSON:-${DWI_ROOT}/config/dwi_select_50dirax_no_fmap.json}"
export SUBJECT_LIST_USE_EXISTING=1
export PIPELINE_ENGINE=snakemake
export PIPELINE_MODE=sdstream
export RUN_RECON=0
export RUN_INPAINT=0
export RUN_CONNECTOME=0
export RUN_NODESTRENGTH=0
export RECON_TOOL=fastsurfer
export CONNECTOME_SIFT2=1
export TRACTOGRAPHY_MODEL=sd_stream
export QSIPREP_NO_SDC=1
export NTHREADS=8
export OMP_NTHREADS=8
export SBATCH_CPUS=8
export EXCLUDE_NODES="${EXCLUDE_NODES-}"
unset SBATCH_DEPENDENCY

echo "CIDUR G2 SD_STREAM backfill: 044 + 059 on ${SBATCH_PARTITION} (${SBATCH_TIME})"
echo "  SUBJECT_LIST_FILE=${SUBJECT_LIST_FILE}"
echo "  CONCURRENCY=${ARRAY_CONCURRENCY} MEM=${SBATCH_MEM}"

cd "${DWI_ROOT}"
exec ./submit.sh --no-recon --no-inpaint --no-connectome --no-node-strength \
  --connectome-sift2 --tractography-model sd_stream --no-sdc \
  --dwi-select "${DWI_SELECT_JSON}"
