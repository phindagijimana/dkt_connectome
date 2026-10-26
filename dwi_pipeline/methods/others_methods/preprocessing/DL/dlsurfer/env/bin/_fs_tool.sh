#!/bin/bash
set -euo pipefail
TOOL="$(basename "$0")"
: "${DLSURFER_SIF_FREESURFER:?source env/cluster_containers.sh}"
: "${FS_LICENSE:?}"
NV=()
# GPU tools (TopoFit / SynthSeg / SynthSR / …) need host NVIDIA driver bind.
if [[ "${DLSURFER_FS_NV:-1}" == "1" ]] && command -v nvidia-smi >/dev/null 2>&1; then
  NV=(--nv)
fi
# Propagate SUBJECTS_DIR so mri_surf2surf / recon-all see host trees (not only SIF subjects).
ENV_ARGS=(--env "FS_LICENSE=${FS_LICENSE}")
if [[ -n "${SUBJECTS_DIR:-}" ]]; then
  ENV_ARGS+=(--env "SUBJECTS_DIR=${SUBJECTS_DIR}")
fi
exec apptainer exec \
  "${NV[@]}" \
  -B /mnt/nfs \
  -B "${FS_LICENSE}:${FS_LICENSE}:ro" \
  "${ENV_ARGS[@]}" \
  "$DLSURFER_SIF_FREESURFER" \
  "$TOOL" "$@"
