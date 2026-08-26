#!/bin/bash
# Slurm array: rerun CIDUR subjects 001, 002, 009, 076 (excluded from main backfill).
#
#   001, 002 — Step 4+5 on flat RESULTS_ROOT (connectome + nodestrength)
#   009      — Step 4+5 per session (ses-1, ses-2) under session_aware/
#   076      — full pipeline (QSIPrep → recon → QSIRecon → connectome → nodestrength)
#
# Launched by scripts/submit_cidur_rerun4.sh — do not run directly.

#SBATCH --job-name=cidur_rerun4
#SBATCH --output=logs/cidur_rerun4_%A_%a.out
#SBATCH --error=logs/cidur_rerun4_%A_%a.err
#SBATCH --time=12:00:00
#SBATCH --partition=interactive
#SBATCH --cpus-per-task=8
#SBATCH --mem=48G
#SBATCH --mail-type=END,FAIL

set -euo pipefail
set +H

: "${DWI_ROOT:?ERROR [array_cidur_rerun4]: DWI_ROOT not set}"
: "${REPO_ROOT:?ERROR [array_cidur_rerun4]: REPO_ROOT not set}"
: "${BIDS_DIR:?ERROR [array_cidur_rerun4]: BIDS_DIR not set}"
source "${DWI_ROOT}/workflow/lib/slurm_env.sh"

PIPELINE="${DWI_ROOT}/workflow/run_subject.sh"
BIDS_APP="${DWI_ROOT}/bids_app.sh"
SUBJECT_LIST_FILE="${SUBJECT_LIST_FILE:?ERROR: SUBJECT_LIST_FILE not set}"
RESULTS_ROOT="${RESULTS_ROOT:?ERROR: RESULTS_ROOT not set}"
SESSION_AWARE_ROOT="${SESSION_AWARE_ROOT:-${RESULTS_ROOT}/session_aware}"
DWI_SELECT_50DIRAX="${DWI_ROOT}/config/dwi_select_50dirax_no_fmap.json"

export NTHREADS="${NTHREADS:-8}"
export OMP_NTHREADS="${OMP_NTHREADS:-8}"
export XDG_CACHE_HOME="${XDG_CACHE_HOME:-${REPO_ROOT}/.cache}"
mkdir -p "${REPO_ROOT}/logs" "${XDG_CACHE_HOME}"

[[ -f "${PIPELINE}" ]] || { echo "Missing ${PIPELINE}"; exit 1; }
[[ -f "${BIDS_APP}" ]] || { echo "Missing ${BIDS_APP}"; exit 1; }
[[ -f "${SUBJECT_LIST_FILE}" ]] || { echo "Missing subject list: ${SUBJECT_LIST_FILE}"; exit 1; }
[[ -n "${SLURM_ARRAY_TASK_ID:-}" ]] || { echo "Need SLURM_ARRAY_TASK_ID"; exit 1; }

