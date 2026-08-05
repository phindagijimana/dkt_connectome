#!/usr/bin/env bash
# Push dkt_connectome.sif to Docker Hub as an OCI image (Apptainer oras transport).
#
# Prerequisites:
#   - apptainer
#   - Existing .../others/containers/dkt_connectome.sif (build first)
#   - Docker Hub credentials
#
# Usage:
#   export DOCKERHUB_USER=phindagijimana321
#   export DOCKERHUB_TOKEN=...   # Docker Hub access token (not password)
#   bash publish_dockerhub.sh
#
# Optional:
#   IMAGE_TAG=2.1.0 bash publish_dockerhub.sh
#
set -euo pipefail

DOCKERHUB_USER="${DOCKERHUB_USER:-phindagijimana321}"
IMAGE_NAME="${IMAGE_NAME:-dkt_connectome}"
IMAGE_TAG="${IMAGE_TAG:-latest}"
SIF="${SIF:-/path/to/others/containers/dkt_connectome.sif}"
URI="oras://registry-1.docker.io/${DOCKERHUB_USER}/${IMAGE_NAME}:${IMAGE_TAG}"

[[ -f "${SIF}" ]] || { echo "ERROR: missing SIF: ${SIF}"; exit 1; }
[[ -n "${DOCKERHUB_TOKEN:-}" ]] || {
  echo "ERROR: set DOCKERHUB_TOKEN (Docker Hub access token)"
  echo "  https://hub.docker.com/settings/security"
  exit 1
}

AUTHFILE="$(mktemp)"
trap 'rm -f "${AUTHFILE}"' EXIT
echo "{\"auths\":{\"https://index.docker.io/v1/\":{\"username\":\"${DOCKERHUB_USER}\",\"password\":\"${DOCKERHUB_TOKEN}\"}}}" > "${AUTHFILE}"

echo "=== Pushing ${SIF} -> ${URI} ==="
apptainer push --allow-unsigned --authfile "${AUTHFILE}" "${SIF}" "${URI}"
echo "=== Published: docker pull ${DOCKERHUB_USER}/${IMAGE_NAME}:${IMAGE_TAG} ==="
