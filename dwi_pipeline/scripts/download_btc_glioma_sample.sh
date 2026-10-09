#!/usr/bin/env bash
# Download ONE glioma subject from OpenNeuro ds001226 (BTC_preop).
#
# This is GLIOMA data, not TBI. It is a public demo of lesion-aware BIDS
# inputs only. Do not cite runs on this subject as TRACK-TBI validation.
#
# Default subject: sub-PAT20 (smallest complete glioma: T1w + acq-AP HARDI
# + T1-space tumor mask). BTC_preop also has meningioma patients — this
# script only accepts known glioma IDs unless you pass --any-pat.
#
# Layout: ds001226 already uses ses-preop, so no ses-1 wrap is applied.
# The OpenNeuro tumor mask is COPIED (not moved) next to T1w as
#   *_T1w_label-lesion_roi.nii.gz
# because this pipeline only finds a mask as a sibling of T1w. That file
# is a TUMOR mask, not a traumatic lesion. A sidecar JSON records that.
#
# Skips func/ and questionnaires to save space.
#
# How to run (from the repository root):
#   bash dwi_pipeline/scripts/download_btc_glioma_sample.sh
#   bash dwi_pipeline/scripts/download_btc_glioma_sample.sh PAT25
#   bash dwi_pipeline/scripts/download_btc_glioma_sample.sh -o /path/to/bids
#
# Downloader: aws --no-sign-request if aws is installed, else curl HTTPS
# (same public OpenNeuro bucket as the IDEAS script). No AWS account needed.
#
# Env:
#   BTC_OUT=/path/to/bids
#   BTC_DOWNLOADER=aws|curl
#
# Usage:
#   download_btc_glioma_sample.sh [-o DIR] [PAT20|sub-PAT20]
#   download_btc_glioma_sample.sh -h

set -euo pipefail

usage() {
  awk 'NR < 5 { next } /^#/ { sub(/^# ?/, ""); print; next } { exit }' "${BASH_SOURCE[0]}"
}

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Known glioma (not meningioma) IDs from ds001226 participants.tsv.
GLIOMA_PATS=(PAT05 PAT16 PAT20 PAT22 PAT25 PAT26 PAT27 PAT28 PAT29 PAT31)
DEFAULT_PAT="PAT20"

OUT="${BTC_OUT:-}"
ALLOW_ANY_PAT=0
ARGS=()
while (( $# > 0 )); do
  case "$1" in
    -h|--help) usage; exit 0 ;;
    -o|--out)
      [[ $# -ge 2 ]] || { echo "ERROR: $1 needs a folder name" >&2; exit 2; }
      OUT="$2"; shift 2 ;;
    --any-pat) ALLOW_ANY_PAT=1; shift ;;
    *) ARGS+=("$1"); shift ;;
  esac
done
set -- ${ARGS[@]+"${ARGS[@]}"}

if [[ -z "${OUT}" ]]; then
  if [[ -d "${SCRIPT_DIR}/../sample_data" ]]; then
    OUT="$(cd "${SCRIPT_DIR}/.." && pwd)/sample_data/btc_glioma/bids"
  else
    OUT="${PWD}/btc_glioma_bids"
  fi
fi

PAT="${1:-${DEFAULT_PAT}}"
[[ "${PAT}" == sub-* ]] || PAT="sub-${PAT}"
PAT_ID="${PAT#sub-}"

is_glioma() {
  local p
  for p in "${GLIOMA_PATS[@]}"; do
    [[ "${p}" == "$1" ]] && return 0
  done
  return 1
}

if (( ! ALLOW_ANY_PAT )) && ! is_glioma "${PAT_ID}"; then
  echo "ERROR: ${PAT} is not in the glioma list (${GLIOMA_PATS[*]})." >&2
  echo "BTC_preop also includes meningioma patients. Pass a glioma ID, or --any-pat." >&2
  exit 2
fi

DS="ds001226"
S3="s3://openneuro.org/${DS}"
HTTP_BASE="https://s3.amazonaws.com/openneuro.org"
AWS_OPTS=(--no-sign-request)
SES="ses-preop"

