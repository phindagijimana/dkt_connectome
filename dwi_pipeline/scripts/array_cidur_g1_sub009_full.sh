#!/bin/bash
# Slurm job: full pipeline for sub-009 (ses-1 and ses-2) under session_aware/.
#
# Launched by scripts/submit_cidur_g1_sub009_full.sh

#SBATCH --job-name=cidur_009_full
#SBATCH --output=logs/cidur_009_full_%j.out
#SBATCH --error=logs/cidur_009_full_%j.err
#SBATCH --time=12:00:00
#SBATCH --partition=interactive
#SBATCH --cpus-per-task=8
#SBATCH --mem=48G
#SBATCH --mail-type=END,FAIL

set -euo pipefail
set +H

: "${DWI_ROOT:?ERROR: DWI_ROOT not set}"
: "${REPO_ROOT:?ERROR: REPO_ROOT not set}"
: "${BIDS_DIR:?ERROR: BIDS_DIR not set}"
: "${RESULTS_ROOT:?ERROR: RESULTS_ROOT not set}"

source "${DWI_ROOT}/workflow/lib/slurm_env.sh"

SESSION_AWARE_ROOT="${SESSION_AWARE_ROOT:-${RESULTS_ROOT}/session_aware}"
BIDS_APP="${DWI_ROOT}/bids_app.sh"
DWI_SELECT="${DWI_SELECT_JSON:-${DWI_ROOT}/config/dwi_select_64dirax_with_fmap.json}"
CONN_ARGS=(--fastsurfer --no-inpaint --connectome-sift2 --tractography-model both --dwi-select "${DWI_SELECT}")

export NTHREADS="${NTHREADS:-8}"
export OMP_NTHREADS="${OMP_NTHREADS:-8}"
export XDG_CACHE_HOME="${XDG_CACHE_HOME:-${REPO_ROOT}/.cache}"
mkdir -p "${REPO_ROOT}/logs" "${XDG_CACHE_HOME}"

[[ -f "${BIDS_APP}" ]] || { echo "Missing ${BIDS_APP}"; exit 1; }
[[ -f "${DWI_SELECT}" ]] || { echo "Missing ${DWI_SELECT}"; exit 1; }

echo "=== CIDUR sub-009 full pipeline (session-aware) ==="
echo "  BIDS_DIR=${BIDS_DIR}"
echo "  SESSION_AWARE_ROOT=${SESSION_AWARE_ROOT}"

for SES in 1 2; do
  echo "--- sub-009 ses-${SES} ---"
  bash "${BIDS_APP}" "${BIDS_DIR}" "${SESSION_AWARE_ROOT}" participant \
    --participant-label 009 --session-label "${SES}" \
    --pipeline-mode all -- \
    "${CONN_ARGS[@]}"
done

echo "=== Done sub-009 (ses-1, ses-2) ==="
