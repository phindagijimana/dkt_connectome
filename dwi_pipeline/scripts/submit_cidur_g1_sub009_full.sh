#!/bin/bash
# Submit full pipeline for sub-009 (ses-1 and ses-2) under session_aware/.
#
# Usage:
#   bash dwi_pipeline/scripts/submit_cidur_g1_sub009_full.sh

set -euo pipefail

DWI_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
REPO_ROOT="$(dirname "${DWI_ROOT}")"
ARRAY="${DWI_ROOT}/scripts/array_cidur_g1_sub009_full.sh"

export BIDS_DIR="${BIDS_DIR:-/mnt/nfs/home/urmc-sh.rochester.edu/pndagiji/Documents/CIDUR_BIDS/data_bids}"
export RESULTS_ROOT="${RESULTS_ROOT:-/mnt/nfs/Gugger_Lab/NIR/dwi_CIDUR/results}"
export SESSION_AWARE_ROOT="${SESSION_AWARE_ROOT:-${RESULTS_ROOT}/session_aware}"
export DWI_SELECT_JSON="${DWI_SELECT_JSON:-${DWI_ROOT}/config/dwi_select_64dirax_with_fmap.json}"
export DWI_ROOT REPO_ROOT
export NTHREADS=8
export OMP_NTHREADS=8
export SBATCH_TIME="${SBATCH_TIME:-12:00:00}"
export SBATCH_PARTITION="${SBATCH_PARTITION:-interactive}"
export SBATCH_CPUS=8
export SBATCH_MEM=48G
export EXCLUDE_NODES="${EXCLUDE_NODES-smdodwork05}"

chmod +x "${ARRAY}"
mkdir -p "${REPO_ROOT}/logs"

cd "${DWI_ROOT}"
sbatch --export=ALL "${ARRAY}"
