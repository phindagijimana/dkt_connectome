#!/bin/bash
# =============================================================================
# submit.sh — Build subject list and submit Slurm array (entry point)
# =============================================================================
#
# What this script does:
#   1. Scans BIDS and writes dwi_pipeline/subjects.txt (DWI participants by default)
#   2. Submits array.sh with --array=1-N%K (default K=5 concurrent jobs)
#   3. Exports env vars so each array task runs subject.sh with the same settings
#
# Pipeline per subject (see subject.sh):
#   QSIPrep -> Recon (recon-all by default, FastSurfer with --fastsurfer)
#          -> QSIRecon (mrtrix_singleshell_ss3t_ACT-hsvs) -> DK connectome
#
# Usage:
#   ./submit.sh                    # full pipeline, recon-all (slow, ~10 h/subject)
#   ./submit.sh --fastsurfer       # full pipeline, FastSurfer (~1-2 h/subject CPU)
#   ./submit.sh --no-recon         # skip Step 2; auto-degrades to ACT-fast + no DK
#   ./submit.sh --no-dk            # full QSIPrep+Recon+QSIRecon, no DK CSV
#   ./submit.sh --syn              # GE / no-fmap subjects: --use-syn-sdc warn
#   ./submit.sh --fmap-retry       # ignore measured fmaps, SyN SDC
#
# Common overrides:
#   ARRAY_CONCURRENCY=5          # Slurm %K throttle
#   PIPELINE_MODE=qsiprep        # only QSIPrep
#   PIPELINE_MODE=recon          # only Step 2 (recon-all / FastSurfer)
#   PIPELINE_MODE=qsirecon       # only QSIRecon (QSIPrep must already exist)
#   PIPELINE_MODE=dk             # only DK (needs QSIRecon + FS outputs)
#   RECON_TOOL=fastsurfer        # same as --fastsurfer
#   RUN_RECON=0                  # same as --no-recon
#   RUN_DK_CONNECTOME=0          # same as --no-dk
#   QSIRECON_SPEC=mrtrix_singleshell_ss3t_ACT-fast  # skip FreeSurfer requirement
#   QSIRECON_ATLASES="Schaefer100"  # parcellations baked in by QSIRecon
#   RESULTS_ROOT=/path/to/output
#   RECON_OUT=/path/freesurfer   # FreeSurfer subjects dir (default RESULTS_ROOT/freesurfer)
#   FS_SUBJECTS_DIR=/path        # point Steps 3+4 at an external FS tree
#   SUBJECT_LIST_ONLY_DWI=0      # include all sub-* folders, not only those with DWI
#   QSIPREP_USE_SYN_SDC=1        # same as --syn
#   EXCLUDE_NODES=smdodwork05    # comma-list passed to sbatch --exclude
#   SBATCH_DEPENDENCY=afterok:JOBID
#                                # chain this submission after another Slurm job
#                                # (e.g. PIPELINE_MODE=qsirecon SBATCH_DEPENDENCY=afterok:44600)
#   SBATCH_PARTITION=interactive # override array.sh's #SBATCH --partition= line
#   SBATCH_TIME=12:00:00         # override array.sh's #SBATCH --time= line
#                                # (must fit the partition's MaxTime; default 12h
#                                # is the interactive partition cap)
#   SBATCH_CPUS=8                # override --cpus-per-task; needs to match
#                                # NTHREADS to keep eddy/recon-all/QSIPrep happy
#   SBATCH_MEM=32G               # override --mem
#   SBATCH_JOB_NAME=dwi_test2    # override --job-name (and the output filenames)
# =============================================================================

set -euo pipefail
set +H

