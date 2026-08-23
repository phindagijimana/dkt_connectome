#!/usr/bin/env bash
# Build dkt_lesion_act.sif — Post-QSIRecon lesion-aware ACT (Step 3.5).
#
# Stages ANTs + MRtrix from qsirecon.sif (same as dkt_connectome without FreeSurfer).
#
# Usage:
#   bash build_lesion_act.sh
#
set -euo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
CTX="${HERE}/build_ctx"
APPTAINER_TMPDIR="${APPTAINER_TMPDIR:-${HERE}/.apptainer_tmp}"
export APPTAINER_TMPDIR SINGULARITY_TMPDIR="${APPTAINER_TMPDIR}" PROOT_TMP_DIR="${APPTAINER_TMPDIR}"
mkdir -p "${APPTAINER_TMPDIR}"

QSI_SIF="${CONTAINER_QSIRECON:-/path/to/others/containers/qsirecon.sif}"
OUT_SIF="${OUT_SIF:-/path/to/others/containers/dkt_lesion_act.sif}"
IMAGE_TAG="${IMAGE_TAG:-dkt_lesion_act:latest}"

echo "=== dkt_lesion_act build ==="
echo "  QSIRecon source: ${QSI_SIF}"
echo "  Output SIF:      ${OUT_SIF}"

[[ -f "${QSI_SIF}" ]] || { echo "ERROR: QSIRecon SIF not found: ${QSI_SIF}"; exit 1; }

stage_from_qsirecon() {
  local dest_ants="${CTX}/ants"
  local dest_mrtrix="${CTX}/mrtrix3-latest"
  rm -rf "${dest_ants}" "${dest_mrtrix}"
  mkdir -p "${dest_ants}" "${dest_mrtrix}"

  echo "  Staging ANTs from ${QSI_SIF}..."
  apptainer exec "${QSI_SIF}" tar -C /opt/ants -cf - . | tar -C "${dest_ants}" -xf -
  [[ -x "${dest_ants}/bin/antsApplyTransforms" ]] || { echo "ERROR: ANTs staging failed"; exit 1; }

  echo "  Staging MRtrix from ${QSI_SIF}..."
  apptainer exec "${QSI_SIF}" tar -C /opt/mrtrix3-latest -cf - . | tar -C "${dest_mrtrix}" -xf -
  [[ -x "${dest_mrtrix}/bin/tckgen" ]] || { echo "ERROR: MRtrix staging failed"; exit 1; }
  echo "  Staged: ANTs $(du -sh "${dest_ants}" | awk '{print $1}'), MRtrix $(du -sh "${dest_mrtrix}" | awk '{print $1}')"
}

if [[ "${SKIP_STAGE:-0}" == "1" \
      && -x "${CTX}/ants/bin/antsApplyTransforms" \
      && -x "${CTX}/mrtrix3-latest/bin/tckgen" ]]; then
  echo "  SKIP_STAGE=1: reusing ${CTX}/"
else
  rm -rf "${CTX}"
  mkdir -p "${CTX}"
  stage_from_qsirecon
fi

cp "${HERE}/run_lesion_aware_act.sh" "${CTX}/"
echo "  Build context: $(du -sh "${CTX}" | awk '{print $1}')"

if [[ -f "${OUT_SIF}" && "${BACKUP_EXISTING:-1}" == "1" ]]; then
  bak="${OUT_SIF}.bak.$(date +%Y%m%d%H%M%S)"
  echo "  Backing up existing SIF -> ${bak}"
  cp -a "${OUT_SIF}" "${bak}"
fi

if command -v docker >/dev/null 2>&1; then
  docker build -t "${IMAGE_TAG}" -f "${HERE}/Dockerfile" "${CTX}"
  apptainer build --force "${OUT_SIF}" "docker-daemon://${IMAGE_TAG}"
else
  cp "${HERE}/Apptainer.def" "${CTX}/Apptainer.def"
  ( cd "${CTX}" && apptainer build --force "${OUT_SIF}" Apptainer.def )
fi

echo "=== Smoke test ==="
apptainer run "${OUT_SIF}" --help | head -8
echo "OK: ${OUT_SIF} ($(du -h "${OUT_SIF}" | cut -f1))"
