#!/usr/bin/env bash
# Stage Docker build context for lean dkt_connectome (Step 4 + 4.1) in CI.
#
# Uses Docker to extract ANTs/MRtrix from qsirecon and minimal FreeSurfer tools.
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

stage_from_docker() {
  local image="$1"
  local cid
  echo "  Pulling ${image}..."
  docker pull "${image}"
  cid="$(docker create "${image}")"
  trap 'docker rm -f "${cid}" >/dev/null 2>&1 || true' RETURN
  echo "$cid"
}

qsi_cid="$(stage_from_docker "${QSI_IMAGE}")"
for mrtrix_src in /opt/mrtrix3-latest /opt/mrtrix3; do
  if docker cp "${qsi_cid}:${mrtrix_src}/." "${CTX}/mrtrix3-latest/" 2>/dev/null \
    && [[ -x "${CTX}/mrtrix3-latest/bin/labelconvert" ]]; then
    echo "  MRtrix staged from ${mrtrix_src}"
    break
  fi
  rm -rf "${CTX}/mrtrix3-latest"/*
done
docker cp "${qsi_cid}:/opt/ants/." "${CTX}/ants/" 2>/dev/null || true
docker rm -f "${qsi_cid}"
trap - RETURN
[[ -x "${CTX}/ants/bin/antsRegistration" ]] || { echo "ERROR: ANTs staging failed"; exit 1; }
[[ -x "${CTX}/mrtrix3-latest/bin/labelconvert" ]] || { echo "ERROR: MRtrix staging failed"; exit 1; }

fs_cid="$(stage_from_docker "${FS_IMAGE}")"
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
if [[ "${staged}" -eq 0 ]]; then
  echo "  docker cp failed; trying docker export tar probe..."
  docker export "${fs_cid}" | tar -t 2>/dev/null | grep -E 'mri_label2vol|FreeSurferColorLUT' | head -5 || true
  for fs_root in usr/local/freesurfer opt/freesurfer freesurfer; do
    docker export "${fs_cid}" | tar -x -C "${CTX}/freesurfer" --strip-components=0 \
      "${fs_root}/FreeSurferColorLUT.txt" 2>/dev/null || true
    docker export "${fs_cid}" | tar -x -C "${CTX}/freesurfer/bin" \
      "${fs_root}/bin/mri_label2vol" "${fs_root}/bin/mri_convert" 2>/dev/null || true
    if [[ -f "${CTX}/freesurfer/FreeSurferColorLUT.txt" ]] \
      && [[ -x "${CTX}/freesurfer/bin/mri_label2vol" ]] \
      && [[ -x "${CTX}/freesurfer/bin/mri_convert" ]]; then
      staged=1
      echo "  FreeSurfer staged via export from ${fs_root}"
      break
    fi
  done
fi
docker rm -f "${fs_cid}"
trap - RETURN
[[ "${staged}" -eq 1 ]] || { echo "ERROR: FreeSurfer staging failed for ${FS_IMAGE}"; exit 1; }

cp "${ROOT}/containers/connectome/run_connectome.sh" "${CTX}/"
cp "${ROOT}/containers/connectome/run_disconnectome.sh" "${CTX}/"
cp "${ROOT}/containers/connectome/mrtrix_lut/fs_dkt.txt" "${CTX}/dkt/lut/"
cp "${ROOT}/scripts/run_disconnectome.py" "${CTX}/dkt/"

echo "=== Connectome build context ready: ${CTX} ($(du -sh "${CTX}" | awk '{print $1}')) ==="
