#!/usr/bin/env bash
# Build dkt_deep_atropos_seg.sif — ANTsPyNet Deep Atropos on native T1w.
#
# Usage:
#   bash build_deep_atropos_seg.sh
#   OUT_SIF=/path/dkt_deep_atropos_seg.sif bash build_deep_atropos_seg.sh
#
set -euo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "${HERE}/../../.." && pwd)"
CTX="${HERE}/build_ctx"
APPTAINER_TMPDIR="${APPTAINER_TMPDIR:-${HERE}/.apptainer_tmp}"
export APPTAINER_TMPDIR SINGULARITY_TMPDIR="${APPTAINER_TMPDIR}" PROOT_TMP_DIR="${APPTAINER_TMPDIR}"
mkdir -p "${APPTAINER_TMPDIR}"

OUT_SIF="${OUT_SIF:-/path/to/others/containers/dkt_deep_atropos_seg.sif}"
IMAGE_TAG="${IMAGE_TAG:-dkt_deep_atropos_seg:latest}"

echo "=== dkt_deep_atropos_seg build ==="
echo "  Output SIF: ${OUT_SIF}"

rm -rf "${CTX}"
mkdir -p "${CTX}/antsxnet_cache"
cp "${REPO_ROOT}/dwi_pipeline/scripts/run_deep_atropos_seg.py" "${CTX}/"
cp "${HERE}/run_deep_atropos_seg.sh" "${CTX}/"
echo "  Build context ready"

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
