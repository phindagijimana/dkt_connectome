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
    /path/to/RESULTS_ROOT EXAMPLE
  $(basename "$0") \\
    /path/to/RESULTS_ROOT EXAMPLE ses-1

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
