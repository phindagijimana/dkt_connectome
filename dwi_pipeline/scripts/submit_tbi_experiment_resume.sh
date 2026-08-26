#!/usr/bin/env bash
# Resume TBI factorial experiment arms from Gugger Lab archive.
#
# Usage:
#   bash scripts/submit_tbi_experiment_resume.sh wave1   # 4 arms in parallel
#   bash scripts/submit_tbi_experiment_resume.sh wave2   # VBT arms (after wave1 or VBT fix)
#   bash scripts/submit_tbi_experiment_resume.sh all     # wave1 then wave2 (no wait between)
#   bash scripts/submit_tbi_experiment_resume.sh arm orig-lesion   # single arm
#
# Outputs: ${ARCH}/sub-<SUBJECT>_fastsurfer_experiment/arms/<arm>/

set -euo pipefail

WAVE="${1:?Usage: $0 wave1|wave2|all|arm [ARM] [SUBJECT]}"
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

submit_arms() {
  local arms_csv="$1"
  preflight_dwi_select
  cd "${DWI_ROOT}"
  bash scripts/submit_all_experiment_arms.sh "${SUBJECT}" --arms "${arms_csv}" \
    "${TBI_SUBMIT_FLAGS[@]}"
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
  preclean_orig_lesion
  submit_arms "orig-std,orig-lesion,neurolit-std,neurolit-lesion"
}

run_wave2() {
  echo "=== Wave 2: vbt-std, vbt-lesion ==="
  preclean_vbt_work
  submit_arms "vbt-std,vbt-lesion"
}

run_single_arm() {
  echo "=== Single arm: ${SINGLE_ARM} ==="
  [[ -d "${BIDS_DIR}/sub-${SUBJECT}" ]] || {
    echo "ERROR: missing BIDS: ${BIDS_DIR}/sub-${SUBJECT}" >&2
    exit 1
  }
  if [[ "${SINGLE_ARM}" == "orig-lesion" ]]; then
    preclean_orig_lesion
  fi
  submit_arms "${SINGLE_ARM}"
}

case "${WAVE}" in
  wave1) run_wave1 ;;
  wave2) run_wave2 ;;
  arm) run_single_arm ;;
  all)
    run_wave1
    echo ""
    echo "Note: wave2 submits immediately; monitor VBT arms separately."
    run_wave2
    ;;
  *)
    echo "ERROR: unknown wave ${WAVE} (use wave1, wave2, arm, or all)" >&2
    exit 2
    ;;
esac

echo ""
echo "Monitor: squeue -u \"\$USER\" -n tbi_${SUBJECT,,}_"
echo "Archive: ${ARMS_ROOT}"
echo "TBI flags: --syn --dwi-select ${TBI_DWI_SELECT}"
