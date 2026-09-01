#!/bin/bash
# Re-run connectome + nodestrength for CIDUR Group 1 (Siemens + fieldmaps) using
# the rigid FS-T1 -> QSIPrep ACPC label registration (PI suggestion).
#
# Reuses existing .tck when present (SKIP_RERUN_INCOMPLETE); rebuilds SD_STREAM
# tractography only if missing. Clears IFOD2 + SD_STREAM connectome CSVs.
#
# Usage:
#   bash dwi_pipeline/scripts/submit_cidur_g1_rigid_reg_rerun.sh

set -euo pipefail

DWI_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
REPO_ROOT="$(dirname "${DWI_ROOT}")"

export BIDS_DIR="${BIDS_DIR:-/mnt/nfs/home/urmc-sh.rochester.edu/pndagiji/Documents/CIDUR_BIDS/data_bids}"
export RESULTS_ROOT="${RESULTS_ROOT:-/mnt/nfs/Gugger_Lab/NIR/dwi_CIDUR/results}"
export DWI_SELECT_JSON="${DWI_SELECT_JSON:-${DWI_ROOT}/config/dwi_select_64dirax_with_fmap.json}"
export SUBJECT_LIST_FILE="${SUBJECT_LIST_FILE:-${DWI_ROOT}/subject_list_cidur_g1_rigid_reg_rerun.txt}"
export SUBJECT_LIST_USE_EXISTING=1
export ARRAY_SCRIPT="${DWI_ROOT}/scripts/array_cidur_g1_rigid_reg_rerun.sh"
export ARRAY_CONCURRENCY="${ARRAY_CONCURRENCY:-5}"
export PIPELINE_ENGINE=snakemake
export PIPELINE_MODE=connectome
export RUN_RECON=0
export RUN_INPAINT=0
export RECON_TOOL=fastsurfer
export CONNECTOME_SIFT2=1
export TRACTOGRAPHY_MODEL=both
export NTHREADS=8
export OMP_NTHREADS=8
export SBATCH_TIME="${SBATCH_TIME:-04:00:00}"
export SBATCH_PARTITION="${SBATCH_PARTITION:-interactive}"
export SBATCH_CPUS=8
export SBATCH_MEM=48G
export SBATCH_JOB_NAME=cidur_g1_rigid
export EXCLUDE_NODES="${EXCLUDE_NODES-smdodwork05}"

[[ -s "${SUBJECT_LIST_FILE}" ]] || {
  echo "Missing subject list: ${SUBJECT_LIST_FILE}" >&2
  exit 1
}

N="$(wc -l < "${SUBJECT_LIST_FILE}")"
echo "CIDUR G1 rigid-reg connectome rerun: ${N} subjects"
echo "  RESULTS_ROOT=${RESULTS_ROOT}"
echo "  SUBJECT_LIST_FILE=${SUBJECT_LIST_FILE}"

chmod +x "${ARRAY_SCRIPT}"

cd "${DWI_ROOT}"
exec ./submit.sh --fastsurfer --no-inpaint --connectome-sift2 --tractography-model both \
  --dwi-select "${DWI_SELECT_JSON}"
