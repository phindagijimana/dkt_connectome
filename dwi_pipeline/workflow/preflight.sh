#!/bin/bash
# =============================================================================
# preflight.sh — Validate environment before a Snakemake pipeline run
# =============================================================================
# Called by submit.sh (once before sbatch) and array.sh (per subject task).
# Exit 0 = OK; non-zero = do not start the workflow.
#
# Usage:
#   bash workflow/preflight.sh [--mode all|qsiprep|...] [--subject SUB] [--quick]
# =============================================================================
set -euo pipefail

WORKFLOW_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DWI_PIPELINE_DIR="$(dirname "${WORKFLOW_DIR}")"
TRACKTBI_ROOT="$(dirname "${DWI_PIPELINE_DIR}")"

PIPELINE_MODE="${PIPELINE_MODE:-all}"
SUBJECT=""
QUICK=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --mode) PIPELINE_MODE="${2:?}"; shift 2 ;;
    --subject) SUBJECT="${2:?}"; shift 2; SUBJECT="${SUBJECT#sub-}" ;;
    --quick) QUICK=1; shift ;;
    -h|--help)
      sed -n '2,12p' "$0" | sed 's/^# \{0,1\}//'
      exit 0
      ;;
    *) echo "Unknown option: $1"; exit 1 ;;
  esac
done

BIDS_DIR="${BIDS_DIR:-/path/to/dwi_pipeline/dwi_test_TBI/bids}"
RESULTS_ROOT="${RESULTS_ROOT:-/path/to/dwi_pipeline/dwi_test_TBI}"
CONFIG="${WORKFLOW_DIR}/config/config.yaml"
LOCAL_CONFIG="${WORKFLOW_DIR}/config/config.local.yaml"

read_config() {
  python3 - "${CONFIG}" "${LOCAL_CONFIG}" "$1" <<'PY'
import sys, yaml
from pathlib import Path

def merge(base, override):
    for key, val in override.items():
        if isinstance(val, dict) and isinstance(base.get(key), dict):
            merge(base[key], val)
        else:
            base[key] = val

cfg = yaml.safe_load(open(sys.argv[1])) or {}
local = Path(sys.argv[2])
if local.is_file():
    merge(cfg, yaml.safe_load(local.open()) or {})
key = sys.argv[3]
node = cfg
for part in key.split("."):
    if not isinstance(node, dict):
        node = None
        break
    node = node.get(part)
print("" if node is None else node)
PY
}

fail() { echo "ERROR [preflight]: $*" >&2; exit 1; }
warn() { echo "WARNING [preflight]: $*" >&2; }

echo "preflight: mode=${PIPELINE_MODE} engine=snakemake"

command -v snakemake >/dev/null 2>&1 || fail "snakemake not found (pip install snakemake or module load)"
command -v apptainer >/dev/null 2>&1 || fail "apptainer not found"
command -v python3 >/dev/null 2>&1 || fail "python3 not found"

[[ -d "${BIDS_DIR}" ]] || fail "BIDS_DIR missing: ${BIDS_DIR}"
[[ -d "${WORKFLOW_DIR}" ]] || fail "workflow dir missing: ${WORKFLOW_DIR}"
[[ -f "${CONFIG}" ]] || fail "config missing: ${CONFIG}"
[[ -f "${WORKFLOW_DIR}/Snakefile" ]] || fail "Snakefile missing"
[[ -f "${WORKFLOW_DIR}/run_subject.sh" ]] || fail "run_subject.sh missing"

mkdir -p "${RESULTS_ROOT}" "${RESULTS_ROOT}/logs"

# Snakemake cache must live on writable storage (not $HOME on some nodes).
export XDG_CACHE_HOME="${XDG_CACHE_HOME:-${TRACKTBI_ROOT}/.cache}"
mkdir -p "${XDG_CACHE_HOME}"

if [[ -n "${SUBJECT}" ]]; then
  [[ -d "${BIDS_DIR}/sub-${SUBJECT}" ]] || fail "subject missing: ${BIDS_DIR}/sub-${SUBJECT}"
fi

# Container paths from merged config (config.yaml + optional config.local.yaml).
read_container() {
  read_config "containers.${1}"
}

need_qsiprep=0 need_qsirecon=0 need_recon=0 need_connectome=0 need_inpaint=0 need_nodestrength=0
case "${PIPELINE_MODE}" in
  all)
    need_qsiprep=1; need_qsirecon=1; need_connectome=1; need_nodestrength=1
    [[ "${RUN_RECON:-1}" == "1" ]] && need_recon=1
    [[ "${RUN_INPAINT:-1}" == "1" ]] && need_inpaint=1
    [[ "${RUN_CONNECTOME:-1}" == "0" ]] && need_connectome=0 && need_nodestrength=0
    [[ "${RUN_NODESTRENGTH:-1}" == "0" ]] && need_nodestrength=0
    ;;
  qsiprep) need_qsiprep=1 ;;
  inpaint) need_inpaint=1 ;;
  recon) need_recon=1 ;;
  qsirecon) need_qsirecon=1 ;;
  connectome) need_connectome=1 ;;
  nodestrength) need_nodestrength=1 ;;
  *) fail "invalid PIPELINE_MODE=${PIPELINE_MODE}" ;;
esac

