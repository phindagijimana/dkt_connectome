#!/usr/bin/env bash
# Mirror the orchestrator image GHCR -> Docker Hub (uses existing podman/skopeo login).
#
# CI always pushes to ghcr.io/phindagijimana/dkt-connectome; run this on OOD/HPC
# when DOCKERHUB_* GitHub secrets are not configured.
#
# Usage:
#   podman login docker.io   # once, as phindagijimana321
#   bash scripts/mirror_ghcr_to_dockerhub.sh
#   bash scripts/mirror_ghcr_to_dockerhub.sh --version 0.2.0
#
set -euo pipefail

VERSION="0.2.1"
GHCR_IMAGE="ghcr.io/phindagijimana/dkt-connectome"
DHUB_IMAGE="phindagijimana321/dkt-connectome"
AUTHFILE="${PODMAN_AUTHFILE:-${HOME}/.config/containers/auth.json}"
TMPDIR="${SKOPEO_TMPDIR:-/tmp/skopeo-${USER:-user}}"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --version) VERSION="$2"; shift 2 ;;
    -h|--help)
      sed -n '2,11p' "$0" | sed 's/^# \{0,1\}//'
      exit 0
      ;;
    *) echo "Unknown option: $1" >&2; exit 2 ;;
  esac
done

command -v skopeo >/dev/null || { echo "ERROR: skopeo required" >&2; exit 1; }
[[ -f "${AUTHFILE}" ]] || { echo "ERROR: missing ${AUTHFILE} — run: podman login docker.io" >&2; exit 1; }

mkdir -p "${TMPDIR}"
export TMPDIR

copy_tag() {
  local tag="$1"
  echo "=== skopeo copy ${GHCR_IMAGE}:${tag} -> docker://${DHUB_IMAGE}:${tag} ==="
  skopeo copy --authfile "${AUTHFILE}" --tmpdir "${TMPDIR}" \
    "docker://${GHCR_IMAGE}:${tag}" \
    "docker://${DHUB_IMAGE}:${tag}"
}

copy_tag "${VERSION}"
if [[ "${VERSION}" != "latest" ]]; then
  copy_tag "latest"
fi

echo "=== Published docker pull ${DHUB_IMAGE}:${VERSION} ==="
