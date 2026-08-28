#!/usr/bin/env bash
# Submit one Slurm array job per factorial experiment arm (all optional flags on).
#
# Usage:
#   bash scripts/submit_all_experiment_arms.sh TBI011011
#   bash scripts/submit_all_experiment_arms.sh TBI011011 --sequential   # one job at a time (Slurm afterok chain)
#   bash scripts/submit_all_experiment_arms.sh TBI011011 --syn
#   bash scripts/submit_all_experiment_arms.sh TBI011011 --arms vbt-lesion,neurolit-lesion
#
# When your account allows only one running job, use --sequential (or cancel extras and
# submit remaining arms manually with SBATCH_DEPENDENCY=afterok:JOBID).
#
# Outputs:
#   ${RESULTS_ROOT}/arms/<arm>/   (default EXPERIMENT_ISOLATE_OUTPUTS=1)
#
set -euo pipefail

SUBJECT="${1:?Need subject id (e.g. TBI011011)}"
SUBJECT="${SUBJECT#sub-}"
shift || true

SEQUENTIAL=0
ARMS_FILTER=""
EXTRA_SUBMIT_FLAGS=()
while [[ $# -gt 0 ]]; do
  case "$1" in
    --sequential)
      SEQUENTIAL=1
      shift
      ;;
    --arms)
      ARMS_FILTER="${2:?Need comma-separated arm names after --arms}"
      shift 2
      ;;
    *)
      EXTRA_SUBMIT_FLAGS+=("$1")
      shift
      ;;
  esac
done

DWI_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

BIDS_DIR="${BIDS_DIR:-${DWI_ROOT}/dwi_test_TBI/bids}"
BASE_RESULTS_ROOT="${RESULTS_ROOT:-${DWI_ROOT}/dwi_test_TBI/sub-${SUBJECT}_fastsurfer_experiment}"
RECON_SESSION="${RECON_SESSION:-2WK}"

export BIDS_DIR
export RECON_SESSION
export SUBJECT_LIST_USE_EXISTING=1
export SUBJECT_LIST_FILE="${DWI_ROOT}/subjects.txt"
printf '%s\n' "${SUBJECT}" > "${SUBJECT_LIST_FILE}"

export SBATCH_CPUS="${SBATCH_CPUS:-8}"
export SBATCH_MEM="${SBATCH_MEM:-32G}"
export SBATCH_TIME="${SBATCH_TIME:-12:00:00}"
export NTHREADS="${NTHREADS:-8}"
export OMP_NTHREADS="${OMP_NTHREADS:-8}"
export ARRAY_CONCURRENCY="${ARRAY_CONCURRENCY:-1}"
export EXPERIMENT_ISOLATE_OUTPUTS="${EXPERIMENT_ISOLATE_OUTPUTS:-1}"

ALL_ARMS=(
  orig-std
  orig-lesion
  neurolit-std
  neurolit-lesion
  vbt-std
  vbt-lesion
)

if [[ -n "${ARMS_FILTER}" ]]; then
  IFS=',' read -r -a ARMS <<< "${ARMS_FILTER}"
else
  ARMS=("${ALL_ARMS[@]}")
fi

export PRIMARY_CONNECTOME_MEASURE="${PRIMARY_CONNECTOME_MEASURE:-sift2}"
export DISCONNECTOME_WEIGHTING="${DISCONNECTOME_WEIGHTING:-sift2}"

BASE_FLAGS=(
  --fastsurfer
  --tractography-model both
  --connectome-sift2
)

arm_submit_flags() {
  local arm="$1"
  local -a flags=("${BASE_FLAGS[@]}")
  if [[ "${arm}" == *"-lesion" ]]; then
    flags+=(--disconnection --disconnectome-weighting sift2)
  fi
  printf '%s\n' "${flags[@]}"
}

echo "Batch submit: sub-${SUBJECT}"
echo "  BIDS_DIR=${BIDS_DIR}"
echo "  BASE_RESULTS_ROOT=${BASE_RESULTS_ROOT}"
echo "  Sequential (afterok chain): $([[ ${SEQUENTIAL} -eq 1 ]] && echo yes || echo no)"
echo "  Arms: ${ARMS[*]}"
echo "  Extra submit flags: ${EXTRA_SUBMIT_FLAGS[*]:-(none)}"
echo ""

declare -a JOB_IDS=()
PREV_JOB="${SBATCH_DEPENDENCY:-}"
PREV_JOB="${PREV_JOB#afterok:}"

for arm in "${ARMS[@]}"; do
  slug="${arm//-/_}"
  export RESULTS_ROOT="${BASE_RESULTS_ROOT}"
  export EXPERIMENT_ARM="${arm}"
  export SBATCH_JOB_NAME="tbi_${SUBJECT,,}_${slug}"

  if [[ ${SEQUENTIAL} -eq 1 && -n "${PREV_JOB}" ]]; then
    export SBATCH_DEPENDENCY="afterok:${PREV_JOB}"
  else
    unset SBATCH_DEPENDENCY
  fi

  echo "=== Submitting arm: ${arm} (job-name=${SBATCH_JOB_NAME}) ==="
  [[ -n "${SBATCH_DEPENDENCY:-}" ]] && echo "  Depends on: ${SBATCH_DEPENDENCY}"

  mapfile -t ARM_FLAGS < <(arm_submit_flags "${arm}")

  set +e
  submit_out="$(
    cd "${DWI_ROOT}" && ./submit.sh \
      --experiment-arm "${arm}" \
      "${ARM_FLAGS[@]}" \
      "${EXTRA_SUBMIT_FLAGS[@]}" 2>&1
  )"
  rc=$?
  set -e
  echo "${submit_out}"
  if [[ ${rc} -ne 0 ]]; then
    echo "ERROR: submit failed for arm=${arm} (exit ${rc})" >&2
    exit "${rc}"
  fi
  job_id="$(sed -n 's/.*Submitted batch job \([0-9][0-9]*\).*/\1/p' <<<"${submit_out}" | tail -1)"
  if [[ -n "${job_id}" ]]; then
    JOB_IDS+=("${job_id}")
    PREV_JOB="${job_id}"
    echo "  -> job ${job_id}"
  fi
  echo ""
done

echo "Submitted ${#ARMS[@]} arm job(s) for sub-${SUBJECT}."
if ((${#JOB_IDS[@]})); then
  echo "Job IDs: ${JOB_IDS[*]}"
  echo "Monitor: squeue -u \"\$USER\" -n tbi_${SUBJECT,,}_"
fi