DOWNLOADER="${BTC_DOWNLOADER:-}"
if [[ -z "${DOWNLOADER}" ]]; then
  if command -v aws >/dev/null 2>&1; then DOWNLOADER=aws; else DOWNLOADER=curl; fi
fi
case "${DOWNLOADER}" in
  aws)  command -v aws  >/dev/null 2>&1 || { echo "ERROR: BTC_DOWNLOADER=aws but aws is not installed" >&2; exit 1; } ;;
  curl) command -v curl >/dev/null 2>&1 || { echo "ERROR: need curl or aws installed" >&2; exit 1; } ;;
  *)    echo "ERROR: BTC_DOWNLOADER must be aws or curl (got '${DOWNLOADER}')" >&2; exit 2 ;;
esac

_urlencode() {
  printf '%s' "$1" | sed -e 's/%/%25/g' -e 's/+/%2B/g' -e 's/\//%2F/g' -e 's/=/%3D/g'
}

_http_list() {
  local prefix="$1" token="" url page
  while :; do
    url="${HTTP_BASE}/?list-type=2&prefix=$(_urlencode "${prefix}")"
    [[ -n "${token}" ]] && url="${url}&continuation-token=$(_urlencode "${token}")"
    page="$(curl -fsS "${url}")" || return 1
    printf '%s' "${page}" | tr '<' '\n' | awk '
      /^Contents>/        { inc = 1 }
      /^\/Contents>/      { inc = 0; if (k != "") print "F\t" k "\t" s; k = ""; s = "" }
      inc && /^Key>/      { k = substr($0, 5) }
      inc && /^Size>/     { s = substr($0, 6) }'
    if [[ "${page}" == *"<IsTruncated>true</IsTruncated>"* ]]; then
      token="$(printf '%s' "${page}" | tr '<' '\n' | sed -n 's/^NextContinuationToken>//p')"
      [[ -n "${token}" ]] || return 1
    else
      break
    fi
  done
}

_http_fetch() {
  local key="$1" dest="$2" size="${3:-}" url part
  url="${HTTP_BASE}/${key}"
  part="${dest}.part"
  if [[ -f "${dest}" && -n "${size}" && "$(wc -c < "${dest}" | tr -d ' ')" == "${size}" ]]; then
    return 0
  fi
  mkdir -p "$(dirname "${dest}")"
  if ! curl -fsS -L -C - -o "${part}" "${url}"; then
    rm -f "${part}"
    curl -fsS -L -o "${part}" "${url}" || { rm -f "${part}"; return 1; }
  fi
  mv -f "${part}" "${dest}"
}

fetch_key() {
  local key="$1" dest="$2"
  if [[ "${DOWNLOADER}" == aws ]]; then
    mkdir -p "$(dirname "${dest}")"
    aws s3 cp "${AWS_OPTS[@]}" "s3://openneuro.org/${key}" "${dest}" --only-show-errors
  else
    _http_fetch "${key}" "${dest}"
  fi
}

sync_prefix() {
  local prefix="$1" dest="$2"
  if [[ "${DOWNLOADER}" == aws ]]; then
    if [[ -z "$(aws s3 ls "${AWS_OPTS[@]}" "${S3}/${prefix}" 2>/dev/null)" ]]; then
      echo "ERROR: ${prefix} not found in ${DS}" >&2
      return 1
    fi
    echo "[btc] syncing ${prefix} ..."
    mkdir -p "${dest}"
    aws s3 sync "${AWS_OPTS[@]}" "${S3}/${prefix}" "${dest}" --only-show-errors
  else
    local listing t key size
    listing="$(_http_list "${DS}/${prefix}")" || { echo "ERROR: could not list ${prefix}" >&2; return 1; }
    if ! grep -q '^F' <<< "${listing}"; then
      echo "ERROR: ${prefix} not found in ${DS}" >&2
      return 1
    fi
    echo "[btc] syncing ${prefix} ..."
    while IFS=$'\t' read -r t key size; do
      [[ "${t}" == F ]] || continue
      _http_fetch "${key}" "${OUT}/${key#${DS}/}" "${size}" || return 1
    done <<< "${listing}"
  fi
}

