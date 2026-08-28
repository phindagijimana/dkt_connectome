#!/usr/bin/env bash
# Push dkt_deep_atropos_seg.sif to Docker Hub.
set -euo pipefail
DOCKERHUB_USER="${DOCKERHUB_USER:-phindagijimana321}"
IMAGE_NAME="${IMAGE_NAME:-dkt-deep-atropos-seg}"
IMAGE_TAG="${IMAGE_TAG:-0.1.0}"
SIF="${SIF:-/path/to/others/containers/dkt_deep_atropos_seg.sif}"
[[ -f "${SIF}" ]] || { echo "ERROR: missing SIF: ${SIF}"; exit 1; }
[[ -n "${DOCKERHUB_TOKEN:-}" ]] || { echo "ERROR: set DOCKERHUB_TOKEN"; exit 1; }
AUTHFILE="$(mktemp)"
trap 'rm -f "${AUTHFILE}"' EXIT
printf '{"auths":{"https://index.docker.io/v1/":{"username":"%s","password":"%s"}}}\n' \
  "${DOCKERHUB_USER}" "${DOCKERHUB_TOKEN}" > "${AUTHFILE}"
echo "=== Pushing ${SIF} -> docker.io/${DOCKERHUB_USER}/${IMAGE_NAME}:${IMAGE_TAG} ==="
apptainer push --allow-unsigned --authfile "${AUTHFILE}" "${SIF}" \
  "oras://registry-1.docker.io/${DOCKERHUB_USER}/${IMAGE_NAME}:${IMAGE_TAG}"
