#!/usr/bin/env bash
# Docker entrypoint for the DKT Connectome orchestrator image.
# Step containers (QSIPrep, FreeSurfer, etc.) must be provided via bind-mount
# or CONTAINER_* environment variables pointing to Apptainer/Docker images on the host.
set -euo pipefail
cd "$(dirname "$0")"
if [[ $# -eq 0 ]]; then
  exec ./run --help
fi
exec ./run "$@"
