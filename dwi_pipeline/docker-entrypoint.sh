#!/usr/bin/env bash
# Docker entrypoint for the DKT Connectome orchestrator image.
#
# Optional first-run bootstrap:
#   -e DKT_AUTO_INSTALL=1
#   -v dkt_cache:/opt/dkt-connectome/containers
#   -e DKT_CONTAINER_CACHE=/opt/dkt-connectome/containers
#
# Step containers land in DKT_CONTAINER_CACHE; config.local.yaml is written on install.
set -euo pipefail
cd "$(dirname "$0")"

CACHE="${DKT_CONTAINER_CACHE:-/opt/dkt-connectome/containers}"

if [[ "${DKT_AUTO_INSTALL:-0}" == "1" ]]; then
  echo "[entrypoint] DKT_AUTO_INSTALL=1 — pulling missing step containers into ${CACHE}"
  bash scripts/install.sh \
    --cache "${CACHE}" \
    --config workflow/config/config.local.yaml \
    --missing-only \
    --no-doctor \
    --quiet \
    || echo "[entrypoint] auto-install had errors (continuing; ./run doctor for details)" >&2
fi

if [[ $# -eq 0 ]]; then
  exec ./run --help
fi
exec ./run "$@"
