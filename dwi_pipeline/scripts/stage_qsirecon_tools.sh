#!/usr/bin/env bash
# Stage MRtrix/ANTs from qsirecon into a build context directory.
# Uses Apptainer pull so paths match HPC .sif layout (/opt/mrtrix3-latest).
#
# Usage:
#   stage_qsirecon_tools.sh DEST_MRTrix DEST_ANTS
#
set -euo pipefail

DEST_MRTrix="${1:?dest mrtrix dir}"
DEST_ANTS="${2:?dest ants dir}"
QSI_IMAGE="${QSI_IMAGE:-pennlinc/qsirecon:1.2.1}"
WORK="${WORK:-/tmp/dkt_qsirecon_stage}"
mkdir -p "${WORK}" "${DEST_MRTrix}" "${DEST_ANTS}"

if ! command -v apptainer >/dev/null 2>&1; then
  echo "ERROR: apptainer required" >&2
  exit 1
fi

QSI_SIF="${WORK}/qsirecon.sif"
echo "  Apptainer pull ${QSI_IMAGE}..."
apptainer pull --force "${QSI_SIF}" "docker://${QSI_IMAGE}"

echo "  Staging MRtrix/ANTs from ${QSI_SIF}..."
apptainer exec "${QSI_SIF}" tar -C /opt/ants -cf - . | tar -C "${DEST_ANTS}" -xf -
apptainer exec "${QSI_SIF}" tar -C /opt/mrtrix3-latest -cf - . | tar -C "${DEST_MRTrix}" -xf -

[[ -x "${DEST_ANTS}/bin/antsApplyTransforms" ]] || { echo "ERROR: ANTs staging failed"; exit 1; }
[[ -x "${DEST_MRTrix}/bin/labelconvert" || -x "${DEST_MRTrix}/bin/tckgen" ]] \
  || { echo "ERROR: MRtrix staging failed"; exit 1; }
echo "  qsirecon tools staged OK"
