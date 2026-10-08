#!/usr/bin/env bash
# The line above ("shebang") tells the system to run this file with bash,
# wherever bash is installed on this machine.
#
# Download IDEAS II BIDS data from OpenNeuro ds007401 (public; no AWS account needed).
# This file works on its own: you do not need the rest of the repository.
#
# How to run (step by step):
#   1. Get the script (skip if you already have the repository):
#        curl -fsSLO https://raw.githubusercontent.com/phindagijimana/dkt_connectome/main/dwi_pipeline/scripts/download_ideas_sample.sh
#   2. Run it:
#        bash download_ideas_sample.sh
#   3. At the menu, type 1 (all data, ~40 GB) or 2 (sample, ~150 MB) and press Enter.
#      Pressing Enter alone picks 2. For option 1, type y to confirm.
#   4. Data is saved to:
#        - dwi_pipeline/sample_data/ideas/bids/  when run from inside the repository
#        - ./ideas_bids/                         when run as a standalone file
#        - or the folder given with -o DIR (or the IDEAS_OUT environment variable)
#   5. If a download is interrupted, run the same command again; it resumes.
#
# Downloader: uses the AWS command-line tool ("aws") if it is installed (faster),
# otherwise plain "curl" over HTTPS. Nothing else is required. Optional aws install:
#   pip install --user awscli       (then make sure ~/.local/bin is on your PATH)
#
# Usage:
#   download_ideas_sample.sh [-o DIR]                # menu: (1) all data, (2) sample
#                                                    # (non-interactive: sample)
#   download_ideas_sample.sh [-o DIR] all            # full dataset (large)
#   download_ideas_sample.sh [-o DIR] sample         # 2-subject sample (sub-1 sub-6)
#   download_ideas_sample.sh [-o DIR] sub-3 sub-10   # specific subjects ("3" = "sub-3")
#   download_ideas_sample.sh -h                      # show help
# Env:
#   IDEAS_OUT=/path/to/bids        # output folder (same as -o)
#   IDEAS_DOWNLOADER=aws|curl      # force a downloader (default: aws if installed)
#
# Troubleshooting:
#   "ERROR: ... not found in ds007401"  -> check the subject ID on https://openneuro.org/datasets/ds007401
#   "curl: (6) Could not resolve host"  -> no internet access (e.g. on a compute node); run on a login node
#   aws crashes with "MemoryError"      -> restricted environment; use IDEAS_DOWNLOADER=curl
#   Download stopped partway            -> run the same command again; finished files are skipped

# Safety settings: -e stops the script at the first failing command,
# -u treats use of an undefined variable as an error,
# -o pipefail makes a pipeline fail if any command inside it fails.
set -euo pipefail

# Print the help text (used by -h/--help).
usage() {
  # Print the header comment block (from line 5 to the first non-comment line)
  # without the leading "# ".
  awk 'NR < 5 { next } /^#/ { sub(/^# ?/, ""); print; next } { exit }' "${BASH_SOURCE[0]}"
}

# Absolute path of the folder containing this script.
# BASH_SOURCE[0] is the path of this file; dirname drops the file name;
# cd + pwd turns it into a full path, so the script works from any directory.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Read options (-o DIR, -h) and keep everything else as positional arguments.
OUT="${IDEAS_OUT:-}"
ARGS=()
while (( $# > 0 )); do
  case "$1" in
    # Show help and stop.
    -h|--help) usage; exit 0 ;;
    # Output folder: the next argument is the folder name.
    -o|--out)
      [[ $# -ge 2 ]] || { echo "ERROR: $1 needs a folder name" >&2; exit 2; }
      OUT="$2"; shift 2 ;;
    # Anything else (all, sample, subject IDs) is kept for later.
    *) ARGS+=("$1"); shift ;;
  esac
done
# Put the remaining arguments back as $1, $2, ...
# (the ${ARGS[@]+...} form avoids an "unbound variable" error on older bash
# when no arguments are left).
set -- ${ARGS[@]+"${ARGS[@]}"}

# Choose the output folder if none was given.
if [[ -z "${OUT}" ]]; then
  # Inside the repository (dwi_pipeline/scripts/), use the repo's git-ignored
  # sample_data folder so downloaded imaging data is never committed.
  if [[ -d "${SCRIPT_DIR}/../sample_data/ideas" ]]; then
    OUT="$(cd "${SCRIPT_DIR}/.." && pwd)/sample_data/ideas/bids"
  # Standalone copy: save next to where the user ran the command.
  else
    OUT="${PWD}/ideas_bids"
  fi
fi

# Dataset ID on OpenNeuro.
DS="ds007401"
# Public OpenNeuro storage, as an S3 address (for aws) and an HTTPS address (for curl).
S3="s3://openneuro.org/${DS}"
HTTP_BASE="https://s3.amazonaws.com/openneuro.org"
# Option passed to every aws command: access the public bucket anonymously,
# so users do not need an AWS account or credentials.
AWS_OPTS=(--no-sign-request)
# Subjects downloaded for the small sample (option 2 / "sample").
SAMPLE_SUBJECTS=(sub-1 sub-6)

# Pick the downloader: the user's choice, else aws if installed, else curl.
DOWNLOADER="${IDEAS_DOWNLOADER:-}"
if [[ -z "${DOWNLOADER}" ]]; then
  if command -v aws >/dev/null 2>&1; then DOWNLOADER=aws; else DOWNLOADER=curl; fi
fi
# Make sure the chosen tool exists before doing anything else.
case "${DOWNLOADER}" in
  aws)  command -v aws  >/dev/null 2>&1 || { echo "ERROR: IDEAS_DOWNLOADER=aws but aws is not installed" >&2; exit 1; } ;;
  curl) command -v curl >/dev/null 2>&1 || { echo "ERROR: need curl or aws installed" >&2; exit 1; } ;;
  *)    echo "ERROR: IDEAS_DOWNLOADER must be aws or curl (got '${DOWNLOADER}')" >&2; exit 2 ;;
