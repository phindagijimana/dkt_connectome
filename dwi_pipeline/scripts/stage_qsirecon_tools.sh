#!/usr/bin/env bash
# Stage MRtrix/ANTs from qsirecon Docker image (no full .sif pull — saves disk on CI).
#
# Usage:
#   stage_qsirecon_tools.sh DEST_MRTrix DEST_ANTS
#
set -euo pipefail

DEST_MRTrix="${1:?dest mrtrix dir}"
DEST_ANTS="${2:?dest ants dir}"
QSI_IMAGE="${QSI_IMAGE:-pennlinc/qsirecon:1.2.1}"

rm -rf "${DEST_MRTrix}" "${DEST_ANTS}"
mkdir -p "${DEST_MRTrix}" "${DEST_ANTS}"

echo "  Docker pull ${QSI_IMAGE}..."
docker pull "${QSI_IMAGE}"
cid="$(docker create "${QSI_IMAGE}")"
trap 'docker rm -f "${cid}" >/dev/null 2>&1 || true' RETURN

docker cp "${cid}:/opt/ants/." "${DEST_ANTS}/" 2>/dev/null || true
[[ -x "${DEST_ANTS}/bin/antsApplyTransforms" ]] || {
  echo "ERROR: ANTs staging failed (/opt/ants)" >&2
  exit 1
}

staged=0
for mrtrix_src in /opt/mrtrix3-latest /opt/mrtrix3 /usr/local/mrtrix3 /usr/local/mrtrix3-latest; do
  rm -rf "${DEST_MRTrix:?}"/*
  if docker cp "${cid}:${mrtrix_src}/." "${DEST_MRTrix}/" 2>/dev/null \
    && { [[ -x "${DEST_MRTrix}/bin/labelconvert" ]] || [[ -x "${DEST_MRTrix}/bin/tckgen" ]]; }; then
    staged=1
    echo "  MRtrix staged from ${mrtrix_src}"
    break
  fi
done

if [[ "${staged}" -eq 0 ]]; then
  echo "  MRtrix path probe:"
  docker export "${cid}" 2>/dev/null | tar -t 2>/dev/null | grep -E 'labelconvert|mrtrix3' | head -10 || true
  echo "ERROR: MRtrix staging failed (tried common paths)" >&2
  exit 1
fi

docker rm -f "${cid}"
trap - RETURN
echo "  qsirecon tools staged OK"
