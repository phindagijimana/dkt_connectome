#!/bin/bash
# =============================================================================
# subject.sh — Atlas connectome pipeline (one subject)
# =============================================================================
#
# Runs QSIPrep -> FreeSurfer/FastSurfer -> QSIRecon (ACT-HSVS + atlas connectome).
# Does NOT run the post-hoc Desikan–Killiany step; connectivity comes from
# QSIRecon's --atlases output (default: 4S156Parcels).
#
# Implementation delegates to dwi_pipeline/subject.sh with defaults set below.
#
# Usage:
#   bash subject.sh all 001
#   bash subject.sh qsiprep 001
#   bash subject.sh recon 001
#   bash subject.sh qsirecon 001
#   bash subject.sh all 001 --syn --fastsurfer
# =============================================================================

set -euo pipefail

CONNECT_ROOT="$(cd "$(dirname "$0")" && pwd)"
TRACKTBI_ROOT="$(cd "${CONNECT_ROOT}/.." && pwd)"
PIPELINE="${TRACKTBI_ROOT}/dwi_pipeline/subject.sh"

export RESULTS_ROOT="${RESULTS_ROOT:-/mnt/nfs/home/urmc-sh.rochester.edu/pndagiji/Documents/CIDUR_BIDS/dwi_test_default}"
export RUN_DK_CONNECTOME="${RUN_DK_CONNECTOME:-0}"
export QSIRECON_SPEC="${QSIRECON_SPEC:-mrtrix_singleshell_ss3t_ACT-hsvs}"
export QSIRECON_ATLASES="${QSIRECON_ATLASES:-4S156Parcels}"
export RUN_RECON="${RUN_RECON:-1}"
export RECON_TOOL="${RECON_TOOL:-freesurfer}"

[[ -f "${PIPELINE}" ]] || { echo "Missing ${PIPELINE}"; exit 1; }

# Force --no-dk for full runs unless caller explicitly re-enabled DK.
args=("$@")
if [[ "${RUN_DK_CONNECTOME}" == "0" ]]; then
  has_no_dk=0
  for a in "${args[@]}"; do
    [[ "$a" == "--no-dk" ]] && has_no_dk=1
  done
  if [[ "${1:-}" == "all" && "${has_no_dk}" -eq 0 ]]; then
    args+=(--no-dk)
  fi
fi

exec bash "${PIPELINE}" "${args[@]}"