esac

# ---------------------------------------------------------------------------
# curl helpers (used only when DOWNLOADER=curl)
# ---------------------------------------------------------------------------

# Make a value safe to put in a URL query (escape %, +, /, =).
_urlencode() {
  printf '%s' "$1" | sed -e 's/%/%25/g' -e 's/+/%2B/g' -e 's/\//%2F/g' -e 's/=/%3D/g'
}

# List the bucket under a prefix. Prints one line per entry, tab-separated:
#   F<TAB>key<TAB>size   for files
#   D<TAB>prefix         for folders (only when $2 is "/")
# Handles result pages of up to 1000 entries by following continuation tokens.
_http_list() {
  local prefix="$1" delim="${2:-}" token="" url page
  while :; do
    # Build the S3 "list objects" request.
    url="${HTTP_BASE}/?list-type=2&prefix=$(_urlencode "${prefix}")"
    [[ -n "${delim}" ]] && url="${url}&delimiter=$(_urlencode "${delim}")"
    [[ -n "${token}" ]] && url="${url}&continuation-token=$(_urlencode "${token}")"
    # Fetch one page of XML; -f makes HTTP errors fail the function.
    page="$(curl -fsS "${url}")" || return 1
    # Split the XML at "<" so each tag starts a line, then pick out files
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
    # (Pattern match instead of "| grep -q": grep can exit early, which makes
    # the pipe fail under "set -o pipefail".)
    if [[ "${page}" == *"<IsTruncated>true</IsTruncated>"* ]]; then
      token="$(printf '%s' "${page}" | tr '<' '\n' | sed -n 's/^NextContinuationToken>//p')"
      [[ -n "${token}" ]] || return 1
    else
      break
    fi
  done
}

# Download one file. Skips it if a local copy with the expected size exists.
# Writes to "<file>.part" first and renames at the end, so an interrupted
# transfer is never mistaken for a finished file; reruns resume the .part file.
_http_fetch() {
  local key="$1" dest="$2" size="${3:-}" url part
  url="${HTTP_BASE}/${key}"
  part="${dest}.part"
  # Already complete? (wc -c prints the size in bytes; tr removes padding spaces.)
  if [[ -f "${dest}" && -n "${size}" && "$(wc -c < "${dest}" | tr -d ' ')" == "${size}" ]]; then
    return 0
  fi
  mkdir -p "$(dirname "${dest}")"
  # Try to resume a partial download (-C -); if that fails, start over once.
  if ! curl -fsS -L -C - -o "${part}" "${url}"; then
    rm -f "${part}"
    curl -fsS -L -o "${part}" "${url}" || { rm -f "${part}"; return 1; }
  fi
  mv -f "${part}" "${dest}"
}

# ---------------------------------------------------------------------------
# Downloader-independent steps
# ---------------------------------------------------------------------------

# Print every subject folder name in the dataset, one per line.
list_all_subjects() {
  if [[ "${DOWNLOADER}" == aws ]]; then
    # Folders appear as "PRE sub-N/"; awk keeps those and drops the trailing "/".
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
# which catches typos such as sub-999 instead of silently downloading nothing.
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
    # List the subject's files (key + size); an empty list means no such subject.
    listing="$(_http_list "${DS}/${sub}/")" || { echo "ERROR: could not list ${sub} (network?)" >&2; return 1; }
    if ! grep -q '^F' <<< "${listing}"; then
      echo "ERROR: ${sub} not found in ${DS}" >&2
      return 1
    fi
    echo "[ideas] syncing ${sub}/ ..."
    # Fetch each file; the local path is the key without the leading "ds007401/".
    while IFS=$'\t' read -r t key size; do
      [[ "${t}" == F ]] || continue
      _http_fetch "${key}" "${OUT}/${key#${DS}/}" "${size}" || { echo "ERROR: failed to download ${key}" >&2; return 1; }
    done <<< "${listing}"
  fi
}

