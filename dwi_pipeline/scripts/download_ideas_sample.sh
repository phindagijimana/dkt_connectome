#!/usr/bin/env bash
# Download IDEAS II BIDS data from OpenNeuro ds007401 (public; no AWS account needed).
#
# Usage:
#   download_ideas_sample.sh                 # menu: (1) all data, (2) sample
#                                            # (non-interactive: sample)
#   download_ideas_sample.sh all             # full dataset (large)
#   download_ideas_sample.sh sample          # 2-subject sample (sub-1 sub-6)
#   download_ideas_sample.sh sub-3 sub-10    # specific subjects
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

SAMPLE_SUBJECTS=(sub-1 sub-6)

_list_all_subjects() {
  aws s3 ls "${AWS_OPTS[@]}" "${S3}/" | awk '/PRE sub-/{sub("/","",$2); print $2}'
}

MODE="${1:-}"
if [[ -z "${MODE}" ]]; then
  if [[ -t 0 ]]; then
    echo "IDEAS II (OpenNeuro ds007401) -> ${OUT}"
    echo "  1) Download all data (542 subjects, ~40 GB)"
    echo "  2) Download a sample (${SAMPLE_SUBJECTS[*]}, ~150 MB)"
    read -r -p "Choose [1/2] (default 2): " choice
    case "${choice:-2}" in
      1) MODE=all ;;
      2) MODE=sample ;;
      *) echo "ERROR: invalid choice '${choice}' (expected 1 or 2)" >&2; exit 2 ;;
    esac
  else
    MODE=sample
  fi
fi

if [[ "${MODE}" == "sample" ]]; then
  SUBJECTS=("${SAMPLE_SUBJECTS[@]}")
elif [[ "${MODE}" == "all" ]]; then
  mapfile -t SUBJECTS < <(_list_all_subjects)
  echo "[ideas] full dataset: ${#SUBJECTS[@]} subjects (~70 MB each)."
  if [[ -t 0 ]]; then
    read -r -p "Continue? [y/N]: " ok
    [[ "${ok}" =~ ^[Yy] ]] || { echo "[ideas] aborted"; exit 0; }
  else
    echo "[ideas] Ctrl-C within 10 s to abort."
    sleep 10
  fi
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
