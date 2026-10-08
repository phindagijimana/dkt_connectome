#!/usr/bin/env bash
# Download IDEAS II BIDS data from OpenNeuro ds007401
# (public; no AWS account needed). This file works on its own:
# you do not need the rest of the repository.
#
# How to run (step by step):
#   1. Get the script (skip if you already have the repository):
#        curl -fsSLO https://raw.githubusercontent.com/phindagijimana/dkt_connectome/main/dwi_pipeline/scripts/download_ideas_sample.sh
#   2. Run it:
#        bash download_ideas_sample.sh
#   3. At the menu, type 1 (all data, ~40 GB) or 2 (sample, ~150 MB)
#      and press Enter. Enter alone picks 2. For 1, type y to confirm.
#   4. Data is saved to:
#        - dwi_pipeline/sample_data/ideas/bids/  inside the repository
#        - ./ideas_bids/                         as a standalone file
#        - or the folder given with -o DIR (or IDEAS_OUT)
#   5. If a download stops, run the same command again; it resumes.
#
# Downloader: the AWS command-line tool ("aws") if installed (faster),
# otherwise plain "curl" over HTTPS. Nothing else is required.
# Optional aws install:
#   pip install --user awscli   (then put ~/.local/bin on your PATH)
#
# Usage:
#   download_ideas_sample.sh [-o DIR]              # menu: 1) all, 2) sample
#   download_ideas_sample.sh [-o DIR] all          # full dataset (large)
#   download_ideas_sample.sh [-o DIR] sample       # sub-1 and sub-6
#   download_ideas_sample.sh [-o DIR] sub-3 10     # chosen subjects
#   download_ideas_sample.sh -h                    # show this help
# Without a terminal (e.g. a SLURM job), no argument means "sample".
#
# Environment variables:
#   IDEAS_OUT=/path/to/bids     output folder (same as -o)
#   IDEAS_DOWNLOADER=aws|curl   force a downloader
#
# Troubleshooting:
#   "ERROR: ... not found in ds007401"
#       check the subject ID on https://openneuro.org/datasets/ds007401
#   "curl: (6) Could not resolve host"
#       no internet (e.g. a compute node); run on a login node
#   aws crashes with "MemoryError"
#       restricted environment; use IDEAS_DOWNLOADER=curl
#   Download stopped partway
#       run the same command again; finished files are skipped

# Line 1 (the "shebang") tells the system to run this file with bash.

# ===========================================================================
# Settings and options
# ===========================================================================

# Stop on the first error (-e), on undefined variables (-u),
# and when any command in a pipeline fails (-o pipefail).
set -euo pipefail

# Print the header above (line 2 up to the first non-comment line)
# without the leading "# ". Used by -h/--help.
usage() {
  awk 'NR == 1 { next } /^#/ { sub(/^# ?/, ""); print; next } { exit }' \
    "${BASH_SOURCE[0]}"
}

# Full path of the folder holding this script, so it works from any
# directory. BASH_SOURCE[0] is this file; dirname drops the file name.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Read -o DIR and -h; keep everything else (all, sample, subject IDs).
OUT="${IDEAS_OUT:-}"
ARGS=()
while (( $# > 0 )); do
  case "$1" in
    -h|--help) usage; exit 0 ;;
    -o|--out)
      [[ $# -ge 2 ]] || { echo "ERROR: $1 needs a folder name" >&2; exit 2; }
      OUT="$2"; shift 2 ;;
    *) ARGS+=("$1"); shift ;;
  esac
done
# Put the kept arguments back as $1, $2, ...
# (this form also works on older bash when no arguments are left).
set -- ${ARGS[@]+"${ARGS[@]}"}

# Default output folder: the repo's git-ignored sample_data folder when run
# inside the repository, otherwise ./ideas_bids where the user ran it.
if [[ -z "${OUT}" ]]; then
  if [[ -d "${SCRIPT_DIR}/../sample_data/ideas" ]]; then
    OUT="$(cd "${SCRIPT_DIR}/.." && pwd)/sample_data/ideas/bids"
  else
    OUT="${PWD}/ideas_bids"
  fi
fi

# Dataset ID and its public storage address, for aws (S3) and curl (HTTPS).
DS="ds007401"
S3="s3://openneuro.org/${DS}"
HTTP_BASE="https://s3.amazonaws.com/openneuro.org"
# Access the public bucket anonymously, so no AWS account is needed.
AWS_OPTS=(--no-sign-request)
# Subjects in the small sample (menu option 2 / "sample").
SAMPLE_SUBJECTS=(sub-1 sub-6)

# ===========================================================================
# Choose the downloader
# ===========================================================================

# The user's choice, else aws if installed, else curl.
DOWNLOADER="${IDEAS_DOWNLOADER:-}"
if [[ -z "${DOWNLOADER}" ]]; then
  if command -v aws >/dev/null 2>&1; then DOWNLOADER=aws; else DOWNLOADER=curl; fi
fi
# Check that the chosen tool exists before doing anything else.
case "${DOWNLOADER}" in
  aws)  command -v aws  >/dev/null 2>&1 || { echo "ERROR: IDEAS_DOWNLOADER=aws but aws is not installed" >&2; exit 1; } ;;
  curl) command -v curl >/dev/null 2>&1 || { echo "ERROR: need curl or aws installed" >&2; exit 1; } ;;
  *)    echo "ERROR: IDEAS_DOWNLOADER must be aws or curl (got '${DOWNLOADER}')" >&2; exit 2 ;;
