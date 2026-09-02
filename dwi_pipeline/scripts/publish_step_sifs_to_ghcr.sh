#!/usr/bin/env bash
# Push locally built DKT step .sif files to GitHub Container Registry (GHCR).
#
# Requires a GitHub PAT with write:packages (or `gh auth refresh -s write:packages`).
#
# Usage:
#   export GHCR_USER=phindagijimana
#   export GHCR_TOKEN=...          # or: gh auth refresh -s write:packages
#   CONTAINER_DIR=/path/to/others/containers IMAGE_TAG=0.3.0 \
#     bash scripts/publish_step_sifs_to_ghcr.sh
#
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
CONTAINER_DIR="${CONTAINER_DIR:-/path/to/others/containers}"
IMAGE_TAG="${IMAGE_TAG:-0.3.0}"
GHCR_USER="${GHCR_USER:-phindagijimana}"
GHCR_OWNER="${GHCR_OWNER:-phindagijimana}"

if [[ -z "${GHCR_TOKEN:-}" ]] && command -v gh >/dev/null 2>&1; then
  GHCR_TOKEN="$(gh auth token 2>/dev/null || true)"
fi
[[ -n "${GHCR_TOKEN:-}" ]] || {
  echo "ERROR: set GHCR_TOKEN or run: gh auth refresh -s write:packages" >&2
  exit 1
}

AUTHFILE="$(mktemp)"
trap 'rm -f "${AUTHFILE}"' EXIT
printf '{"auths":{"ghcr.io":{"username":"%s","password":"%s"}}}\n' \
  "${GHCR_USER}" "${GHCR_TOKEN}" > "${AUTHFILE}"

push_one() {
  local sif="$1" repo="$2"
  [[ -f "${sif}" ]] || { echo "SKIP missing ${sif}"; return 0; }
  local uri="oras://ghcr.io/${GHCR_OWNER}/${repo}:${IMAGE_TAG}"
  echo "=== Push ${sif} -> ${uri} ==="
  apptainer push --allow-unsigned --authfile "${AUTHFILE}" "${sif}" "${uri}"
}

declare -A MAP=(
  ["dkt_connectome.sif"]="dk-connectome"
  ["dkt_vbt.sif"]="dkt-vbt"
  ["dkt_lesion_act.sif"]="dkt-lesion-act"
  ["dkt_deep_atropos.sif"]="dkt-deep-atropos"
  ["dkt_deep_atropos_seg.sif"]="dkt-deep-atropos-seg"
)

for sif_name in "${!MAP[@]}"; do
  push_one "${CONTAINER_DIR}/${sif_name}" "${MAP[$sif_name]}"
done

echo "=== Done. GHCR packages at ghcr.io/${GHCR_OWNER}/*:${IMAGE_TAG} ==="
