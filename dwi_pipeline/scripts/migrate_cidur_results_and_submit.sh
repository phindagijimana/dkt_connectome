#!/usr/bin/env bash
# Migrate repo-local CIDUR results to the shared results store, then submit backfill batches.
set -euo pipefail

DWI_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
REPO_ROOT="$(cd "${DWI_ROOT}/.." && pwd)"
SRC="${SRC:-${DWI_ROOT}/results}"
DEST="${RESULTS_ROOT:?Set RESULTS_ROOT to the shared CIDUR results directory (rsync destination)}"
LOG="${REPO_ROOT}/logs/cidur_results_rsync_$(date +%Y%m%d_%H%M%S).log"

mkdir -p "${DEST}" "$(dirname "${LOG}")"

echo "=== CIDUR results migration ===" | tee -a "${LOG}"
echo "SRC:  ${SRC}" | tee -a "${LOG}"
echo "DEST: ${DEST}" | tee -a "${LOG}"
echo "Started: $(date -Is)" | tee -a "${LOG}"

rsync -a --info=stats2 "${SRC}/" "${DEST}/" 2>&1 | tee -a "${LOG}"

echo "Rsync finished: $(date -Is)" | tee -a "${LOG}"
du -sh "${SRC}" "${DEST}" 2>&1 | tee -a "${LOG}"

echo "Home results left in place at ${SRC} (RESULTS_ROOT for jobs: ${DEST})" | tee -a "${LOG}"

echo "=== Submitting CIDUR backfill batches ===" | tee -a "${LOG}"
chmod +x "${DWI_ROOT}/scripts/submit_cidur_backfill_batches.sh"
bash "${DWI_ROOT}/scripts/submit_cidur_backfill_batches.sh" 2>&1 | tee -a "${LOG}"

echo "Done: $(date -Is)" | tee -a "${LOG}"
