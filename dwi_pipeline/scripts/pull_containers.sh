#!/usr/bin/env bash
# Pull pinned Apptainer .sif images into DKT_CONTAINER_CACHE.
# See scripts/container_install.py and bash scripts/install.sh.
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
exec python3 "${SCRIPT_DIR}/container_install.py" pull "$@"
