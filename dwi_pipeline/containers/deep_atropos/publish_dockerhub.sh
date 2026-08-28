#!/usr/bin/env bash
# Push dkt_deep_atropos.sif to Docker Hub as an OCI image (Apptainer oras transport).
#
# Usage:
#   export DOCKERHUB_USER=phindagijimana321
#   export DOCKERHUB_TOKEN=...
#   SIF=/path/to/dkt_deep_atropos.sif bash publish_dockerhub.sh
#
# Publish all Step 3.1 images (Docker Hub + GHCR): ../../scripts/publish_act_containers.sh
set -euo pipefail

DOCKERHUB_USER="${DOCKERHUB_USER:-phindagijimana321}"
IMAGE_NAME="${IMAGE_NAME:-dkt-deep-atropos}"
IMAGE_TAG="${IMAGE_TAG:-0.1.0}"
SIF="${SIF:-/path/to/others/containers/dkt_deep_atropos.sif}"
URI="oras://registry-1.docker.io/${DOCKERHUB_USER}/${IMAGE_NAME}:${IMAGE_TAG}"

[[ -f "${SIF}" ]] || { echo "ERROR: missing SIF: ${SIF}"; exit 1; }
[[ -n "${DOCKERHUB_TOKEN:-}" ]] || {
  echo "ERROR: set DOCKERHUB_TOKEN (Docker Hub access token)"
  exit 1
}

AUTHFILE="$(mktemp)"
trap 'rm -f "${AUTHFILE}"' EXIT
printf '{"auths":{"https://index.docker.io/v1/":{"username":"%s","password":"%s"}}}\n' \
  "${DOCKERHUB_USER}" "${DOCKERHUB_TOKEN}" > "${AUTHFILE}"

echo "=== Pushing ${SIF} -> ${URI} ==="
apptainer push --allow-unsigned --authfile "${AUTHFILE}" "${SIF}" "${URI}"
echo "=== Published: docker pull ${DOCKERHUB_USER}/${IMAGE_NAME}:${IMAGE_TAG} ==="
