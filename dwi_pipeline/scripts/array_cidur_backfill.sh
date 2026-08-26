#!/bin/bash
# Slurm array task: Step 4 (connectome + SIFT2 + SD_STREAM) then Step 5 (nodestrength).
# Launched by scripts/submit_cidur_backfill.sh — do not run directly.

#SBATCH --job-name=cidur_conn_ns
#SBATCH --output=logs/cidur_conn_ns_%A_%a.out
#SBATCH --error=logs/cidur_conn_ns_%A_%a.err
#SBATCH --time=12:00:00
#SBATCH --partition=interactive
#SBATCH --cpus-per-task=8
#SBATCH --mem=32G
#SBATCH --mail-type=END,FAIL

set -euo pipefail
set +H

: "${DWI_ROOT:?ERROR [array_cidur_backfill]: DWI_ROOT not set}"
: "${REPO_ROOT:?ERROR [array_cidur_backfill]: REPO_ROOT not set}"
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

prepare_snakemake_workdir() {
  export SNAKEMAKE_WORKDIR="${RESULTS_ROOT}/.snakemake_workdir/sub-${SUBJECT}"
  rm -rf "${SNAKEMAKE_WORKDIR}/.snakemake/locks"
  mkdir -p "${SNAKEMAKE_WORKDIR}/.snakemake/locks"
}

preclean_stale_sdstream() {
  local tract_dir="${RESULTS_ROOT}/tractography/sub-${SUBJECT}"
  local tck="${tract_dir}/model-SDSTREAM_streamlines.tck"
  local weights="${tract_dir}/model-SDSTREAM_sift2weights.csv"
  if [[ -f "${tck}" && ! -f "${weights}" ]]; then
    echo "Removing incomplete SDSTREAM tractography: ${tck}"
    rm -f "${tck}"
  fi
}

preclean_legacy_nodestrength() {
  local s="sub-${SUBJECT}"
  rm -f "${RESULTS_ROOT}/node_strength/strength/per_subject/${s}_"*.csv
  rm -rf "${RESULTS_ROOT}/node_strength/reports/${s}"
  rm -f "${RESULTS_ROOT}/node_strength/volume/per_subject/${s}_"*.csv
}

prepare_snakemake_workdir
preclean_stale_sdstream
preclean_legacy_nodestrength

preflight_args=(bash "${DWI_ROOT}/workflow/preflight.sh" --mode connectome --subject "${SUBJECT}" --quick)
export RECON_TOOL="${RECON_TOOL:-fastsurfer}"
"${preflight_args[@]}" || exit 1

echo "=== CIDUR backfill task ${SLURM_ARRAY_TASK_ID}: sub-${SUBJECT} ==="
echo "Step 4: connectome"
bash "${PIPELINE}" connectome "${SUBJECT}" "${SUBJECT_ARGS[@]}"
echo "Step 5: nodestrength"
bash "${PIPELINE}" nodestrength "${SUBJECT}" --no-inpaint
echo "=== Done sub-${SUBJECT} ==="
