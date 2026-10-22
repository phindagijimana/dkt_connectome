#!/bin/bash
# After KKI239 pack lands: refresh within-site P_L (n=5), then start Dir 8 scale (Boekel wave).
set -euo pipefail
UHAT=/mnt/nfs/home/urmc-sh.rochester.edu/pndagiji/Documents/TrackTBI-Sub/dwi_pipeline/methods/mapping_uhat
R="${UHAT}/work/R"
LOGDIR="${UHAT}/work/sites_v1/logs"
LOG="${LOGDIR}/watch_mini_then_scale.log"
FLAG="${LOGDIR}/scale_descriptive_STARTED"
PACK="${R}/kirby21_KKI239_ses-1/C0.npy"
POLL_SEC="${POLL_SEC:-600}"
mkdir -p "${LOGDIR}"
log() { echo "[$(date -Is)] $*" | tee -a "${LOG}"; }

if [[ -f "${FLAG}" ]]; then
  log "scale already started ($(cat "${FLAG}")) — exit"
  exit 0
fi

log "watching for KKI239 pack: ${PACK}"
while [[ ! -f "${PACK}" ]]; do
  # still alive?
  if ! squeue -u "$USER" -h -o '%j %T %R' 2>/dev/null | grep -E 'uhat_mini_(ifod|pack)_KKI239' | grep -vE 'DependencyNeverSatisfied' | grep -qE ' (R|PD) '; then
    if [[ ! -f "${PACK}" ]]; then
      log "WARNING: no live KKI239 mini job and no pack yet — keep waiting ${POLL_SEC}s (manual rescue may be needed)"
    fi
  fi
  sleep "${POLL_SEC}"
done
log "KKI239 pack present"

log "run within-site P_L (expect n=5)"
cd "${UHAT}"
PYTHONPATH="/mnt/nfs/home/urmc-sh.rochester.edu/pndagiji/Documents/edgeuq/src:${PYTHONPATH:-}" \
  python3 run_within_site_PL.py --allow-partial >> "${LOG}" 2>&1 || log "within-site PL exit=$?"

log "gate unlocked: scale descriptive (user: run scale cohort after this is done)"
echo "$(date -Is) boekel_wave" > "${FLAG}"
SCALE_PARTITION="${SCALE_PARTITION:-general}" bash "${UHAT}/slurm/submit_scale_descriptive.sh" boekel >> "${LOG}" 2>&1
log "Boekel scale wave submitted — see ${LOGDIR}/scale_descriptive_submit.txt"
log "Kirby remaining: run submit_scale_descriptive.sh kirby when Boekel pressure/disk OK"
