#!/usr/bin/env bash
# Download IDEAS II BIDS data from OpenNeuro ds007401 (public; no AWS account needed).
#
# Usage:
#   download_ideas_sample.sh                 # 2-subject sample (sub-1 sub-6)
#   download_ideas_sample.sh sub-3 sub-10    # specific subjects
#   download_ideas_sample.sh all             # full dataset (large)
# Env:
#   IDEAS_OUT=/path/to/bids                  # override output directory
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DWI_PIPELINE_DIR="$(dirname "${SCRIPT_DIR}")"
OUT="${IDEAS_OUT:-${DWI_PIPELINE_DIR}/sample_data/ideas/bids}"
S3="s3://openneuro.org/ds007401"
AWS_OPTS=(--no-sign-request)

if ! command -v aws >/dev/null 2>&1; then
  echo "ERROR: aws CLI required. Install: pip install awscli" >&2
  exit 1
fi

if (( $# == 0 )); then
  SUBJECTS=(sub-1 sub-6)
elif [[ "$1" == "all" ]]; then
  mapfile -t SUBJECTS < <(aws s3 ls "${AWS_OPTS[@]}" "${S3}/" | awk '/PRE sub-/{sub("/","",$2); print $2}')
  echo "[ideas] full dataset: ${#SUBJECTS[@]} subjects (~70 MB each). Ctrl-C within 10 s to abort."
  sleep 10
else
  SUBJECTS=()
  for sub in "$@"; do
    [[ "${sub}" == sub-* ]] || sub="sub-${sub}"
    SUBJECTS+=("${sub}")
  done
fi

mkdir -p "${OUT}"
for f in dataset_description.json README.md CHANGES; do
  aws s3 cp "${AWS_OPTS[@]}" "${S3}/${f}" "${OUT}/${f}" --only-show-errors
done

for sub in "${SUBJECTS[@]}"; do
  if [[ -z "$(aws s3 ls "${AWS_OPTS[@]}" "${S3}/${sub}/" 2>/dev/null)" ]]; then
    echo "ERROR: ${sub} not found in ds007401" >&2
    exit 1
  fi
  echo "[ideas] syncing ${sub}/ ..."
  aws s3 sync "${AWS_OPTS[@]}" "${S3}/${sub}/" "${OUT}/${sub}/" --only-show-errors
done

echo "[ideas] done. BIDS root: ${OUT}"
echo "[ideas] subjects: ${SUBJECTS[*]}"
du -sh "${OUT}" 2>/dev/null || true
echo "[ideas] cite: Taylor et al. 2026 Epilepsia doi:10.1002/epi.70186 + OpenNeuro doi:10.18112/openneuro.ds007401.v1.0.0"
