#!/bin/bash
# SD_STREAM backfill for G2 subjects that finished with IFOD2-only (044, 059).
# Runs tractography + SD_STREAM connectomes on general (24h).
#
# Usage:
#   bash dwi_pipeline/scripts/submit_cidur_g2_sdstream_general.sh
#   IFOD2_JOB_ID=51117 bash dwi_pipeline/scripts/submit_cidur_g2_sdstream_general.sh

set -euo pipefail

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

submit_sdstream() {
  local list_file="$1"
  local job_name="$2"
  local dependency="${3:-}"

  export BIDS_DIR="/mnt/nfs/home/urmc-sh.rochester.edu/pndagiji/Documents/CIDUR_BIDS/data_bids"
  export RESULTS_ROOT
  export FS_LICENSE="/mnt/nfs/home/urmc-sh.rochester.edu/pndagiji/Documents/others/data_mining/freesurfer/license.txt"
  export APPTAINER_TMPDIR="${HOME}/.cache/dkt-connectome/apptainer_tmp"
  mkdir -p "${APPTAINER_TMPDIR}"
  export DWI_SELECT_JSON="${DWI_SELECT_JSON:-${DWI_ROOT}/config/dwi_select_50dirax_no_fmap.json}"
  export SUBJECT_LIST_FILE="${list_file}"
  export SUBJECT_LIST_USE_EXISTING=1
  export ARRAY_CONCURRENCY=1
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
  export SBATCH_TIME="${SBATCH_TIME:-24:00:00}"
  export SBATCH_PARTITION="${SBATCH_PARTITION:-general}"
  export SBATCH_CPUS=8
  export SBATCH_MEM="${SBATCH_MEM:-128G}"
  export SBATCH_JOB_NAME="${job_name}"
  export EXCLUDE_NODES="${EXCLUDE_NODES-}"
  if [[ -n "${dependency}" ]]; then
    export SBATCH_DEPENDENCY="${dependency}"
  else
    unset SBATCH_DEPENDENCY
  fi

  cd "${DWI_ROOT}"
  ./submit.sh --no-recon --no-inpaint --no-connectome --no-node-strength \
    --connectome-sift2 --tractography-model sd_stream --no-sdc \
    --dwi-select "${DWI_SELECT_JSON}"
}

IFOD2_JOB_ID="${IFOD2_JOB_ID:-51117}"
LIST_044="${DWI_ROOT}/subject_list_cidur_g2_wave3_044.txt"
LIST_059="${DWI_ROOT}/subject_list_cidur_g2_059.txt"

preclean_stale_sdstream 044
preclean_stale_sdstream 059

echo "=== CIDUR G2 SD_STREAM backfill (general ${SBATCH_TIME:-24:00:00}) ==="
echo "  044: submit now (IFOD2 connectome already on Gugger)"
echo "  059: after IFOD2 job ${IFOD2_JOB_ID} if still active"

submit_sdstream "${LIST_044}" "cidur_g2_044_sd" ""

DEP=""
if squeue -h -j "${IFOD2_JOB_ID}" 2>/dev/null | grep -q .; then
  DEP="afterok:${IFOD2_JOB_ID}"
  echo "  059 dependency: ${DEP} (IFOD2 job still queued/running)"
elif sacct -j "${IFOD2_JOB_ID}" --format=State -n 2>/dev/null | grep -qE 'RUNNING|PENDING'; then
  DEP="afterok:${IFOD2_JOB_ID}"
  echo "  059 dependency: ${DEP}"
else
  if [[ ! -f "${RESULTS_ROOT}/connectomes/sub-059/dkt_nodes.mif" ]]; then
    echo "WARNING: sub-059 IFOD2 connectome not ready and job ${IFOD2_JOB_ID} not running." >&2
    echo "  Set IFOD2_JOB_ID or wait for IFOD2 finish before 059 SD_STREAM." >&2
    DEP="afterok:${IFOD2_JOB_ID}"
  else
    echo "  059: IFOD2 connectome present — no dependency"
  fi
fi

submit_sdstream "${LIST_059}" "cidur_g2_059_sd" "${DEP}"

echo ""
squeue -u "${USER}" -o "%.18i %.9P %.30j %.8u %.2t %.10M %.6D %R" | head -15
