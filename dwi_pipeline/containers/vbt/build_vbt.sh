#!/usr/bin/env bash
# Build dkt_vbt.sif — lean LeAPP-compatible virtual brain transplant (Step 1.1).
#
# Stages the FSL conda env from qsiprep.sif (same tools used in validation) plus
# run_vbt.py. Python deps (nibabel, numpy, scipy) are installed in the image.
#
# Usage:
#   bash build_vbt.sh
#   CONTAINER_QSIPREP=/path/qsiprep.sif OUT_SIF=/path/dkt_vbt.sif bash build_vbt.sh
#
set -euo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "${HERE}/../../.." && pwd)"
CTX="${HERE}/build_ctx"
APPTAINER_TMPDIR="${APPTAINER_TMPDIR:-${HERE}/.apptainer_tmp}"
export APPTAINER_TMPDIR SINGULARITY_TMPDIR="${APPTAINER_TMPDIR}" PROOT_TMP_DIR="${APPTAINER_TMPDIR}"
mkdir -p "${APPTAINER_TMPDIR}"

QSIPREP_SIF="${CONTAINER_QSIPREP:-/path/to/others/containers/qsiprep.sif}"
OUT_SIF="${OUT_SIF:-/path/to/others/containers/dkt_vbt.sif}"
IMAGE_TAG="${IMAGE_TAG:-dkt_vbt:latest}"
FSL_ENV="${FSL_ENV:-/opt/conda/envs/fslqsiprep}"

echo "=== dkt_vbt build ==="
echo "  QSIPrep source: ${QSIPREP_SIF}"
echo "  FSL env:        ${FSL_ENV}"
echo "  Output SIF:     ${OUT_SIF}"

[[ -f "${QSIPREP_SIF}" ]] || { echo "ERROR: QSIPrep SIF not found: ${QSIPREP_SIF}"; exit 1; }

stage_fsl() {
  local dest="${CTX}/fsl"
  rm -rf "${dest}"
  mkdir -p "${dest}"
  echo "  Staging FSL from ${QSIPREP_SIF}:${FSL_ENV}..."
  apptainer exec "${QSIPREP_SIF}" test -d "${FSL_ENV}/bin"
  apptainer exec "${QSIPREP_SIF}" tar -C "${FSL_ENV}" -cf - . | tar -C "${dest}" -xf -
  for cmd in flirt fslswapdim midtrans convert_xfm fslmaths; do
    [[ -x "${dest}/bin/${cmd}" ]] || { echo "ERROR: missing ${cmd} in staged FSL"; exit 1; }
  done
  [[ -f "${dest}/etc/flirtsch/ident.mat" ]] || { echo "ERROR: missing FSL ident.mat"; exit 1; }
  echo "  FSL staged: $(du -sh "${dest}" | awk '{print $1}')"
}

if [[ "${SKIP_STAGE:-0}" == "1" && -x "${CTX}/fsl/bin/flirt" ]]; then
  echo "  SKIP_STAGE=1: reusing ${CTX}/fsl"
else
  rm -rf "${CTX}"
  mkdir -p "${CTX}"
  stage_fsl
fi

cp "${REPO_ROOT}/dwi_pipeline/scripts/run_vbt.py" "${CTX}/"
echo "  Build context: $(du -sh "${CTX}" | awk '{print $1}')"

if [[ -f "${OUT_SIF}" && "${BACKUP_EXISTING:-1}" == "1" ]]; then
  bak="${OUT_SIF}.bak.$(date +%Y%m%d%H%M%S)"
  echo "  Backing up existing SIF -> ${bak}"
  cp -a "${OUT_SIF}" "${bak}"
fi

if command -v docker >/dev/null 2>&1; then
  echo "  Building Docker image ${IMAGE_TAG}..."
  docker build -t "${IMAGE_TAG}" -f "${HERE}/Dockerfile" "${CTX}"
  echo "  Building Apptainer SIF from Docker..."
  apptainer build --force "${OUT_SIF}" "docker-daemon://${IMAGE_TAG}"
else
  echo "  Building SIF from Apptainer.def..."
  cp "${HERE}/Apptainer.def" "${CTX}/Apptainer.def"
  ( cd "${CTX}" && apptainer build --force "${OUT_SIF}" Apptainer.def )
fi

echo "=== Smoke test ==="
apptainer exec "${OUT_SIF}" flirt -help 2>&1 | head -3
apptainer exec "${OUT_SIF}" python3 /opt/vbt/run_vbt.py --help | head -5
echo "OK: ${OUT_SIF} ($(du -h "${OUT_SIF}" | cut -f1))"
