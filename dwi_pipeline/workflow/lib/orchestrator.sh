#!/bin/bash
# =============================================================================
# orchestrator.sh — Run the BIDS App (./run) inside the pinned orchestrator SIF
#
# HPC pattern: host Slurm -> apptainer exec dkt_connectome_orchestrator.sif -> ./run
# Step containers (QSIPrep, connectome, ...) are still separate .sif files on NFS;
# the orchestrator image supplies Snakemake + Python glue only.
# =============================================================================

_orchestrator_fail() {
  echo "ERROR [orchestrator]: $*" >&2
  exit 1
}

_orchestrator_repo_dwi() {
  if [[ -n "${DWI_ROOT:-}" && -d "${DWI_ROOT}" ]]; then
    echo "${DWI_ROOT}"
  elif [[ -n "${REPO_ROOT:-}" && -d "${REPO_ROOT}/dwi_pipeline" ]]; then
    echo "${REPO_ROOT}/dwi_pipeline"
  else
    _orchestrator_fail "DWI_ROOT or REPO_ROOT/dwi_pipeline must be set"
  fi
}

_orchestrator_read_config_orchestrator() {
  local cfg="${1}/workflow/config/config.yaml"
  local local_cfg="${1}/workflow/config/config.local.yaml"
  "${PIPELINE_PYTHON:-python3}" - "${cfg}" "${local_cfg}" <<'PY' 2>/dev/null || true
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
print((cfg.get("containers") or {}).get("orchestrator") or "")
PY
}

resolve_orchestrator_sif() {
  if [[ -n "${CONTAINER_ORCHESTRATOR:-}" && -f "${CONTAINER_ORCHESTRATOR}" ]]; then
    echo "${CONTAINER_ORCHESTRATOR}"
    return 0
  fi
  local dwi_root cache ver sif
  dwi_root="$(_orchestrator_repo_dwi)"
  ver="${DKT_ORCHESTRATOR_VERSION:-0.2.0}"
  cache="${DKT_CONTAINER_CACHE:-${HOME}/.cache/dkt-connectome/containers}"
  sif="${cache}/dkt_connectome_orchestrator_${ver}.sif"
  if [[ -f "${sif}" ]]; then
    echo "${sif}"
    return 0
  fi
  sif="$(_orchestrator_read_config_orchestrator "${dwi_root}")"
  if [[ -n "${sif}" && -f "${sif}" ]]; then
    echo "${sif}"
    return 0
  fi
  return 1
}

_orchestrator_bind_file() {
  local -n _binds=$1
  local path="$2"
  [[ -n "${path}" && -e "${path}" ]] || return 0
  local real
  real="$(readlink -f "${path}" 2>/dev/null || echo "${path}")"
  _binds+=(-B "${real}:${real}")
}

_orchestrator_bind_apptainer() {
  local -n _binds=$1
  local appt_bin libexec etc
  appt_bin="$(command -v apptainer 2>/dev/null || command -v singularity 2>/dev/null || true)"
  [[ -n "${appt_bin}" ]] || return 0
  _binds+=(-B "${appt_bin}:${appt_bin}:ro")
  libexec="$(dirname "${appt_bin}")/../libexec/apptainer"
  [[ -d "${libexec}" ]] && _binds+=(-B "${libexec}:${libexec}:ro")
  for etc in /etc/apptainer /etc/singularity; do
    [[ -d "${etc}" ]] && _binds+=(-B "${etc}:${etc}:ro")
  done
}

