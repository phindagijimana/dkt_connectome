#!/usr/bin/env bash
# Resume TBI factorial experiment arms from Gugger Lab archive.
#
# Usage:
#   bash scripts/submit_tbi_experiment_resume.sh prep          # backfill markers + clean stale Step 3.1 (all arms)
#   bash scripts/submit_tbi_experiment_resume.sh wave1         # 4 arms in parallel
#   bash scripts/submit_tbi_experiment_resume.sh wave2         # VBT arms (after wave1 or VBT fix)
#   bash scripts/submit_tbi_experiment_resume.sh all           # wave1 then wave2 (no wait between)
#   bash scripts/submit_tbi_experiment_resume.sh arm orig-lesion   # single arm
#   bash scripts/submit_tbi_experiment_resume.sh remaining       # incomplete arms, sequential (skips running)
#
# Requires rebuilt dkt_lesion_act.sif (ACPC-first Step 3.1 + mrstats QA fix):
#   CONTAINER_QSIRECON=/path/to/qsirecon.sif OUT_SIF=/path/to/dkt_lesion_act.sif \
#     bash containers/lesion_act/build_lesion_act.sh
#
# Outputs: ${ARCH}/sub-<SUBJECT>_fastsurfer_experiment/arms/<arm>/

set -euo pipefail

WAVE="${1:?Usage: $0 prep|wave1|wave2|all|remaining|arm [ARM] [SUBJECT]}"
SUBJECT="${2:-TBI011011}"
if [[ "${WAVE}" == "arm" ]]; then
  SINGLE_ARM="${2:?Usage: $0 arm <arm-name> [SUBJECT]}"
  SUBJECT="${3:-TBI011011}"
fi
SUBJECT="${SUBJECT#sub-}"

DWI_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
ARCH="${TBI_EXPERIMENT_ARCH:-/mnt/nfs/Gugger_Lab/NIR/dwi_test_TBI_experiment}"

export BIDS_DIR="${BIDS_DIR:-${ARCH}/bids}"
export RESULTS_ROOT="${RESULTS_ROOT:-${ARCH}/sub-${SUBJECT}_fastsurfer_experiment}"
export RECON_SESSION="${RECON_SESSION:-2WK}"
export SBATCH_PARTITION="${SBATCH_PARTITION:-interactive}"
export SBATCH_TIME="${SBATCH_TIME:-12:00:00}"
export SBATCH_MEM="${SBATCH_MEM:-48G}"
export SBATCH_CPUS="${SBATCH_CPUS:-8}"
export NTHREADS="${NTHREADS:-8}"
export OMP_NTHREADS="${OMP_NTHREADS:-8}"
export EXCLUDE_NODES="${EXCLUDE_NODES-smdodwork05}"
export SUBJECT_LIST_FILE="${SUBJECT_LIST_FILE:-/tmp/tbi_experiment_subjects.txt}"

ARMS_ROOT="${RESULTS_ROOT}/arms"
ALL_ARMS=(orig-std orig-lesion neurolit-std neurolit-lesion vbt-std vbt-lesion)
LESION_ARMS=(orig-lesion neurolit-lesion vbt-lesion)

# TBI experiment: SyN SDC + b=1300 ses-2WK dwi-select only.
TBI_DWI_SHELL="${TBI_DWI_SHELL:-1300}"
TBI_DWI_SELECT="${TBI_DWI_SELECT:-${DWI_ROOT}/config/dwi_select_b1300_ses-2WK.json}"
TBI_SUBMIT_FLAGS=(--syn --dwi-select "${TBI_DWI_SELECT}")

preflight_dwi_select() {
  local tmp_filter
  tmp_filter="$(mktemp /tmp/tbi_dwi_filter_XXXXXX.json)"
  if ! python3 "${DWI_ROOT}/scripts/build_bids_filter.py" \
    --bids-dir "${BIDS_DIR}" --subject "${SUBJECT}" \
    --select-json "${TBI_DWI_SELECT}" --output "${tmp_filter}"; then
    rm -f "${tmp_filter}"
    echo "ERROR: dwi-select does not match sub-${SUBJECT} BIDS DWI." >&2
    echo "  Config: ${TBI_DWI_SELECT}" >&2
    echo "  TBI011011 ses-2WK/6MO DWI nonzero shells are b=1300 (not 1000)." >&2
    echo "  Use TBI_DWI_SELECT or TBI_DWI_SHELL to override dwi-select config." >&2
    exit 1
  fi
  rm -f "${tmp_filter}"
  echo "Preflight dwi-select OK: ${TBI_DWI_SELECT}"
}

preclean_arm_locks() {
  local arm="$1"
  local wd="${ARMS_ROOT}/${arm}/.snakemake_workdir/.snakemake"
  rm -rf "${wd}/locks" "${wd}/incomplete" 2>/dev/null || true
  mkdir -p "${wd}/locks"
}

