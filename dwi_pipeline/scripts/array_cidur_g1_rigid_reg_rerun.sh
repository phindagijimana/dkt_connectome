#!/bin/bash
# Slurm array: re-run Step 4 (+ SIFT2) and Step 5 after rigid FS->ACPC connectome registration.
# Upstream QSIPrep / recon / tractography are reused when .tck files already exist.

#SBATCH --job-name=cidur_g1_rigid
#SBATCH --output=logs/cidur_g1_rigid_%A_%a.out
#SBATCH --error=logs/cidur_g1_rigid_%A_%a.err
#SBATCH --time=04:00:00
#SBATCH --partition=interactive
#SBATCH --cpus-per-task=8
#SBATCH --mem=48G
#SBATCH --mail-type=END,FAIL

set -euo pipefail
set +H

: "${DWI_ROOT:?ERROR: DWI_ROOT not set}"
: "${REPO_ROOT:?ERROR: REPO_ROOT not set}"
source "${DWI_ROOT}/workflow/lib/slurm_env.sh"
source "${DWI_ROOT}/scripts/lib/rigid_reg_rerun_helpers.sh"

PIPELINE="${DWI_ROOT}/workflow/run_subject.sh"
SUBJECT_LIST_FILE="${SUBJECT_LIST_FILE:?ERROR: SUBJECT_LIST_FILE not set}"
REQUESTED_MODEL="${TRACTOGRAPHY_MODEL:-both}"

export NTHREADS="${NTHREADS:-8}"
export OMP_NTHREADS="${OMP_NTHREADS:-8}"
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

SUBJECT_ARGS=(--fastsurfer --no-inpaint --connectome-sift2)
[[ -n "${RECON_SESSION:-}" ]] && SUBJECT_ARGS+=(--recon-session "${RECON_SESSION}")
[[ -n "${DWI_SELECT_JSON:-}" ]] && SUBJECT_ARGS+=(--dwi-select "${DWI_SELECT_JSON}")

prepare_snakemake_workdir() {
  export SNAKEMAKE_WORKDIR="${RESULTS_ROOT}/.snakemake_workdir/sub-${SUBJECT}"
  rm -rf "${SNAKEMAKE_WORKDIR}/.snakemake/locks"
  mkdir -p "${SNAKEMAKE_WORKDIR}/.snakemake/locks"
}

preclean_nodestrength() {
  local s="sub-${SUBJECT}"
  rm -f "${RESULTS_ROOT}/node_strength/strength/per_subject/${s}_"*.csv
  rm -rf "${RESULTS_ROOT}/node_strength/reports/${s}"
  rm -f "${RESULTS_ROOT}/node_strength/volume/per_subject/${s}_"*.csv
}

prepare_snakemake_workdir
clear_connectome_outputs_for_rigid_reg "${RESULTS_ROOT}" "${SUBJECT}"
preclean_nodestrength

export RECON_TOOL="${RECON_TOOL:-fastsurfer}"
export RUN_RECON=0
bash "${DWI_ROOT}/workflow/preflight.sh" --mode connectome --subject "${SUBJECT}" --quick || exit 1

EFFECTIVE_MODEL="$(prepare_rigid_reg_tractography \
  "${RESULTS_ROOT}" "${SUBJECT}" "${PIPELINE}" "${REQUESTED_MODEL}" \
  "${SUBJECT_ARGS[@]}")"
SUBJECT_ARGS+=(--tractography-model "${EFFECTIVE_MODEL}")

echo "=== CIDUR G1 rigid-reg rerun task ${SLURM_ARRAY_TASK_ID}: sub-${SUBJECT} ==="
echo "  RESULTS_ROOT=${RESULTS_ROOT}"
echo "  REQUESTED_MODEL=${REQUESTED_MODEL} EFFECTIVE_MODEL=${EFFECTIVE_MODEL}"
echo "  SKIP_RERUN_INCOMPLETE=${SKIP_RERUN_INCOMPLETE:-0}"
[[ -n "${RECON_SESSION:-}" ]] && echo "  RECON_SESSION=${RECON_SESSION}"

echo "Step 4: connectome (rigid FS T1 -> QSIPrep ACPC)"
bash "${PIPELINE}" connectome "${SUBJECT}" "${SUBJECT_ARGS[@]}"
echo "Step 5: nodestrength"
bash "${PIPELINE}" nodestrength "${SUBJECT}" --no-inpaint "${SUBJECT_ARGS[@]}"
echo "=== Done sub-${SUBJECT} ==="
