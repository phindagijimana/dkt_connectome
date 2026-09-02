#!/usr/bin/env bash
# Stage Docker build context for lean dkt_connectome (Step 4 + 4.1) in CI.
#
# Uses Apptainer pull + the same staging logic as build_connectome.sh so CI
# matches HPC builds (FreeSurfer + QSIRecon binaries from published images).
#
# Usage:
#   bash scripts/ci_stage_connectome_build_context.sh
#
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
QSI_IMAGE="${QSI_IMAGE:-pennlinc/qsirecon:1.2.1}"
FS_IMAGE="${FS_IMAGE:-freesurfer/freesurfer:7.4.1}"
WORK="${WORK:-/tmp/dkt_connectome_ci}"
mkdir -p "${WORK}"

echo "=== Stage connectome build context (Apptainer) ==="
echo "  QSIRecon: ${QSI_IMAGE}"
echo "  FreeSurfer: ${FS_IMAGE}"
echo "  Workdir:  ${WORK}"

if ! command -v apptainer >/dev/null 2>&1; then
  echo "ERROR: apptainer required for connectome CI staging" >&2
  exit 1
fi

QSI_SIF="${WORK}/qsirecon.sif"
FS_SIF="${WORK}/freesurfer.sif"
apptainer pull --force "${QSI_SIF}" "docker://${QSI_IMAGE}"
apptainer pull --force "${FS_SIF}" "docker://${FS_IMAGE}"

CONTAINER_FREESURFER="${FS_SIF}" \
CONTAINER_QSIRECON="${QSI_SIF}" \
OUT_SIF="${WORK}/unused.sif" \
STAGE_ONLY=1 \
BACKUP_EXISTING=0 \
bash "${ROOT}/containers/connectome/build_connectome.sh"

echo "=== Connectome CI context ready: ${ROOT}/containers/connectome/build_ctx_lean ==="
