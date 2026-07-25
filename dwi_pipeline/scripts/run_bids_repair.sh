#!/usr/bin/env bash
# Repair BIDS DWI/fmap sidecars for QSIPrep (PE, phasediff echoes, IntendedFor).
#
# Usage:
#   ./run_bids_repair.sh /path/to/bids SUBJ01 [SUBJ02 ...]
#   ./run_bids_repair.sh /path/to/bids --subjects-table subjects.csv --all-from-table
#   ./run_bids_repair.sh /path/to/bids SUBJ01 --dry-run
#
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG="${SCRIPT_DIR}/../config/bids_repair_defaults.json"
REPAIR_PY="${SCRIPT_DIR}/repair_bids_sidecars.py"

if [[ $# -lt 1 ]]; then
  echo "Usage: $0 BIDS_DIR [SUBJECT ... | --subjects-table FILE --all-from-table] [--dry-run]" >&2
  exit 1
fi

BIDS_DIR="$1"
shift
SUBJECTS=()
TABLE=""
ALL_FROM_TABLE=0
DRY=()
while [[ $# -gt 0 ]]; do
  case "$1" in
    --dry-run) DRY=(--dry-run) ;;
    --all-from-table) ALL_FROM_TABLE=1 ;;
    --subjects-table)
      TABLE="$2"
      shift
      ;;
    *) SUBJECTS+=("$1") ;;
  esac
  shift
done

ARGS=(--bids-dir "$BIDS_DIR" --config "$CONFIG")
if [[ -n "$TABLE" ]]; then
  ARGS+=(--subjects-table "$TABLE")
fi
if [[ "$ALL_FROM_TABLE" -eq 1 ]]; then
  ARGS+=(--all-from-table)
fi
for s in "${SUBJECTS[@]}"; do
  ARGS+=(--subject "$s")
done

python3 "$REPAIR_PY" "${ARGS[@]}" "${DRY[@]}"
