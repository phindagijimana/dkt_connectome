#!/usr/bin/env bash
# Verify a real QSIPrep integration run completed (used by GitHub Actions).
set -euo pipefail

RESULTS_ROOT="${1:?usage: integration_verify_qsiprep.sh RESULTS_ROOT [SUBJECT]}"
SUBJECT="${2:-EXAMPLE}"

MARKER="${RESULTS_ROOT}/.snakemake_markers/sub-${SUBJECT}/qsiprep.done"
OUT="${RESULTS_ROOT}/qsiprep_single_run_output/sub-${SUBJECT}"
LOG="${RESULTS_ROOT}/logs/sub-${SUBJECT}_qsiprep.log"

errors=0

if [[ -f "${MARKER}" ]]; then
  echo "[verify] OK marker: ${MARKER}"
else
  echo "[verify] FAIL missing marker: ${MARKER}" >&2
  errors=$((errors + 1))
fi

if [[ -d "${OUT}" ]] && find "${OUT}" -type f | head -1 | grep -q .; then
  echo "[verify] OK qsiprep output dir: ${OUT}"
else
  echo "[verify] FAIL empty or missing: ${OUT}" >&2
  errors=$((errors + 1))
fi

if [[ -f "${LOG}" ]]; then
  if grep -qiE 'qsiprep|finished|complete|success' "${LOG}"; then
    echo "[verify] OK log mentions QSIPrep activity: ${LOG}"
  else
    echo "[verify] WARN log present but no obvious success line — tail:" >&2
    tail -n 40 "${LOG}" >&2 || true
  fi
else
  echo "[verify] WARN missing log: ${LOG}" >&2
fi

if [[ "${errors}" -gt 0 ]]; then
  echo "[verify] FAILED (${errors} checks)" >&2
  exit 1
fi

echo "[verify] PASSED qsiprep integration for sub-${SUBJECT}"
