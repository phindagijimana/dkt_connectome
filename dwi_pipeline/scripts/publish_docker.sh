#!/usr/bin/env bash
# Build and optionally push the TrackTBI BIDS App orchestrator Docker image.
# Step containers (QSIPrep, FreeSurfer, etc.) are NOT included — mount at runtime.
#
# Usage:
#   bash scripts/publish_docker.sh              # build local tag
#   bash scripts/publish_docker.sh --push       # build + push to Docker Hub
#
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(dirname "${SCRIPT_DIR}")"
VERSION="$(python3 -c "import json; print(json.load(open('${SCRIPT_DIR}/../app.json'))['PipelineVersion'])")"
IMAGE="phindagijimana/tracktbi-connectome"
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

echo "Building ${IMAGE}:${VERSION} from ${REPO_ROOT}"
docker build -f "${SCRIPT_DIR}/../Dockerfile" -t "${IMAGE}:${VERSION}" -t "${IMAGE}:latest" "${REPO_ROOT}"

echo "Smoke test:"
docker run --rm "${IMAGE}:${VERSION}" --version

if [[ "${PUSH}" -eq 1 ]]; then
  echo "Pushing ${IMAGE}:${VERSION} and :latest"
  docker push "${IMAGE}:${VERSION}"
  docker push "${IMAGE}:latest"
  echo "Done. Registry URL: docker.io/${IMAGE}:${VERSION}"
else
  echo "Built locally. Push with: bash scripts/publish_docker.sh --push"
fi