QSIPREP_USE_SYN_SDC="${QSIPREP_USE_SYN_SDC:-0}"
QSIPREP_FMAP_RETRY="${QSIPREP_FMAP_RETRY:-0}"
QSIPREP_BIDS_FILTER="${QSIPREP_BIDS_FILTER:-}"
DWI_SELECT_JSON="${DWI_SELECT_JSON:-}"
RUN_RECON="${RUN_RECON:-1}"
RECON_TOOL="${RECON_TOOL:-freesurfer}"
RUN_DK_CONNECTOME="${RUN_DK_CONNECTOME:-1}"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --syn|--use-syn-sdc)
      QSIPREP_USE_SYN_SDC=1
      ;;
    --fmap-retry)
      QSIPREP_FMAP_RETRY=1
      ;;
    --fastsurfer)
      RECON_TOOL=fastsurfer
      ;;
    --freesurfer)
      RECON_TOOL=freesurfer
      ;;
    --no-recon)
      RUN_RECON=0
      ;;
    --no-dk)
      RUN_DK_CONNECTOME=0
      ;;
    --bids-filter)
      QSIPREP_BIDS_FILTER="$2"
      shift 2
      continue
      ;;
    --dwi-select)
      DWI_SELECT_JSON="$2"
      shift 2
      continue
      ;;
    -h|--help)
      sed -n '14,42p' "$0"
      exit 0
      ;;
    *)
      echo "Unknown option: $1 (try --syn, --fmap-retry, --fastsurfer, --no-recon, --no-dk)"
      exit 1
      ;;
  esac
  shift
done

DWI_ROOT="$(cd "$(dirname "$0")" && pwd)"
TRACKTBI_ROOT="$(cd "${DWI_ROOT}/.." && pwd)"

# --- Defaults (override via environment before ./submit.sh) ---
BIDS_DIR="${BIDS_DIR:-/mnt/nfs/home/urmc-sh.rochester.edu/pndagiji/Documents/CIDUR_BIDS/data_bids}"
RESULTS_ROOT="${RESULTS_ROOT:-/mnt/nfs/home/urmc-sh.rochester.edu/pndagiji/Documents/CIDUR_BIDS/dwi_test}"
SUBJECT_LIST_FILE="${SUBJECT_LIST_FILE:-${DWI_ROOT}/subjects.txt}"
SUBJECT_LIST_ONLY_DWI="${SUBJECT_LIST_ONLY_DWI:-1}"
ARRAY_SCRIPT="${DWI_ROOT}/array.sh"
ARRAY_CONCURRENCY="${ARRAY_CONCURRENCY:-5}"
NTHREADS="${NTHREADS:-8}"
OMP_NTHREADS="${OMP_NTHREADS:-8}"
PIPELINE_MODE="${PIPELINE_MODE:-all}"
QSIRECON_SPEC="${QSIRECON_SPEC:-mrtrix_singleshell_ss3t_ACT-hsvs}"
# QSIRecon MRtrix specs require at least one atlas for connectivity estimation.
# 4S156Parcels = Schaefer-100 cortex + Tian/HCP 56 subcortex (modern default).
# See subject.sh for the full list of recognised built-in atlas names.
QSIRECON_ATLASES="${QSIRECON_ATLASES-4S156Parcels}"
RECON_OUT="${RECON_OUT:-${RESULTS_ROOT}/freesurfer}"
FS_SUBJECTS_DIR="${FS_SUBJECTS_DIR:-${RECON_OUT}}"
# Workaround: smdodwork05 fails the Slurm prolog ("mkdir /var/spool/slurmd/logs:
# Permission denied"). Excluded by default; override with EXCLUDE_NODES="" or a
# different comma-list when the node is healthy again.
EXCLUDE_NODES="${EXCLUDE_NODES:-smdodwork05}"

[[ -d "${BIDS_DIR}" ]] || { echo "BIDS directory missing: ${BIDS_DIR}"; exit 1; }
[[ -f "${ARRAY_SCRIPT}" ]] || { echo "Missing array script: ${ARRAY_SCRIPT}"; exit 1; }
if [[ -n "${QSIPREP_BIDS_FILTER}" && -n "${DWI_SELECT_JSON}" ]]; then
  echo "ERROR: use only one of --bids-filter or --dwi-select"; exit 1
fi

