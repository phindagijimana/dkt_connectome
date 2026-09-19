#!/bin/bash
# Slurm array: render unified subject_qc.html for CIDUR G1 (Step 6 only).
#
# Usage (from repo):
#   bash dwi_pipeline/scripts/submit_cidur_g1_subject_qc.sh

#SBATCH --job-name=cidur_g1_qc
#SBATCH --output=logs/cidur_g1_qc_%A_%a.out
#SBATCH --error=logs/cidur_g1_qc_%A_%a.err
#SBATCH --time=00:30:00
#SBATCH --partition=interactive
#SBATCH --cpus-per-task=2
#SBATCH --mem=8G
#SBATCH --mail-type=END,FAIL

set -euo pipefail
set +H

: "${DWI_ROOT:?ERROR: DWI_ROOT not set}"
: "${REPO_ROOT:?ERROR: REPO_ROOT not set}"
source "${DWI_ROOT}/workflow/lib/slurm_env.sh"

PIPELINE="${DWI_ROOT}/workflow/run_subject.sh"
SUBJECT_LIST_FILE="${SUBJECT_LIST_FILE:?ERROR: SUBJECT_LIST_FILE not set}"

[[ -f "${PIPELINE}" ]] || { echo "Missing ${PIPELINE}"; exit 1; }
[[ -f "${SUBJECT_LIST_FILE}" ]] || { echo "Missing subject list: ${SUBJECT_LIST_FILE}"; exit 1; }
[[ -n "${SLURM_ARRAY_TASK_ID:-}" ]] || { echo "Need SLURM_ARRAY_TASK_ID"; exit 1; }

SUBJECT="$(sed -n "${SLURM_ARRAY_TASK_ID}p" "${SUBJECT_LIST_FILE}" | tr -d '\r')"
SUBJECT="${SUBJECT#"${SUBJECT%%[![:space:]]*}"}"
SUBJECT="${SUBJECT%"${SUBJECT##*[![:space:]]}"}"
[[ -n "${SUBJECT}" ]] || { echo "Task ${SLURM_ARRAY_TASK_ID}: empty line"; exit 0; }
[[ "${SUBJECT}" != \#* ]] || { echo "Task ${SLURM_ARRAY_TASK_ID}: comment line"; exit 0; }
SUBJECT="${SUBJECT#sub-}"

SUBJECT_ARGS=(--fastsurfer --no-inpaint --connectome-sift2 --tractography-model both)
[[ -n "${RECON_SESSION:-}" ]] && SUBJECT_ARGS+=(--recon-session "${RECON_SESSION}")
[[ -n "${DWI_SELECT_JSON:-}" ]] && SUBJECT_ARGS+=(--dwi-select "${DWI_SELECT_JSON}")

export SNAKEMAKE_WORKDIR="${RESULTS_ROOT}/.snakemake_workdir/sub-${SUBJECT}"
mkdir -p "${SNAKEMAKE_WORKDIR}/.snakemake/locks"

echo "=== CIDUR G1 subject_qc task ${SLURM_ARRAY_TASK_ID}: sub-${SUBJECT} ==="
bash "${PIPELINE}" subject_qc "${SUBJECT}" "${SUBJECT_ARGS[@]}"
echo "=== Done sub-${SUBJECT} ==="
