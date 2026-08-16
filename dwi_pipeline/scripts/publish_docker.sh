#!/usr/bin/env bash
# Build and optionally push the DKT Connectome BIDS App orchestrator Docker image.
# Step containers (QSIPrep, FreeSurfer, etc.) are NOT included — mount at runtime.
#
# Usage:
#   bash scripts/publish_docker.sh              # build local tag
#   bash scripts/publish_docker.sh --push       # build + push to Docker Hub
#
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DWI_DIR="$(dirname "${SCRIPT_DIR}")"
REPO_ROOT="$(dirname "${DWI_DIR}")"
VERSION="$(python3 -c "import json; print(json.load(open('${DWI_DIR}/app.json'))['PipelineVersion'])")"
IMAGE="phindagijimana321/dkt-connectome"
CONTAINER="${CONTAINER:-}"
if [[ -z "${CONTAINER}" ]]; then
  if command -v docker >/dev/null 2>&1; then
    CONTAINER=docker
  elif command -v podman >/dev/null 2>&1; then
    CONTAINER=podman
  else
    echo "ERROR: docker or podman required" >&2
    exit 1
  fi
fi
PUSH=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --push) PUSH=1; shift ;;
    -h|--help)
      sed -n '2,8p' "$0" | sed 's/^# \{0,1\}//'
      exit 0
      ;;
    *) echo "Unknown option: $1" >&2; exit 2 ;;
  esac
done

echo "Building ${IMAGE}:${VERSION} from ${REPO_ROOT} (${CONTAINER})"
"${CONTAINER}" build -f "${DWI_DIR}/Dockerfile" \
  -t "docker.io/${IMAGE}:${VERSION}" \
  -t "docker.io/${IMAGE}:latest" \
  "${REPO_ROOT}"

echo "Smoke test:"
"${CONTAINER}" run --rm "docker.io/${IMAGE}:${VERSION}" --version

if [[ "${PUSH}" -eq 1 ]]; then
  echo "Pushing ${IMAGE}:${VERSION} and :latest"
  "${CONTAINER}" push "docker.io/${IMAGE}:${VERSION}"
  "${CONTAINER}" push "docker.io/${IMAGE}:latest"
  echo "Done. Registry URL: docker.io/${IMAGE}:${VERSION}"
else
  echo "Built locally. Push with: bash scripts/publish_docker.sh --push"
fi
