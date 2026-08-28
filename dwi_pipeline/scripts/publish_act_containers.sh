#!/usr/bin/env bash
# Build (optional) and publish Step 3.1 containers to Docker Hub and GHCR.
#
# Images (tag 0.1.0):
#   dkt-lesion-act, dkt-deep-atropos, dkt-deep-atropos-seg
#
# Usage:
#   export DOCKERHUB_USER=phindagijimana321
#   export DOCKERHUB_TOKEN=...
#   export GHCR_TOKEN=...          # GitHub PAT with write:packages (for GHCR push)
#   bash scripts/publish_act_containers.sh
#
# Optional:
#   CONTAINER_DIR=/path/to/others/containers
#   IMAGE_TAG=0.1.0
#   SKIP_BUILD=1
#   PUSH_GHCR=1                    # default 1 when GHCR_TOKEN set
#   PUSH_DOCKERHUB=1               # default 1 when DOCKERHUB_TOKEN set
#
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
CONTAINER_DIR="${CONTAINER_DIR:-${HOME}/.cache/dkt-connectome/containers}"
IMAGE_TAG="${IMAGE_TAG:-0.1.0}"
DOCKERHUB_USER="${DOCKERHUB_USER:-phindagijimana321}"
GHCR_OWNER="${GHCR_OWNER:-phindagijimana}"
SKIP_BUILD="${SKIP_BUILD:-0}"
PUSH_GHCR="${PUSH_GHCR:-$([[ -n "${GHCR_TOKEN:-}" ]] && echo 1 || echo 0)}"
PUSH_DOCKERHUB="${PUSH_DOCKERHUB:-$([[ -n "${DOCKERHUB_TOKEN:-}" ]] && echo 1 || echo 0)}"

authfile_dockerhub() {
  [[ -n "${DOCKERHUB_TOKEN:-}" ]] || return 1
  local f
  f="$(mktemp)"
  printf '{"auths":{"https://index.docker.io/v1/":{"username":"%s","password":"%s"}}}\n' \
    "${DOCKERHUB_USER}" "${DOCKERHUB_TOKEN}" > "${f}"
  echo "${f}"
}

authfile_ghcr() {
  [[ -n "${GHCR_TOKEN:-}" ]] || return 1
  local f user
  f="$(mktemp)"
  user="${GHCR_USER:-${GITHUB_ACTOR:-${DOCKERHUB_USER}}}"
  printf '{"auths":{"ghcr.io":{"username":"%s","password":"%s"}}}\n' \
    "${user}" "${GHCR_TOKEN}" > "${f}"
  echo "${f}"
}

resolve_authfile() {
  if [[ -n "${DOCKERHUB_TOKEN:-}" ]]; then
    authfile_dockerhub
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

resolve_ghcr_authfile() {
  if [[ -n "${GHCR_TOKEN:-}" ]]; then
    authfile_ghcr
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
  local sif="$1" registry="$2" repo="$3" authfile="$4"
  apptainer push --allow-unsigned --authfile "${authfile}" "${sif}" \
    "oras://${registry}/${repo}:${IMAGE_TAG}"
}

publish_one() {
  local sif="$1" dh_repo="$2" ghcr_repo="$3"
  [[ -f "${sif}" ]] || { echo "ERROR: missing SIF: ${sif}" >&2; exit 1; }
  echo "=== ${dh_repo} ==="
  if [[ "${PUSH_DOCKERHUB}" == "1" ]]; then
    local dh_auth
    dh_auth="$(resolve_authfile)" || { echo "ERROR: set DOCKERHUB_TOKEN or podman/apptainer login docker.io" >&2; exit 1; }
    trap '[[ "${dh_auth}" == /tmp/* ]] && rm -f "${dh_auth}"' RETURN
    push_sif "${sif}" "registry-1.docker.io/${DOCKERHUB_USER}" "${dh_repo}" "${dh_auth}"
    echo "  Docker Hub: docker pull ${DOCKERHUB_USER}/${dh_repo}:${IMAGE_TAG}"
  fi
  if [[ "${PUSH_GHCR}" == "1" ]]; then
    local gh_auth
    gh_auth="$(resolve_ghcr_authfile)" || { echo "ERROR: set GHCR_TOKEN or podman/apptainer login ghcr.io" >&2; exit 1; }
    trap '[[ "${gh_auth}" == /tmp/* ]] && rm -f "${gh_auth}"' RETURN
    push_sif "${sif}" "ghcr.io/${GHCR_OWNER}" "${ghcr_repo}" "${gh_auth}"
    echo "  GHCR: oras://ghcr.io/${GHCR_OWNER}/${ghcr_repo}:${IMAGE_TAG}"
  fi
}

# Auto-push when credentials or logged-in registries are available
if [[ "${PUSH_DOCKERHUB}" == "0" && "${PUSH_GHCR}" == "0" ]]; then
  resolve_authfile >/dev/null 2>&1 && PUSH_DOCKERHUB=1 || true
  resolve_ghcr_authfile >/dev/null 2>&1 && PUSH_GHCR=1 || true
fi

if [[ "${SKIP_BUILD}" != "1" ]]; then
  echo "=== Rebuild dkt_lesion_act.sif ==="
  CONTAINER_QSIRECON="${CONTAINER_DIR}/qsirecon.sif" \
    OUT_SIF="${CONTAINER_DIR}/dkt_lesion_act.sif" BACKUP_EXISTING=0 \
    bash "${ROOT}/containers/lesion_act/build_lesion_act.sh"

  echo "=== Rebuild dkt_deep_atropos.sif ==="
  CONTAINER_QSIRECON="${CONTAINER_DIR}/qsirecon.sif" \
    OUT_SIF="${CONTAINER_DIR}/dkt_deep_atropos.sif" BACKUP_EXISTING=0 \
    bash "${ROOT}/containers/deep_atropos/build_deep_atropos.sh"

  echo "=== Rebuild dkt_deep_atropos_seg.sif ==="
  OUT_SIF="${CONTAINER_DIR}/dkt_deep_atropos_seg.sif" BACKUP_EXISTING=0 \
    bash "${ROOT}/containers/deep_atropos_seg/build_deep_atropos_seg.sh"
fi

publish_one "${CONTAINER_DIR}/dkt_lesion_act.sif" "dkt-lesion-act" "dkt-lesion-act"
publish_one "${CONTAINER_DIR}/dkt_deep_atropos.sif" "dkt-deep-atropos" "dkt-deep-atropos"
publish_one "${CONTAINER_DIR}/dkt_deep_atropos_seg.sif" "dkt-deep-atropos-seg" "dkt-deep-atropos-seg"

echo "=== Done ==="
