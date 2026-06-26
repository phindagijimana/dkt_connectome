#!/bin/bash
# =============================================================================
# submit.sh — Submit Slurm array for dwi_connect_default
# =============================================================================
#
# Default pipeline per subject:
#   QSIPrep -> FreeSurfer (recon-all) -> QSIRecon (ACT-HSVS + 4S156 atlas connectome)
#
# Connectome output comes from QSIRecon (--atlases 4S156Parcels), not the post-hoc
# Desikan–Killiany step. For DK connectomes use dwi_pipeline/ instead.
#
# Usage:
#   ./submit.sh
#   ./submit.sh --fastsurfer
#   ./submit.sh --syn
#   PIPELINE_MODE=qsirecon ./submit.sh   # QSIRecon only (Steps 1–2 must exist)
#
# Overrides:
#   RESULTS_ROOT=/path/to/output
#   BIDS_DIR=/path/to/bids
#   QSIRECON_ATLASES="4S156Parcels AAL116"
#   SUBJECT_LIST_FILE=.../subjects.txt
#   ARRAY_CONCURRENCY=5
# =============================================================================

set -euo pipefail
set +H

QSIPREP_USE_SYN_SDC="${QSIPREP_USE_SYN_SDC:-0}"
QSIPREP_FMAP_RETRY="${QSIPREP_FMAP_RETRY:-0}"
QSIPREP_BIDS_FILTER="${QSIPREP_BIDS_FILTER:-}"
DWI_SELECT_JSON="${DWI_SELECT_JSON:-}"
RUN_RECON="${RUN_RECON:-1}"
RECON_TOOL="${RECON_TOOL:-freesurfer}"
RUN_DK_CONNECTOME="${RUN_DK_CONNECTOME:-0}"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --syn|--use-syn-sdc) QSIPREP_USE_SYN_SDC=1 ;;
    --fmap-retry) QSIPREP_FMAP_RETRY=1 ;;
    --fastsurfer) RECON_TOOL=fastsurfer ;;
    --freesurfer) RECON_TOOL=freesurfer ;;
    --no-recon) RUN_RECON=0 ;;
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
      sed -n '12,24p' "$0"
      exit 0
      ;;
    *)
      echo "Unknown option: $1 (try --syn, --fmap-retry, --fastsurfer, --no-recon)"
      exit 1
      ;;
  esac
  shift
done

CONNECT_ROOT="$(cd "$(dirname "$0")" && pwd)"
TRACKTBI_ROOT="$(cd "${CONNECT_ROOT}/.." && pwd)"

BIDS_DIR="${BIDS_DIR:-/mnt/nfs/home/urmc-sh.rochester.edu/pndagiji/Documents/CIDUR_BIDS/data_bids}"
RESULTS_ROOT="${RESULTS_ROOT:-/mnt/nfs/home/urmc-sh.rochester.edu/pndagiji/Documents/CIDUR_BIDS/dwi_test_default}"
SUBJECT_LIST_FILE="${SUBJECT_LIST_FILE:-${CONNECT_ROOT}/subjects.txt}"
SUBJECT_LIST_ONLY_DWI="${SUBJECT_LIST_ONLY_DWI:-1}"
ARRAY_SCRIPT="${CONNECT_ROOT}/array.sh"
ARRAY_CONCURRENCY="${ARRAY_CONCURRENCY:-5}"
NTHREADS="${NTHREADS:-8}"
OMP_NTHREADS="${OMP_NTHREADS:-8}"
PIPELINE_MODE="${PIPELINE_MODE:-all}"
QSIRECON_SPEC="${QSIRECON_SPEC:-mrtrix_singleshell_ss3t_ACT-hsvs}"
QSIRECON_ATLASES="${QSIRECON_ATLASES:-4S156Parcels}"
RECON_OUT="${RECON_OUT:-${RESULTS_ROOT}/freesurfer}"
FS_SUBJECTS_DIR="${FS_SUBJECTS_DIR:-${RECON_OUT}}"
EXCLUDE_NODES="${EXCLUDE_NODES:-smdodwork05}"

