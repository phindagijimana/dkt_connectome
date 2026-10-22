#!/bin/bash
# Scale descriptive with concurrency cap: keep up to MAX_IN_FLIGHT full
# subject chains on PARTITION. Resumes from furthest completed stage so a
# 12h interactive TIMEOUT does not redo finished QSI/FS/iFOD overnight.
#
# Usage: watch_scale_throttle.sh [boekel|kirby] [max_in_flight] [loop|once]
# Env:
#   SCALE_PARTITION=interactive|general   (default interactive)
#   POLL_SEC=300
#   ACTIVE_HOURS=18-8   optional; only submit new/rescue work in this window
#                       (24h clock, wrap allowed). Empty = always active.
#   STOP_AFTER_EPOCH=   optional unix time hard stop
set -euo pipefail
UHAT=/mnt/nfs/home/urmc-sh.rochester.edu/pndagiji/Documents/TrackTBI-Sub/dwi_pipeline/methods/mapping_uhat
SD=/mnt/nfs/home/urmc-sh.rochester.edu/pndagiji/Documents/TrackTBI-Sub/dwi_pipeline/sample_data
SLURM="${UHAT}/slurm"
R="${UHAT}/work/R"
LOGDIR="${UHAT}/work/sites_v1/logs"
WAVE="${1:-boekel}"
MAX_IN_FLIGHT="${2:-5}"
MODE="${3:-loop}"                         # loop | once
PART="${SCALE_PARTITION:-interactive}"
POLL_SEC="${POLL_SEC:-300}"
ACTIVE_HOURS="${ACTIVE_HOURS:-}"          # e.g. 18-8 for overnight-biased submit
STOP_AFTER_EPOCH="${STOP_AFTER_EPOCH:-}"
LIST_B="${UHAT}/work/sites_v1/subjects_scale_boekel.txt"
LIST_K="${UHAT}/work/sites_v1/subjects_scale_kirby.txt"
LOG="${LOGDIR}/watch_scale_throttle_${WAVE}.log"
STATE="${LOGDIR}/watch_scale_throttle_${WAVE}.state"
mkdir -p "${LOGDIR}"
touch "${STATE}"
log() { echo "[$(date -Is)] $*" | tee -a "${LOG}"; }

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
for d in "${SD}/boekel_dwi_retest/bids/sub-pp"*; do
  [[ -d "$d" ]] || continue
  sid=${d##*-}
  is_done_boekel "$sid" && continue
  echo "boekel ${sid}" >> "${LIST_B}"
done
: > "${LIST_K}"
for d in "${SD}/kirby21/bids/sub-KKI"*; do
  [[ -d "$d" ]] || continue
  sid=${d##*-}
  is_done_kirby "$sid" && continue
  echo "kirby ${sid}" >> "${LIST_K}"
done

LIST="${LIST_B}"
[[ "${WAVE}" == "kirby" ]] && LIST="${LIST_K}"

ds_for() {
  if [[ "$1" == "kirby" ]]; then echo kirby21; else echo boekel_dwi_retest; fi
}

have_pack() {
  local kind=$1 sid=$2
  if [[ "${kind}" == "kirby" ]]; then
    [[ -f "${R}/kirby21_${sid}_ses-1/C0.npy" ]]
  else
    [[ -f "${R}/boekel_dwi_retest_${sid}_ses-1/C0.npy" ]]
  fi
}

have_dwiref() {
  local kind=$1 sid=$2 ds
  ds=$(ds_for "${kind}")
  local base="${SD}/${ds}/results/sub-${sid}/sub-${sid}"
  [[ -f "${base}/ses-1/dwi/sub-${sid}_ses-1_space-T1w_dwiref.nii.gz" \
     && -f "${base}/ses-2/dwi/sub-${sid}_ses-2_space-T1w_dwiref.nii.gz" ]]
}

have_fs() {
  local kind=$1 sid=$2 ds
  ds=$(ds_for "${kind}")
  [[ -f "${SD}/${ds}/freeze/sub-${sid}/freesurfer/sub-${sid}/mri/aparc+aseg.mgz" ]]
}

have_conn() {
  local kind=$1 sid=$2 ds
  ds=$(ds_for "${kind}")
  local c1="${SD}/${ds}/freeze/sub-${sid}/connectomes/sub-${sid}/ses-1"
  local c2="${SD}/${ds}/freeze/sub-${sid}/connectomes/sub-${sid}/ses-2"
  # either naming from ifod post-copy
  { [[ -f "${c1}/connectome_count.csv" ]] || [[ -f "${c1}/dkt_connectome_count.csv" ]]; } \
    && { [[ -f "${c2}/connectome_count.csv" ]] || [[ -f "${c2}/dkt_connectome_count.csv" ]]; }
}

# live chain for sid (ignore DependencyNeverSatisfied zombies).
# Anchor sid at end of job name so pp02 does not match pp020, etc.
live_sid() {
  local sid=$1
  squeue -u "$USER" -h -o '%j %T %R' 2>/dev/null \
    | grep -E "uhat_scale_(qsi|fs|ifod|pack)_${sid}[[:space:]]" \
    | grep -vE 'DependencyNeverSatisfied' \
    | grep -E '[[:space:]](RUNNING|PENDING)[[:space:]]' >/dev/null
}

n_in_flight() {
  local n=0 kind sid
  while read -r kind sid; do
    [[ -z "${sid:-}" ]] && continue
    have_pack "${kind}" "${sid}" && continue
    if live_sid "${sid}"; then
      n=$((n + 1))
    fi
  done < "${LIST}"
  echo "${n}"
}

# True if wall-clock hour is inside ACTIVE_HOURS (e.g. 18-8 wraps midnight).
in_active_window() {
  [[ -z "${ACTIVE_HOURS}" ]] && return 0
  local start end h
  start="${ACTIVE_HOURS%%-*}"
  end="${ACTIVE_HOURS##*-}"
  h=$(date +%H)
  h=$((10#$h)); start=$((10#$start)); end=$((10#$end))
  if [[ "${start}" -le "${end}" ]]; then
    [[ "${h}" -ge "${start}" && "${h}" -lt "${end}" ]]
  else
    # wraps midnight: active if h >= start OR h < end
    [[ "${h}" -ge "${start}" || "${h}" -lt "${end}" ]]
  fi
}

sb_qsi() {
  local kind=$1 sid=$2 out
  out=$(sbatch --parsable --partition="${PART}" --time=12:00:00 \
    --job-name="uhat_scale_qsi_${sid}" \
    --export=ALL,RETEST_KIND="${kind}",RETEST_SID="${sid}" \
    "${SLURM}/retest_qsiprep_sid.sbatch") || { log "sbatch qsi failed kind=${kind} sid=${sid}"; return 1; }
  echo "${out}"
}
sb_fs() {
  local kind=$1 sid=$2 dep=${3:-} ds out
  ds=$(ds_for "${kind}")
  local args=(--parsable --partition="${PART}" --time=12:00:00
    --job-name="uhat_scale_fs_${sid}"
    --export=ALL,RETEST_DATASET="${ds}",RETEST_SID="${sid}")
  [[ -n "${dep}" ]] && args+=(--dependency="afterok:${dep}")
  out=$(sbatch "${args[@]}" "${SLURM}/kirby_fastsurfer.sbatch") || { log "sbatch fs failed sid=${sid}"; return 1; }
  echo "${out}"
}
sb_ifod() {
  local kind=$1 sid=$2 dep=${3:-} ds out
  ds=$(ds_for "${kind}")
  local args=(--parsable --partition="${PART}" --time=12:00:00
    --job-name="uhat_scale_ifod_${sid}"
    --export=ALL,RETEST_DATASET="${ds}",RETEST_SID="${sid}")
  [[ -n "${dep}" ]] && args+=(--dependency="afterok:${dep}")
  out=$(sbatch "${args[@]}" "${SLURM}/retest_ifod2.sbatch") || { log "sbatch ifod failed sid=${sid}"; return 1; }
  echo "${out}"
}
sb_pack() {
  local kind=$1 sid=$2 dep=${3:-} ds out
  ds=$(ds_for "${kind}")
  local args=(--parsable --partition="${PART}" --time=12:00:00 --mem=48G --cpus-per-task=4
    --job-name="uhat_scale_pack_${sid}"
    --export=ALL,RETEST_DATASET="${ds}",RETEST_SID="${sid}")
  [[ -n "${dep}" ]] && args+=(--dependency="afterok:${dep}")
  out=$(sbatch "${args[@]}" "${SLURM}/retest_pack.sbatch") || { log "sbatch pack failed sid=${sid}"; return 1; }
  echo "${out}"
}

# Resume from furthest done stage (TIMEOUT/fail safe). QSI/FS scripts skip-if-done.
submit_one() {
  local kind=$1 sid=$2
  local qsi="" fs="" ifod="" pack=""
  if live_sid "${sid}"; then
    log "${kind}/${sid}: already live — skip"
    return 0
  fi
  if have_pack "${kind}" "${sid}"; then
    log "${kind}/${sid}: pack done — skip"
    return 0
  fi

  if have_conn "${kind}" "${sid}"; then
    pack=$(sb_pack "${kind}" "${sid}" "") || return 1
    log "${kind}/${sid}: RESUME pack=${pack} (connectomes present)"
    echo "${sid} resume=pack pack=${pack}" >> "${STATE}"
    return 0
  fi
  if have_fs "${kind}" "${sid}" && have_dwiref "${kind}" "${sid}"; then
    ifod=$(sb_ifod "${kind}" "${sid}" "") || return 1
    pack=$(sb_pack "${kind}" "${sid}" "${ifod}") || return 1
    log "${kind}/${sid}: RESUME ifod=${ifod} pack=${pack} (FS+dwiref)"
    echo "${sid} resume=ifod ifod=${ifod} pack=${pack}" >> "${STATE}"
    return 0
  fi
  if have_dwiref "${kind}" "${sid}"; then
    fs=$(sb_fs "${kind}" "${sid}" "") || return 1
    ifod=$(sb_ifod "${kind}" "${sid}" "${fs}") || return 1
    pack=$(sb_pack "${kind}" "${sid}" "${ifod}") || return 1
    log "${kind}/${sid}: RESUME fs=${fs} ifod=${ifod} pack=${pack} (dwiref)"
    echo "${sid} resume=fs fs=${fs} ifod=${ifod} pack=${pack}" >> "${STATE}"
    return 0
  fi

  # Fresh or TIMEOUT mid-QSI: keep .work so qsiprep can continue; scripts skip if done.
  qsi=$(sb_qsi "${kind}" "${sid}") || return 1
  fs=$(sb_fs "${kind}" "${sid}" "${qsi}") || return 1
  ifod=$(sb_ifod "${kind}" "${sid}" "${fs}") || return 1
  pack=$(sb_pack "${kind}" "${sid}" "${ifod}") || return 1
  log "${kind}/${sid}: FULL qsi=${qsi} fs=${fs} ifod=${ifod} pack=${pack}"
  echo "${sid} resume=full qsi=${qsi} fs=${fs} ifod=${ifod} pack=${pack}" >> "${STATE}"
}

log "start wave=${WAVE} max_in_flight=${MAX_IN_FLIGHT} partition=${PART} mode=${MODE} active_hours=${ACTIVE_HOURS:-always}"
log "queue size: $(wc -l < "${LIST}") subjects"

while true; do
  if [[ -n "${STOP_AFTER_EPOCH}" ]] && [[ "$(date +%s)" -ge "${STOP_AFTER_EPOCH}" ]]; then
    log "hard stop epoch reached — exit"
    exit 0
  fi

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

  if in_active_window; then
    if [[ "${inflight}" -lt "${MAX_IN_FLIGHT}" ]]; then
      while read -r kind sid; do
        [[ -z "${sid:-}" ]] && continue
        have_pack "${kind}" "${sid}" && continue
        live_sid "${sid}" && continue
        submit_one "${kind}" "${sid}" || log "${kind}/${sid}: submit_one failed — continue"
        inflight=$(n_in_flight)
        [[ "${inflight}" -ge "${MAX_IN_FLIGHT}" ]] && break
      done < "${LIST}"
    fi
  else
    log "outside ACTIVE_HOURS=${ACTIVE_HOURS} — monitor only (no new submit)"
  fi

  left=0
  while read -r kind sid; do
    [[ -z "${sid:-}" ]] && continue
    have_pack "${kind}" "${sid}" || left=$((left + 1))
  done < "${LIST}"
  if [[ "${left}" -eq 0 ]]; then
    log "all packs present for wave=${WAVE} — exit"
    exit 0
  fi
  [[ "${MODE}" == "once" ]] && { log "once-pass done (left=${left})"; exit 0; }
  sleep "${POLL_SEC}"
done