_orchestrator_export_env() {
  local -n _env=$1
  local key val
  for key in \
    BIDS_DIR RESULTS_ROOT RECON_OUT FS_SUBJECTS_DIR NODESTRENGTH_OUT \
    NTHREADS OMP_NTHREADS RECON_SESSION EXPERIMENT_ARM EXPERIMENT_ISOLATE_OUTPUTS \
    QSIPREP_USE_SYN_SDC QSIPREP_FMAP_RETRY QSIPREP_NO_SDC QSIPREP_BIDS_FILTER \
    DWI_SELECT_JSON DWI_SHELL_B QSIPREP_NO_DWI_FILTER \
    RUN_RECON RECON_TOOL RECON_FSAPARC RUN_CONNECTOME RUN_INPAINT RUN_NODESTRENGTH \
    ANAT_MITIGATION ACT_MODE ACT_STREAMLINES ACT_RANDOM_SEED TRACTOGRAPHY_MODEL \
    CONNECTOME_SIFT2 RUN_DISCONNECTOME DISCONNECTOME_CORE_ONLY \
    DISCONNECTOME_ERODE_VOXELS DISCONNECTOME_WEIGHTING PRIMARY_CONNECTOME_MEASURE \
    CONNECTOME_WEIGHTING CONNECTOME_PARCELLATION QSIRECON_SPEC QSIRECON_ATLASES \
    INPAINT_DEVICE INPAINT_BATCH_SIZE VBT_SMOOTHING_FACTOR \
    CONTAINER_QSIPREP CONTAINER_QSIRECON CONTAINER_FASTSURFER CONTAINER_FREESURFER \
    CONTAINER_CONNECTOME CONTAINER_VBT CONTAINER_LESION_ACT CONTAINER_LIT \
    CONTAINER_NODESTRENGTH FS_LICENSE TEMPLATEFLOW_HOME DKT_CONTAINER_CACHE \
    XDG_CACHE_HOME SNAKEMAKE_WORKDIR RANDOM_SEED
  do
    val="${!key:-}"
    [[ -n "${val}" ]] && _env+=(--env "${key}=${val}")
  done
  _env+=(--env DKT_ORCHESTRATOR_RUNTIME=1)
  _env+=(--env PIPELINE_PYTHON=/usr/local/bin/python3)
}

# Invoke ./run inside the orchestrator SIF (BIDS App participant level).
run_orchestrator_participant() {
  local subject="$1" mode="$2"
  shift 2

  local sif dwi_root repo_root
  sif="$(resolve_orchestrator_sif)" || _orchestrator_fail \
    "orchestrator SIF not found — run: bash dwi_pipeline/scripts/build_orchestrator_sif.sh"
  dwi_root="$(_orchestrator_repo_dwi)"
  repo_root="$(dirname "${dwi_root}")"

  : "${BIDS_DIR:?BIDS_DIR required}"
  : "${RESULTS_ROOT:?RESULTS_ROOT required}"

  local -a binds=()
  binds+=(-B "${dwi_root}:/opt/dkt-connectome/dwi_pipeline:ro")
  binds+=(-B "${repo_root}:${repo_root}")
  binds+=(-B "${BIDS_DIR}:${BIDS_DIR}:ro")
  binds+=(-B "${RESULTS_ROOT}:${RESULTS_ROOT}")
  _orchestrator_bind_file binds "${FS_LICENSE:-}"
  _orchestrator_bind_file binds "${TEMPLATEFLOW_HOME:-}"
  _orchestrator_bind_file binds "${DKT_CONTAINER_CACHE:-}"
  _orchestrator_bind_file binds "${XDG_CACHE_HOME:-${repo_root}/.cache}"
  local cpath
  for cpath in \
    "${CONTAINER_QSIPREP:-}" "${CONTAINER_QSIRECON:-}" \
    "${CONTAINER_FASTSURFER:-}" "${CONTAINER_FREESURFER:-}" \
    "${CONTAINER_CONNECTOME:-}" "${CONTAINER_VBT:-}" \
    "${CONTAINER_LESION_ACT:-}" "${CONTAINER_LIT:-}" \
    "${CONTAINER_NODESTRENGTH:-}"
  do
    _orchestrator_bind_file binds "${cpath}"
  done
  _orchestrator_bind_apptainer binds

  local -a env_args=()
  _orchestrator_export_env env_args

  local -a nv=()
  if [[ -n "${SBATCH_GRES:-}" && "${SBATCH_GRES}" == *gpu* ]]; then
    nv=(--nv)
  fi

  local -a run_args=(
    "${BIDS_DIR}" "${RESULTS_ROOT}" participant
    --participant-label "${subject}"
    --mode "${mode}"
    --n-cpus "${NTHREADS:-8}"
    --skip-bids-validation
  )
  [[ -n "${RECON_SESSION:-}" ]] && run_args+=(--session-filter "${RECON_SESSION}")
  run_args+=("$@")

  echo "BIDS App orchestrator: ${sif}"
  echo "  sub-${subject} mode=${mode} -> ${RESULTS_ROOT}"
  exec apptainer exec --cleanenv "${nv[@]}" "${binds[@]}" "${env_args[@]}" \
    --pwd /opt/dkt-connectome/dwi_pipeline \
    "${sif}" \
    ./run "${run_args[@]}"
}
