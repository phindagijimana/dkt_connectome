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

# Personal home / cluster paths must never be committed.
check_pattern "personal NFS path" '/mnt/nfs/home/[^/]+/pndagiji'
check_pattern "URMC home path" 'urmc-sh\.rochester\.edu/pndagiji'

# Cohort export tree is local-only (connectomes + manifests with source paths).
if git ls-files --error-unmatch dwi_pipeline/networks_URMC >/dev/null 2>&1; then
  echo "ERROR: dwi_pipeline/networks_URMC/ must not be tracked" >&2
  git ls-files 'dwi_pipeline/networks_URMC/**' | head -20 >&2
  failures=$((failures + 1))
fi

# Doc figures built from local validation subjects stay local.
if git ls-files 'dwi_pipeline/docs/img/qc/tbi011011_*.png' | grep -q .; then
  echo "ERROR: validation-subject QC figures must not be tracked" >&2
  git ls-files 'dwi_pipeline/docs/img/qc/tbi011011_*.png' >&2
  failures=$((failures + 1))
fi

if [[ "${failures}" -gt 0 ]]; then
  echo "Privacy check failed (${failures} issue(s)). See .gitignore and docs/contributing.md." >&2
  exit 1
fi

echo "Privacy check OK: no personal paths or study exports in tracked files."