SUBJECT="$(sed -n "${SLURM_ARRAY_TASK_ID}p" "${SUBJECT_LIST_FILE}" | tr -d '\r')"
SUBJECT="${SUBJECT#"${SUBJECT%%[![:space:]]*}"}"
SUBJECT="${SUBJECT%"${SUBJECT##*[![:space:]]}"}"
[[ -n "${SUBJECT}" ]] || { echo "Task ${SLURM_ARRAY_TASK_ID}: empty line"; exit 0; }
[[ "${SUBJECT}" != \#* ]] || { echo "Task ${SLURM_ARRAY_TASK_ID}: comment line"; exit 0; }
SUBJECT="${SUBJECT#sub-}"

CONN_ARGS=(--fastsurfer --no-inpaint --connectome-sift2 --tractography-model both)

prepare_snakemake_workdir() {
  local subj="$1"
  export SNAKEMAKE_WORKDIR="${RESULTS_ROOT}/.snakemake_workdir/sub-${subj}"
  rm -rf "${SNAKEMAKE_WORKDIR}/.snakemake/locks"
  mkdir -p "${SNAKEMAKE_WORKDIR}/.snakemake/locks"
}

preclean_stale_sdstream() {
  local subj="$1"
  local tract_dir="${RESULTS_ROOT}/tractography/sub-${subj}"
  local tck="${tract_dir}/model-SDSTREAM_streamlines.tck"
  local weights="${tract_dir}/model-SDSTREAM_sift2weights.csv"
  if [[ -f "${tck}" && ! -f "${weights}" ]]; then
    echo "Removing incomplete SDSTREAM tractography: ${tck}"
    rm -f "${tck}"
  fi
}

preclean_legacy_nodestrength() {
  local subj="$1"
  local s="sub-${subj}"
  rm -f "${RESULTS_ROOT}/node_strength/strength/per_subject/${s}_"*.csv
  rm -rf "${RESULTS_ROOT}/node_strength/reports/${s}"
  rm -f "${RESULTS_ROOT}/node_strength/volume/per_subject/${s}_"*.csv
}

preclean_session_nodestrength() {
  local subj="$1" ses="$2"
  local unit="${SESSION_AWARE_ROOT}/sub-${subj}/ses-${ses}"
  local s="sub-${subj}"
  rm -f "${unit}/node_strength/strength/per_subject/${s}_"*.csv
  rm -rf "${unit}/node_strength/reports/${s}"
}

backfill_qsiprep_marker() {
  local subj="$1"
  local marker="${RESULTS_ROOT}/.snakemake_markers/sub-${subj}/qsiprep.done"
  if [[ -f "${marker}" ]]; then
    return 0
  fi
  if [[ ! -f "${RESULTS_ROOT}/.snakemake_markers/sub-${subj}/qsirecon.done" ]]; then
    return 0
  fi
  if [[ -d "${RESULTS_ROOT}/qsiprep_single_run_output/sub-${subj}" ]] \
     || [[ -d "${RESULTS_ROOT}/qsiprep/sub-${subj}" ]]; then
    mkdir -p "$(dirname "${marker}")"
    touch "${marker}"
    echo "Backfilled qsiprep.done marker for sub-${subj} (QSIRecon outputs present)"
  fi
}

run_connectome_nodestrength() {
  local subj="$1"
  echo "=== CIDUR rerun4 task ${SLURM_ARRAY_TASK_ID}: sub-${subj} (connectome + nodestrength) ==="
  prepare_snakemake_workdir "${subj}"
  backfill_qsiprep_marker "${subj}"
  preclean_stale_sdstream "${subj}"
  preclean_legacy_nodestrength "${subj}"
  preflight_args=(bash "${DWI_ROOT}/workflow/preflight.sh" --mode connectome --subject "${subj}" --quick)
  "${preflight_args[@]}" || exit 1
  echo "Step 4a: sdstream tractography"
  bash "${PIPELINE}" sdstream "${subj}" "${CONN_ARGS[@]}"
  echo "Step 4b: connectome"
  bash "${PIPELINE}" connectome "${subj}" "${CONN_ARGS[@]}"
  echo "Step 5: nodestrength"
  bash "${PIPELINE}" nodestrength "${subj}" --no-inpaint
  echo "=== Done sub-${subj} ==="
}

run_session_unit() {
  local subj="$1" ses="$2" mode="$3"
  shift 3
  local -a extra=("$@")
  local unit_root="${SESSION_AWARE_ROOT}/sub-${subj}/ses-${ses}"
  RECON_OUT="${unit_root}/freesurfer" \
  FS_SUBJECTS_DIR="${unit_root}/freesurfer" \
    bash "${BIDS_APP}" "${BIDS_DIR}" "${SESSION_AWARE_ROOT}" participant \
      --participant-label "${subj}" --session-label "${ses}" \
      --pipeline-mode "${mode}" -- "${extra[@]}"
}

case "${SUBJECT}" in
  001|002)
    run_connectome_nodestrength "${SUBJECT}"
    ;;
  009)
    echo "=== CIDUR rerun4 task ${SLURM_ARRAY_TASK_ID}: sub-009 ses-1,2 (connectome + nodestrength) ==="
    for SES in 1 2; do
      echo "--- sub-009 ses-${SES} ---"
      preclean_session_nodestrength 009 "${SES}"
      unit="${SESSION_AWARE_ROOT}/sub-009/ses-${SES}"
      tck="${unit}/tractography/sub-009/model-SDSTREAM_streamlines.tck"
      weights="${unit}/tractography/sub-009/model-SDSTREAM_sift2weights.csv"
      if [[ -f "${tck}" && ! -f "${weights}" ]]; then
        echo "Removing incomplete SDSTREAM: ${tck}"
        rm -f "${tck}"
      fi
      echo "Step 4a: sdstream ses-${SES}"
      run_session_unit 009 "${SES}" sdstream "${CONN_ARGS[@]}"
      echo "Step 4b: connectome ses-${SES}"
      run_session_unit 009 "${SES}" connectome "${CONN_ARGS[@]}"
      echo "Step 5: nodestrength ses-${SES}"
      run_session_unit 009 "${SES}" nodestrength --no-inpaint
    done
    echo "=== Done sub-009 (ses-1, ses-2) ==="
    ;;
  076)
    echo "=== CIDUR rerun4 task ${SLURM_ARRAY_TASK_ID}: sub-076 (staged full pipeline, no SDC) ==="
    [[ -f "${DWI_SELECT_50DIRAX}" ]] || { echo "Missing ${DWI_SELECT_50DIRAX}"; exit 1; }
    prepare_snakemake_workdir 076
    stale_recon="${RESULTS_ROOT}/freesurfer/sub-076"
    if [[ -d "${stale_recon}" && ! -f "${stale_recon}/mri/aparc+aseg.mgz" ]]; then
      echo "Removing stale partial recon (no aparc+aseg.mgz): ${stale_recon}"
      rm -rf "${stale_recon}"
    fi
    QSIPREP_ARGS=(--fastsurfer --no-inpaint --no-sdc --session-filter 1 --dwi-select "${DWI_SELECT_50DIRAX}")
    echo "Step: qsiprep"
    RUN_RECON=1 bash "${PIPELINE}" qsiprep 076 "${QSIPREP_ARGS[@]}"
    echo "Step: recon"
    RUN_RECON=1 bash "${PIPELINE}" recon 076 --fastsurfer --no-inpaint --session-filter 1
    echo "Step: qsirecon"
    RUN_RECON=1 bash "${PIPELINE}" qsirecon 076 --fastsurfer --no-inpaint --session-filter 1
    echo "Step: connectome"
    bash "${PIPELINE}" connectome 076 "${CONN_ARGS[@]}"
    echo "Step: nodestrength"
    bash "${PIPELINE}" nodestrength 076 --no-inpaint
    echo "=== Done sub-076 ==="
    ;;
  *)
    echo "Unknown subject in rerun4 list: ${SUBJECT}" >&2
    exit 1
    ;;
esac
