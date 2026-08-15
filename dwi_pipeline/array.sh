#!/bin/bash
# =============================================================================
# array.sh — Slurm job array: one array task = one subject
# =============================================================================
#
# Do not run this directly unless testing. Normally launched by submit.sh via:
#   sbatch --array=1-N%5 array.sh
#
# For each SLURM_ARRAY_TASK_ID:
#   1. Read subject ID from line N of subjects.txt (or SUBJECT_LIST_FILE)
#   2. Call the pipeline engine (subject.sh or workflow/run_subject.sh)
#
# %5 in the array (set by submit.sh) limits concurrent subjects to 5.
# =============================================================================

# --- Slurm resource requests (override array range via sbatch --array=...) ---
#SBATCH --job-name=dwi_act_arr
#SBATCH --output=logs/dwi_act_%A_%a.out
#SBATCH --error=logs/dwi_act_%A_%a.err
#SBATCH --time=12:00:00
#SBATCH --partition=interactive
#SBATCH --cpus-per-task=4
#SBATCH --mem=24G
#SBATCH --mail-type=END,FAIL
# Set mail in submit.sh via: SBATCH --mail-user=you@example.edu (optional)
#SBATCH --array=1-76%5

set -euo pipefail
set +H

# Inside sbatch $0 points to Slurm's spool copy (/var/spool/slurmd/job<id>/slurm_script),
# so deriving paths from $0 would write into /var/spool/slurmd (Permission denied).
# Paths must be exported by submit.sh (Slurm spool copy of $0 cannot derive repo paths).
: "${DWI_ROOT:?ERROR [array]: DWI_ROOT not set — run via submit.sh or export DWI_ROOT}"
: "${REPO_ROOT:?ERROR [array]: REPO_ROOT not set — run via submit.sh or export REPO_ROOT}"
[[ -d "${DWI_ROOT}" ]] || { echo "ERROR [array]: DWI_ROOT is not a directory: ${DWI_ROOT}"; exit 1; }

PIPELINE_ENGINE="${PIPELINE_ENGINE:-snakemake}"
case "${PIPELINE_ENGINE}" in
  bash|subject|subject.sh)
    PIPELINE="${PIPELINE:-${DWI_ROOT}/subject.sh}"
    ;;
  snakemake|workflow|run_subject)
    PIPELINE="${PIPELINE:-${DWI_ROOT}/workflow/run_subject.sh}"
    export XDG_CACHE_HOME="${XDG_CACHE_HOME:-${REPO_ROOT}/.cache}"
    mkdir -p "${XDG_CACHE_HOME}"
    ;;
  *)
    echo "ERROR [array]: invalid PIPELINE_ENGINE=${PIPELINE_ENGINE} (use bash or snakemake)"
    exit 1
    ;;
esac

SUBJECT_LIST_FILE="${SUBJECT_LIST_FILE:-${DWI_ROOT}/subjects.txt}"

# Threading inside each container (should match --cpus-per-task)
export NTHREADS="${NTHREADS:-4}"
export OMP_NTHREADS="${OMP_NTHREADS:-4}"

mkdir -p "${REPO_ROOT}/logs"

[[ -f "${PIPELINE}" ]] || { echo "Missing ${PIPELINE}"; exit 1; }
[[ -f "${SUBJECT_LIST_FILE}" ]] || { echo "Missing subject list: ${SUBJECT_LIST_FILE}"; exit 1; }
[[ -n "${SLURM_ARRAY_TASK_ID:-}" ]] || { echo "Need SLURM_ARRAY_TASK_ID"; exit 1; }