preclean_failed_lesion_act() {
  local arm="$1"
  if arm_is_running "${arm}"; then
    echo "  ${arm}: skip Step 3.1 cleanup (Slurm job running)"
    return 0
  fi
  local arm_root="${ARMS_ROOT}/${arm}"
  local log="${arm_root}/logs/sub-${SUBJECT}_lesion_aware_act.log"
  local act_json="${arm_root}/lesion_aware_act/sub-${SUBJECT}/lesion_aware_act.json"
  local act_ok=0
  [[ -f "${act_json}" ]] && act_ok=1
  if [[ -f "${log}" ]] && grep -q "ERROR \[lesion-aware-act\]" "${log}"; then
    act_ok=0
  fi
  if [[ "${act_ok}" -eq 1 ]]; then
    return 0
  fi
  if [[ -d "${arm_root}/lesion_aware_act" ]] || [[ -f "${log}" ]]; then
    echo "  ${arm}: clearing stale Step 3.1 outputs (failed or incomplete lesion-aware ACT)"
    rm -rf "${arm_root}/lesion_aware_act"
    : > "${log}" 2>/dev/null || true
    rm -rf "${arm_root}/connectomes/sub-${SUBJECT}" \
      "${arm_root}/disconnectome/sub-${SUBJECT}" 2>/dev/null || true
  fi
}

backfill_arm_markers() {
  local arm="$1"
  local arm_root="${ARMS_ROOT}/${arm}"
  [[ -d "${arm_root}" ]] || return 0
  echo "  ${arm}: backfill Snakemake markers (skip hung QSIRecon tckgen when FOD+5TT exist)"
  RESULTS_ROOT="${arm_root}" bash "${DWI_ROOT}/workflow/backfill_markers.sh" "${SUBJECT}"
}

prep_arm() {
  local arm="$1"
  local arm_root="${ARMS_ROOT}/${arm}"
  [[ -d "${arm_root}" ]] || {
    echo "  ${arm}: skip (no arm directory)"
    return 0
  }
  preclean_arm_locks "${arm}"
  backfill_arm_markers "${arm}"
  case "${arm}" in
    *-lesion) preclean_failed_lesion_act "${arm}" ;;
  esac
}

prep_all_arms() {
  echo "=== Prep all experiment arms (sub-${SUBJECT}) ==="
  local lesion_act_sif
  lesion_act_sif="$(python3 - <<PY 2>/dev/null || true
import yaml
from pathlib import Path
local = Path("${DWI_ROOT}/workflow/config/config.local.yaml")
if local.is_file():
    cfg = yaml.safe_load(local.read_text()) or {}
    print(cfg.get("containers", {}).get("lesion_act", ""))
PY
)"
  if [[ -n "${lesion_act_sif}" && -f "${lesion_act_sif}" ]]; then
    echo "  lesion_act container: ${lesion_act_sif} ($(du -h "${lesion_act_sif}" | awk '{print $1}'), mtime $(date -r "${lesion_act_sif}" '+%Y-%m-%d %H:%M'))"
  else
    echo "WARNING: dkt_lesion_act.sif not found — rebuild before *-lesion arms:" >&2
    echo "  bash containers/lesion_act/build_lesion_act.sh" >&2
  fi
  preclean_orig_lesion
  preclean_vbt_work
  preclean_stale_vbt_std_connectome
  for arm in "${ALL_ARMS[@]}"; do
    prep_arm "${arm}"
  done
  echo "=== Prep done ==="
}

arm_is_running() {
  local arm="$1"
  local slug="${arm//-/_}"
  squeue -u "${USER}" -n "tbi_${SUBJECT,,}_${slug}" -h 2>/dev/null | grep -q .
}

arm_is_complete() {
  local arm="$1"
  local arm_root="${ARMS_ROOT}/${arm}"
  [[ -f "${arm_root}/connectomes/sub-${SUBJECT}/dkt_connectome_sift2.csv" ]]
}

preclean_orig_lesion() {
  local fs="${ARMS_ROOT}/orig-lesion/freesurfer/sub-${SUBJECT}"
  if [[ -d "${fs}" ]] && [[ ! -f "${fs}/mri/aparc+aseg.mgz" ]]; then
    echo "Removing stale partial recon: ${fs}"
    rm -rf "${fs}"
  fi
  rm -rf "${ARMS_ROOT}/orig-lesion/.snakemake_workdir/.snakemake/locks"
  mkdir -p "${ARMS_ROOT}/orig-lesion/.snakemake_workdir/.snakemake/locks"
}