echo "[btc] GLIOMA sample (not TBI). downloader: ${DOWNLOADER}; output: ${OUT}"
echo "[btc] subject: ${PAT} (${SES}); skipping func/ and questionnaires"
mkdir -p "${OUT}"

for f in dataset_description.json README CHANGES; do
  fetch_key "${DS}/${f}" "${OUT}/${f}"
done

# Only anat + dwi (no func/, no CANTAB / questionnaire tables).
sync_prefix "${PAT}/${SES}/anat/" "${OUT}/${PAT}/${SES}/anat/"
sync_prefix "${PAT}/${SES}/dwi/" "${OUT}/${PAT}/${SES}/dwi/"

# Copy (do not move-only) the T1-space OpenNeuro tumor mask next to T1w.
MASK_SRC_KEY="${DS}/derivatives/tumor_masks/${PAT}/anat/${PAT}_space_T1_label-tumor.nii"
MASK_TMP="${OUT}/.tmp_${PAT}_space_T1_label-tumor.nii"
MASK_DEST="${OUT}/${PAT}/${SES}/anat/${PAT}_${SES}_T1w_label-lesion_roi.nii.gz"
MASK_JSON="${OUT}/${PAT}/${SES}/anat/${PAT}_${SES}_T1w_label-lesion_roi.json"

echo "[btc] copying tumor mask -> ${MASK_DEST##*/}"
fetch_key "${MASK_SRC_KEY}" "${MASK_TMP}"
mkdir -p "$(dirname "${MASK_DEST}")"
# OpenNeuro ships an uncompressed .nii; this pipeline expects .nii.gz.
gzip -c "${MASK_TMP}" > "${MASK_DEST}"
rm -f "${MASK_TMP}"

cat > "${MASK_JSON}" <<EOF
{
  "Description": "OpenNeuro ds001226 BTC_preop tumor mask, copied and renamed so this pipeline can find it as a sibling of T1w (*_T1w_label-lesion_roi.nii.gz). This is a TUMOR mask (glioma), NOT a traumatic brain-injury lesion. Do not cite runs on this subject as TRACK-TBI validation.",
  "Sources": [
    "https://s3.amazonaws.com/openneuro.org/${MASK_SRC_KEY}"
  ],
  "OriginalFile": "derivatives/tumor_masks/${PAT}/anat/${PAT}_space_T1_label-tumor.nii",
  "SpatialReference": "T1w native space (OpenNeuro space_T1 tumor mask)",
  "Label": "tumor",
  "Pathology": "glioma",
  "NotTraumaticLesion": true,
  "LayoutNote": "Filename follows this pipeline lesion-mask convention. Voxel data are an unmodified gzipped copy of the OpenNeuro tumor mask. ds001226 already uses ses-preop; no ses-1 wrap was applied.",
  "DatasetDOI": "doi:10.18112/openneuro.ds001226.v5.0.0"
}
EOF

# Slim participants row (tumor type only; no questionnaire scores).
cat > "${OUT}/participants.tsv" <<EOF
participant_id	tumor_type	note
${PAT}	glioma	BTC_preop OpenNeuro ds001226; tumor mask renamed for pipeline layout; NOT TBI
EOF

echo "[btc] done. BIDS root: ${OUT}"
echo "[btc] ${PAT}/${SES}  (layout wrap: not needed — source already has ses-preop)"
echo "[btc] lesion-style filename (TUMOR mask): ${MASK_DEST}"
du -sh "${OUT}" 2>/dev/null || true
echo "[btc] cite: Aerts et al. 2018 eNeuro doi:10.1523/ENEURO.0083-18.2018 + OpenNeuro doi:10.18112/openneuro.ds001226.v5.0.0"
echo "[btc] this is GLIOMA, not TBI — do not cite as TRACK-TBI validation"
