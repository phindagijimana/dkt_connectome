#!/usr/bin/env bash
# Finish sub-002 (GE, ses-3 DWI only): iFOD2 connectome + nodestrength + QC.
#
# BIDS note: ses-1 = PET+T1w, ses-2 = fMRI only — no DWI. Only ses-3 is processed.
#
# Usage:
#   bash dwi_pipeline/scripts/submit_sub002_connectome_finish.sh

set -euo pipefail

DWI_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
REPO_ROOT="$(dirname "${DWI_ROOT}")"
GUGGER="${CIDUR_RESULTS_ROOT:-/mnt/nfs/Gugger_Lab/NIR/dwi_CIDUR/results}"
ARRAY="${DWI_ROOT}/scripts/array_cidur_g1_connectome_finish.sh"

export BIDS_DIR="${CIDUR_BIDS_DIR:-/mnt/nfs/home/urmc-sh.rochester.edu/pndagiji/Documents/CIDUR_BIDS/data_bids}"
export RESULTS_ROOT="${GUGGER}"
export SUBJECT_LIST_FILE="${DWI_ROOT}/subject_list_sub002_finish.txt"
export DWI_ROOT REPO_ROOT
export RECON_SESSION="3"
export DWI_SELECT_JSON="${DWI_ROOT}/config/dwi_select_50dirax_no_fmap.json"
export QSIPREP_NO_SDC=1
export PIPELINE_ENGINE=snakemake
export RUN_RECON=0
export RUN_INPAINT=0
export RECON_TOOL=fastsurfer
export CONNECTOME_SIFT2=1
export TRACTOGRAPHY_MODEL=both
export NTHREADS=8
export OMP_NTHREADS=8
export SBATCH_TIME="${SBATCH_TIME:-12:00:00}"
export SBATCH_PARTITION="${SBATCH_PARTITION:-interactive}"
export SBATCH_CPUS=8
export SBATCH_MEM="${SBATCH_MEM:-128G}"
export SBATCH_JOB_NAME="cidur_sub002_finish"
export EXCLUDE_NODES="${EXCLUDE_NODES-smdodwork05}"

chmod +x "${ARRAY}"
cd "${DWI_ROOT}"
SBATCH_EXTRA=(--export=ALL --array=1)
[[ -n "${EXCLUDE_NODES}" ]] && SBATCH_EXTRA+=(--exclude="${EXCLUDE_NODES}")
[[ -n "${SBATCH_PARTITION}" ]] && SBATCH_EXTRA+=(--partition="${SBATCH_PARTITION}")
[[ -n "${SBATCH_TIME}" ]] && SBATCH_EXTRA+=(--time="${SBATCH_TIME}")
[[ -n "${SBATCH_CPUS}" ]] && SBATCH_EXTRA+=(--cpus-per-task="${SBATCH_CPUS}")
[[ -n "${SBATCH_MEM}" ]] && SBATCH_EXTRA+=(--mem="${SBATCH_MEM}")
SBATCH_EXTRA+=(--job-name="${SBATCH_JOB_NAME}"
               --output="${REPO_ROOT}/logs/${SBATCH_JOB_NAME}_%A_%a.out"
               --error="${REPO_ROOT}/logs/${SBATCH_JOB_NAME}_%A_%a.err")
sbatch "${SBATCH_EXTRA[@]}" "${ARRAY}"
