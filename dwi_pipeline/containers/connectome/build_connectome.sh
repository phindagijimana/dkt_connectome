#!/usr/bin/env bash
# Build dkt_connectome.sif — lean shareable Step 4 image (~500 MB).
#
# Stages from your existing pipeline SIFs (no version drift vs dual-container Step 4):
#   freesurfer_7.4.1.sif  → mri_label2vol, mri_convert, FreeSurferColorLUT.txt (~8 MB)
#   qsirecon.sif          → /opt/ants + /opt/mrtrix3-latest (~455 MB)
#
# FreeSurfer license is bind-mounted at runtime, not baked in.
#
# Usage:
#   bash build_connectome.sh
#   SKIP_STAGE=1 bash build_connectome.sh
#
set -euo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
CTX="${HERE}/build_ctx_lean"
APPTAINER_TMPDIR="${APPTAINER_TMPDIR:-${HERE}/.apptainer_tmp}"
export APPTAINER_TMPDIR SINGULARITY_TMPDIR="${APPTAINER_TMPDIR}" PROOT_TMP_DIR="${APPTAINER_TMPDIR}"
mkdir -p "${APPTAINER_TMPDIR}"

FS_SIF="${CONTAINER_FREESURFER:-/path/to/others/containers/freesurfer_7.4.1.sif}"
QSI_SIF="${CONTAINER_QSIRECON:-/path/to/others/containers/qsirecon.sif}"
OUT_SIF="${OUT_SIF:-/path/to/others/containers/dkt_connectome.sif}"
IMAGE_TAG="${IMAGE_TAG:-dkt_connectome:latest}"

echo "=== dkt_connectome build (legacy-staged lean) ==="
echo "  FS source:  ${FS_SIF}"
echo "  QSI source: ${QSI_SIF}"
echo "  Output SIF: ${OUT_SIF}"

[[ -f "${FS_SIF}" ]] || { echo "ERROR: FreeSurfer SIF not found: ${FS_SIF}"; exit 1; }
[[ -f "${QSI_SIF}" ]] || { echo "ERROR: QSIRecon SIF not found: ${QSI_SIF}"; exit 1; }

stage_freesurfer_minimal() {
  local dest="${CTX}/freesurfer"
  mkdir -p "${dest}/bin"

  if [[ -f "${FS_SIF}" && "${USE_HOST_FREESURFER:-0}" != "1" ]]; then
    echo "  FreeSurfer source: ${FS_SIF} (mri_label2vol, mri_convert, LUT only)"
    local fs_root
    fs_root="$(apptainer exec "${FS_SIF}" bash -lc '
      for d in /usr/local/freesurfer /opt/freesurfer /freesurfer; do
        [[ -f "${d}/FreeSurferColorLUT.txt" ]] && { echo "${d}"; exit 0; }
      done
      exit 1
    ')"
    apptainer exec "${FS_SIF}" cat "${fs_root}/FreeSurferColorLUT.txt" > "${dest}/FreeSurferColorLUT.txt"
    apptainer exec "${FS_SIF}" tar -C "${fs_root}/bin" -cf - mri_label2vol mri_convert \
      | tar -C "${dest}/bin" -xf -
  elif [[ -n "${FREESURFER_HOME:-}" && -f "${FREESURFER_HOME}/FreeSurferColorLUT.txt" ]]; then
    echo "  FreeSurfer source: host FREESURFER_HOME=${FREESURFER_HOME}"
    cp "${FREESURFER_HOME}/FreeSurferColorLUT.txt" "${dest}/"
    cp "${FREESURFER_HOME}/bin/mri_label2vol" "${FREESURFER_HOME}/bin/mri_convert" "${dest}/bin/"
  else
    echo "ERROR: set CONTAINER_FREESURFER or USE_HOST_FREESURFER=1 with FREESURFER_HOME"
    exit 1
  fi

  [[ -f "${dest}/FreeSurferColorLUT.txt" ]] || { echo "ERROR: missing FreeSurferColorLUT.txt"; exit 1; }
  [[ -x "${dest}/bin/mri_label2vol" && -x "${dest}/bin/mri_convert" ]] \
    || { echo "ERROR: missing mri_label2vol or mri_convert"; exit 1; }
  echo "  FreeSurfer staged: $(du -sh "${dest}" | awk '{print $1}')"
}

stage_from_qsirecon() {
  local dest_ants="${CTX}/ants"
  local dest_mrtrix="${CTX}/mrtrix3-latest"
  rm -rf "${dest_ants}" "${dest_mrtrix}"
  mkdir -p "${dest_ants}" "${dest_mrtrix}"

  echo "  Staging ANTs from ${QSI_SIF}..."
  apptainer exec "${QSI_SIF}" tar -C /opt/ants -cf - . | tar -C "${dest_ants}" -xf -
  [[ -x "${dest_ants}/bin/antsRegistration" ]] || { echo "ERROR: ANTs staging failed"; exit 1; }
  echo "  ANTs staged: $(du -sh "${dest_ants}" | awk '{print $1}')"

  echo "  Staging MRtrix from ${QSI_SIF}..."
  apptainer exec "${QSI_SIF}" tar -C /opt/mrtrix3-latest -cf - . | tar -C "${dest_mrtrix}" -xf -
  [[ -x "${dest_mrtrix}/bin/labelconvert" ]] || { echo "ERROR: MRtrix staging failed"; exit 1; }
  echo "  MRtrix staged: $(du -sh "${dest_mrtrix}" | awk '{print $1}')"
}

if [[ "${SKIP_STAGE:-0}" == "1" \
      && -x "${CTX}/freesurfer/bin/mri_label2vol" \
      && -x "${CTX}/ants/bin/antsRegistration" \
      && -x "${CTX}/mrtrix3-latest/bin/labelconvert" ]]; then
  echo "  SKIP_STAGE=1: reusing ${CTX}/"
else
  rm -rf "${CTX}"
  mkdir -p "${CTX}"
  stage_freesurfer_minimal
  stage_from_qsirecon
fi

cp "${HERE}/run_connectome.sh" "${CTX}/"
cp "${HERE}/run_disconnectome.sh" "${CTX}/"
mkdir -p "${CTX}/dkt/lut"
cp "${HERE}/mrtrix_lut/fs_dkt.txt" "${CTX}/dkt/lut/"
cp "${HERE}/../../scripts/run_disconnectome.py" "${CTX}/dkt/"
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

echo "=== Build complete: ${OUT_SIF} ($(du -sh "${OUT_SIF}" | awk '{print $1}')) ==="
apptainer run "${OUT_SIF}" --help | head -5
