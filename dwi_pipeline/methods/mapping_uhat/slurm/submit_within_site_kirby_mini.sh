#!/bin/bash
# Within-site Kirby mini-scale: 4 new subjects (+ KKI849 = 5). All on interactive.
# Per subject: QSIPrep array task → FastSurfer → iFOD2 (ses1+2) → pack.
set -euo pipefail
UHAT=/mnt/nfs/home/urmc-sh.rochester.edu/pndagiji/Documents/TrackTBI-Sub/dwi_pipeline/methods/mapping_uhat
SLURM="${UHAT}/slurm"
LIST="${UHAT}/work/sites_v1/subjects_within_site_kirby.txt"
LOG="${UHAT}/work/sites_v1/logs/within_site_kirby_mini_submit.txt"
mkdir -p "${UHAT}/work/sites_v1/logs" "${UHAT}/work/R/logs"

echo "=== within-site Kirby mini submit $(date -Is) ===" | tee "${LOG}"

QSI=$(sbatch --parsable "${SLURM}/retest_qsiprep_mini.sbatch")
echo "QSIPrep array ${QSI} (1-4%2 interactive)" | tee -a "${LOG}"

i=0
while IFS= read -r LINE; do
  [[ -z "${LINE// }" ]] && continue
  i=$((i + 1))
  SID="${LINE##* }"

  FS=$(sbatch --parsable \
    --dependency=afterok:${QSI}_${i} \
    --partition=interactive --time=12:00:00 \
    --job-name="uhat_mini_fs_${SID}" \
    --export=ALL,RETEST_DATASET=kirby21,RETEST_SID="${SID}" \
    "${SLURM}/kirby_fastsurfer.sbatch")
  echo "  ${SID}: FS ${FS} <- afterok ${QSI}_${i}" | tee -a "${LOG}"

  IFOD=$(sbatch --parsable \
    --dependency=afterok:${FS} \
    --partition=interactive --time=12:00:00 \
    --job-name="uhat_mini_ifod_${SID}" \
    --export=ALL,RETEST_DATASET=kirby21,RETEST_SID="${SID}" \
    "${SLURM}/retest_ifod2.sbatch")
  echo "  ${SID}: iFOD ${IFOD} <- afterok ${FS}" | tee -a "${LOG}"

  PACK=$(sbatch --parsable \
    --dependency=afterok:${IFOD} \
    --partition=interactive --time=12:00:00 \
    --mem=48G --cpus-per-task=4 \
    --job-name="uhat_mini_pack_${SID}" \
    --export=ALL,RETEST_DATASET=kirby21,RETEST_SID="${SID}" \
    "${SLURM}/retest_pack.sbatch")
  echo "  ${SID}: pack ${PACK} <- afterok ${IFOD}" | tee -a "${LOG}"
done < "${LIST}"

echo "Pilot KKI849 already packed. When 4 packs done, run:" | tee -a "${LOG}"
echo "  PYTHONPATH=.../edgeuq/src python3 ${UHAT}/run_within_site_PL.py" | tee -a "${LOG}"
echo "Done submit $(date -Is)" | tee -a "${LOG}"
