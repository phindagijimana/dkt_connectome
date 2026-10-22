#!/bin/bash
# Overnight rescue for Kirby within-site mini: resubmit failed/missing stages;
# run LOSO P_L when packs land. Idempotent. Interactive partition.
set -euo pipefail
UHAT=/mnt/nfs/home/urmc-sh.rochester.edu/pndagiji/Documents/TrackTBI-Sub/dwi_pipeline/methods/mapping_uhat
SLURM="${UHAT}/slurm"
SD=/mnt/nfs/home/urmc-sh.rochester.edu/pndagiji/Documents/TrackTBI-Sub/dwi_pipeline/sample_data/kirby21
R="${UHAT}/work/R"
LOGDIR="${UHAT}/work/sites_v1/logs"
STATE="${LOGDIR}/within_site_overnight.state"
LOG="${LOGDIR}/within_site_overnight.log"
SIDS=(KKI113 KKI127 KKI142 KKI239)
POLL_SEC="${POLL_SEC:-1800}"          # 30 min
STOP_AFTER_EPOCH="${STOP_AFTER_EPOCH:-}"  # optional unix time hard stop
mkdir -p "${LOGDIR}" "${R}/logs"
touch "${STATE}"

log() { echo "[$(date -Is)] $*" | tee -a "${LOG}"; }

have_pack() { [[ -f "${R}/kirby21_${1}_ses-1/C0.npy" ]]; }
have_dwiref() {
  local s=$1
  [[ -f "${SD}/results/sub-${s}/sub-${s}/ses-1/dwi/sub-${s}_ses-1_space-T1w_dwiref.nii.gz" \
     && -f "${SD}/results/sub-${s}/sub-${s}/ses-2/dwi/sub-${s}_ses-2_space-T1w_dwiref.nii.gz" ]]
}
have_fs() { [[ -f "${SD}/freeze/sub-${1}/freesurfer/sub-${1}/mri/aparc+aseg.mgz" ]]; }
have_conn() {
  local s=$1
  [[ -f "${SD}/freeze/sub-${s}/connectomes/sub-${s}/ses-1/connectome_count.csv" \
     && -f "${SD}/freeze/sub-${s}/connectomes/sub-${s}/ses-2/connectome_count.csv" ]]
}

# True if a real runnable job exists (ignore DependencyNeverSatisfied zombies)
live_for() {
  local s=$1
  squeue -u "$USER" -h -o '%j %T %R' 2>/dev/null \
    | grep -E "uhat_mini_.*${s}" \
    | grep -vE 'DependencyNeverSatisfied' \
    | grep -E ' (R|PD) ' >/dev/null
}

submit_fs() {
  local s=$1
  sbatch --parsable --partition=interactive --time=12:00:00 \
    --job-name="uhat_mini_fs_${s}" \
    --export=ALL,RETEST_DATASET=kirby21,RETEST_SID="${s}" \
    "${SLURM}/kirby_fastsurfer.sbatch"
}
submit_ifod() {
  local s=$1 dep=$2
  local args=(--parsable --partition=interactive --time=12:00:00
    --job-name="uhat_mini_ifod_${s}"
    --export=ALL,RETEST_DATASET=kirby21,RETEST_SID="${s}")
  [[ -n "${dep}" ]] && args+=(--dependency="afterok:${dep}")
  sbatch "${args[@]}" "${SLURM}/retest_ifod2.sbatch"
}
submit_pack() {
  local s=$1 dep=$2
  local args=(--parsable --partition=interactive --time=12:00:00 --mem=48G --cpus-per-task=4
    --job-name="uhat_mini_pack_${s}"
    --export=ALL,RETEST_DATASET=kirby21,RETEST_SID="${s}")
  [[ -n "${dep}" ]] && args+=(--dependency="afterok:${dep}")
  sbatch "${args[@]}" "${SLURM}/retest_pack.sbatch"
}

rescue_sid() {
  local s=$1
  if have_pack "${s}"; then
    log "${s}: pack OK"
    return 0
  fi
  if live_for "${s}"; then
    log "${s}: live job present — leave alone"
    return 0
  fi
  # No live jobs and no pack → rebuild from furthest done stage
  if have_conn "${s}"; then
    local p; p=$(submit_pack "${s}" "")
    log "${s}: RESUBMIT pack ${p} (connectomes present)"
    echo "${s} pack ${p}" >> "${STATE}"
    return 0
  fi
  if have_fs "${s}" && have_dwiref "${s}"; then
    local i p
    i=$(submit_ifod "${s}" "")
    p=$(submit_pack "${s}" "${i}")
    log "${s}: RESUBMIT iFOD ${i} + pack ${p} (FS+dwiref present)"
    echo "${s} ifod ${i} pack ${p}" >> "${STATE}"
    return 0
  fi
  if have_dwiref "${s}"; then
    local f i p
    f=$(submit_fs "${s}")
    i=$(submit_ifod "${s}" "${f}")
    p=$(submit_pack "${s}" "${i}")
    log "${s}: RESUBMIT FS ${f} + iFOD ${i} + pack ${p}"
    echo "${s} fs ${f} ifod ${i} pack ${p}" >> "${STATE}"
    return 0
  fi
  log "${s}: missing dwiref and no live QSI — manual QSI check needed"
  return 1
}

run_pl_if_ready() {
  local missing=0 s
  for s in KKI849 "${SIDS[@]}"; do
    have_pack "${s}" || missing=1
  done
  if [[ "${missing}" -eq 1 ]]; then
    return 1
  fi
  local out="${R}/paper2/within_site_kirby/P_L_loso_within_kirby.json"
  if [[ -f "${out}" ]]; then
    log "P_L already written: ${out}"
    return 0
  fi
  log "All packs present — running within-site P_L"
  PYTHONPATH=/mnt/nfs/home/urmc-sh.rochester.edu/pndagiji/Documents/edgeuq/src \
    python3 "${UHAT}/run_within_site_PL.py" >> "${LOG}" 2>&1 || log "P_L script exit $?"
  return 0
}

MODE="${1:-loop}"  # loop | once
log "=== overnight watch start mode=${MODE} poll=${POLL_SEC}s ==="

while true; do
  if [[ -n "${STOP_AFTER_EPOCH}" ]] && [[ "$(date +%s)" -ge "${STOP_AFTER_EPOCH}" ]]; then
    log "Hard stop epoch reached — exiting"
    break
  fi
  for s in "${SIDS[@]}"; do
    rescue_sid "${s}" || true
  done
  if run_pl_if_ready; then
    log "Within-site pipeline complete — exiting"
    break
  fi
  [[ "${MODE}" == "once" ]] && { log "once-pass done"; break; }
  sleep "${POLL_SEC}"
done
log "=== overnight watch end ==="
