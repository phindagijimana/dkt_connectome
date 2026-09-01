#!/usr/bin/env bash
# Re-run Step 4 (+ SIFT2, nodestrength, disconnectome) on all TBI011011 factorial
# arms after the rigid FS-T1 -> QSIPrep ACPC label registration change.
#
# Usage:
#   bash dwi_pipeline/scripts/rerun_tbi011011_connectome_rigid_reg.sh
#   bash dwi_pipeline/scripts/rerun_tbi011011_connectome_rigid_reg.sh --dry-run
#   bash dwi_pipeline/scripts/rerun_tbi011011_connectome_rigid_reg.sh --from-phase disconnectome

set -euo pipefail

DRY_RUN=0
FROM_PHASE=all

while [[ $# -gt 0 ]]; do
  case "$1" in
    --dry-run) DRY_RUN=1; shift ;;
    --from-phase)
      FROM_PHASE="${2:?Need phase: connectome, disconnectome, nodestrength, or qc}"
      shift 2
      ;;
    *)
      echo "Unknown argument: $1" >&2
      exit 1
      ;;
  esac
done

case "${FROM_PHASE}" in
  all|connectome|disconnectome|nodestrength|qc) ;;
  *)
    echo "Invalid --from-phase ${FROM_PHASE} (use connectome, disconnectome, nodestrength, or qc)" >&2
    exit 1
    ;;
esac

DWI_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
# shellcheck disable=SC1091
source "${DWI_ROOT}/scripts/lib/rigid_reg_rerun_helpers.sh"

EXP="${EXP:-/mnt/nfs/Gugger_Lab/NIR/dwi_test_TBI_experiment/sub-TBI011011_fastsurfer_experiment}"
BIDS="${BIDS:-/mnt/nfs/Gugger_Lab/NIR/dwi_test_TBI_experiment/bids}"
SUBJECT="${SUBJECT:-TBI011011}"
SUBJECT="${SUBJECT#sub-}"
SID="sub-${SUBJECT}"

ALL_ARMS=(orig-std orig-lesion neurolit-std neurolit-lesion vbt-std vbt-lesion deep-atropos-pilot)
LESION_ARMS=(orig-lesion neurolit-lesion vbt-lesion deep-atropos-pilot)

run_cmd() {
  if ((DRY_RUN)); then
    echo "[dry-run] $*"
  else
    echo "+ $*"
    "$@"
  fi
}

clear_connectome_outputs() {
  local arm_dir="$1"
  local conn="${arm_dir}/connectomes/${SID}"
  if ((DRY_RUN)); then
    echo "[dry-run] clear connectome outputs under ${conn}"
    return 0
  fi
  clear_connectome_outputs_for_rigid_reg "${arm_dir}" "${SUBJECT}"
}

clear_nodestrength_outputs() {
  local arm_dir="$1"
  local ns="${arm_dir}/node_strength"
  [[ -d "${ns}" ]] || return 0
  if ((DRY_RUN)); then
    echo "[dry-run] clear nodestrength outputs for ${SID} under ${ns}"
    return 0
  fi
  rm -rf "${ns}/strength/per_subject/${SID}"* \
         "${ns}/volume/per_subject/${SID}"* \
         "${ns}/reports/${SID}" 2>/dev/null || true
}

clear_disconnectome_outputs() {
  local arm_dir="$1"
  local disc="${arm_dir}/connectomes/${SID}/disconnectome"
  [[ -d "${disc}" ]] || return 0
  if ((DRY_RUN)); then
    echo "[dry-run] clear disconnectome under ${disc}"
    return 0
  fi
  rm -rf "${disc}"
}

run_arm_mode() {
  local arm="$1"
  local mode="$2"
  shift 2
  local arm_dir="${EXP}/arms/${arm}"
  echo ""
  echo "=== ${arm}: ${mode} ==="
  date
  BIDS_DIR="${BIDS}" \
  RESULTS_ROOT="${arm_dir}" \
  EXPERIMENT_ARM="${arm}" \
  SNAKEMAKE_WORKDIR="${arm_dir}/.snakemake_workdir/${SID}" \
  NTHREADS=8 \
  CONNECTOME_SIFT2=1 \
  ACT_BIND_MOUNT_DEV=1 \
  SKIP_RERUN_INCOMPLETE=1 \
    run_cmd bash workflow/run_subject.sh "${mode}" "${SUBJECT}" \
      --experiment-arm "${arm}" \
      --recon-session 2WK \
      --fastsurfer \
      --no-inpaint \
      --connectome-sift2 \
      --tractography-model ifod2 \
      "$@"
}

# shellcheck disable=SC1091
source "${DWI_ROOT}/workflow/lib/slurm_env.sh"
cd "${DWI_ROOT}"

echo "=== TBI011011 connectome rerun (rigid FS->ACPC registration) ==="
echo "  FROM_PHASE=${FROM_PHASE}"
date

should_run() {
  local phase="$1"
  case "${FROM_PHASE}" in
    all) return 0 ;;
    connectome) [[ "${phase}" == connectome ]] && return 0 ;;
    disconnectome) [[ "${phase}" == disconnectome || "${phase}" == nodestrength || "${phase}" == qc ]] && return 0 ;;
    nodestrength) [[ "${phase}" == nodestrength || "${phase}" == qc ]] && return 0 ;;
    qc) [[ "${phase}" == qc ]] && return 0 ;;
  esac
  return 1
}

if should_run connectome; then
  for arm in "${ALL_ARMS[@]}"; do
    arm_dir="${EXP}/arms/${arm}"
    clear_connectome_outputs "${arm_dir}"
    extra=()
    [[ "${arm}" == "deep-atropos-pilot" ]] && extra+=(--act-5tt-source deep-atropos-native)
    run_arm_mode "${arm}" connectome "${extra[@]}"
  done
fi

if should_run disconnectome; then
  for arm in "${LESION_ARMS[@]}"; do
    arm_dir="${EXP}/arms/${arm}"
    clear_disconnectome_outputs "${arm_dir}"
    extra=(--disconnection --primary-connectome-measure sift2 --disconnectome-weighting sift2)
    [[ "${arm}" == "deep-atropos-pilot" ]] && extra+=(--act-5tt-source deep-atropos-native)
    run_arm_mode "${arm}" disconnectome "${extra[@]}"
  done
fi

if should_run nodestrength; then
  for arm in "${ALL_ARMS[@]}"; do
    arm_dir="${EXP}/arms/${arm}"
    clear_nodestrength_outputs "${arm_dir}"
    extra=()
    [[ "${arm}" == "deep-atropos-pilot" ]] && extra+=(--act-5tt-source deep-atropos-native)
    run_arm_mode "${arm}" nodestrength "${extra[@]}"
  done
fi

if should_run qc; then
  for arm in "${ALL_ARMS[@]}"; do
    arm_dir="${EXP}/arms/${arm}"
    echo ""
    echo "=== ${arm}: subject_qc refresh ==="
    run_cmd python3 scripts/render_subject_qc.py \
      --results-root "${arm_dir}" --subject "${SUBJECT}" 2>/dev/null || \
    run_cmd python3.12 scripts/render_subject_qc.py \
      --results-root "${arm_dir}" --subject "${SUBJECT}" || true
  done

  echo ""
  echo "=== verify ==="
  run_cmd bash scripts/verify_tbi011011_arms.sh
fi

echo "=== Done ==="
date
