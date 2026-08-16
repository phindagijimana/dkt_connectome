#!/usr/bin/env bash
# Thin wrapper for run_disconnectome.py (Step 4.5 standalone test).
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PIPELINE_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

CONTAINER="${DISCONNECTOME_CONTAINER:-${CONTAINER_CONNECTOME:-/path/to/dkt_connectome.sif}}"

usage() {
  cat <<EOF
Usage: $(basename "$0") <results-root> <subject-id> [session]

Standalone Step 4.5 disconnectome on a completed results tree.

Examples:
  $(basename "$0") \\
    ${PIPELINE_DIR}/dwi_test_TBI/sub-TBI011011_fastsurfer_inpaint TBI011011
  $(basename "$0") \\
    ${PIPELINE_DIR}/dwi_test_TBI/sub-TBI011204_fastsurfer_inpaint TBI011204 2WK

Environment:
  DISCONNECTOME_CONTAINER  Apptainer image (default: dkt_connectome.sif)
EOF
}

if [[ $# -lt 2 ]]; then
  usage
  exit 1
fi

RESULTS_ROOT="$1"
SUBJECT="$2"
SESSION="${3:-}"

extra=()
[[ -n "${SESSION}" ]] && extra+=(--session "${SESSION}")

exec python3 "${SCRIPT_DIR}/run_disconnectome.py" \
  --results-root "${RESULTS_ROOT}" \
  --subject "${SUBJECT}" \
  --container "${CONTAINER}" \
  "${extra[@]}"
