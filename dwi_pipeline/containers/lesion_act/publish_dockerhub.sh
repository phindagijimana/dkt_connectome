#!/usr/bin/env bash
# Push dkt_lesion_act.sif to Docker Hub as an OCI image (Apptainer oras transport).
#
# Prerequisites:
#   - apptainer
#   - Existing dkt_lesion_act.sif (build first: bash build_lesion_act.sh)
#   - DOCKERHUB_TOKEN (access token, not password)
#
# Usage:
#   export DOCKERHUB_USER=phindagijimana321
#   export DOCKERHUB_TOKEN=...
#   bash publish_dockerhub.sh
#
# Optional:
#   IMAGE_TAG=0.1.0 SIF=/path/to/dkt_lesion_act.sif bash publish_dockerhub.sh
#
set -euo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"

DOCKERHUB_USER="${DOCKERHUB_USER:-phindagijimana321}"
IMAGE_NAME="${IMAGE_NAME:-dkt-lesion-act}"
IMAGE_TAG="${IMAGE_TAG:-0.1.0}"
SIF="${SIF:-/path/to/others/containers/dkt_lesion_act.sif}"
URI="oras://registry-1.docker.io/${DOCKERHUB_USER}/${IMAGE_NAME}:${IMAGE_TAG}"

[[ -f "${SIF}" ]] || { echo "ERROR: missing SIF: ${SIF}"; exit 1; }
[[ -n "${DOCKERHUB_TOKEN:-}" ]] || {
  echo "ERROR: set DOCKERHUB_TOKEN (Docker Hub access token)"
  echo "  https://hub.docker.com/settings/security"
  exit 1
}

AUTHFILE="$(mktemp)"
trap 'rm -f "${AUTHFILE}"' EXIT
printf '{"auths":{"https://index.docker.io/v1/":{"username":"%s","password":"%s"}}}\n' \
  "${DOCKERHUB_USER}" "${DOCKERHUB_TOKEN}" > "${AUTHFILE}"

echo "=== Pushing ${SIF} -> ${URI} ==="
apptainer push --allow-unsigned --authfile "${AUTHFILE}" "${SIF}" "${URI}"
echo "=== Published: docker pull ${DOCKERHUB_USER}/${IMAGE_NAME}:${IMAGE_TAG} ==="
echo "=== Apptainer: apptainer pull docker://${DOCKERHUB_USER}/${IMAGE_NAME}:${IMAGE_TAG} ==="
