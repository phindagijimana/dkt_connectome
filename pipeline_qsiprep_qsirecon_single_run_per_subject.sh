#!/bin/bash
# Per-subject QSIPrep + QSIrecon (entrypoint for pipeline_qsiprep_qsirecon_single_run_array.sh).
#
# Usage:  bash "$0" <all|qsiprep|qsirecon> <subj_id> [--syn] [--fmap-retry]
# SDC:    fmap in BIDS -> measured; no fmap -> no SyN by default; --syn or QSIPREP_USE_SYN_SDC=1 -> warn
# Env:    QSIPREP_FMAP_RETRY=1 / QSIPREP_USE_SYN_SDC=1 (same as CLI flags)
#   ... plus TEMPLATEFLOW_HOME, CONTAINER_*, FS_LICENSE, etc.

set -euo pipefail
set +H

PIPELINE_MODE="${1:?Need mode: all, qsiprep, or qsirecon}"
SUBJECT="${2:?Need subject id}"
SUBJECT="${SUBJECT#sub-}"
shift 2 || true
while [[ $# -gt 0 ]]; do
  case "$1" in
    --syn|--use-syn-sdc) QSIPREP_USE_SYN_SDC=1 ;;
    --fmap-retry) QSIPREP_FMAP_RETRY=1 ;;
    *) echo "Unknown option: $1"; exit 1 ;;
  esac
  shift
done

PROJECT_ROOT="/mnt/nfs/home/urmc-sh.rochester.edu/pndagiji/Documents/TrackTBI-Sub"
RESULTS_ROOT="${RESULTS_ROOT:-/mnt/nfs/home/urmc-sh.rochester.edu/pndagiji/Documents/CIDUR_BIDS/results_fmaps}"
BIDS_DIR="${BIDS_DIR:-/mnt/nfs/home/urmc-sh.rochester.edu/pndagiji/Documents/CIDUR_BIDS/data_bids}"
NTHREADS="${NTHREADS:-8}"
OMP_NTHREADS="${OMP_NTHREADS:-8}"
OUTPUT_RES="${OUTPUT_RES:-2}"

CONTAINER_QSIPREP="${CONTAINER_QSIPREP:-/mnt/nfs/home/urmc-sh.rochester.edu/pndagiji/Documents/containers/qsiprep.sif}"
CONTAINER_QSIRECON="${CONTAINER_QSIRECON:-/mnt/nfs/home/urmc-sh.rochester.edu/pndagiji/Documents/containers/qsirecon.sif}"
TEMPLATEFLOW_HOME="${TEMPLATEFLOW_HOME:-${PROJECT_ROOT}/templateflow}"
FS_LICENSE="${FS_LICENSE:-/mnt/nfs/home/urmc-sh.rochester.edu/pndagiji/Documents/data_mining/freesurfer/license.txt}"
QSIRECON_SPEC="${QSIRECON_SPEC:-dsi_studio_autotrack}"

QSIPREP_OUT="${RESULTS_ROOT}/qsiprep_single_run_output"
QSIRECON_OUT="${RESULTS_ROOT}/qsirecon_single_run_output"
INTER_QSP="${RESULTS_ROOT}/intermediate_results_qsiprep_single"
INTER_QSI="${RESULTS_ROOT}/intermediate_results_qsirecon_single"
WORK_QSIPREP="${INTER_QSP}/_work_qsiprep_${SUBJECT}"
WORK_QSIRECON="${INTER_QSI}/_work_qsirecon_${SUBJECT}"

[[ -d "${BIDS_DIR}" ]] || { echo "BIDS not found: ${BIDS_DIR}"; exit 1; }
[[ -d "${BIDS_DIR}/sub-${SUBJECT}" ]] || { echo "Missing ${BIDS_DIR}/sub-${SUBJECT}"; exit 1; }
[[ -f "${CONTAINER_QSIPREP}" ]] || { echo "Missing ${CONTAINER_QSIPREP}"; exit 1; }
[[ -f "${FS_LICENSE}" ]] || { echo "Missing FreeSurfer license: ${FS_LICENSE}"; exit 1; }
mkdir -p "${TEMPLATEFLOW_HOME}" "${QSIPREP_OUT}" "${QSIRECON_OUT}" "${INTER_QSP}" "${INTER_QSI}" "${RESULTS_ROOT}/logs" 2>/dev/null || true

echo "RESULTS_ROOT=${RESULTS_ROOT} (QSIPrep+QSIRecon outputs)"