mkdir -p "${TRACKTBI_ROOT}/logs" "${RESULTS_ROOT}"

# --- Build subjects.txt (skip if SUBJECT_LIST_USE_EXISTING=1 and file already has entries) ---
if [[ "${SUBJECT_LIST_USE_EXISTING:-0}" == "1" && -s "${SUBJECT_LIST_FILE}" ]]; then
  echo "Using existing subject list: ${SUBJECT_LIST_FILE}"
elif [[ "${SUBJECT_LIST_ONLY_DWI}" == "1" ]]; then
  # Only participants with at least one DWI NIfTI (matches main cohort QC list idea)
  tmp="${SUBJECT_LIST_FILE}.$$"
  : > "${tmp}"
  shopt -s nullglob
  for d in "${BIDS_DIR}"/sub-*; do
    [[ -d "$d" ]] || continue
    id="${d##*/}"
    id="${id#sub-}"
    if find "$d" -type f \( -name '*.nii.gz' -o -name '*.nii' \) -path '*/dwi/*' -print -quit 2>/dev/null | grep -q .; then
      echo "${id}" >> "${tmp}"
    fi
  done
  shopt -u nullglob
  sort -u "${tmp}" > "${SUBJECT_LIST_FILE}"
  rm -f "${tmp}"
else
  # Every top-level sub-* folder
  find "${BIDS_DIR}" -maxdepth 1 -mindepth 1 -type d -name "sub-*" -printf "%f\n" 2>/dev/null | sed 's/^sub-//' | sort -u > "${SUBJECT_LIST_FILE}"
fi

N=$(wc -l < "${SUBJECT_LIST_FILE}")
[[ "${N}" -ge 1 ]] || { echo "Subject list is empty: ${SUBJECT_LIST_FILE}"; exit 1; }

# Align FreeSurfer paths with this run when stale shell exports leak across submissions.
RECON_OUT="${RECON_OUT:-${RESULTS_ROOT}/freesurfer}"
_first_sub="$(head -1 "${SUBJECT_LIST_FILE}")"
if [[ -n "${RECON_OUT:-}" && "${RECON_OUT}" != "${RESULTS_ROOT}/freesurfer" && ! -d "${RECON_OUT}/sub-${_first_sub}" ]]; then
  echo "NOTE: RECON_OUT (${RECON_OUT}) missing sub-${_first_sub}; using ${RESULTS_ROOT}/freesurfer"
  RECON_OUT="${RESULTS_ROOT}/freesurfer"
fi
if [[ -n "${FS_SUBJECTS_DIR:-}" && "${FS_SUBJECTS_DIR}" != "${RECON_OUT}" && -d "${FS_SUBJECTS_DIR}" && ! -d "${FS_SUBJECTS_DIR}/sub-${_first_sub}" ]]; then
  echo "NOTE: FS_SUBJECTS_DIR (${FS_SUBJECTS_DIR}) missing sub-${_first_sub}; using ${RECON_OUT}"
  FS_SUBJECTS_DIR="${RECON_OUT}"
else
  FS_SUBJECTS_DIR="${FS_SUBJECTS_DIR:-${RECON_OUT}}"
fi

echo "dwi_pipeline submit"
echo "  Subjects: ${N} from ${SUBJECT_LIST_FILE}"
echo "  Array: 1-${N}%${ARRAY_CONCURRENCY}"
echo "  Mode: ${PIPELINE_MODE}"
echo "  RESULTS_ROOT: ${RESULTS_ROOT}"
echo "  QSIRECON_SPEC: ${QSIRECON_SPEC}"
if [[ -n "${QSIRECON_ATLASES}" ]]; then
  echo "  QSIRECON_ATLASES: ${QSIRECON_ATLASES}"
