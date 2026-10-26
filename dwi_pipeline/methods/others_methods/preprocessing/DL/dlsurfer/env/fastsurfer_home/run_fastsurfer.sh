#!/bin/bash
set -euo pipefail
: "${DLSURFER_SIF_FASTSURFER:?source env/cluster_containers.sh}"
: "${FS_LICENSE:?}"
NV=()
if [[ "${DLSURFER_FASTSURFER_NV:-1}" == "1" ]] && command -v nvidia-smi >/dev/null 2>&1; then
  NV=(--nv)
fi
exec apptainer exec "${NV[@]}" \
  -B /mnt/nfs \
  -B "${FS_LICENSE}:${FS_LICENSE}:ro" \
  --env "FS_LICENSE=${FS_LICENSE}" \
  "$DLSURFER_SIF_FASTSURFER" \
  /fastsurfer/run_fastsurfer.sh "$@"
