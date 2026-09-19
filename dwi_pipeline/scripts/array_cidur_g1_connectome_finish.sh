#!/bin/bash
# Slurm array: connectome + nodestrength when tractography already exists.
# Skips sdstream if model-SDSTREAM_streamlines.tck + sift2 weights are present.

#SBATCH --job-name=cidur_conn_fin
#SBATCH --output=logs/cidur_conn_fin_%A_%a.out
#SBATCH --error=logs/cidur_conn_fin_%A_%a.err
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

PIPELINE="${DWI_ROOT}/workflow/run_subject.sh"
SUBJECT_LIST_FILE="${SUBJECT_LIST_FILE:?ERROR: SUBJECT_LIST_FILE not set}"

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

SUBJECT_ARGS=(--fastsurfer --no-inpaint --connectome-sift2 --tractography-model both)
[[ -n "${RECON_SESSION:-}" ]] && SUBJECT_ARGS+=(--recon-session "${RECON_SESSION}")

prepare_snakemake_workdir() {
  export SNAKEMAKE_WORKDIR="${RESULTS_ROOT}/.snakemake_workdir/sub-${SUBJECT}"
  rm -rf "${SNAKEMAKE_WORKDIR}/.snakemake/locks"
  mkdir -p "${SNAKEMAKE_WORKDIR}/.snakemake/locks"
}

preclean_legacy_nodestrength() {
  local s="sub-${SUBJECT}"
  rm -f "${RESULTS_ROOT}/node_strength/strength/per_subject/${s}_"*.csv
  rm -rf "${RESULTS_ROOT}/node_strength/reports/${s}"
  rm -f "${RESULTS_ROOT}/node_strength/volume/per_subject/${s}_"*.csv
}

sdstream_complete() {
  local tract_dir="${RESULTS_ROOT}/tractography/sub-${SUBJECT}"
  [[ -f "${tract_dir}/model-SDSTREAM_streamlines.tck" \
     && -f "${tract_dir}/model-SDSTREAM_sift2weights.csv" ]]
}

prepare_snakemake_workdir
preclean_legacy_nodestrength

export RECON_TOOL="${RECON_TOOL:-fastsurfer}"
export RUN_RECON=0
bash "${DWI_ROOT}/workflow/preflight.sh" --mode connectome --subject "${SUBJECT}" --quick || exit 1

echo "=== CIDUR connectome finish task ${SLURM_ARRAY_TASK_ID}: sub-${SUBJECT} ==="
echo "  RESULTS_ROOT=${RESULTS_ROOT}"
[[ -n "${RECON_SESSION:-}" ]] && echo "  RECON_SESSION=${RECON_SESSION}"

if sdstream_complete; then
  echo "Step 3b: sdstream already complete — skip"
else
  echo "Step 3b: sdstream"
  bash "${PIPELINE}" sdstream "${SUBJECT}" "${SUBJECT_ARGS[@]}"
fi

echo "Step 4: connectome"
bash "${PIPELINE}" connectome "${SUBJECT}" "${SUBJECT_ARGS[@]}"
echo "Step 5: nodestrength"
bash "${PIPELINE}" nodestrength "${SUBJECT}" --no-inpaint
echo "=== Done sub-${SUBJECT} ==="
