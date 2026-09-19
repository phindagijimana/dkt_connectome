#!/bin/bash
# Resume sub-009 ses-2 under session_aware (upstream done; SD_STREAM timed out Sep 3).
#
# Usage:
#   bash dwi_pipeline/scripts/submit_cidur_g1_sub009_ses2_resume.sh

set -euo pipefail

DWI_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
GUGGER="${CIDUR_RESULTS_ROOT:-/mnt/nfs/Gugger_Lab/NIR/dwi_CIDUR/results}"
SA="${GUGGER}/session_aware/sub-009/ses-2"
TRACT="${SA}/tractography/sub-009"
TCK="${TRACT}/model-SDSTREAM_streamlines.tck"
WEIGHTS="${TRACT}/model-SDSTREAM_sift2weights.csv"

if [[ -f "${TCK}" && ! -f "${WEIGHTS}" ]]; then
  echo "Removing incomplete SD_STREAM tractography: ${TCK}"
  rm -f "${TCK}"
fi

export FS_SUBJECTS_DIR="${FS_SUBJECTS_DIR:-${SA}/freesurfer}"
export RECON_OUT="${RECON_OUT:-${FS_SUBJECTS_DIR}}"
export SBATCH_TIME="${SBATCH_TIME:-12:00:00}"
export SBATCH_MEM="${SBATCH_MEM:-128G}"
export SBATCH_PARTITION="${SBATCH_PARTITION:-interactive}"
export SBATCH_JOB_NAME="${SBATCH_JOB_NAME:-cidur_009_ses2}"
export EXCLUDE_NODES="${EXCLUDE_NODES-}"

echo "CIDUR sub-009 ses-2 resume (sdstream + connectome + nodestrength)"
echo "  RESULTS_ROOT=${SA}"
echo "  FS_SUBJECTS_DIR=${FS_SUBJECTS_DIR}"
echo "  SBATCH_TIME=${SBATCH_TIME} MEM=${SBATCH_MEM} PARTITION=${SBATCH_PARTITION}"

bash "${DWI_ROOT}/scripts/submit_cidur_g1_connectome_finish.sh" 009 \
  --results-root "${SA}" \
  --recon-session 2
