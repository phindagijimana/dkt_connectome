#!/usr/bin/env bash
# Submit CIDUR backfill in two batches: Group 1 (Siemens+fmap) then Group 2 (GE/no-fmap).
#
# Usage:
#   bash scripts/submit_cidur_backfill_batches.sh
#   ARRAY_CONCURRENCY=8 SBATCH_PARTITION=interactive bash scripts/submit_cidur_backfill_batches.sh
#
# Does not cancel existing jobs. Group 2 starts after Group 1 array completes (afterok).
set -euo pipefail

DWI_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
GUGGER_RESULTS="${RESULTS_ROOT:-/mnt/nfs/Gugger_Lab/NIR/dwi_CIDUR/results}"
G1_LIST="${DWI_ROOT}/subject_list_cidur_backfill_group1.txt"
G2_LIST="${DWI_ROOT}/subject_list_cidur_backfill_group2.txt"

[[ -s "${G1_LIST}" ]] || { echo "Missing ${G1_LIST}" >&2; exit 1; }
[[ -s "${G2_LIST}" ]] || { echo "Missing ${G2_LIST}" >&2; exit 1; }

echo "=== CIDUR backfill batches ==="
echo "  RESULTS_ROOT=${GUGGER_RESULTS}"
echo "  Group 1 (with fmap): $(wc -l < "${G1_LIST}") subjects -> ${G1_LIST##*/}"
echo "  Group 2 (no fmap):   $(wc -l < "${G2_LIST}") subjects -> ${G2_LIST##*/}"
echo "  ARRAY_CONCURRENCY=${ARRAY_CONCURRENCY:-8}"
echo "  SBATCH_PARTITION=${SBATCH_PARTITION:-interactive}"
echo ""

submit_one() {
  local label="$1"
  local list="$2"
  local dep="${3:-}"
  echo "--- Submitting ${label} ---"
  if [[ -n "${dep}" ]]; then
    export SBATCH_DEPENDENCY="afterok:${dep}"
    echo "  Depends on job ${dep}"
  else
    unset SBATCH_DEPENDENCY
  fi
  export RESULTS_ROOT="${GUGGER_RESULTS}"
  export SUBJECT_LIST_FILE="${list}"
  export SUBJECT_LIST_USE_EXISTING=1
  export ARRAY_CONCURRENCY="${ARRAY_CONCURRENCY:-8}"
  set +e
  local out
  out="$(bash "${DWI_ROOT}/scripts/submit_cidur_backfill.sh" 2>&1)"
  local rc=$?
  set -e
  echo "${out}"
  [[ ${rc} -eq 0 ]] || exit "${rc}"
  sed -n 's/.*Submitted batch job \([0-9][0-9]*\).*/\1/p' <<<"${out}" | tail -1
}

JOB1="$(submit_one "Group 1" "${G1_LIST}")"
[[ -n "${JOB1}" ]] || { echo "ERROR: Group 1 submit did not return a job id" >&2; exit 1; }
echo "Group 1 job: ${JOB1}"

JOB2="$(submit_one "Group 2" "${G2_LIST}" "${JOB1}")"
[[ -n "${JOB2}" ]] || { echo "ERROR: Group 2 submit did not return a job id" >&2; exit 1; }
echo "Group 2 job: ${JOB2} (afterok:${JOB1})"

echo ""
echo "Monitor:"
echo "  squeue -u \"\$USER\" -n cidur_conn_ns"
echo "  sacct -j ${JOB1},${JOB2} --format=JobID,JobName,State,Elapsed"
