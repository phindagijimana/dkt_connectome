#!/usr/bin/env bash
# One-command install: pull step containers + write workflow/config/config.local.yaml
#
# Usage:
#   bash scripts/install.sh
#   bash scripts/install.sh --cache ~/.cache/dkt-connectome/containers
#   bash scripts/install.sh --missing-only --mode qsiprep
#   DKT_CONTAINER_CACHE=/shared/containers bash scripts/install.sh
#
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DWI_PIPELINE_DIR="$(dirname "${SCRIPT_DIR}")"
CONFIG_OUT="${DWI_PIPELINE_DIR}/workflow/config/config.local.yaml"

CACHE="${DKT_CONTAINER_CACHE:-${HOME}/.cache/dkt-connectome/containers}"
MISSING_ONLY=0
FORCE=0
QUIET=0
MODE=""
ONLY=""
SKIP_PULL=0
DOCTOR=1

usage() {
  cat <<'EOF'
Usage: install.sh [options]

Pull pinned Apptainer images (container_pins in config.yaml) and write
workflow/config/config.local.yaml with local .sif paths.

Options:
  --cache DIR         Container cache (default: ~/.cache/dkt-connectome/containers)
  --config PATH       Output config.local.yaml (default: workflow/config/config.local.yaml)
  --mode MODE         Pull subset for pipeline mode (all, qsiprep, recon, ...)
  --only KEY,KEY      Pull only these keys (qsiprep, qsirecon, ...)
  --missing-only      Skip images already in cache
  --force             Re-pull / rebuild even if present
  --skip-pull         Only write config.local.yaml (paths must exist)
  --no-doctor         Skip ./run doctor at end
  --quiet             Less logging
  -h, --help

After install:
  export FS_LICENSE=/path/to/license.txt
  ./run doctor
  bash scripts/download_ideas_sample.sh   # optional public sample

Environment:
  DKT_CONTAINER_CACHE   Same as --cache
  APPTAINER_TMPDIR      Temp dir for apptainer pull (default: <cache>/../apptainer_tmp)
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --cache) CACHE="$2"; shift 2 ;;
    --config) CONFIG_OUT="$2"; shift 2 ;;
    --mode) MODE="$2"; shift 2 ;;
    --only) ONLY="$2"; shift 2 ;;
    --missing-only) MISSING_ONLY=1; shift ;;
    --force) FORCE=1; shift ;;
    --skip-pull) SKIP_PULL=1; shift ;;
    --no-doctor) DOCTOR=0; shift ;;
    --quiet) QUIET=1; shift ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown option: $1" >&2; usage; exit 2 ;;
  esac
done

export DKT_CONTAINER_CACHE="${CACHE}"
mkdir -p "${CACHE}"
export APPTAINER_TMPDIR="${APPTAINER_TMPDIR:-$(dirname "${CACHE}")/apptainer_tmp}"
mkdir -p "${APPTAINER_TMPDIR}"

PY="${SCRIPT_DIR}/container_install.py"
args=(--cache "${CACHE}" --config "${CONFIG_OUT}")
[[ -n "${MODE}" ]] && args+=(--mode "${MODE}")
[[ -n "${ONLY}" ]] && args+=(--only "${ONLY}")
((QUIET)) && args+=(--quiet)

if ((SKIP_PULL)); then
  echo "[install] skip pull — writing config only"
  python3 "${PY}" write-config "${args[@]}"
else
  pull_args=(pull "${args[@]}" --write-config)
  ((MISSING_ONLY)) && pull_args+=(--missing-only)
  ((FORCE)) && pull_args+=(--force)
  python3 "${PY}" "${pull_args[@]}"
fi

echo ""
echo "[install] cache: ${CACHE}"
echo "[install] config: ${CONFIG_OUT}"
echo "[install] next: export FS_LICENSE=/path/to/license.txt"
echo "[install] verify: ./run doctor"

if ((DOCTOR)); then
  echo ""
  echo "[install] running ./run doctor ..."
  bash "${SCRIPT_DIR}/doctor.sh" --cache "${CACHE}" || true
fi
