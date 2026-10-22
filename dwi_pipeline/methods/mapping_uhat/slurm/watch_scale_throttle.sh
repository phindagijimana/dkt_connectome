#!/bin/bash
# Scale descriptive with concurrency cap: keep up to MAX_IN_FLIGHT full
# subject chains (QSI→FS→iFOD→pack). Default partition=interactive (override SCALE_PARTITION=general;
# interactive is MaxCPUsPerNode=16 and often Priority-starved by GPU jobs).
# Override: SCALE_PARTITION=interactive watch_scale_throttle.sh ...
# Usage: watch_scale_throttle.sh [boekel|kirby] [max_in_flight]
set -euo pipefail
UHAT=/mnt/nfs/home/urmc-sh.rochester.edu/pndagiji/Documents/TrackTBI-Sub/dwi_pipeline/methods/mapping_uhat
SLURM="${UHAT}/slurm"
R="${UHAT}/work/R"
LOGDIR="${UHAT}/work/sites_v1/logs"
WAVE="${1:-boekel}"
MAX_IN_FLIGHT="${2:-5}"
PART="${SCALE_PARTITION:-interactive}"
POLL_SEC="${POLL_SEC:-300}"
LIST_B="${UHAT}/work/sites_v1/subjects_scale_boekel.txt"
LIST_K="${UHAT}/work/sites_v1/subjects_scale_kirby.txt"
LOG="${LOGDIR}/watch_scale_throttle_${WAVE}.log"
STATE="${LOGDIR}/watch_scale_throttle_${WAVE}.state"
mkdir -p "${LOGDIR}"
touch "${STATE}"
log() { echo "[$(date -Is)] $*" | tee -a "${LOG}"; }

# rebuild lists (same rules as submit_scale_descriptive)
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

LIST="${LIST_B}"
[[ "${WAVE}" == "kirby" ]] && LIST="${LIST_K}"

have_pack() {
  local kind=$1 sid=$2
  if [[ "${kind}" == "kirby" ]]; then
    [[ -f "${R}/kirby21_${sid}_ses-1/C0.npy" ]]
  else
    [[ -f "${R}/boekel_dwi_retest_${sid}_ses-1/C0.npy" ]]
  fi
}

# live chain for sid (ignore DependencyNeverSatisfied zombies)
live_sid() {
  local sid=$1
  squeue -u "$USER" -h -o '%j %T %R' 2>/dev/null \
    | grep -E "uhat_scale_(qsi|fs|ifod|pack)_${sid}" \
    | grep -vE 'DependencyNeverSatisfied' \
    | grep -E 'RUNNING|PENDING' >/dev/null
}

n_in_flight() {
  local n=0 line kind sid
  while read -r kind sid; do
    [[ -z "${sid:-}" ]] && continue
    have_pack "${kind}" "${sid}" && continue
    if live_sid "${sid}"; then
      n=$((n + 1))
    fi
  done < "${LIST}"
  echo "${n}"
}

submit_one() {
  local kind=$1 sid=$2
  local ds qsi fs ifod pack
  if [[ "${kind}" == "kirby" ]]; then ds=kirby21; else ds=boekel_dwi_retest; fi
  if live_sid "${sid}"; then
    log "${kind}/${sid}: already live — skip"
    return 0
  fi
  if have_pack "${kind}" "${sid}"; then
    log "${kind}/${sid}: pack done — skip"
    return 0
  fi
  # interactive MaxTime=12:00:00 — do not exceed or jobs sit in PartitionTimeLimit.
  qsi=$(sbatch --parsable --partition="${PART}" --time=12:00:00 \
    --job-name="uhat_scale_qsi_${sid}" \
    --export=ALL,RETEST_KIND="${kind}",RETEST_SID="${sid}" \
    "${SLURM}/retest_qsiprep_sid.sbatch")
  fs=$(sbatch --parsable --partition="${PART}" --time=12:00:00 \
    --dependency=afterok:${qsi} \
    --job-name="uhat_scale_fs_${sid}" \
    --export=ALL,RETEST_DATASET="${ds}",RETEST_SID="${sid}" \
    "${SLURM}/kirby_fastsurfer.sbatch")
  ifod=$(sbatch --parsable --partition="${PART}" --time=12:00:00 \
    --dependency=afterok:${fs} \
    --job-name="uhat_scale_ifod_${sid}" \
    --export=ALL,RETEST_DATASET="${ds}",RETEST_SID="${sid}" \
    "${SLURM}/retest_ifod2.sbatch")
  pack=$(sbatch --parsable --partition="${PART}" --time=12:00:00 --mem=48G --cpus-per-task=4 \
    --dependency=afterok:${ifod} \
    --job-name="uhat_scale_pack_${sid}" \
    --export=ALL,RETEST_DATASET="${ds}",RETEST_SID="${sid}" \
    "${SLURM}/retest_pack.sbatch")
  log "${kind}/${sid}: qsi=${qsi} fs=${fs} ifod=${ifod} pack=${pack}"
  echo "${sid} qsi=${qsi} fs=${fs} ifod=${ifod} pack=${pack}" >> "${STATE}"
}

log "start wave=${WAVE} max_in_flight=${MAX_IN_FLIGHT} partition=${PART}"
log "queue size: $(wc -l < "${LIST}") subjects"

while true; do
  # cancel zombies with DependencyNeverSatisfied on this wave
  zids=$(squeue -u "$USER" -h -o '%i %j %R' 2>/dev/null \
    | awk '/uhat_scale_/ && /DependencyNeverSatisfied/ {print $1}')
  if [[ -n "${zids}" ]]; then
    log "scancel zombies: ${zids}"
    # shellcheck disable=SC2086
    scancel ${zids} 2>/dev/null || true
  fi

  inflight=$(n_in_flight)
  log "in_flight=${inflight}/${MAX_IN_FLIGHT}"

  if [[ "${inflight}" -lt "${MAX_IN_FLIGHT}" ]]; then
    while read -r kind sid; do
      [[ -z "${sid:-}" ]] && continue
      have_pack "${kind}" "${sid}" && continue
      live_sid "${sid}" && continue
      submit_one "${kind}" "${sid}"
      inflight=$(n_in_flight)
      [[ "${inflight}" -ge "${MAX_IN_FLIGHT}" ]] && break
    done < "${LIST}"
  fi

  # done?
  left=0
  while read -r kind sid; do
    [[ -z "${sid:-}" ]] && continue
    have_pack "${kind}" "${sid}" || left=$((left + 1))
  done < "${LIST}"
  if [[ "${left}" -eq 0 ]]; then
    log "all packs present for wave=${WAVE} — exit"
    exit 0
  fi
  sleep "${POLL_SEC}"
done
