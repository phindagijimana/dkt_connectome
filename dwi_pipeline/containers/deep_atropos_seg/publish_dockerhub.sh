#!/usr/bin/env bash
# Push dkt_deep_atropos_seg.sif to Docker Hub as an OCI image (Apptainer oras transport).
#
# Manual use only: CI (.github/workflows/act_containers_publish.yml) normally
# builds this image from the Dockerfile and pushes it to GHCR (and to Docker Hub
# when DOCKERHUB_* secrets are set) on every push to main that touches this
# container. Use this script to mirror a locally built SIF by hand.
#
# Prerequisites:
#   - apptainer
#   - Existing dkt_deep_atropos_seg.sif (build first: bash build_deep_atropos_seg.sh)
#   - DOCKERHUB_TOKEN (access token, not password); no `docker login` needed,
#     the token is written to a temporary auth file for this push only
#
# Usage:
#   export DOCKERHUB_USER=phindagijimana321
#   export DOCKERHUB_TOKEN=...
#   SIF=/path/to/dkt_deep_atropos_seg.sif bash publish_dockerhub.sh
#
# Environment variables (all optional except DOCKERHUB_TOKEN):
#   DOCKERHUB_USER   Docker Hub namespace to push to (default: phindagijimana321)
#   DOCKERHUB_TOKEN  Docker Hub access token (required)
#   IMAGE_NAME       Repository name (default: dkt-deep-atropos-seg)
#   IMAGE_TAG        Tag to push (default: 0.1.0)
#   SIF              Path to the SIF to push
#
# Publish all Step 3.1 images (Docker Hub + GHCR): ../../scripts/publish_act_containers.sh
set -euo pipefail

DOCKERHUB_USER="${DOCKERHUB_USER:-phindagijimana321}"
IMAGE_NAME="${IMAGE_NAME:-dkt-deep-atropos-seg}"
IMAGE_TAG="${IMAGE_TAG:-0.1.0}"
SIF="${SIF:-/path/to/others/containers/dkt_deep_atropos_seg.sif}"
URI="oras://registry-1.docker.io/${DOCKERHUB_USER}/${IMAGE_NAME}:${IMAGE_TAG}"

[[ -f "${SIF}" ]] || { echo "ERROR: missing SIF: ${SIF}"; exit 1; }
[[ -n "${DOCKERHUB_TOKEN:-}" ]] || {
  echo "ERROR: set DOCKERHUB_TOKEN (Docker Hub access token)"
  echo "  https://hub.docker.com/settings/security"
  exit 1
}

# Temporary auth file (deleted on exit) so the token is not persisted to any login config.
AUTHFILE="$(mktemp)"
trap 'rm -f "${AUTHFILE}"' EXIT
printf '{"auths":{"https://index.docker.io/v1/":{"username":"%s","password":"%s"}}}\n' \
  "${DOCKERHUB_USER}" "${DOCKERHUB_TOKEN}" > "${AUTHFILE}"

echo "=== Pushing ${SIF} -> ${URI} ==="
# --allow-unsigned: the SIF is not signed with an apptainer key.
apptainer push --allow-unsigned --authfile "${AUTHFILE}" "${SIF}" "${URI}"
echo "=== Published: docker pull ${DOCKERHUB_USER}/${IMAGE_NAME}:${IMAGE_TAG} ==="
