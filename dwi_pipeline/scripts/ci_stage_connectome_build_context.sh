#!/usr/bin/env bash
# Stage Docker build context for lean dkt_connectome (Step 4 + 4.1) in CI.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
CTX="${ROOT}/containers/connectome/build_ctx_lean"
FS_IMAGE="${FS_IMAGE:-freesurfer/freesurfer:7.4.1}"
WORK="${WORK:-/tmp/dkt_connectome_ci}"
mkdir -p "${WORK}" "${CTX}/freesurfer/bin" "${CTX}/dkt/lut"

rm -rf "${CTX}/ants" "${CTX}/mrtrix3-latest"
mkdir -p "${CTX}/ants" "${CTX}/mrtrix3-latest"

echo "=== Stage connectome build context ==="
bash "${ROOT}/scripts/stage_qsirecon_tools.sh" "${CTX}/mrtrix3-latest" "${CTX}/ants"

FS_SIF="${WORK}/freesurfer.sif"
echo "  Apptainer pull ${FS_IMAGE}..."
apptainer pull --force "${FS_SIF}" "docker://${FS_IMAGE}"

apptainer exec "${FS_SIF}" bash -lc '
  for d in /usr/local/freesurfer /opt/freesurfer /freesurfer; do
    [[ -f "${d}/FreeSurferColorLUT.txt" ]] && { echo "${d}"; exit 0; }
  done
  exit 1
' > "${WORK}/fs_root.txt"
fs_root="$(tr -d "\r\n" < "${WORK}/fs_root.txt")"
apptainer exec "${FS_SIF}" cat "${fs_root}/FreeSurferColorLUT.txt" > "${CTX}/freesurfer/FreeSurferColorLUT.txt"
apptainer exec "${FS_SIF}" tar -C "${fs_root}/bin" -cf - mri_label2vol mri_convert \
  | tar -C "${CTX}/freesurfer/bin" -xf -

cp "${ROOT}/containers/connectome/run_connectome.sh" "${CTX}/"
cp "${ROOT}/containers/connectome/run_disconnectome.sh" "${CTX}/"
cp "${ROOT}/containers/connectome/mrtrix_lut/fs_dkt.txt" "${CTX}/dkt/lut/"
cp "${ROOT}/scripts/run_disconnectome.py" "${CTX}/dkt/"

echo "=== Connectome build context ready: ${CTX} ($(du -sh "${CTX}" | awk '{print $1}')) ==="
