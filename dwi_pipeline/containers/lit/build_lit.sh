#!/usr/bin/env bash
# Build/refresh lit_<version>.sif — neuroLIT (FastSurfer-LIT) lesion inpainting.
#
# Pulls the published image straight from Docker Hub (deepmi/lit); there is no
# custom build stage the way there is for dkt_connectome.sif, so this is a thin
# wrapper around `apptainer pull` with the pipeline's usual tmpdir/output
# conventions.
#
# Usage:
#   bash build_lit.sh                 # pulls deepmi/lit:0.6.0 -> .../containers/lit_0.6.0.sif
#   LIT_VERSION=0.7.0 bash build_lit.sh
#   OUT_SIF=/path/lit.sif bash build_lit.sh
#
set -euo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
APPTAINER_TMPDIR="${APPTAINER_TMPDIR:-${HERE}/.apptainer_tmp}"
export APPTAINER_TMPDIR SINGULARITY_TMPDIR="${APPTAINER_TMPDIR}"
mkdir -p "${APPTAINER_TMPDIR}"

LIT_VERSION="${LIT_VERSION:-0.6.0}"
SOURCE_IMAGE="${SOURCE_IMAGE:-docker://deepmi/lit:${LIT_VERSION}}"
OUT_SIF="${OUT_SIF:-/path/to/others/containers/lit_${LIT_VERSION}.sif}"

echo "=== lit_${LIT_VERSION}.sif build (Docker Hub pull) ==="
echo "  Source: ${SOURCE_IMAGE}"
echo "  Output: ${OUT_SIF}"

if [[ -f "${OUT_SIF}" && "${FORCE:-0}" != "1" ]]; then
  echo "  ${OUT_SIF} already exists — set FORCE=1 to overwrite."
  exit 0
fi

mkdir -p "$(dirname "${OUT_SIF}")"
apptainer pull --force "${OUT_SIF}" "${SOURCE_IMAGE}"

echo "=== Smoke test: lit-inpainting --help ==="
apptainer exec "${OUT_SIF}" lit-inpainting --help | head -20

echo "OK: ${OUT_SIF} ($(du -h "${OUT_SIF}" | cut -f1))"
echo "Point subject.sh at it with CONTAINER_LIT=${OUT_SIF} (this is already the default path)."