esac

# ===========================================================================
# curl helpers (used only when DOWNLOADER=curl)
# ===========================================================================

# Escape %, +, / and = so a value can go in a URL query.
_urlencode() {
  printf '%s' "$1" | sed -e 's/%/%25/g' -e 's/+/%2B/g' -e 's/\//%2F/g' -e 's/=/%3D/g'
}

# List the bucket under a prefix, one tab-separated line per entry:
#   F<TAB>key<TAB>size   for files
#   D<TAB>prefix         for folders (only when $2 is "/")
# S3 returns at most 1000 entries per page; continuation tokens fetch the rest.
_http_list() {
  local prefix="$1" delim="${2:-}" token="" url page
  while :; do
    url="${HTTP_BASE}/?list-type=2&prefix=$(_urlencode "${prefix}")"
    [[ -n "${delim}" ]] && url="${url}&delimiter=$(_urlencode "${delim}")"
    [[ -n "${token}" ]] && url="${url}&continuation-token=$(_urlencode "${token}")"
    # Fetch one page of XML (-f: fail on HTTP errors).
    page="$(curl -fsS "${url}")" || return 1
    # Put each XML tag on its own line, then pick out files
    # (<Contents>: Key + Size) and folders (<CommonPrefixes>: Prefix).
    printf '%s' "${page}" | tr '<' '\n' | awk '
      /^Contents>/        { inc = 1 }
      /^\/Contents>/      { inc = 0; if (k != "") print "F\t" k "\t" s; k = ""; s = "" }
      inc && /^Key>/      { k = substr($0, 5) }
      inc && /^Size>/     { s = substr($0, 6) }
      /^CommonPrefixes>/  { inp = 1 }
      /^\/CommonPrefixes>/{ inp = 0 }
      inp && /^Prefix>/   { print "D\t" substr($0, 8) }'
    # More pages? Continue with the token; otherwise stop.
    # (A pattern match, not "| grep -q", which can fail under pipefail.)
    if [[ "${page}" == *"<IsTruncated>true</IsTruncated>"* ]]; then
      token="$(printf '%s' "${page}" | tr '<' '\n' | sed -n 's/^NextContinuationToken>//p')"
      [[ -n "${token}" ]] || return 1
    else
      break
    fi
  done
}

# Download one file, skipping it if a local copy has the expected size.
# Data goes to "<file>.part" and is renamed when complete, so a cut-off
# transfer never looks finished; a rerun resumes the .part file.
_http_fetch() {
  local key="$1" dest="$2" size="${3:-}" url part
  url="${HTTP_BASE}/${key}"
  part="${dest}.part"
  # Already complete? (wc -c gives the size in bytes; tr strips spaces.)
  if [[ -f "${dest}" && -n "${size}" && "$(wc -c < "${dest}" | tr -d ' ')" == "${size}" ]]; then
    return 0
  fi
  mkdir -p "$(dirname "${dest}")"
  # Resume a partial download (-C -); if that fails, start over once.
  if ! curl -fsS -L -C - -o "${part}" "${url}"; then
    rm -f "${part}"
    curl -fsS -L -o "${part}" "${url}" || { rm -f "${part}"; return 1; }
  fi
  mv -f "${part}" "${dest}"
}

# ===========================================================================
# Download steps (each works with aws or curl)
# ===========================================================================

# Print every subject folder name in the dataset, one per line.
list_all_subjects() {
  if [[ "${DOWNLOADER}" == aws ]]; then
    # aws shows folders as "PRE sub-N/"; keep those and drop the "/".
    aws s3 ls "${AWS_OPTS[@]}" "${S3}/" | awk '/PRE sub-/{sub("/","",$2); print $2}'
  else
    _http_list "${DS}/" "/" | awk -F'\t' '$1 == "D" { p = $2; sub(/^[^\/]*\//, "", p); sub(/\/$/, "", p); if (p ~ /^sub-/) print p }'
  fi
}

# Download one dataset-level file (e.g. README.md) into the output folder.
fetch_root_file() {
  if [[ "${DOWNLOADER}" == aws ]]; then
    aws s3 cp "${AWS_OPTS[@]}" "${S3}/$1" "${OUT}/$1" --only-show-errors
  else
    _http_fetch "${DS}/$1" "${OUT}/$1"
  fi
}

