#!/usr/bin/env bash
# One-command install: pull step containers + write workflow/config/config.local.yaml
#
# Usage:
#   ./dkt install                  # all containers (same as: ./dkt install all)
#   ./dkt install all
#   ./dkt install qsirecon         # one container
#   ./dkt install qsirecon --force # re-pull one container
#   ./dkt install qsiprep qsirecon # several containers
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
DRY_RUN=0
# doctor: auto = run for full install, skip for single-container; override with flags
DOCTOR="auto"

usage() {
  cat <<'EOF'
Usage: install.sh [targets ...] [options]
       ./dkt install [targets ...] [options]

Pull pinned Apptainer images (container_pins in config.yaml) and write
workflow/config/config.local.yaml with local .sif paths.

Targets (positional; default = all):
  all                 Every step image (qsiprep, qsirecon, freesurfer, ...)
  KEY [KEY ...]       One or more container keys only (easier re-download)

  Valid KEY values:
    qsiprep qsirecon freesurfer fastsurfer connectome vbt
    lesion_act deep_atropos deep_atropos_seg lit nodestrength

Examples:
  ./dkt install
  ./dkt install all
  ./dkt install qsirecon
  ./dkt install qsirecon --force
  ./dkt install qsiprep qsirecon --missing-only
  ./dkt install --only qsirecon --force   # equivalent flag form
  ./dkt install --dry-run qsirecon        # print plan; no pull

Options:
  --cache DIR         Container cache (default: ~/.cache/dkt-connectome/containers)
  --config PATH       Output config.local.yaml (default: workflow/config/config.local.yaml)
  --mode MODE         Pull subset for pipeline *mode* (all, qsiprep, recon, ...)
                      Note: --mode qsirecon pulls qsirecon+freesurfer; positional
                      qsirecon pulls only the qsirecon image.
  --only KEY,KEY      Pull only these keys (same as positional KEY KEY)
  --missing-only      Skip images already in cache
  --force             Re-pull / rebuild even if present
  --skip-pull         Only write config.local.yaml (paths must exist)
  --dry-run           Print which keys would be pulled; do not pull or write config
  --doctor            Always run ./run doctor at end
  --no-doctor         Never run doctor (default for single-container installs)
  --quiet             Less logging
  -h, --help

After install:
  export FS_LICENSE=/path/to/license.txt
  ./run doctor
  bash scripts/download_ideas_sample.sh   # optional public sample

Environment:
  DKT_CONTAINER_CACHE   Same as --cache
  APPTAINER_TMPDIR      Temp dir for apptainer pull (default: <cache>/../apptainer_tmp)
  PROOT_TMP_DIR         Also set to APPTAINER_TMPDIR — required when /tmp is noexec
EOF
}

TARGETS=()
while [[ $# -gt 0 ]]; do
  case "$1" in
    --cache) CACHE="$2"; shift 2 ;;
    --config) CONFIG_OUT="$2"; shift 2 ;;
    --mode) MODE="$2"; shift 2 ;;
    --only) ONLY="$2"; shift 2 ;;
    --missing-only) MISSING_ONLY=1; shift ;;
    --force) FORCE=1; shift ;;
    --skip-pull) SKIP_PULL=1; shift ;;
    --dry-run) DRY_RUN=1; shift ;;
    --doctor) DOCTOR=1; shift ;;
    --no-doctor) DOCTOR=0; shift ;;
    --quiet) QUIET=1; shift ;;
    -h|--help) usage; exit 0 ;;
    --*)
      echo "Unknown option: $1" >&2
      usage
      exit 2
      ;;
    *)
      TARGETS+=("$1")
      shift
      ;;
  esac
done

if [[ ${#TARGETS[@]} -gt 0 ]]; then
  if [[ -n "${ONLY}" ]]; then
    echo "ERROR: pass either positional targets or --only, not both" >&2
    exit 2
  fi
  # Join as comma list for container_install.resolve_keys
  ONLY=$(IFS=,; echo "${TARGETS[*]}")
fi

if [[ -n "${ONLY}" && -n "${MODE}" ]]; then
  echo "ERROR: pass either install targets/--only or --mode, not both" >&2
  exit 2
fi

# Single-container (or subset) installs skip doctor by default — other images may
# still be missing and would make doctor noisy. Full install keeps doctor on.
if [[ "${DOCTOR}" == "auto" ]]; then
  if [[ -n "${ONLY}" && "${ONLY}" != "all" ]]; then
    DOCTOR=0
  else
    DOCTOR=1
  fi
fi

export DKT_CONTAINER_CACHE="${CACHE}"
mkdir -p "${CACHE}"
if [[ -z "${APPTAINER_TMPDIR:-}" ]]; then
  APPTAINER_TMPDIR="$(dirname "${CACHE}")/apptainer_tmp"
fi
if ! mkdir -p "${APPTAINER_TMPDIR}" 2>/dev/null; then
  APPTAINER_TMPDIR="${CACHE}/apptainer_tmp"
  mkdir -p "${APPTAINER_TMPDIR}"
fi
export APPTAINER_TMPDIR
# proot (used during OCI→SIF) ignores APPTAINER_TMPDIR and fails on noexec /tmp
export SINGULARITY_TMPDIR="${SINGULARITY_TMPDIR:-${APPTAINER_TMPDIR}}"
export PROOT_TMP_DIR="${PROOT_TMP_DIR:-${APPTAINER_TMPDIR}}"

PY="${SCRIPT_DIR}/container_install.py"
# write-config only accepts --cache/--config/--quiet (not --mode/--only)
cfg_args=(--cache "${CACHE}" --config "${CONFIG_OUT}")
((QUIET)) && cfg_args+=(--quiet)

select_args=()
[[ -n "${MODE}" ]] && select_args+=(--mode "${MODE}")
[[ -n "${ONLY}" ]] && select_args+=(--only "${ONLY}")

if ((DRY_RUN)); then
  echo "[install] dry-run — keys that would be pulled:"
  list_args=(list --cache "${CACHE}" "${select_args[@]}")
  python3 "${PY}" "${list_args[@]}"
  exit 0
fi

if ((SKIP_PULL)); then
  echo "[install] skip pull — writing config only"
  python3 "${PY}" write-config "${cfg_args[@]}"
else
  pull_args=(pull --cache "${CACHE}" --config "${CONFIG_OUT}" --write-config "${select_args[@]}")
  ((MISSING_ONLY)) && pull_args+=(--missing-only)
  ((FORCE)) && pull_args+=(--force)
  ((QUIET)) && pull_args+=(--quiet)
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
