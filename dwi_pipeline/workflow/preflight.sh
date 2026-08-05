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

BIDS_DIR="${BIDS_DIR:-/path/to/CIDUR_BIDS/data_bids}"
RESULTS_ROOT="${RESULTS_ROOT:-/path/to/CIDUR_BIDS/dwi_test}"
CONFIG="${WORKFLOW_DIR}/config/config.yaml"

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

# Container paths from config.yaml defaults (override via env if set).
read_container() {
  python3 - "${CONFIG}" "$1" <<'PY'
import sys, yaml
cfg = yaml.safe_load(open(sys.argv[1]))
key = sys.argv[2]
print(cfg.get("containers", {}).get(key, ""))
PY
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

FS_LICENSE="${FS_LICENSE:-/path/to/others/data_mining/freesurfer/license.txt}"
[[ -f "${FS_LICENSE}" ]] || fail "FreeSurfer license missing: ${FS_LICENSE}"

check_sif() {
  local label="$1" path="$2"
  [[ -n "${path}" && -f "${path}" ]] || fail "container missing (${label}): ${path}"
}

((need_qsiprep)) && check_sif qsiprep "$(read_container qsiprep)"
((need_qsirecon)) && check_sif qsirecon "$(read_container qsirecon)"
((need_connectome)) && check_sif connectome "$(read_container connectome)"
((need_inpaint)) && check_sif lit "$(read_container lit)"
((need_nodestrength)) && check_sif nodestrength "$(read_container nodestrength)"

if ((need_recon)); then
  case "${RECON_TOOL:-freesurfer}" in
    freesurfer) check_sif freesurfer "$(read_container freesurfer)" ;;
    fastsurfer) check_sif fastsurfer "$(read_container fastsurfer)" ;;
    *) fail "invalid RECON_TOOL=${RECON_TOOL:-}" ;;
  esac
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