# Map array index -> subject ID (one line per subject, no "sub-" prefix in file)
SUBJECT="$(sed -n "${SLURM_ARRAY_TASK_ID}p" "${SUBJECT_LIST_FILE}" | tr -d '\r')"
SUBJECT="${SUBJECT#"${SUBJECT%%[![:space:]]*}"}"
SUBJECT="${SUBJECT%"${SUBJECT##*[![:space:]]}"}"
[[ -n "${SUBJECT}" ]] || { echo "Task ${SLURM_ARRAY_TASK_ID}: empty line"; exit 0; }
[[ "${SUBJECT}" != \#* ]] || { echo "Task ${SLURM_ARRAY_TASK_ID}: comment line"; exit 0; }
SUBJECT="${SUBJECT#sub-}"

PIPELINE_MODE="${PIPELINE_MODE:-all}"
# Step 4 was called "dk" before it served both DK and DKT; subject.sh still
# accepts the old name, so pass it through rather than rejecting it here.
case "${PIPELINE_MODE}" in
  all|qsiprep|inpaint|recon|qsirecon|connectome|nodestrength|dk) ;;
  *) echo "Invalid PIPELINE_MODE=${PIPELINE_MODE} (use all|qsiprep|inpaint|recon|qsirecon|connectome|nodestrength)"; exit 1 ;;
esac

# Optional flags forwarded to the pipeline CLI (set by submit.sh or export before sbatch)
SUBJECT_ARGS=()
[[ "${QSIPREP_USE_SYN_SDC:-0}" == "1" ]] && SUBJECT_ARGS+=(--syn)
[[ "${QSIPREP_FMAP_RETRY:-0}" == "1" ]] && SUBJECT_ARGS+=(--fmap-retry)
[[ "${QSIPREP_NO_SDC:-0}"      == "1" ]] && SUBJECT_ARGS+=(--no-sdc)
[[ -n "${QSIPREP_BIDS_FILTER:-}" ]] && SUBJECT_ARGS+=(--bids-filter "${QSIPREP_BIDS_FILTER}")
if [[ "${RECON_TOOL:-freesurfer}" == "fastsurfer" ]]; then
  if [[ "${RECON_FSAPARC:-0}" == "1" ]]; then
    SUBJECT_ARGS+=(--fast-fs)
  else
    SUBJECT_ARGS+=(--fastsurfer)
  fi
fi
[[ "${RUN_RECON:-1}" == "0" ]] && SUBJECT_ARGS+=(--no-recon)
[[ "${RUN_CONNECTOME:-${RUN_DK_CONNECTOME:-1}}" == "0" && "${PIPELINE_MODE}" == "all" ]] && \
  SUBJECT_ARGS+=(--no-connectome)
[[ "${RUN_INPAINT:-1}" == "0" ]] && SUBJECT_ARGS+=(--no-inpaint)
[[ "${RUN_NODESTRENGTH:-1}" == "0" ]] && SUBJECT_ARGS+=(--no-node-strength)
[[ "${NODESTRENGTH_STRENGTH_ONLY:-0}" == "1" ]] && SUBJECT_ARGS+=(--strength-only)
[[ "${NODESTRENGTH_NO_REPORT:-0}" == "1" ]] && SUBJECT_ARGS+=(--no-report)
[[ "${QSIPREP_NO_DWI_FILTER:-0}" == "1" ]] && SUBJECT_ARGS+=(--no-dwi-filter)
[[ -n "${DWI_SELECT_JSON:-}" ]] && SUBJECT_ARGS+=(--dwi-select "${DWI_SELECT_JSON}")
[[ -z "${DWI_SELECT_JSON:-}" && -n "${DWI_SHELL_B:-}" && "${DWI_SHELL_B}" != "1000" ]] && \
  SUBJECT_ARGS+=(--dwi-shell "${DWI_SHELL_B}")
[[ -n "${RECON_SESSION:-}" ]] && SUBJECT_ARGS+=(--recon-session "${RECON_SESSION}")

if [[ "${PIPELINE_ENGINE}" != "bash" && "${PIPELINE_ENGINE}" != "subject" && "${PIPELINE_ENGINE}" != "subject.sh" ]]; then
  preflight_args=(bash "${DWI_ROOT}/workflow/preflight.sh" --mode "${PIPELINE_MODE}" --subject "${SUBJECT}" --quick)
  ((BIDS_VALIDATE)) && preflight_args+=(--bids-validation)
  ((BIDS_IGNORE_WARNINGS)) && preflight_args+=(--ignore-warnings)
  "${preflight_args[@]}" || exit 1
fi

echo "ACT array task ${SLURM_ARRAY_TASK_ID}: sub-${SUBJECT} mode=${PIPELINE_MODE} engine=${PIPELINE_ENGINE} \
recon=${RECON_TOOL:-freesurfer} run_recon=${RUN_RECON:-1} run_inpaint=${RUN_INPAINT:-1} \
run_nodestrength=${RUN_NODESTRENGTH:-1} \
NTHREADS=${NTHREADS} syn=${QSIPREP_USE_SYN_SDC:-0} dwi_shell=${DWI_SHELL_B:-1000}"
exec bash "${PIPELINE}" "${PIPELINE_MODE}" "${SUBJECT}" "${SUBJECT_ARGS[@]}"
