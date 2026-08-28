#!/usr/bin/env bash
# Build dkt_deep_atropos.sif — Deep Atropos seg → base_5tt_native.mif (Step 3.5a).
#
# Stages MRtrix from qsirecon.sif for mrconvert / 5ttcheck.
#
# Usage:
#   bash build_deep_atropos.sh
#   CONTAINER_QSIRECON=/path/qsirecon.sif OUT_SIF=/path/dkt_deep_atropos.sif bash build_deep_atropos.sh
#
set -euo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "${HERE}/../../.." && pwd)"
CTX="${HERE}/build_ctx"
APPTAINER_TMPDIR="${APPTAINER_TMPDIR:-${HERE}/.apptainer_tmp}"
export APPTAINER_TMPDIR SINGULARITY_TMPDIR="${APPTAINER_TMPDIR}" PROOT_TMP_DIR="${APPTAINER_TMPDIR}"
mkdir -p "${APPTAINER_TMPDIR}"

QSI_SIF="${CONTAINER_QSIRECON:-/path/to/others/containers/qsirecon.sif}"
OUT_SIF="${OUT_SIF:-/path/to/others/containers/dkt_deep_atropos.sif}"
IMAGE_TAG="${IMAGE_TAG:-dkt_deep_atropos:latest}"

echo "=== dkt_deep_atropos build ==="
echo "  QSIRecon source: ${QSI_SIF}"
echo "  Output SIF:      ${OUT_SIF}"

[[ -f "${QSI_SIF}" ]] || { echo "ERROR: QSIRecon SIF not found: ${QSI_SIF}"; exit 1; }

stage_mrtrix() {
  local dest_mrtrix="${CTX}/mrtrix3-latest"
  rm -rf "${dest_mrtrix}"
  mkdir -p "${dest_mrtrix}"
  echo "  Staging MRtrix from ${QSI_SIF}..."
  apptainer exec "${QSI_SIF}" tar -C /opt/mrtrix3-latest -cf - . | tar -C "${dest_mrtrix}" -xf -
  [[ -x "${dest_mrtrix}/bin/mrconvert" ]] || { echo "ERROR: MRtrix staging failed"; exit 1; }
  echo "  MRtrix staged: $(du -sh "${dest_mrtrix}" | awk '{print $1}')"
}

if [[ "${SKIP_STAGE:-0}" == "1" && -x "${CTX}/mrtrix3-latest/bin/mrconvert" ]]; then
  echo "  SKIP_STAGE=1: reusing ${CTX}/mrtrix3-latest"
else
  rm -rf "${CTX}"
  mkdir -p "${CTX}"
  stage_mrtrix
fi

cp "${REPO_ROOT}/dwi_pipeline/scripts/convert_deep_atropos_to_5tt.py" "${CTX}/"
cp "${HERE}/run_deep_atropos_5tt.sh" "${CTX}/"
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
