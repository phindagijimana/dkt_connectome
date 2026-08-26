#!/usr/bin/env bash
# Build (if needed) and publish Step 1.5 VBT + Step 3.5 lesion-aware ACT to Docker Hub.
#
# Usage:
#   export DOCKERHUB_USER=phindagijimana321
#   export DOCKERHUB_TOKEN=...    # https://hub.docker.com/settings/security
#   bash scripts/publish_vbt_lesion_act.sh
#
# Optional:
#   CONTAINER_DIR=/path/to/others/containers
#   IMAGE_TAG=0.1.0
#   SKIP_BUILD=1                  # push existing .sif only
#   MIRROR_FROM_GHCR=1            # skopeo copy GHCR -> Docker Hub (no local .sif)
#
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
CONTAINER_DIR="${CONTAINER_DIR:-/path/to/others/containers}"
IMAGE_TAG="${IMAGE_TAG:-0.1.0}"
DOCKERHUB_USER="${DOCKERHUB_USER:-phindagijimana321}"
SKIP_BUILD="${SKIP_BUILD:-0}"
MIRROR_FROM_GHCR="${MIRROR_FROM_GHCR:-0}"

authfile_from_token() {
  [[ -n "${DOCKERHUB_TOKEN:-}" ]] || return 1
  local f
  f="$(mktemp)"
  printf '{"auths":{"https://index.docker.io/v1/":{"username":"%s","password":"%s"}}}\n' \
    "${DOCKERHUB_USER}" "${DOCKERHUB_TOKEN}" > "${f}"
  echo "${f}"
}

resolve_authfile() {
  if [[ -n "${DOCKERHUB_TOKEN:-}" ]]; then
    authfile_from_token
    return
  fi
  for candidate in \
    "${XDG_RUNTIME_DIR}/containers/auth.json" \
    "${HOME}/.config/containers/auth.json" \
    "${HOME}/.docker/config.json"; do
    if [[ -f "${candidate}" ]]; then
      echo "${candidate}"
      return
    fi
  done
  return 1
}

push_sif() {
  local sif="$1" repo="$2"
  local authfile
  authfile="$(resolve_authfile)" || {
    echo "ERROR: set DOCKERHUB_TOKEN or podman login docker.io" >&2
    exit 1
  }
  trap '[[ "${authfile}" == /tmp/* ]] && rm -f "${authfile}"' RETURN
  apptainer push --allow-unsigned --authfile "${authfile}" "${sif}" \
    "oras://registry-1.docker.io/${DOCKERHUB_USER}/${repo}:${IMAGE_TAG}"
}

mirror_ghcr() {
  local ghcr="$1" repo="$2"
  local authfile
  authfile="$(resolve_authfile)" || {
    echo "ERROR: set DOCKERHUB_TOKEN or podman login docker.io" >&2
    exit 1
  }
  skopeo copy --dest-authfile "${authfile}" \
    "docker://${ghcr}:${IMAGE_TAG}" \
    "docker://${DOCKERHUB_USER}/${repo}:${IMAGE_TAG}"
}

if [[ "${MIRROR_FROM_GHCR}" == "1" ]]; then
  echo "=== Mirror GHCR -> Docker Hub (${IMAGE_TAG}) ==="
  mirror_ghcr "ghcr.io/phindagijimana/dkt-vbt" "dkt-vbt"
  mirror_ghcr "ghcr.io/phindagijimana/dkt-lesion-act" "dkt-lesion-act"
  exit 0
fi

if [[ "${SKIP_BUILD}" != "1" ]]; then
  echo "=== Build dkt_lesion_act.sif ==="
  CONTAINER_QSIRECON="${CONTAINER_DIR}/qsirecon.sif" \
    OUT_SIF="${CONTAINER_DIR}/dkt_lesion_act.sif" \
    BACKUP_EXISTING=0 \
    bash "${ROOT}/containers/lesion_act/build_lesion_act.sh"

  echo "=== Build dkt_vbt.sif ==="
  CONTAINER_QSIPREP="${CONTAINER_DIR}/qsiprep.sif" \
    OUT_SIF="${CONTAINER_DIR}/dkt_vbt.sif" \
    BACKUP_EXISTING=0 \
    bash "${ROOT}/containers/vbt/build_vbt.sh"
fi

echo "=== Push to Docker Hub (${IMAGE_TAG}) ==="
push_sif "${CONTAINER_DIR}/dkt_lesion_act.sif" "dkt-lesion-act"
push_sif "${CONTAINER_DIR}/dkt_vbt.sif" "dkt-vbt"

echo "=== Done ==="
echo "  docker pull ${DOCKERHUB_USER}/dkt-vbt:${IMAGE_TAG}"
echo "  docker pull ${DOCKERHUB_USER}/dkt-lesion-act:${IMAGE_TAG}"