# ---------------------------------------------------------------------------
# Decide what to download
# ---------------------------------------------------------------------------

# First positional argument (empty if none was given).
MODE="${1:-}"
# No argument given: decide between "all" and "sample".
if [[ -z "${MODE}" ]]; then
  # -t 0 is true when the script is run in a terminal where a person can type.
  if [[ -t 0 ]]; then
    # Show the menu.
    echo "IDEAS II (OpenNeuro ${DS}) -> ${OUT}   [downloader: ${DOWNLOADER}]"
    echo "  1) Download all data (542 subjects, ~40 GB)"
    echo "  2) Download a sample (${SAMPLE_SUBJECTS[*]}, ~150 MB)"
    # Wait for the user's answer and store it in "choice".
    read -r -p "Choose [1/2] (default 2): " choice
    # Pressing Enter without typing anything counts as 2.
    case "${choice:-2}" in
      1) MODE=all ;;
      2) MODE=sample ;;
      # Anything else is an error; exit status 2 means "bad input".
      *) echo "ERROR: invalid choice '${choice}' (expected 1 or 2)" >&2; exit 2 ;;
    esac
  # Not in a terminal (e.g. a SLURM job or another script): nobody can answer
  # a menu, so default to the sample instead of waiting forever.
  else
    MODE=sample
  fi
fi

# Build the list of subjects to download, stored in the array SUBJECTS.
SUBJECTS=()
if [[ "${MODE}" == "sample" ]]; then
  # Sample mode: use the fixed two-subject list.
  SUBJECTS=("${SAMPLE_SUBJECTS[@]}")
elif [[ "${MODE}" == "all" ]]; then
  # All mode: ask OpenNeuro for every subject (stop if the listing fails).
  all_list="$(list_all_subjects)" || { echo "ERROR: could not list subjects (network?)" >&2; exit 1; }
  # Load one subject per line into the array (works on bash 3.2 and newer).
  while IFS= read -r s; do
    if [[ -n "${s}" ]]; then SUBJECTS+=("${s}"); fi
  done <<< "${all_list}"
  (( ${#SUBJECTS[@]} > 0 )) || { echo "ERROR: no subjects found in ${DS}" >&2; exit 1; }
  # Tell the user how many subjects that is.
  echo "[ideas] full dataset: ${#SUBJECTS[@]} subjects (~70 MB each)."
  # In a terminal, ask for confirmation before a large download.
  if [[ -t 0 ]]; then
    read -r -p "Continue? [y/N]: " ok
    # Anything other than y/Y cancels cleanly (exit status 0 = not an error).
    [[ "${ok}" =~ ^[Yy] ]] || { echo "[ideas] aborted"; exit 0; }
  # Without a terminal, give a 10-second window to cancel with Ctrl-C.
  else
    echo "[ideas] Ctrl-C within 10 s to abort."
    sleep 10
  fi
# Otherwise the arguments are subject IDs, e.g. "sub-3 10".
else
  for sub in "$@"; do
    # Accept "10" as shorthand for "sub-10" by adding the prefix when missing.
    [[ "${sub}" == sub-* ]] || sub="sub-${sub}"
    SUBJECTS+=("${sub}")
  done
fi

# ---------------------------------------------------------------------------
# Download
# ---------------------------------------------------------------------------

echo "[ideas] downloader: ${DOWNLOADER}; output: ${OUT}"
# Create the output folder (and any missing parent folders); no error if it exists.
mkdir -p "${OUT}"
# Copy the dataset-level files that describe the dataset.
for f in dataset_description.json README.md CHANGES; do
  fetch_root_file "${f}"
done

# Download each subject in the list; stop at the first failure.
for sub in "${SUBJECTS[@]}"; do
  sync_subject "${sub}" || exit 1
done

# Summary: where the data is and which subjects were downloaded.
echo "[ideas] done. BIDS root: ${OUT}"
echo "[ideas] subjects: ${SUBJECTS[*]}"
# Show the total size on disk; "|| true" keeps a du failure from stopping the script.
du -sh "${OUT}" 2>/dev/null || true
# Remind users how to cite the dataset in publications.
echo "[ideas] cite: Taylor et al. 2026 Epilepsia doi:10.1002/epi.70186 + OpenNeuro doi:10.18112/openneuro.ds007401.v1.0.0"
