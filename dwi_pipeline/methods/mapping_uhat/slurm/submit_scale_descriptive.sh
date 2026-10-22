#!/bin/bash
# Dir 8 — scale descriptive cohort submit (Boekel then Kirby remaining).
# Policy: descriptive replication only; no invent/G retune; not hat{U}.
# Usage: submit_scale_descriptive.sh [boekel|kirby|all]
set -euo pipefail
UHAT=/mnt/nfs/home/urmc-sh.rochester.edu/pndagiji/Documents/TrackTBI-Sub/dwi_pipeline/methods/mapping_uhat
SLURM="${UHAT}/slurm"
R="${UHAT}/work/R"
LOGDIR="${UHAT}/work/sites_v1/logs"
LIST_B="${UHAT}/work/sites_v1/subjects_scale_boekel.txt"
LIST_K="${UHAT}/work/sites_v1/subjects_scale_kirby.txt"
LOG="${LOGDIR}/scale_descriptive_submit.txt"
PART="${SCALE_PARTITION:-general}"
WAVE="${1:-boekel}"
mkdir -p "${LOGDIR}"

DONE_KIRBY=(KKI849 KKI113 KKI127 KKI142 KKI239)
DONE_BOEKEL=(pp01)

is_done_kirby() {
  local s=$1 d
  for d in "${DONE_KIRBY[@]}"; do [[ "$s" == "$d" ]] && return 0; done
  [[ -f "${R}/kirby21_${s}_ses-1/C0.npy" ]] && return 0
  return 1
}
is_done_boekel() {
  local s=$1 d
  for d in "${DONE_BOEKEL[@]}"; do [[ "$s" == "$d" ]] && return 0; done
  [[ -f "${R}/boekel_dwi_retest_${s}_ses-1/C0.npy" ]] && return 0
  return 1
}

# rebuild lists from BIDS
: > "${LIST_B}"
for d in /mnt/nfs/home/urmc-sh.rochester.edu/pndagiji/Documents/TrackTBI-Sub/dwi_pipeline/sample_data/boekel_dwi_retest/bids/sub-pp*; do
  [[ -d "$d" ]] || continue
  sid=${d##*-}
  is_done_boekel "$sid" && continue
  echo "boekel ${sid}" >> "${LIST_B}"
done
: > "${LIST_K}"
for d in /mnt/nfs/home/urmc-sh.rochester.edu/pndagiji/Documents/TrackTBI-Sub/dwi_pipeline/sample_data/kirby21/bids/sub-KKI*; do
  [[ -d "$d" ]] || continue
  sid=${d##*-}
  is_done_kirby "$sid" && continue
  echo "kirby ${sid}" >> "${LIST_K}"
done

submit_one() {
  local kind=$1 sid=$2
  local ds qsi fs ifod pack
  if [[ "${kind}" == "kirby" ]]; then
    ds=kirby21
  else
    ds=boekel_dwi_retest
  fi
  qsi=$(sbatch --parsable --partition="${PART}" --time=24:00:00 \
    --job-name="uhat_scale_qsi_${sid}" \
    --export=ALL,RETEST_KIND="${kind}",RETEST_SID="${sid}" \
    "${SLURM}/retest_qsiprep_sid.sbatch")
  fs=$(sbatch --parsable --partition="${PART}" --time=12:00:00 \
    --dependency=afterok:${qsi} \
    --job-name="uhat_scale_fs_${sid}" \
    --export=ALL,RETEST_DATASET="${ds}",RETEST_SID="${sid}" \
    "${SLURM}/kirby_fastsurfer.sbatch")
  ifod=$(sbatch --parsable --partition="${PART}" --time=24:00:00 \
    --dependency=afterok:${fs} \
    --job-name="uhat_scale_ifod_${sid}" \
    --export=ALL,RETEST_DATASET="${ds}",RETEST_SID="${sid}" \
    "${SLURM}/retest_ifod2.sbatch")
  pack=$(sbatch --parsable --partition="${PART}" --time=12:00:00 --mem=48G --cpus-per-task=4 \
    --dependency=afterok:${ifod} \
    --job-name="uhat_scale_pack_${sid}" \
    --export=ALL,RETEST_DATASET="${ds}",RETEST_SID="${sid}" \
    "${SLURM}/retest_pack.sbatch")
  echo "  ${kind}/${sid}: qsi=${qsi} fs=${fs} ifod=${ifod} pack=${pack}" | tee -a "${LOG}"
}

echo "=== scale descriptive submit $(date -Is) wave=${WAVE} part=${PART} ===" | tee "${LOG}"
echo "policy: Dir 8 descriptive only; no invent retune; not hat{U}" | tee -a "${LOG}"
echo "boekel remaining: $(wc -l < "${LIST_B}")  kirby remaining: $(wc -l < "${LIST_K}")" | tee -a "${LOG}"

if [[ "${WAVE}" == "boekel" || "${WAVE}" == "all" ]]; then
  while read -r kind sid; do
    [[ -z "${sid:-}" ]] && continue
    submit_one "${kind}" "${sid}"
  done < "${LIST_B}"
fi
if [[ "${WAVE}" == "kirby" || "${WAVE}" == "all" ]]; then
  while read -r kind sid; do
    [[ -z "${sid:-}" ]] && continue
    submit_one "${kind}" "${sid}"
  done < "${LIST_K}"
fi
echo "Done submit $(date -Is)" | tee -a "${LOG}"
echo "HCP stratum not auto-submitted (separate adapt path). Disk: prune .work after tck+counts." | tee -a "${LOG}"
