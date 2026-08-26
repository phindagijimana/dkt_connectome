#!/usr/bin/env bash
# Migrate home CIDUR results to Gugger Lab, then submit backfill batches.
set -euo pipefail

SRC="/mnt/nfs/home/URMC-SH/pndagiji/Documents/TrackTBI-Sub/dwi_pipeline/results"
DEST="/mnt/nfs/Gugger_Lab/NIR/dwi_CIDUR/results"
LOG="/mnt/nfs/home/URMC-SH/pndagiji/Documents/TrackTBI-Sub/logs/cidur_results_rsync_$(date +%Y%m%d_%H%M%S).log"
DWI_ROOT="/mnt/nfs/home/URMC-SH/pndagiji/Documents/TrackTBI-Sub/dwi_pipeline"

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
