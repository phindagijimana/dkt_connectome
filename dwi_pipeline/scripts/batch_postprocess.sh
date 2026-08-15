#!/usr/bin/env bash
# =============================================================================
# batch_postprocess.sh — Cohort post-processing on an existing RESULTS_ROOT
# =============================================================================
# Run after subjects finish (or incrementally). Does NOT re-run QSIPrep/recon.
# Equivalent to: ./run BIDS OUT group
#
# Usage:
#   export RESULTS_ROOT=/path/to/cohort_output
#   export BIDS_DIR=/path/to/BIDS
#   bash dwi_pipeline/scripts/batch_postprocess.sh
#
# Options:
#   --copy              Copy files for BIDS export (default: symlinks)
#   --skip-export       Skip derivatives/ export
#   --skip-qc           Skip HTML QC generation
# =============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DWI_ROOT="$(dirname "${SCRIPT_DIR}")"

RESULTS_ROOT="${RESULTS_ROOT:?Set RESULTS_ROOT}"
BIDS_DIR="${BIDS_DIR:-}"
COPY=0
SKIP_EXPORT=0
SKIP_QC=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --copy) COPY=1 ;;
    --skip-export) SKIP_EXPORT=1 ;;
    --skip-qc) SKIP_QC=1 ;;
    -h|--help)
      sed -n '2,15p' "$0" | sed 's/^# \{0,1\}//'
      exit 0
      ;;
    *) echo "Unknown option: $1" >&2; exit 1 ;;
  esac
  shift
done

echo "[batch_postprocess] RESULTS_ROOT=${RESULTS_ROOT}"

if [[ "${SKIP_QC}" == "0" ]]; then
  python3 "${SCRIPT_DIR}/render_cohort_qc.py" \
    --results-root "${RESULTS_ROOT}" \
    --write-subject-reports
  python3 "${SCRIPT_DIR}/render_disconnectome_cohort_qc.py" \
    --results-root "${RESULTS_ROOT}" \
    --write-subject-reports
fi

python3 "${SCRIPT_DIR}/write_derivatives_description.py" \
  --results-root "${RESULTS_ROOT}" \
  ${BIDS_DIR:+--bids-dir "${BIDS_DIR}"}

if [[ "${SKIP_EXPORT}" == "0" ]]; then
  export_args=(--results-root "${RESULTS_ROOT}")
  [[ -n "${BIDS_DIR}" ]] && export_args+=(--bids-dir "${BIDS_DIR}")
  ((COPY)) && export_args+=(--copy)
  python3 "${SCRIPT_DIR}/export_bids_derivatives.py" "${export_args[@]}"
fi

echo "[batch_postprocess] Done."
echo "  cohort QC:        ${RESULTS_ROOT}/cohort_qc.html"
echo "  disconnectome QC: ${RESULTS_ROOT}/disconnectome_cohort_qc.html"
[[ "${SKIP_EXPORT}" == "0" ]] && echo "  BIDS export:      ${RESULTS_ROOT}/derivatives/"