has_fmap() {
  find "${BIDS_DIR}/sub-${SUBJECT}" -type f \( -name '*.nii' -o -name '*.nii.gz' \) -path '*/fmap/*' 2>/dev/null | head -1 | grep -q .
}

run_qsiprep() {
  local -a xtra=()
  if [[ "${QSIPREP_FMAP_RETRY:-0}" == "1" ]]; then
    xtra+=(--ignore fieldmaps)
    xtra+=(--use-syn-sdc warn)
    echo "QSIPrep: sub-${SUBJECT}: fmap retry -> --ignore fieldmaps --use-syn-sdc warn"
  elif has_fmap; then
    echo "QSIPrep: sub-${SUBJECT}: fmap/ NIfTI present -> measured fmaps (no --use-syn-sdc)"
  elif [[ "${QSIPREP_USE_SYN_SDC:-0}" == "1" ]]; then
    xtra+=(--use-syn-sdc warn)
    echo "QSIPrep: sub-${SUBJECT}: no fmap, SyN enabled -> --use-syn-sdc warn"
  else
    echo "QSIPrep: sub-${SUBJECT}: no fmap, SyN off (default; pass --syn to enable)"
  fi

  echo "=== QSIPrep: sub-${SUBJECT} ==="
  rm -rf "${WORK_QSIPREP}"
  mkdir -p "${WORK_QSIPREP}"
  apptainer run --cleanenv --containall \
    -B "${BIDS_DIR}":/bids_input:ro \
    -B "${QSIPREP_OUT}":/output \
    -B "${WORK_QSIPREP}":/work \
    -B "${FS_LICENSE}":/opt/freesurfer/license.txt:ro \
    -B "${TEMPLATEFLOW_HOME}":/templateflow \
    --env "TEMPLATEFLOW_HOME=/templateflow" \
    "${CONTAINER_QSIPREP}" \
    /bids_input /output participant \
    --participant-label "${SUBJECT}" \
    --fs-license-file /opt/freesurfer/license.txt \
    --work-dir /work \
    --output-resolution "${OUTPUT_RES}" \
    --nthreads "${NTHREADS}" \
    --omp-nthreads "${OMP_NTHREADS}" \
    --skip-bids-validation \
    "${xtra[@]}"

  rm -rf "${WORK_QSIPREP}" && echo "Cleanup: removed QSIPrep workdir sub-${SUBJECT}" || true
}

run_qsirecon() {
  [[ -f "${CONTAINER_QSIRECON}" ]] || { echo "Missing ${CONTAINER_QSIRECON}"; exit 1; }
  echo "=== QSIRecon (${QSIRECON_SPEC}): sub-${SUBJECT} ==="
  rm -rf "${WORK_QSIRECON}"
  mkdir -p "${WORK_QSIRECON}" "${QSIRECON_OUT}/derivatives"
  apptainer run --cleanenv --containall \
    -B "${QSIPREP_OUT}":/qsiprep_input:ro \
    -B "${QSIRECON_OUT}":/output \
    -B "${WORK_QSIRECON}":/work \
    -B "${FS_LICENSE}":/opt/freesurfer/license.txt:ro \
    -B "${TEMPLATEFLOW_HOME}":/templateflow \
    --env "TEMPLATEFLOW_HOME=/templateflow" \
    "${CONTAINER_QSIRECON}" \
    /qsiprep_input /output participant \
    --input-type qsiprep \
    --recon-spec "${QSIRECON_SPEC}" \
    --participant-label "${SUBJECT}" \
    --fs-license-file /opt/freesurfer/license.txt \
    --work-dir /work \
    --nthreads "${NTHREADS}" \
    --omp-nthreads "${OMP_NTHREADS}" \
    --output-resolution "${OUTPUT_RES}"

  rm -rf "${WORK_QSIRECON}" && echo "Cleanup: removed QSIRecon workdir sub-${SUBJECT}" || true
}

case "${PIPELINE_MODE}" in
  all) run_qsiprep; run_qsirecon ;;
  qsiprep) run_qsiprep ;;
  qsirecon) run_qsirecon ;;
  *)
    echo "Invalid PIPELINE_MODE=${PIPELINE_MODE} (use all, qsiprep, or qsirecon)"
    exit 1
    ;;
esac

echo "QSIPrep output: ${QSIPREP_OUT}"
echo "QSIRecon output: ${QSIRECON_OUT}"