# Download (or resume) one subject. Fails if the subject does not exist,
# so a typo such as sub-999 is reported instead of downloading nothing.
sync_subject() {
  local sub="$1" listing t key size
  if [[ "${DOWNLOADER}" == aws ]]; then
    if [[ -z "$(aws s3 ls "${AWS_OPTS[@]}" "${S3}/${sub}/" 2>/dev/null)" ]]; then
      echo "ERROR: ${sub} not found in ${DS}" >&2
      return 1
    fi
    echo "[ideas] syncing ${sub}/ ..."
    # "sync" copies only files that are missing or changed locally.
    aws s3 sync "${AWS_OPTS[@]}" "${S3}/${sub}/" "${OUT}/${sub}/" --only-show-errors
  else
    # List the subject's files; no files means no such subject.
    listing="$(_http_list "${DS}/${sub}/")" || { echo "ERROR: could not list ${sub} (network?)" >&2; return 1; }
    if ! grep -q '^F' <<< "${listing}"; then
      echo "ERROR: ${sub} not found in ${DS}" >&2
      return 1
    fi
    echo "[ideas] syncing ${sub}/ ..."
    # Fetch each file; the local path is the key minus "ds007401/".
    while IFS=$'\t' read -r t key size; do
      [[ "${t}" == F ]] || continue
      _http_fetch "${key}" "${OUT}/${key#${DS}/}" "${size}" || { echo "ERROR: failed to download ${key}" >&2; return 1; }
    done <<< "${listing}"
  fi
}

# ===========================================================================
# Decide what to download
# ===========================================================================

# With no argument, show the menu in a terminal ([[ -t 0 ]] is true when a
# person can type). Without a terminal (e.g. a SLURM job) nobody can answer,
# so use the sample instead of waiting forever.
MODE="${1:-}"
if [[ -z "${MODE}" ]]; then
  if [[ -t 0 ]]; then
    echo "IDEAS II (OpenNeuro ${DS}) -> ${OUT}   [downloader: ${DOWNLOADER}]"
    echo "  1) Download all data (542 subjects, ~40 GB)"
    echo "  2) Download a sample (${SAMPLE_SUBJECTS[*]}, ~150 MB)"
    read -r -p "Choose [1/2] (default 2): " choice
    # Enter alone means 2; anything else is bad input (exit status 2).
    case "${choice:-2}" in
      1) MODE=all ;;
      2) MODE=sample ;;
      *) echo "ERROR: invalid choice '${choice}' (expected 1 or 2)" >&2; exit 2 ;;
    esac
  else
    MODE=sample
  fi
fi

# Build the list of subjects to download.
SUBJECTS=()
if [[ "${MODE}" == "sample" ]]; then
  SUBJECTS=("${SAMPLE_SUBJECTS[@]}")

elif [[ "${MODE}" == "all" ]]; then
  # Ask OpenNeuro for every subject, one per line, and load them into the
  # array (a read loop rather than mapfile, so it works on bash 3.2).
  all_list="$(list_all_subjects)" || { echo "ERROR: could not list subjects (network?)" >&2; exit 1; }
  while IFS= read -r s; do
    if [[ -n "${s}" ]]; then SUBJECTS+=("${s}"); fi
  done <<< "${all_list}"
  (( ${#SUBJECTS[@]} > 0 )) || { echo "ERROR: no subjects found in ${DS}" >&2; exit 1; }
  echo "[ideas] full dataset: ${#SUBJECTS[@]} subjects (~70 MB each)."
  # Confirm a large download: ask in a terminal (anything but y cancels),
  # otherwise allow 10 seconds to cancel with Ctrl-C.
  if [[ -t 0 ]]; then
    read -r -p "Continue? [y/N]: " ok
    [[ "${ok}" =~ ^[Yy] ]] || { echo "[ideas] aborted"; exit 0; }
  else
    echo "[ideas] Ctrl-C within 10 s to abort."
    sleep 10
  fi

else
  # The arguments are subject IDs; "10" is short for "sub-10".
  for sub in "$@"; do
    [[ "${sub}" == sub-* ]] || sub="sub-${sub}"
    SUBJECTS+=("${sub}")
  done
fi

# ===========================================================================
# Download
# ===========================================================================

echo "[ideas] downloader: ${DOWNLOADER}; output: ${OUT}"
mkdir -p "${OUT}"
# Files that describe the dataset as a whole.
for f in dataset_description.json README.md CHANGES; do
  fetch_root_file "${f}"
done
# Each subject in turn; stop at the first failure.
for sub in "${SUBJECTS[@]}"; do
  sync_subject "${sub}" || exit 1
done

# Summary, size on disk ("|| true": a du failure must not stop the script),
# and how to cite the dataset.
echo "[ideas] done. BIDS root: ${OUT}"
echo "[ideas] subjects: ${SUBJECTS[*]}"
du -sh "${OUT}" 2>/dev/null || true
echo "[ideas] cite: Taylor et al. 2026 Epilepsia doi:10.1002/epi.70186 + OpenNeuro doi:10.18112/openneuro.ds007401.v1.0.0"
