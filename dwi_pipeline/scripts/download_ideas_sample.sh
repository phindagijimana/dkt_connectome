#!/usr/bin/env bash
# The line above ("shebang") tells the system to run this file with bash,
# wherever bash is installed on this machine.
#
# Download IDEAS II BIDS data from OpenNeuro ds007401 (public; no AWS account needed).
#
# How to run (step by step):
#   1. Install the AWS command-line tool once (either option works; no AWS account needed):
#        a) pip:  pip install --user awscli        (AWS CLI v1)
#        b) official installer, no admin rights:   (AWS CLI v2)
#             cd ~      # not /tmp: it is often "noexec" and the installer fails
#             curl -sSL https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip -o awscliv2.zip
#             unzip -q awscliv2.zip && ./aws/install -i ~/.local/aws-cli -b ~/.local/bin
#      Make sure ~/.local/bin is on your PATH, then check with:  aws --version
#   2. Go to the repository root:                cd /path/to/TrackTBI-Sub
#   3. Start the script:                         bash dwi_pipeline/scripts/download_ideas_sample.sh
#   4. At the menu, type 1 (all data, ~40 GB) or 2 (sample, ~150 MB) and press Enter.
#      Pressing Enter alone picks 2. For option 1, type y to confirm.
#   5. Data is saved to dwi_pipeline/sample_data/ideas/bids/ (or to $IDEAS_OUT if set).
#   6. If a download is interrupted, run the same command again; it resumes.
#   Troubleshooting: see dwi_pipeline/sample_data/ideas/README.md
#
# Usage:
#   download_ideas_sample.sh                 # menu: (1) all data, (2) sample
#                                            # (non-interactive: sample)
#   download_ideas_sample.sh all             # full dataset (large)
#   download_ideas_sample.sh sample          # 2-subject sample (sub-1 sub-6)
#   download_ideas_sample.sh sub-3 sub-10    # specific subjects
# Env:
#   IDEAS_OUT=/path/to/bids                  # override output directory
#
# Requirements: the AWS command-line tool ("aws"); see step 1 above.

# Safety settings: -e stops the script at the first failing command,
# -u treats use of an undefined variable as an error,
# -o pipefail makes a pipeline fail if any command inside it fails.
set -euo pipefail

# Absolute path of the folder containing this script (dwi_pipeline/scripts).
# BASH_SOURCE[0] is the path of this file; dirname drops the file name;
# cd + pwd turns it into a full path, so the script works from any directory.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# One level up from scripts/, i.e. the dwi_pipeline folder.
DWI_PIPELINE_DIR="$(dirname "${SCRIPT_DIR}")"
# Where data is saved: $IDEAS_OUT if the user set it, otherwise
# dwi_pipeline/sample_data/ideas/bids (this folder is git-ignored, so
# downloaded imaging data is never committed).
OUT="${IDEAS_OUT:-${DWI_PIPELINE_DIR}/sample_data/ideas/bids}"
# Public OpenNeuro storage location for the IDEAS II dataset (ds007401).
S3="s3://openneuro.org/ds007401"
# Option passed to every aws command: access the public bucket anonymously,
# so users do not need an AWS account or credentials.
AWS_OPTS=(--no-sign-request)

# Check that the aws tool is installed before doing anything else.
if ! command -v aws >/dev/null 2>&1; then
  # Print the error to stderr (>&2) so it is not mixed with normal output.
  echo "ERROR: aws CLI required. Install: pip install --user awscli (or AWS CLI v2; see script header)" >&2
  # Exit with status 1 to signal failure.
  exit 1
fi

# Subjects downloaded for the small sample (option 2 / "sample").
SAMPLE_SUBJECTS=(sub-1 sub-6)

# Helper function: print every subject folder name in the dataset, one per line.
_list_all_subjects() {
  # "aws s3 ls" lists the top level of the dataset; folders appear as "PRE sub-N/".
  # awk keeps only those lines, removes the trailing "/" and prints the name.
  aws s3 ls "${AWS_OPTS[@]}" "${S3}/" | awk '/PRE sub-/{sub("/","",$2); print $2}'
}

# First command-line argument (empty if none was given).
MODE="${1:-}"
# No argument given: decide between "all" and "sample".
if [[ -z "${MODE}" ]]; then
  # -t 0 is true when the script is run in a terminal where a person can type.
  if [[ -t 0 ]]; then
    # Show the menu.
    echo "IDEAS II (OpenNeuro ds007401) -> ${OUT}"
    echo "  1) Download all data (542 subjects, ~40 GB)"
    echo "  2) Download a sample (${SAMPLE_SUBJECTS[*]}, ~150 MB)"
    # Wait for the user's answer and store it in "choice".
    read -r -p "Choose [1/2] (default 2): " choice
    # Pressing Enter without typing anything counts as 2.
    case "${choice:-2}" in
      # 1 means download everything.
      1) MODE=all ;;
      # 2 means download the sample.
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
if [[ "${MODE}" == "sample" ]]; then
  # Sample mode: use the fixed two-subject list.
  SUBJECTS=("${SAMPLE_SUBJECTS[@]}")
elif [[ "${MODE}" == "all" ]]; then
  # All mode: ask OpenNeuro for every subject and load them into the array.
  mapfile -t SUBJECTS < <(_list_all_subjects)
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
  # Start with an empty list.
  SUBJECTS=()
  # Look at each argument in turn.
  for sub in "$@"; do
    # Accept "10" as shorthand for "sub-10" by adding the prefix when missing.
    [[ "${sub}" == sub-* ]] || sub="sub-${sub}"
    # Add the (normalized) subject to the list.
    SUBJECTS+=("${sub}")
  done
fi

# Create the output folder (and any missing parent folders); no error if it exists.
mkdir -p "${OUT}"
# Copy the dataset-level files that describe the dataset.
for f in dataset_description.json README.md CHANGES; do
  # Download one file; only print something if it fails.
  aws s3 cp "${AWS_OPTS[@]}" "${S3}/${f}" "${OUT}/${f}" --only-show-errors
done

# Download each subject in the list.
for sub in "${SUBJECTS[@]}"; do
  # List the subject folder online; empty output means it does not exist
  # (catches typos such as sub-999 instead of silently downloading nothing).
  if [[ -z "$(aws s3 ls "${AWS_OPTS[@]}" "${S3}/${sub}/" 2>/dev/null)" ]]; then
    echo "ERROR: ${sub} not found in ds007401" >&2
    exit 1
  fi
  # Progress message.
  echo "[ideas] syncing ${sub}/ ..."
  # "sync" copies only files that are missing or changed locally, so
  # re-running the script resumes an interrupted download instead of restarting.
  aws s3 sync "${AWS_OPTS[@]}" "${S3}/${sub}/" "${OUT}/${sub}/" --only-show-errors
done

# Summary: where the data is and which subjects were downloaded.
echo "[ideas] done. BIDS root: ${OUT}"
echo "[ideas] subjects: ${SUBJECTS[*]}"
# Show the total size on disk; "|| true" keeps a du failure from stopping the script.
du -sh "${OUT}" 2>/dev/null || true
# Remind users how to cite the dataset in publications.
echo "[ideas] cite: Taylor et al. 2026 Epilepsia doi:10.1002/epi.70186 + OpenNeuro doi:10.18112/openneuro.ds007401.v1.0.0"
