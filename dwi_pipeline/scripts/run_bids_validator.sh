#!/usr/bin/env bash
# Opt-in BIDS validation before pipeline runs (Phase B).
# Requires bids-validator CLI (npm) or Apptainer image via BIDS_VALIDATOR_SIF.
#
# Usage:
#   bash run_bids_validator.sh /path/to/BIDS [--ignore-warnings]
#
set -euo pipefail

BIDS_DIR="${1:?Usage: run_bids_validator.sh BIDS_DIR [--ignore-warnings]}"
shift || true
IGNORE_WARNINGS=0
for arg in "$@"; do
  [[ "${arg}" == "--ignore-warnings" ]] && IGNORE_WARNINGS=1
done

BIDS_DIR="$(cd "${BIDS_DIR}" && pwd)"
[[ -f "${BIDS_DIR}/dataset_description.json" ]] || {
  echo "ERROR [bids-validator]: missing dataset_description.json in ${BIDS_DIR}" >&2
  exit 1
}

ARGS=(--ignoreSubjectConsistency --ignoreNIfTIHeaders)
((IGNORE_WARNINGS)) && ARGS+=(--ignoreWarnings)

run_cli() {
  echo "[bids-validator] ${*}"
  "$@"
}

if command -v bids-validator >/dev/null 2>&1; then
  run_cli bids-validator "${BIDS_DIR}" "${ARGS[@]}"
  exit $?
fi

if [[ -n "${BIDS_VALIDATOR_SIF:-}" && -f "${BIDS_VALIDATOR_SIF}" ]]; then
  run_cli apptainer exec -B "${BIDS_DIR}:${BIDS_DIR}:ro" "${BIDS_VALIDATOR_SIF}" \
    bids-validator "${BIDS_DIR}" "${ARGS[@]}"
  exit $?
fi

if command -v npx >/dev/null 2>&1; then
  run_cli npx --yes bids-validator "${BIDS_DIR}" "${ARGS[@]}"
  exit $?
fi

cat >&2 <<'EOF'
ERROR [bids-validator]: no validator found.

Install one of:
  npm install -g bids-validator
  npx bids-validator (requires Node.js)
  export BIDS_VALIDATOR_SIF=/path/to/bids-validator.sif

Or omit --bids-validation to skip (default).
EOF
exit 1