fi
echo "  QSIPREP SDC: fmap when in BIDS; SyN=$([[ ${QSIPREP_USE_SYN_SDC} == 1 ]] && echo on || echo off) if no fmap"
[[ "${QSIPREP_FMAP_RETRY}" == "1" ]] && echo "  QSIPREP_FMAP_RETRY=1 (--ignore fieldmaps --use-syn-sdc warn)"
[[ -n "${DWI_SELECT_JSON}" ]] && echo "  DWI_SELECT_JSON: ${DWI_SELECT_JSON}"
[[ -n "${QSIPREP_BIDS_FILTER}" ]] && echo "  QSIPREP_BIDS_FILTER: ${QSIPREP_BIDS_FILTER}"
if [[ "${PIPELINE_MODE}" == "all" || "${PIPELINE_MODE}" == "recon" ]]; then
  echo "  Recon (Step 2): $([[ ${RUN_RECON} == 1 ]] && echo on || echo off)  tool=${RECON_TOOL}  out=${RECON_OUT}"
fi
echo "  FS_SUBJECTS_DIR: ${FS_SUBJECTS_DIR}"
echo "  DK connectome: $([[ ${RUN_DK_CONNECTOME} == 1 && ( ${PIPELINE_MODE} == all || ${PIPELINE_MODE} == dk ) ]] && echo on || echo off/skip)"
[[ -n "${EXCLUDE_NODES}" ]] && echo "  Exclude nodes: ${EXCLUDE_NODES}"

# Passed through to array.sh -> subject.sh (sbatch --export=ALL)
# DWI_ROOT/TRACKTBI_ROOT are critical: inside sbatch $0 points to Slurm's spool
# copy of the script, so array.sh cannot derive them on the compute node.
export DWI_ROOT TRACKTBI_ROOT
export BIDS_DIR RESULTS_ROOT SUBJECT_LIST_FILE PIPELINE_MODE NTHREADS OMP_NTHREADS QSIRECON_SPEC QSIRECON_ATLASES
export QSIPREP_USE_SYN_SDC QSIPREP_FMAP_RETRY QSIPREP_BIDS_FILTER DWI_SELECT_JSON
export RUN_RECON RECON_TOOL RECON_OUT RUN_DK_CONNECTOME FS_SUBJECTS_DIR

SBATCH_EXTRA=()
[[ -n "${EXCLUDE_NODES}" ]] && SBATCH_EXTRA+=(--exclude="${EXCLUDE_NODES}")
# Optional job-chaining hook used when stages are submitted as separate arrays
# (recon -> qsirecon -> dk), so downstream stages only fire after upstream OK.
[[ -n "${SBATCH_DEPENDENCY:-}" ]] && SBATCH_EXTRA+=(--dependency="${SBATCH_DEPENDENCY}")
# Optional one-shot overrides of the #SBATCH directives baked into array.sh.
# Useful for picking a different partition (must allow the requested time),
# bumping per-task CPUs/mem for a fresh recon-all subject, or routing output
# files to a per-experiment log name.
[[ -n "${SBATCH_PARTITION:-}" ]] && SBATCH_EXTRA+=(--partition="${SBATCH_PARTITION}")
[[ -n "${SBATCH_TIME:-}"      ]] && SBATCH_EXTRA+=(--time="${SBATCH_TIME}")
[[ -n "${SBATCH_CPUS:-}"      ]] && SBATCH_EXTRA+=(--cpus-per-task="${SBATCH_CPUS}")
[[ -n "${SBATCH_MEM:-}"       ]] && SBATCH_EXTRA+=(--mem="${SBATCH_MEM}")
if [[ -n "${SBATCH_JOB_NAME:-}" ]]; then
  SBATCH_EXTRA+=(--job-name="${SBATCH_JOB_NAME}"
                 --output="${TRACKTBI_ROOT}/logs/${SBATCH_JOB_NAME}_%A_%a.out"
                 --error="${TRACKTBI_ROOT}/logs/${SBATCH_JOB_NAME}_%A_%a.err")
fi
exec sbatch --array="1-${N}%${ARRAY_CONCURRENCY}" --export=ALL "${SBATCH_EXTRA[@]}" "${ARRAY_SCRIPT}"
