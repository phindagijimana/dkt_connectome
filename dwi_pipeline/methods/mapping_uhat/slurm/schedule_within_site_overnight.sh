#!/bin/bash
# Arm overnight rescue: long-running watcher now + morning one-shot backups via at(1).
set -euo pipefail
UHAT=/mnt/nfs/home/urmc-sh.rochester.edu/pndagiji/Documents/TrackTBI-Sub/dwi_pipeline/methods/mapping_uhat
WATCH="${UHAT}/slurm/watch_within_site_overnight.sh"
LOGDIR="${UHAT}/work/sites_v1/logs"
mkdir -p "${LOGDIR}"
chmod +x "${WATCH}"

# Stop looping mid-afternoon Wed if still stuck (unix); ~15:00 local
STOP=$(date -d 'today 15:00' +%s 2>/dev/null || date -d '15:00' +%s)

# Detached loop covering the rest of the night / morning
nohup env POLL_SEC=1800 STOP_AFTER_EPOCH="${STOP}" bash "${WATCH}" loop \
  >> "${LOGDIR}/within_site_overnight.nohup.out" 2>&1 &
echo $! > "${LOGDIR}/within_site_overnight.pid"
echo "Watcher PID $(cat "${LOGDIR}/within_site_overnight.pid") stop_after=$(date -d "@${STOP}" -Is)"

# Backup one-shots if the long watcher dies
for when in "06:00" "09:00" "12:00"; do
  echo "env POLL_SEC=60 bash ${WATCH} once >> ${LOGDIR}/within_site_overnight.log 2>&1" | at "${when}" 2>&1 || true
done
atq | tail -10
echo "Log: ${LOGDIR}/within_site_overnight.log"
