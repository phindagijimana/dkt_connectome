#!/bin/bash
# Arm overnight scale rescue: throttle watcher (resume-after-TIMEOUT) + at(1) one-shots.
# Prefer evening→morning window when interactive Priority contention is lower.
#
# Usage:
#   schedule_scale_overnight.sh [boekel|kirby] [max_in_flight]
# Env:
#   ACTIVE_HOURS=18-8     only submit inside window (default overnight-biased)
#   SCALE_PARTITION=interactive
#   STOP_AFTER            wall time for date -d (default: tomorrow 12:00)
set -euo pipefail
UHAT=/mnt/nfs/home/urmc-sh.rochester.edu/pndagiji/Documents/TrackTBI-Sub/dwi_pipeline/methods/mapping_uhat
WATCH="${UHAT}/slurm/watch_scale_throttle.sh"
LOGDIR="${UHAT}/work/sites_v1/logs"
WAVE="${1:-boekel}"
MAX_IN_FLIGHT="${2:-5}"
PART="${SCALE_PARTITION:-interactive}"
ACTIVE_HOURS="${ACTIVE_HOURS:-18-8}"
STOP_AFTER="${STOP_AFTER:-tomorrow 12:00}"
PIDF="${LOGDIR}/watch_scale_throttle_${WAVE}.pid"
mkdir -p "${LOGDIR}"
chmod +x "${WATCH}" "${UHAT}/slurm/schedule_scale_overnight.sh"

STOP=$(date -d "${STOP_AFTER}" +%s)

# stop prior watcher for this wave if still looping
if [[ -f "${PIDF}" ]]; then
  old=$(cat "${PIDF}" || true)
  if [[ -n "${old}" ]] && kill -0 "${old}" 2>/dev/null; then
    echo "stopping prior watcher pid=${old}"
    kill "${old}" 2>/dev/null || true
    sleep 2
    kill -9 "${old}" 2>/dev/null || true
  fi
fi

nohup env \
  SCALE_PARTITION="${PART}" \
  ACTIVE_HOURS="${ACTIVE_HOURS}" \
  POLL_SEC="${POLL_SEC:-300}" \
  STOP_AFTER_EPOCH="${STOP}" \
  bash "${WATCH}" "${WAVE}" "${MAX_IN_FLIGHT}" loop \
  >> "${LOGDIR}/watch_scale_throttle_${WAVE}.nohup.out" 2>&1 &
echo $! > "${PIDF}"
echo "Watcher PID $(cat "${PIDF}") wave=${WAVE} max=${MAX_IN_FLIGHT} part=${PART} active=${ACTIVE_HOURS} stop_after=$(date -d "@${STOP}" -Is)"

# One-shot backups (fill empty slots / resume TIMEOUT chains) if the loop dies
for when in "02:00" "06:00" "09:00"; do
  echo "env SCALE_PARTITION=${PART} ACTIVE_HOURS= POLL_SEC=60 bash ${WATCH} ${WAVE} ${MAX_IN_FLIGHT} once >> ${LOGDIR}/watch_scale_throttle_${WAVE}.log 2>&1" \
    | at "${when}" 2>&1 || true
done
atq 2>/dev/null | tail -15 || true
echo "Log: ${LOGDIR}/watch_scale_throttle_${WAVE}.log"
