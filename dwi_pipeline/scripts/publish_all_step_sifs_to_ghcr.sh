#!/usr/bin/env bash
# Push all DKT-owned step .sif files to GitHub Container Registry (GHCR).
#
# Prerequisites:
#   gh auth login -h github.com -s write:packages,read:packages
#
# Usage:
#   CONTAINER_DIR=/path/to/others/containers IMAGE_TAG=0.3.0 \
#     bash scripts/publish_all_step_sifs_to_ghcr.sh
#
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
CONTAINER_DIR="${CONTAINER_DIR:-/path/to/others/containers}"
IMAGE_TAG="${IMAGE_TAG:-0.3.0}"
GHCR_USER="${GHCR_USER:-$(gh api user -q .login 2>/dev/null || echo phindagijimana)}"
GHCR_OWNER="${GHCR_OWNER:-phindagijimana}"

if ! gh auth status -h github.com >/dev/null 2>&1; then
  echo "ERROR: run: gh auth login -h github.com -s write:packages,read:packages" >&2
  exit 1
fi

TOKEN="$(gh auth token)"
AUTHFILE="$(mktemp)"
trap 'rm -f "${AUTHFILE}"' EXIT
printf '{"auths":{"ghcr.io":{"username":"%s","password":"%s"}}}\n' \
  "${GHCR_USER}" "${TOKEN}" > "${AUTHFILE}"

declare -A MAP=(
  ["dkt_connectome.sif"]="dk-connectome"
  ["dkt_vbt.sif"]="dkt-vbt"
  ["dkt_lesion_act.sif"]="dkt-lesion-act"
  ["dkt_deep_atropos.sif"]="dkt-deep-atropos"
  ["dkt_deep_atropos_seg.sif"]="dkt-deep-atropos-seg"
)

echo "=== Push DKT step SIFs -> ghcr.io/${GHCR_OWNER}/*:${IMAGE_TAG} ==="
for sif_name in "${!MAP[@]}"; do
  repo="${MAP[$sif_name]}"
  sif="${CONTAINER_DIR}/${sif_name}"
  uri="oras://ghcr.io/${GHCR_OWNER}/${repo}:${IMAGE_TAG}"
  if [[ ! -f "${sif}" ]]; then
    echo "SKIP missing ${sif}"
    continue
  fi
  echo "--- ${sif_name} -> ${uri} ($(du -sh "${sif}" | awk '{print $1}')) ---"
  apptainer push --allow-unsigned --authfile "${AUTHFILE}" "${sif}" "${uri}"
done

echo "=== Done ==="
echo "Orchestrator (separate): ghcr.io/${GHCR_OWNER}/dkt-connectome:${IMAGE_TAG}"
echo "Verify: apptainer pull -F /tmp/test.sif oras://ghcr.io/${GHCR_OWNER}/dk-connectome:${IMAGE_TAG}"
