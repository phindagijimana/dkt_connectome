#!/usr/bin/env bash
# Download two-subject IDEAS II BIDS sample from OpenNeuro ds007401.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DWI_PIPELINE_DIR="$(dirname "${SCRIPT_DIR}")"
OUT="${DWI_PIPELINE_DIR}/sample_data/ideas/bids"
S3="s3://openneuro.org/ds007401"

SUBJECTS=(sub-1 sub-6)

if ! command -v aws >/dev/null 2>&1; then
  echo "ERROR: aws CLI required (aws s3 cp/sync)" >&2
  exit 1
fi

mkdir -p "${OUT}"

echo "[ideas] dataset_description.json -> ${OUT}/"
aws s3 cp "${S3}/dataset_description.json" "${OUT}/dataset_description.json"

for sub in "${SUBJECTS[@]}"; do
  echo "[ideas] syncing ${sub}/ ..."
  aws s3 sync "${S3}/${sub}/" "${OUT}/${sub}/" --only-show-errors
done

echo "[ideas] done. BIDS root: ${OUT}"
echo "[ideas] subjects: ${SUBJECTS[*]}"
du -sh "${OUT}" 2>/dev/null || true
