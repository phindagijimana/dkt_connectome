#!/usr/bin/env bash
# Stage Docker build context for dkt_vbt (Step 1.1 VBT) in CI.
#
# Usage:
#   bash scripts/ci_stage_vbt_build_context.sh
#
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
CTX="${ROOT}/containers/vbt/build_ctx"
QSIPREP_IMAGE="${QSIPREP_IMAGE:-pennlinc/qsiprep:1.0.0}"
FSL_ENV="${FSL_ENV:-/opt/conda/envs/fslqsiprep}"

rm -rf "${CTX}"
mkdir -p "${CTX}/fsl"

echo "=== Stage VBT build context ==="
echo "  QSIPrep: ${QSIPREP_IMAGE}"
echo "  FSL env: ${FSL_ENV}"

docker pull "${QSIPREP_IMAGE}"
cid="$(docker create "${QSIPREP_IMAGE}")"
trap 'docker rm -f "${cid}" >/dev/null 2>&1 || true' RETURN
docker cp "${cid}:${FSL_ENV}/." "${CTX}/fsl/"
docker rm -f "${cid}"
trap - RETURN

for cmd in flirt fslswapdim midtrans convert_xfm fslmaths; do
  [[ -x "${CTX}/fsl/bin/${cmd}" ]] || { echo "ERROR: missing FSL ${cmd}"; exit 1; }
done
[[ -f "${CTX}/fsl/etc/flirtsch/ident.mat" ]] || { echo "ERROR: missing ident.mat"; exit 1; }

cp "${ROOT}/scripts/run_vbt.py" "${CTX}/"

echo "=== VBT build context ready: ${CTX} ($(du -sh "${CTX}" | awk '{print $1}')) ==="
