#!/usr/bin/env bash
# Fail CI if tracked files contain personal NFS paths or committed study exports.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "${ROOT}"

failures=0

check_pattern() {
  local label="$1"
  local pattern="$2"
  local matches
  matches="$(git ls-files -z | xargs -0 rg -l "${pattern}" 2>/dev/null || true)"
  if [[ -n "${matches}" ]]; then
    echo "ERROR: ${label} found in tracked files:" >&2
    echo "${matches}" >&2
    failures=$((failures + 1))
  fi
}

check_tracked_glob() {
  local label="$1"
  local pattern="$2"
  local matches
  matches="$(git ls-files "${pattern}" 2>/dev/null || true)"
  if [[ -n "${matches}" ]]; then
    echo "ERROR: ${label} must not be tracked:" >&2
    echo "${matches}" >&2
    failures=$((failures + 1))
  fi
}

# Personal home / cluster paths must never be committed.
check_pattern "personal NFS path" '/mnt/nfs/home/[^/]+/pndagiji'
check_pattern "URMC home path" 'urmc-sh\.rochester\.edu/pndagiji'

# Real study subject ids must not appear in tracked source (allowlist below).
allowlist='(\.gitignore|check_public_repo_privacy\.sh|contributing\.md)$'
study_id_matches="$(
  git ls-files -z \
    | xargs -0 rg -l 'TBI011|tbi011011' 2>/dev/null \
    | rg -v "${allowlist}" \
    || true
)"
if [[ -n "${study_id_matches}" ]]; then
  echo "ERROR: validation-subject IDs found in tracked files:" >&2
  echo "${study_id_matches}" >&2
  failures=$((failures + 1))
fi

# Cohort export tree is local-only (connectomes + manifests with source paths).
check_tracked_glob "networks_URMC/" 'dwi_pipeline/networks_URMC/**'

# Local IDEAS symlink and inpainting notes stay off GitHub.
check_tracked_glob "IDEAS_II_derivatives_dwi symlink" 'dwi_pipeline/IDEAS_II_derivatives_dwi'
check_tracked_glob "Inpainting local docs" 'dwi_pipeline/Inpainting/**'

# Legacy cohort subject lists at repo root.
check_tracked_glob "root subject_list files" 'subject_list*.txt'

# Doc figures built from local validation subjects stay local.
check_tracked_glob "validation-subject QC figures" 'dwi_pipeline/docs/img/qc/tbi011011_*.png'

if [[ "${failures}" -gt 0 ]]; then
  echo "Privacy check failed (${failures} issue(s)). See .gitignore and docs/contributing.md." >&2
  exit 1
fi

echo "Privacy check OK: no personal paths or study exports in tracked files."