preclean_vbt_work() {
  for arm in vbt-std vbt-lesion; do
    local w="${ARMS_ROOT}/${arm}/vbt/.vbt_work"
    if [[ -d "${w}" ]]; then
      echo "Clearing partial VBT workdir: ${w}"
      rm -rf "${w}"
    fi
  done
}

preclean_arm_locks() {
  local arm="$1"
  local wd="${ARMS_ROOT}/${arm}/.snakemake_workdir/.snakemake"
  rm -rf "${wd}/locks" "${wd}/incomplete" 2>/dev/null || true
  mkdir -p "${wd}/locks"
}

preclean_stale_vbt_std_connectome() {
  local conn="${ARMS_ROOT}/vbt-std/connectomes/sub-${SUBJECT}"
  if [[ -d "${conn}" ]] && [[ ! -f "${conn}/dkt_connectome_sift2.csv" ]]; then
    echo "Removing stale partial vbt-std connectome outputs (no sift2): ${conn}"
    rm -rf "${conn}"
  fi
}

submit_arms() {
  local arms_csv="$1"
  local sequential="${2:-0}"
  export PIPELINE_ENGINE="${PIPELINE_ENGINE:-snakemake}"
  preflight_dwi_select
  cd "${DWI_ROOT}"
  local -a extra=(--arms "${arms_csv}" "${TBI_SUBMIT_FLAGS[@]}")
  [[ "${sequential}" == "1" ]] && extra=(--sequential "${extra[@]}")
  bash scripts/submit_all_experiment_arms.sh "${SUBJECT}" "${extra[@]}"
}

run_wave1() {
  echo "=== Wave 1: orig-std, orig-lesion, neurolit-std, neurolit-lesion ==="
  [[ -d "${BIDS_DIR}/sub-${SUBJECT}" ]] || {
    echo "ERROR: missing BIDS: ${BIDS_DIR}/sub-${SUBJECT}" >&2
    exit 1
  }
  [[ -d "${ARMS_ROOT}" ]] || {
    echo "ERROR: missing arms root: ${ARMS_ROOT}" >&2
    exit 1
  }
  prep_all_arms
  submit_arms "orig-std,orig-lesion,neurolit-std,neurolit-lesion"
}

run_wave2() {
  echo "=== Wave 2: vbt-std, vbt-lesion ==="
  prep_all_arms
  submit_arms "vbt-std,vbt-lesion"
}

run_remaining() {
  echo "=== Remaining incomplete arms (sequential) ==="
  [[ -d "${BIDS_DIR}/sub-${SUBJECT}" ]] || {
    echo "ERROR: missing BIDS: ${BIDS_DIR}/sub-${SUBJECT}" >&2
    exit 1
  }
  prep_all_arms
  local -a todo=()
  for arm in orig-lesion neurolit-lesion vbt-std vbt-lesion; do
    if arm_is_complete "${arm}"; then
      echo "  skip ${arm}: connectome complete"
      continue
    fi
    if arm_is_running "${arm}"; then
      echo "  skip ${arm}: Slurm job already running"
      continue
    fi
    todo+=("${arm}")
  done
  if ((${#todo[@]} == 0)); then
    echo "No remaining arms to submit."
    return 0
  fi
  local arms_csv
  arms_csv="$(IFS=,; echo "${todo[*]}")"
  echo "  Submitting: ${arms_csv}"
  submit_arms "${arms_csv}" 1
}

run_single_arm() {
  echo "=== Single arm: ${SINGLE_ARM} ==="
  [[ -d "${BIDS_DIR}/sub-${SUBJECT}" ]] || {
    echo "ERROR: missing BIDS: ${BIDS_DIR}/sub-${SUBJECT}" >&2
    exit 1
  }
  prep_arm "${SINGLE_ARM}"
  preclean_orig_lesion
  [[ "${SINGLE_ARM}" == vbt-std || "${SINGLE_ARM}" == vbt-lesion ]] && preclean_vbt_work
  submit_arms "${SINGLE_ARM}"
}

case "${WAVE}" in
  prep) prep_all_arms ;;
  wave1) run_wave1 ;;
  wave2) run_wave2 ;;
  remaining) run_remaining ;;
  arm) run_single_arm ;;
  all)
    prep_all_arms
    run_wave1
    echo ""
    echo "Note: wave2 submits immediately; monitor VBT arms separately."
    run_wave2
    ;;
  *)
    echo "ERROR: unknown wave ${WAVE} (use prep, wave1, wave2, arm, remaining, or all)" >&2
    exit 2
    ;;
esac

echo ""
echo "Monitor: squeue -u \"\$USER\" -n tbi_${SUBJECT,,}_"
echo "Archive: ${ARMS_ROOT}"
echo "TBI flags: --syn --dwi-select ${TBI_DWI_SELECT}"