# Prefer subject.sh-style env overrides, then config.local.yaml / config.yaml.
FS_LICENSE="${FS_LICENSE:-$(read_config fs_license)}"
FS_LICENSE="${FS_LICENSE:-/path/to/others/data_mining/freesurfer/license.txt}"
[[ -f "${FS_LICENSE}" ]] || fail "FreeSurfer license missing: ${FS_LICENSE}"

check_sif() {
  local label="$1" path="$2"
  [[ -n "${path}" && -f "${path}" ]] || fail "container missing (${label}): ${path}"
}

container_path() {
  local key="$1" env_name="$2"
  local from_env="${!env_name:-}"
  if [[ -n "${from_env}" ]]; then
    echo "${from_env}"
  else
    read_container "${key}"
  fi
}

((need_qsiprep)) && check_sif qsiprep "$(container_path qsiprep CONTAINER_QSIPREP)"
((need_qsirecon)) && check_sif qsirecon "$(container_path qsirecon CONTAINER_QSIRECON)"
((need_connectome)) && check_sif connectome "$(container_path connectome CONTAINER_CONNECTOME)"
((need_inpaint)) && check_sif lit "$(container_path lit CONTAINER_LIT)"
((need_nodestrength)) && check_sif nodestrength "$(container_path nodestrength CONTAINER_NODESTRENGTH)"

if ((need_recon)); then
  case "${RECON_TOOL:-freesurfer}" in
    freesurfer) check_sif freesurfer "$(container_path freesurfer CONTAINER_FREESURFER)" ;;
    fastsurfer) check_sif fastsurfer "$(container_path fastsurfer CONTAINER_FASTSURFER)" ;;
    *) fail "invalid RECON_TOOL=${RECON_TOOL:-}" ;;
  esac
fi

# HSVS specs need an existing FreeSurfer/FastSurfer subject tree once recon has run
# (or been provided). Warn at submit-time; fail at per-subject preflight if missing
# after recon is expected to already exist (qsirecon-only / connectome modes).
QSIRECON_SPEC="${QSIRECON_SPEC:-$(read_config qsirecon.spec)}"
QSIRECON_SPEC="${QSIRECON_SPEC:-mrtrix_singleshell_ss3t_ACT-hsvs}"
FS_SUBJECTS_DIR="${FS_SUBJECTS_DIR:-$(read_config fs_subjects_dir)}"
FS_SUBJECTS_DIR="${FS_SUBJECTS_DIR:-${RECON_OUT:-${RESULTS_ROOT}/freesurfer}}"
if ((need_qsirecon)) && [[ "${QSIRECON_SPEC}" == *hsvs* ]]; then
  if [[ -n "${SUBJECT}" ]]; then
    if [[ "${PIPELINE_MODE}" == "qsirecon" || "${PIPELINE_MODE}" == "connectome" || "${PIPELINE_MODE}" == "nodestrength" ]]; then
      [[ -d "${FS_SUBJECTS_DIR}/sub-${SUBJECT}" ]] || fail \
        "QSIRECON_SPEC=${QSIRECON_SPEC} needs ${FS_SUBJECTS_DIR}/sub-${SUBJECT} (run Step 2 first)"
    elif [[ ! -d "${FS_SUBJECTS_DIR}/sub-${SUBJECT}" && "${RUN_RECON:-1}" == "0" ]]; then
      fail "QSIRECON_SPEC=${QSIRECON_SPEC} needs FreeSurfer but RUN_RECON=0 and ${FS_SUBJECTS_DIR}/sub-${SUBJECT} missing"
    fi
  fi
fi

# QSIPrep SDC configuration sanity check (same rules as subject.sh).
QSIPREP_USE_SYN_SDC="${QSIPREP_USE_SYN_SDC:-0}"
QSIPREP_FMAP_RETRY="${QSIPREP_FMAP_RETRY:-0}"
QSIPREP_BIDS_FILTER="${QSIPREP_BIDS_FILTER:-}"
QSIPREP_NO_DWI_FILTER="${QSIPREP_NO_DWI_FILTER:-0}"
if ((need_qsiprep)) && [[ "${QSIPREP_FMAP_RETRY}" != "1" && "${QSIPREP_USE_SYN_SDC}" != "1" ]]; then
  if [[ "${QSIPREP_NO_DWI_FILTER}" == "1" && -z "${QSIPREP_BIDS_FILTER}" ]]; then
    warn "QSIPrep: no dwi-filter and no --syn — SDC will fail unless fmaps are in a static filter"
  fi
fi

# GPU recommendation for inpaint / FastSurfer cuda.
if ((need_inpaint)) && [[ "${RUN_INPAINT:-1}" == "1" ]]; then
  if [[ -z "${SBATCH_GRES:-}" && -z "${SLURM_JOB_ID:-}" ]]; then
    warn "Step 1.5 (inpaint) needs a GPU slice (gpu:l40s.12g or gpu:l40s.24g). Set SBATCH_GRES before submit."
  fi
fi

if ((QUICK)); then
  echo "preflight: quick checks OK"
  exit 0
fi

# Per-subject DAG dry-run when a subject is given (catches dwi-select / session errors early).
if [[ -n "${SUBJECT}" ]]; then
  echo "preflight: dry-run DAG for sub-${SUBJECT} ..."
  bash "${WORKFLOW_DIR}/run_subject.sh" "${PIPELINE_MODE}" "${SUBJECT}" --dry-run >/dev/null \
    || fail "dry-run failed for sub-${SUBJECT} (check dwi-select / --syn / session settings)"
fi

echo "preflight: OK"