if [[ "${PIPELINE_MODE}" == "dk" ]]; then
  echo "ERROR: PIPELINE_MODE=dk is not supported in dwi_connect_default (use dwi_pipeline/)"
  exit 1
fi

[[ -d "${BIDS_DIR}" ]] || { echo "BIDS directory missing: ${BIDS_DIR}"; exit 1; }
[[ -f "${ARRAY_SCRIPT}" ]] || { echo "Missing array script: ${ARRAY_SCRIPT}"; exit 1; }
if [[ -n "${QSIPREP_BIDS_FILTER}" && -n "${DWI_SELECT_JSON}" ]]; then
  echo "ERROR: use only one of --bids-filter or --dwi-select"
  exit 1
fi

mkdir -p "${TRACKTBI_ROOT}/logs" "${RESULTS_ROOT}"

if [[ "${SUBJECT_LIST_USE_EXISTING:-0}" == "1" && -s "${SUBJECT_LIST_FILE}" ]]; then
  echo "Using existing subject list: ${SUBJECT_LIST_FILE}"
elif [[ "${SUBJECT_LIST_ONLY_DWI}" == "1" ]]; then
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
  find "${BIDS_DIR}" -maxdepth 1 -mindepth 1 -type d -name "sub-*" -printf "%f\n" 2>/dev/null | sed 's/^sub-//' | sort -u > "${SUBJECT_LIST_FILE}"
fi

N=$(wc -l < "${SUBJECT_LIST_FILE}")
[[ "${N}" -ge 1 ]] || { echo "Subject list is empty: ${SUBJECT_LIST_FILE}"; exit 1; }

RECON_OUT="${RECON_OUT:-${RESULTS_ROOT}/freesurfer}"
_first_sub="$(head -1 "${SUBJECT_LIST_FILE}")"
if [[ -n "${RECON_OUT:-}" && "${RECON_OUT}" != "${RESULTS_ROOT}/freesurfer" && ! -d "${RECON_OUT}/sub-${_first_sub}" ]]; then
  echo "NOTE: RECON_OUT (${RECON_OUT}) missing sub-${_first_sub}; using ${RESULTS_ROOT}/freesurfer"
  RECON_OUT="${RESULTS_ROOT}/freesurfer"
fi
FS_SUBJECTS_DIR="${FS_SUBJECTS_DIR:-${RECON_OUT}}"

echo "dwi_connect_default submit"
echo "  Subjects: ${N} from ${SUBJECT_LIST_FILE}"
echo "  Array: 1-${N}%${ARRAY_CONCURRENCY}"
echo "  Mode: ${PIPELINE_MODE}"
echo "  RESULTS_ROOT: ${RESULTS_ROOT}"
echo "  QSIRECON_SPEC: ${QSIRECON_SPEC}"
echo "  QSIRECON_ATLASES: ${QSIRECON_ATLASES} (connectome from QSIRecon)"
echo "  Recon: $([[ ${RUN_RECON} == 1 ]] && echo on || echo off)  tool=${RECON_TOOL}"
echo "  DK connectome: off (atlas connectome only)"
[[ -n "${EXCLUDE_NODES}" ]] && echo "  Exclude nodes: ${EXCLUDE_NODES}"

export CONNECT_ROOT TRACKTBI_ROOT
export BIDS_DIR RESULTS_ROOT SUBJECT_LIST_FILE PIPELINE_MODE NTHREADS OMP_NTHREADS
export QSIRECON_SPEC QSIRECON_ATLASES QSIPREP_USE_SYN_SDC QSIPREP_FMAP_RETRY
export QSIPREP_BIDS_FILTER DWI_SELECT_JSON RUN_RECON RECON_TOOL RECON_OUT
export RUN_DK_CONNECTOME FS_SUBJECTS_DIR

SBATCH_EXTRA=()
[[ -n "${EXCLUDE_NODES}" ]] && SBATCH_EXTRA+=(--exclude="${EXCLUDE_NODES}")
[[ -n "${SBATCH_DEPENDENCY:-}" ]] && SBATCH_EXTRA+=(--dependency="${SBATCH_DEPENDENCY}")
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
