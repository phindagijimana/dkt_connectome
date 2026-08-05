#!/bin/bash
# =============================================================================
# backfill_markers.sh — Create Snakemake marker files for subject.sh outputs
# =============================================================================
# When migrating from subject.sh to the Snakemake engine, existing QSIPrep and
# QSIRecon derivatives are on disk but lack marker files under
# RESULTS_ROOT/.snakemake_markers/. Without markers, Snakemake will redo
# Steps 1 and 3 (hours) even though outputs already exist.
#
# Usage:
#   RESULTS_ROOT=/path/to/output bash workflow/backfill_markers.sh
#   RESULTS_ROOT=/path/to/output bash workflow/backfill_markers.sh SUBJECT001 001
# =============================================================================
set -euo pipefail

RESULTS_ROOT="${RESULTS_ROOT:?Set RESULTS_ROOT}"
MARKERS_DIR="${RESULTS_ROOT}/.snakemake_markers"
QSIPREP_OUT="${RESULTS_ROOT}/qsiprep_single_run_output"
QSIRECON_OUT="${RESULTS_ROOT}/qsirecon_single_run_output"

mkdir -p "${MARKERS_DIR}"

backfill_one() {
  local sub="$1"
  sub="${sub#sub-}"
  local marker_dir="${MARKERS_DIR}/sub-${sub}"
  mkdir -p "${marker_dir}"

  if [[ -d "${QSIPREP_OUT}/sub-${sub}" ]]; then
    touch "${marker_dir}/qsiprep.done"
    echo "  qsiprep.done  (found ${QSIPREP_OUT}/sub-${sub})"
  fi

  if [[ -d "${QSIRECON_OUT}/sub-${sub}" ]] || \
     find "${QSIRECON_OUT}" -maxdepth 2 -type d -name "sub-${sub}" -print -quit 2>/dev/null | grep -q .; then
    touch "${marker_dir}/qsirecon.done"
    echo "  qsirecon.done (found under ${QSIRECON_OUT})"
  fi
}

echo "backfill_markers: ${RESULTS_ROOT}"

if (($#)); then
  for sub in "$@"; do
    echo "sub-${sub#sub-}:"
    backfill_one "${sub#sub-}"
  done
else
  shopt -s nullglob
  for d in "${QSIPREP_OUT}"/sub-*; do
    [[ -d "$d" ]] || continue
    sub="${d##*/sub-}"
    echo "sub-${sub}:"
    backfill_one "${sub}"
  done
  shopt -u nullglob
fi

echo "backfill_markers: done"
