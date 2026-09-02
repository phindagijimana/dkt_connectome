#!/usr/bin/env bash
# Stage Docker build context for lean dkt_connectome (Step 4 + 4.1) in CI.
#
# Usage:
#   bash scripts/ci_stage_connectome_build_context.sh
#
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
CTX="${ROOT}/containers/connectome/build_ctx_lean"
QSI_IMAGE="${QSI_IMAGE:-pennlinc/qsirecon:1.2.1}"
FS_IMAGE="${FS_IMAGE:-freesurfer/freesurfer:7.4.1}"

rm -rf "${CTX}"
mkdir -p "${CTX}/freesurfer/bin" "${CTX}/ants" "${CTX}/mrtrix3-latest" "${CTX}/dkt/lut"

echo "=== Stage connectome build context ==="
echo "  QSIRecon: ${QSI_IMAGE}"
echo "  FreeSurfer: ${FS_IMAGE}"

echo "  Pulling ${QSI_IMAGE}..."
docker pull "${QSI_IMAGE}"
qsi_cid="$(docker create "${QSI_IMAGE}")"
trap 'docker rm -f "${qsi_cid}" >/dev/null 2>&1 || true' RETURN
docker cp "${qsi_cid}:/opt/ants/." "${CTX}/ants/"
docker cp "${qsi_cid}:/opt/mrtrix3-latest/." "${CTX}/mrtrix3-latest/"
docker rm -f "${qsi_cid}"
trap - RETURN
[[ -x "${CTX}/ants/bin/antsRegistration" ]] || { echo "ERROR: ANTs staging failed"; exit 1; }
[[ -x "${CTX}/mrtrix3-latest/bin/labelconvert" ]] || { echo "ERROR: MRtrix staging failed"; exit 1; }

echo "  Pulling ${FS_IMAGE}..."
docker pull "${FS_IMAGE}"
fs_cid="$(docker create "${FS_IMAGE}")"
trap 'docker rm -f "${fs_cid}" >/dev/null 2>&1 || true' RETURN
staged=0
for fs_root in /usr/local/freesurfer /opt/freesurfer /freesurfer; do
  rm -f "${CTX}/freesurfer/FreeSurferColorLUT.txt"
  rm -f "${CTX}/freesurfer/bin/mri_label2vol" "${CTX}/freesurfer/bin/mri_convert"
  if docker cp "${fs_cid}:${fs_root}/FreeSurferColorLUT.txt" "${CTX}/freesurfer/" 2>/dev/null \
    && docker cp "${fs_cid}:${fs_root}/bin/mri_label2vol" "${CTX}/freesurfer/bin/" 2>/dev/null \
    && docker cp "${fs_cid}:${fs_root}/bin/mri_convert" "${CTX}/freesurfer/bin/" 2>/dev/null \
    && [[ -f "${CTX}/freesurfer/FreeSurferColorLUT.txt" ]] \
    && [[ -x "${CTX}/freesurfer/bin/mri_label2vol" ]] \
    && [[ -x "${CTX}/freesurfer/bin/mri_convert" ]]; then
    staged=1
    echo "  FreeSurfer staged from ${fs_root}"
    break
  fi
done
docker rm -f "${fs_cid}"
trap - RETURN
if [[ "${staged}" -eq 0 ]]; then
  echo "ERROR: could not stage mri_label2vol/mri_convert/LUT from ${FS_IMAGE}" >&2
  echo "  Tried: /usr/local/freesurfer /opt/freesurfer /freesurfer" >&2
  exit 1
fi

cp "${ROOT}/containers/connectome/run_connectome.sh" "${CTX}/"
cp "${ROOT}/containers/connectome/run_disconnectome.sh" "${CTX}/"
cp "${ROOT}/containers/connectome/mrtrix_lut/fs_dkt.txt" "${CTX}/dkt/lut/"
cp "${ROOT}/scripts/run_disconnectome.py" "${CTX}/dkt/"

echo "=== Connectome build context ready: ${CTX} ($(du -sh "${CTX}" | awk '{print $1}')) ==="
