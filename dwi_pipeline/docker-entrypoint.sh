#!/usr/bin/env bash
# Docker entrypoint for the DKT Connectome orchestrator image.
#
# BIDS App (default):  docker run … IMAGE /data/bids /out participant …
# Unified CLI:         docker run … IMAGE dkt install|check|…
#
# Optional first-run bootstrap:
#   -e DKT_AUTO_INSTALL=1
#   -v dkt_cache:/opt/dkt-connectome/containers
#   -e DKT_CONTAINER_CACHE=/opt/dkt-connectome/containers
set -euo pipefail
cd "$(dirname "$0")"

CACHE="${DKT_CONTAINER_CACHE:-/opt/dkt-connectome/containers}"

_config_writable() {
  local dest="$1" dir t
  dir="$(dirname "${dest}")"
  mkdir -p "${dir}" 2>/dev/null || return 1
  t="${dir}/.dkt_write_test"
  : > "${t}" 2>/dev/null || return 1
  rm -f "${t}"
}

if [[ "${DKT_AUTO_INSTALL:-0}" == "1" ]]; then
  CONFIG_OUT="${DKT_LOCAL_CONFIG:-workflow/config/config.local.yaml}"
  if ! _config_writable "${CONFIG_OUT}"; then
    CONFIG_OUT="${CACHE}/config.local.yaml"
    echo "[entrypoint] image config is read-only — writing ${CONFIG_OUT}" >&2
  fi
  export DKT_LOCAL_CONFIG="$(cd "$(dirname "${CONFIG_OUT}")" && pwd)/$(basename "${CONFIG_OUT}")"
  echo "[entrypoint] DKT_AUTO_INSTALL=1 — pulling missing step containers into ${CACHE}"
  bash scripts/install.sh \
    --cache "${CACHE}" \
    --config "${DKT_LOCAL_CONFIG}" \
    --missing-only \
    --no-doctor \
    --quiet \
    || echo "[entrypoint] auto-install had errors (continuing; dkt check for details)" >&2
fi

if [[ $# -eq 0 ]]; then
  exec ./run --help
fi

case "$1" in
  install|pull|log|check|version|doctor)
    exec ./dkt "$@"
    ;;
  dkt)
    shift
    exec ./dkt "$@"
    ;;
esac

exec ./run "$@"
