#!/usr/bin/env bash
# Poll SLURM job 192080 until terminal state or 90 minutes
set -uo pipefail
DLS="/mnt/nfs/home/URMC-SH/pndagiji/Documents/TrackTBI-Sub/dwi_pipeline/methods/others_methods/preprocessing/DL/dlsurfer"
JOB=192080
OUT="$DLS/dlsurfer_v2c_${JOB}.out"
ERR="$DLS/dlsurfer_v2c_${JOB}.err"
WORK="$DLS/work/phase3_v2c"
REPORT="$DLS/.poll_192080_report.txt"
LOG="$DLS/.poll_192080.log"

MAX_SEC=$((90 * 60))
START=$(date +%s)
OUT_OFF=0
ERR_OFF=0

log() { echo "[$(date -Iseconds)] $*" | tee -a "$LOG"; }

job_state() {
  if squeue -j "$JOB" -h 2>/dev/null | grep -q .; then
    squeue -j "$JOB" 2>/dev/null
    echo "STATE=RUNNING"
    return
  fi
  sacct -j "$JOB" --format=JobID,State,ExitCode,Elapsed,End -P -n 2>/dev/null | head -5
  local st
  st=$(sacct -j "$JOB" --format=State -P -n 2>/dev/null | head -1 | tr -d ' ')
  echo "STATE=${st:-UNKNOWN}"
}

terminal_state() {
  local st="$1"
  case "$st" in
    COMPLETED|FAILED|CANCELLED|TIMEOUT|OUT_OF_MEMORY|NODE_FAIL|PREEMPTED|BOOT_FAIL|DEADLINE)
      return 0 ;;
    RUNNING|PENDING|CONFIGURING|COMPLETING|RESIZING|SUSPENDED|REQUEUED)
      return 1 ;;
    *)
      # If not in queue and state looks finished
      if [[ "$st" != "RUNNING" && "$st" != "PENDING" && "$st" != "UNKNOWN" && -n "$st" ]]; then
        return 0
      fi
      return 1 ;;
  esac
}

tail_new() {
  local f="$1" off_var="$2"
  local off=${!off_var}
  local sz
  [[ -f "$f" ]] || return
  sz=$(wc -c < "$f" | tr -d ' ')
  if (( sz > off )); then
    log "--- new from $(basename "$f") (offset $off) ---"
    tail -c +$((off + 1)) "$f" | tail -c 8000 >> "$LOG"
    printf '\n' >> "$LOG"
    printf -v "$off_var" '%s' "$sz"
  fi
}

SID=sub-EG
check_markers() {
  log "Markers:"
  for p in \
    "$WORK/with_lit/$SID/scripts/dlsurfer_v2c.done" \
    "$WORK/with_lit/$SID/scripts/dlsurfer_v2c.exit" \
    "$WORK/no_lit/$SID/scripts/dlsurfer_v2c.done" \
    "$WORK/no_lit/$SID/scripts/dlsurfer_v2c.exit" \
    "$WORK/with_lit/$SID/scripts/dlsurfer_surf_dl.done" \
    "$WORK/no_lit/$SID/scripts/dlsurfer_surf_dl.done" \
    "$WORK/with_lit/$SID/scripts/dlsurfer_v2c_fs_install.done" \
    "$WORK/no_lit/$SID/scripts/dlsurfer_v2c_fs_install.done" \
    ; do
    if [[ -f "$p" ]]; then
      log "  EXISTS: $p ($(head -c 200 "$p" 2>/dev/null))"
    fi
  done
  find "$WORK" -maxdepth 5 \( -name '*.done' -o -name '*.exit' \) 2>/dev/null | while read -r f; do
    log "  found: $f"
  done
}

log "=== Poll start job $JOB ==="
POLL=0
while true; do
  POLL=$((POLL + 1))
  NOW=$(date +%s)
  ELAPSED=$((NOW - START))
  log "=== Poll #$POLL elapsed=${ELAPSED}s ==="
  SQ=$(job_state)
  log "$SQ"
  ST=$(echo "$SQ" | grep '^STATE=' | cut -d= -f2)
  tail_new "$OUT" OUT_OFF
  tail_new "$ERR" ERR_OFF
  check_markers

  if [[ "$ST" != "RUNNING" && "$ST" != "PENDING" ]] && terminal_state "$ST"; then
    log "Terminal state: $ST"
    break
  fi
  if (( ELAPSED >= MAX_SEC )); then
    log "90 minute cap reached"
    break
  fi
  # 3-5 min: use 240s (4 min)
  sleep 240
done

# Final sacct
log "=== FINAL ==="
sacct -j "$JOB" --format=JobID,JobName,State,ExitCode,Elapsed,End -P 2>/dev/null | tee -a "$LOG"
tail_new "$OUT" OUT_OFF
tail_new "$ERR" ERR_OFF
check_markers

# Write summary for agent
{
  echo "JOB=$JOB"
  echo "POLL_ELAPSED=$(( $(date +%s) - START ))"
  sacct -j "$JOB" --format=JobID,State,ExitCode,Elapsed,End -P -n 2>/dev/null | head -10
  echo "--- markers ---"
  find "$WORK" -maxdepth 6 \( -name 'dlsurfer_v2c*.done' -o -name 'dlsurfer_v2c*.exit' -o -name 'dlsurfer_surf_dl.done' -o -name 'dlsurfer_v2c_fs_install.*' \) 2>/dev/null
  for arm in with_lit no_lit; do
    for f in exit done; do
      p="$WORK/$arm/$SID/scripts/dlsurfer_v2c.$f"
      [[ -f "$p" ]] && echo "$p: $(cat "$p")"
    done
    p="$WORK/$arm/$SID/scripts/dlsurfer_surf_dl.done"
    [[ -f "$p" ]] && echo "SURF_$arm: $p"
  done
} > "$REPORT"

log "Report written to $REPORT"
