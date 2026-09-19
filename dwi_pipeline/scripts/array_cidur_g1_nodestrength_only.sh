#!/bin/bash
# Slurm array: Step 5 nodestrength only (connectome must already exist).
# Uses Snakemake --allowed-rules nodestrength so qsirecon/connectome are not rerun.

#SBATCH --job-name=cidur_ns
#SBATCH --output=logs/cidur_ns_%A_%a.out
#SBATCH --error=logs/cidur_ns_%A_%a.err
#SBATCH --time=00:45:00
#SBATCH --partition=interactive
#SBATCH --cpus-per-task=4
#SBATCH --mem=16G
#SBATCH --mail-type=END,FAIL

set -euo pipefail
set +H

: "${DWI_ROOT:?ERROR: DWI_ROOT not set}"
: "${REPO_ROOT:?ERROR: REPO_ROOT not set}"
source "${DWI_ROOT}/workflow/lib/slurm_env.sh"

PIPELINE="${DWI_ROOT}/workflow/run_subject.sh"
SUBJECT_LIST_FILE="${SUBJECT_LIST_FILE:?ERROR: SUBJECT_LIST_FILE not set}"

export NTHREADS="${NTHREADS:-4}"
export OMP_NTHREADS="${OMP_NTHREADS:-4}"
export XDG_CACHE_HOME="${XDG_CACHE_HOME:-${REPO_ROOT}/.cache}"
mkdir -p "${REPO_ROOT}/logs" "${XDG_CACHE_HOME}"

[[ -f "${PIPELINE}" ]] || { echo "Missing ${PIPELINE}"; exit 1; }
[[ -f "${SUBJECT_LIST_FILE}" ]] || { echo "Missing subject list: ${SUBJECT_LIST_FILE}"; exit 1; }
[[ -n "${SLURM_ARRAY_TASK_ID:-}" ]] || { echo "Need SLURM_ARRAY_TASK_ID"; exit 1; }

SUBJECT="$(sed -n "${SLURM_ARRAY_TASK_ID}p" "${SUBJECT_LIST_FILE}" | tr -d '\r')"
SUBJECT="${SUBJECT#"${SUBJECT%%[![:space:]]*}"}"
SUBJECT="${SUBJECT%"${SUBJECT##*[![:space:]]}"}"
[[ -n "${SUBJECT}" ]] || { echo "Task ${SLURM_ARRAY_TASK_ID}: empty line"; exit 0; }
[[ "${SUBJECT}" != \#* ]] || { echo "Task ${SLURM_ARRAY_TASK_ID}: comment line"; exit 0; }
SUBJECT="${SUBJECT#sub-}"

conn="${RESULTS_ROOT}/connectomes/sub-${SUBJECT}/dkt_connectome.csv"
ns="${RESULTS_ROOT}/node_strength/strength/per_subject/sub-${SUBJECT}_strength.csv"
if [[ -f "${ns}" ]]; then
  echo "Task ${SLURM_ARRAY_TASK_ID}: sub-${SUBJECT} nodestrength already present — skip"
  exit 0
fi
[[ -f "${conn}" ]] || {
  echo "Task ${SLURM_ARRAY_TASK_ID}: sub-${SUBJECT} missing connectome (${conn}) — abort"
  exit 1
}

# Backfill qsirecon marker when connectome exists (avoids upstream reruns if allowed-rules slips).
marker="${RESULTS_ROOT}/.snakemake_markers/sub-${SUBJECT}/qsirecon.done"
if [[ ! -f "${marker}" ]]; then
  mkdir -p "$(dirname "${marker}")"
  touch "${marker}"
  echo "Backfilled qsirecon.done for sub-${SUBJECT}"
fi

prepare_snakemake_workdir() {
  export SNAKEMAKE_WORKDIR="${RESULTS_ROOT}/.snakemake_workdir/sub-${SUBJECT}"
  rm -rf "${SNAKEMAKE_WORKDIR}/.snakemake/locks"
  mkdir -p "${SNAKEMAKE_WORKDIR}/.snakemake/locks"
}

prepare_snakemake_workdir
bash "${DWI_ROOT}/workflow/preflight.sh" --mode nodestrength --subject "${SUBJECT}" --quick || exit 1

echo "=== CIDUR nodestrength task ${SLURM_ARRAY_TASK_ID}: sub-${SUBJECT} ==="
bash "${PIPELINE}" nodestrength "${SUBJECT}" --no-inpaint -- --allowed-rules nodestrength

[[ -f "${ns}" ]] || { echo "ERROR: expected ${ns} after nodestrength"; exit 1; }
echo "=== Done sub-${SUBJECT}: ${ns} ==="
