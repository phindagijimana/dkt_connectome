#!/usr/bin/env bash
# Session-aware BIDS App entry point for the DKT connectome workflow.
#
# Usage:
#   bids_app.sh BIDS_DIR OUTPUT_DIR participant \
#     --participant-label 009 --session-label 1
#
# Repeat --participant-label / --session-label to select multiple entities.
# When --session-label is omitted, all sessions found for each participant run
# independently. Each subject-session receives an isolated workflow root, which
# prevents FreeSurfer, QSIRecon, connectome, and report outputs from colliding.

set -euo pipefail

BIDS_DIR="${1:?Usage: bids_app.sh BIDS_DIR OUTPUT_DIR participant [options]}"
OUTPUT_DIR="${2:?Usage: bids_app.sh BIDS_DIR OUTPUT_DIR participant [options]}"
ANALYSIS_LEVEL="${3:?Usage: bids_app.sh BIDS_DIR OUTPUT_DIR participant [options]}"
shift 3

[[ "${ANALYSIS_LEVEL}" == "participant" ]] || {
  echo "ERROR: analysis_level must be participant" >&2
  exit 2
}
[[ -d "${BIDS_DIR}" ]] || { echo "ERROR: missing BIDS directory: ${BIDS_DIR}" >&2; exit 2; }

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PIPELINE_MODE="all"
DRY_RUN=0
declare -a PARTICIPANTS=()
declare -a SESSIONS=()
declare -a PIPELINE_ARGS=()

while [[ $# -gt 0 ]]; do
  case "$1" in
    --participant-label)
      PARTICIPANTS+=("${2#sub-}")
      shift 2
      ;;
    --session-label)
      SESSIONS+=("${2#ses-}")
      shift 2
      ;;
    --pipeline-mode)
      PIPELINE_MODE="${2:?Need a mode after --pipeline-mode}"
      shift 2
      ;;
    --dry-run|-n)
      DRY_RUN=1
      shift
      ;;
    --)
      shift
      PIPELINE_ARGS+=("$@")
      break
      ;;
    -h|--help)
      sed -n '2,11p' "$0"
      exit 0
      ;;
    *)
      echo "ERROR: unknown option: $1" >&2
      exit 2
      ;;
  esac
done

if [[ ${#PARTICIPANTS[@]} -eq 0 ]]; then
  shopt -s nullglob
  for subject_dir in "${BIDS_DIR}"/sub-*; do
    [[ -d "${subject_dir}" ]] && PARTICIPANTS+=("${subject_dir##*/sub-}")
  done
  shopt -u nullglob
fi
[[ ${#PARTICIPANTS[@]} -gt 0 ]] || { echo "ERROR: no BIDS participants found" >&2; exit 2; }

mkdir -p "${OUTPUT_DIR}"
python3 - "${OUTPUT_DIR}/dataset_description.json" <<'PY'
import json
import sys
from pathlib import Path

path = Path(sys.argv[1])
if not path.exists():
    path.write_text(json.dumps({
        "Name": "DKT Connectome Pipeline derivatives",
        "BIDSVersion": "1.10.0",
        "DatasetType": "derivative",
        "GeneratedBy": [{"Name": "dkt_connectome BIDS App"}],
    }, indent=2) + "\n")
PY

run_unit() {
  local subject="$1" session="$2"
  local unit_root="${OUTPUT_DIR}/sub-${subject}/ses-${session}"
  local -a args=("${PIPELINE_ARGS[@]}")
  (( DRY_RUN )) && args+=(--dry-run)

  echo "=== BIDS App unit: sub-${subject} ses-${session} -> ${unit_root} ==="
  mkdir -p "${unit_root}"
  BIDS_DIR="${BIDS_DIR}" \
  RESULTS_ROOT="${unit_root}" \
  RECON_SESSION="${session}" \
  SNAKEMAKE_WORKDIR="${unit_root}/.snakemake_workdir" \
    bash "${SCRIPT_DIR}/workflow/run_subject.sh" \
      "${PIPELINE_MODE}" "${subject}" --session-filter "${session}" "${args[@]}"
}

for subject in "${PARTICIPANTS[@]}"; do
  [[ -d "${BIDS_DIR}/sub-${subject}" ]] || {
    echo "ERROR: participant not found: sub-${subject}" >&2
    exit 2
  }

  declare -a subject_sessions=()
  if [[ ${#SESSIONS[@]} -gt 0 ]]; then
    subject_sessions=("${SESSIONS[@]}")
  else
    shopt -s nullglob
    for session_dir in "${BIDS_DIR}/sub-${subject}"/ses-*; do
      [[ -d "${session_dir}" ]] && subject_sessions+=("${session_dir##*/ses-}")
    done
    shopt -u nullglob
  fi
  [[ ${#subject_sessions[@]} -gt 0 ]] || {
    echo "ERROR: no sessions found for sub-${subject}" >&2
    exit 2
  }

  for session in "${subject_sessions[@]}"; do
    [[ -d "${BIDS_DIR}/sub-${subject}/ses-${session}" ]] || {
      echo "ERROR: session not found: sub-${subject} ses-${session}" >&2
      exit 2
    }
    run_unit "${subject}" "${session}"
  done
done
