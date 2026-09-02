#!/usr/bin/env bash
# Stage Docker build context for lean dkt_connectome (Step 4 + 4.1) in CI.
# Uses selective docker cp (no multi-GB apptainer pull).
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
CTX="${ROOT}/containers/connectome/build_ctx_lean"
FS_IMAGE="${FS_IMAGE:-freesurfer/freesurfer:7.4.1}"

rm -rf "${CTX}"
mkdir -p "${CTX}/freesurfer/bin" "${CTX}/dkt/lut" "${CTX}/ants" "${CTX}/mrtrix3-latest"

echo "=== Stage connectome build context ==="
bash "${ROOT}/scripts/stage_qsirecon_tools.sh" "${CTX}/mrtrix3-latest" "${CTX}/ants"

echo "  Docker pull ${FS_IMAGE} (minimal FS tools only)..."
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
    && [[ -x "${CTX}/freesurfer/bin/mri_label2vol" ]]; then
    staged=1
    echo "  FreeSurfer staged from ${fs_root}"
    break
  fi
done
docker rm -f "${fs_cid}"
trap - RETURN

if [[ "${staged}" -eq 0 ]]; then
  echo "ERROR: FreeSurfer staging failed — set FS_IMAGE or push connectome SIF manually" >&2
  exit 1
fi

cp "${ROOT}/containers/connectome/run_connectome.sh" "${CTX}/"
cp "${ROOT}/containers/connectome/run_disconnectome.sh" "${CTX}/"
cp "${ROOT}/containers/connectome/mrtrix_lut/fs_dkt.txt" "${CTX}/dkt/lut/"
cp "${ROOT}/scripts/run_disconnectome.py" "${CTX}/dkt/"

echo "=== Connectome build context ready: ${CTX} ($(du -sh "${CTX}" | awk '{print $1}')) ==="
