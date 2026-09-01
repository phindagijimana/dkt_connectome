#!/bin/bash
# =============================================================================
# run_subject.sh — subject.sh-equivalent CLI in front of the Snakemake
# plugin/workflow engine. Translates (mode, subject, flags) into a
# `snakemake --config ... -- <target>` invocation, using a generated
# override configfile for anything that needs a nested config key (--config
# on the Snakemake CLI itself only sets flat top-level keys).
#
# Usage (mirrors dwi_pipeline/subject.sh exactly):
#   bash run_subject.sh all 014                  # full pipeline
#   bash run_subject.sh all 014 --fastsurfer
#   bash run_subject.sh all 014 --fast-fs         # FastSurfer + --fsaparc
#   bash run_subject.sh all 014 --no-recon
#   bash run_subject.sh all 014 --no-connectome   # (Step 5 with it)
#   bash run_subject.sh all 014 --no-inpaint
#   bash run_subject.sh all 014 --no-node-strength
#   bash run_subject.sh qsiprep 014
#   bash run_subject.sh inpaint 014               # Step 1.1 only (needs a lesion mask)
#   bash run_subject.sh recon 014 --fastsurfer
#   bash run_subject.sh qsirecon 014
#   bash run_subject.sh connectome 014
#   bash run_subject.sh disconnectome 014   # Step 4.1 (needs lesion mask + DKT connectome)
#   bash run_subject.sh nodestrength 014
#
# Not yet ported from subject.sh (use subject.sh directly for these):
#   CONNECTOME_LEGACY_DUAL_CONTAINER=1.
#
# Extra flags not in subject.sh:
#   --dry-run     forward -n to snakemake (show the plan, run nothing)
#   --            everything after this is passed through to snakemake as-is
# =============================================================================
set -euo pipefail
set +H

WORKFLOW_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DWI_PIPELINE_DIR="$(dirname "${WORKFLOW_DIR}")"
COMMON_SH="${WORKFLOW_DIR}/lib/common.sh"
SLURM_ENV_SH="${WORKFLOW_DIR}/lib/slurm_env.sh"
RESOLVE_SESSION_PY="${WORKFLOW_DIR}/lib/resolve_session.py"
source "${COMMON_SH}"
# shellcheck source=workflow/lib/slurm_env.sh
if [[ -z "${DKT_ORCHESTRATOR_RUNTIME:-}" ]]; then
  source "${SLURM_ENV_SH}"
fi

PIPELINE_MODE="${1:?Need mode: all, qsiprep, inpaint, recon, qsirecon, connectome, disconnectome, or nodestrength}"
[[ "${PIPELINE_MODE}" == "dk" ]] && PIPELINE_MODE="connectome"
SUBJECT="${2:?Need subject id}"
SUBJECT="${SUBJECT#sub-}"
shift 2 || true

NTHREADS="${NTHREADS:-8}"
RESULTS_ROOT="${RESULTS_ROOT:-}"
BIDS_DIR="${BIDS_DIR:-}"
DRY_RUN=0
declare -A OVERRIDES=()   # dotted-path -> YAML scalar value
[[ -n "${RECON_SESSION:-}" ]] && OVERRIDES[recon.session]="${RECON_SESSION}"
declare -a SNAKEMAKE_PASSTHROUGH=()

REPO_ROOT="$(dirname "${DWI_PIPELINE_DIR}")"
export XDG_CACHE_HOME="${XDG_CACHE_HOME:-${REPO_ROOT}/.cache}"
mkdir -p "${XDG_CACHE_HOME}"

# Apply subject.sh-equivalent env vars when CLI flags did not already set them.
_apply_env() {
  local key="$1" val="${2:-}"
  [[ -n "${val}" ]] || return 0
  if [[ -z "${OVERRIDES[$key]+x}" ]]; then
    OVERRIDES["$key"]="$val"
  fi
  return 0
}
[[ "${QSIPREP_USE_SYN_SDC:-0}" == "1" ]] && _apply_env qsiprep.use_syn_sdc true
[[ "${QSIPREP_FMAP_RETRY:-0}" == "1" ]] && _apply_env qsiprep.fmap_retry true
[[ "${QSIPREP_NO_SDC:-0}"      == "1" ]] && _apply_env qsiprep.no_sdc      true
_apply_env qsiprep.bids_filter        "${QSIPREP_BIDS_FILTER:-}"
_apply_env dwi_select.json            "${DWI_SELECT_JSON:-}"
_apply_env dwi_select.shell_b         "${DWI_SHELL_B:-}"
[[ "${QSIPREP_NO_DWI_FILTER:-0}" == "1" ]] && _apply_env dwi_select.enabled false
_apply_env recon.enabled              "$([[ "${RUN_RECON:-1}" == "1" ]] && echo true || echo false)"
_apply_env recon.tool                 "${RECON_TOOL:-}"
_apply_env recon.fsaparc              "$([[ "${RECON_FSAPARC:-0}" == "1" ]] && echo true || echo false)"
_apply_env recon.fastsurfer_device    "${RECON_FASTSURFER_DEVICE:-}"
_apply_env recon.session              "${RECON_SESSION:-}"
_apply_env recon_out                  "${RECON_OUT:-}"
_apply_env fs_subjects_dir            "${FS_SUBJECTS_DIR:-}"
_apply_env nodestrength_out           "${NODESTRENGTH_OUT:-}"
_apply_env inpaint.enabled            "$([[ "${RUN_INPAINT:-1}" == "1" ]] && echo true || echo false)"
_apply_env inpaint.backend            "${ANAT_MITIGATION:-}"
_apply_env inpaint.require_mask       "$([[ "${INPAINT_REQUIRE_MASK:-0}" == "1" ]] && echo true || echo false)"
_apply_env inpaint.dilate             "${INPAINT_DILATE:-}"
_apply_env inpaint.device             "${INPAINT_DEVICE:-}"
_apply_env inpaint.batch_size         "${INPAINT_BATCH_SIZE:-}"
_apply_env inpaint.labels             "${INPAINT_LABELS:-}"
_apply_env inpaint.binarize           "$([[ "${INPAINT_BINARIZE:-0}" == "1" ]] && echo true || echo false)"
_apply_env inpaint.fail_on_qc         "$([[ "${INPAINT_FAIL_ON_QC:-0}" == "1" ]] && echo true || echo false)"
_apply_env inpaint.vbt.smoothing_factor "${VBT_SMOOTHING_FACTOR:-}"
_apply_env act.mode                   "${ACT_MODE:-}"
_apply_env act.five_tt_source         "${ACT_FIVE_TT_SOURCE:-}"
_apply_env act.deep_atropos.segmentation "${DEEP_ATROPOS_SEG:-}"
_apply_env act.deep_atropos.segmentation_mode "${DEEP_ATROPOS_SEG_MODE:-}"
_apply_env act.deep_atropos.antsxnet_cache "${DEEP_ATROPOS_ANTSXNET_CACHE:-}"
_apply_env act.streamlines            "${ACT_STREAMLINES:-}"
_apply_env act.random_seed             "${ACT_RANDOM_SEED:-}"
_apply_env tractography.model          "${TRACTOGRAPHY_MODEL:-}"
_apply_env experiment.arm              "${EXPERIMENT_ARM:-}"
_apply_env connectome.enabled         "$([[ "${RUN_CONNECTOME:-${RUN_DK_CONNECTOME:-1}}" == "1" ]] && echo true || echo false)"
_apply_env connectome.parcellation    "${CONNECTOME_PARCELLATION:-}"
_apply_env connectome.fail_on_empty_nodes "$([[ "${CONNECTOME_FAIL_ON_EMPTY_NODES:-0}" == "1" ]] && echo true || echo false)"
_apply_env connectome.deterministic   "$([[ "${CONNECTOME_DETERMINISTIC:-1}" == "1" ]] && echo true || echo false)"
_apply_env connectome.resample_to_dwi "$([[ "${CONNECTOME_RESAMPLE_TO_DWI:-1}" == "1" ]] && echo true || echo false)"
_apply_env connectome.weighting       "${CONNECTOME_WEIGHTING:-count}"
_apply_env connectome.primary_measure "${PRIMARY_CONNECTOME_MEASURE:-}"
_apply_env connectome.sift2       "$([[ "${CONNECTOME_SIFT2:-0}" == "1" ]] && echo true || echo false)"
if [[ -n "${CONNECTOME_ATLASES:-}" ]]; then
  _apply_env connectome.atlases         "${CONNECTOME_ATLASES}"
fi
_apply_env disconnectome.enabled      "$([[ "${RUN_DISCONNECTOME:-0}" == "1" ]] && echo true || echo false)"
_apply_env disconnectome.core_only    "$([[ "${DISCONNECTOME_CORE_ONLY:-0}" == "1" ]] && echo true || echo false)"
_apply_env disconnectome.lesion_erode_voxels "${DISCONNECTOME_ERODE_VOXELS:-0}"
_apply_env disconnectome.weighting    "${DISCONNECTOME_WEIGHTING:-${CONNECTOME_WEIGHTING:-count}}"
_apply_env nodestrength.enabled       "$([[ "${RUN_NODESTRENGTH:-1}" == "1" ]] && echo true || echo false)"
_apply_env nodestrength.strength_only "$([[ "${NODESTRENGTH_STRENGTH_ONLY:-0}" == "1" ]] && echo true || echo false)"
_apply_env nodestrength.no_report     "$([[ "${NODESTRENGTH_NO_REPORT:-0}" == "1" ]] && echo true || echo false)"
_apply_env random_seed                 "${RANDOM_SEED:-0}"
_apply_env qsirecon.spec              "${QSIRECON_SPEC:-}"
if [[ -n "${QSIRECON_ATLASES:-}" ]]; then
  _apply_env qsirecon.atlases         "${QSIRECON_ATLASES}"
fi
# Container / license paths (same env names as subject.sh; override config.local.yaml)
_apply_env containers.qsiprep         "${CONTAINER_QSIPREP:-}"
_apply_env containers.qsirecon        "${CONTAINER_QSIRECON:-}"
_apply_env containers.fastsurfer      "${CONTAINER_FASTSURFER:-}"
_apply_env containers.freesurfer      "${CONTAINER_FREESURFER:-}"
_apply_env containers.connectome      "${CONTAINER_CONNECTOME:-}"
_apply_env containers.vbt              "${CONTAINER_VBT:-}"
_apply_env containers.lesion_act       "${CONTAINER_LESION_ACT:-}"
_apply_env containers.deep_atropos    "${CONTAINER_DEEP_ATROPOS:-}"
_apply_env containers.deep_atropos_seg "${CONTAINER_DEEP_ATROPOS_SEG:-}"
_apply_env containers.lit             "${CONTAINER_LIT:-}"
_apply_env containers.nodestrength    "${CONTAINER_NODESTRENGTH:-}"
_apply_env fs_license                 "${FS_LICENSE:-}"
_apply_env templateflow_home          "${TEMPLATEFLOW_HOME:-}"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --syn|--use-syn-sdc)   OVERRIDES[qsiprep.use_syn_sdc]=true ;;
    --fmap-retry)          OVERRIDES[qsiprep.fmap_retry]=true ;;
    --no-sdc)              OVERRIDES[qsiprep.no_sdc]=true ;;
    --bids-filter)         OVERRIDES[qsiprep.bids_filter]="${2:?Need path after --bids-filter}"; shift ;;
    --fastsurfer)          OVERRIDES[recon.tool]=fastsurfer ;;
    --freesurfer)          OVERRIDES[recon.tool]=freesurfer ;;
    --fast-fs)             OVERRIDES[recon.tool]=fastsurfer; OVERRIDES[recon.fsaparc]=true ;;
    --no-recon)            OVERRIDES[recon.enabled]=false ;;
    --no-connectome|--no-dk) OVERRIDES[connectome.enabled]=false ;;
    --inpaint)             OVERRIDES[inpaint.enabled]=true; OVERRIDES[inpaint.backend]=neurolit ;;
    --no-inpaint)          OVERRIDES[inpaint.enabled]=false; OVERRIDES[inpaint.backend]=none ;;
    --anat-mitigation)
      OVERRIDES[inpaint.backend]="${2:?Need none, neurolit, or vbt}"
      if [[ "${2}" == "none" ]]; then
        OVERRIDES[inpaint.enabled]=false
      else
        OVERRIDES[inpaint.enabled]=true
      fi
      shift
      ;;
    --node-strength)       OVERRIDES[nodestrength.enabled]=true ;;
    --no-node-strength)    OVERRIDES[nodestrength.enabled]=false ;;
    --strength-only)       OVERRIDES[nodestrength.strength_only]=true ;;
    --no-report)           OVERRIDES[nodestrength.no_report]=true ;;
    --dwi-shell)           OVERRIDES[dwi_select.shell_b]="${2:?Need b-value after --dwi-shell}"; shift ;;
    --dwi-select)          OVERRIDES[dwi_select.json]="${2:?Need path after --dwi-select}"; shift ;;
    --no-dwi-filter)       OVERRIDES[dwi_select.enabled]=false ;;
    --recon-session)       OVERRIDES[recon.session]="${2:?Need session after --recon-session}"; shift ;;
    --session-filter)      OVERRIDES[recon.session]="${2:?Need session after --session-filter}"; shift ;;
    --connectome-weighting) OVERRIDES[connectome.weighting]="${2:?Need count or sift2}"; shift ;;
    --primary-connectome-measure) OVERRIDES[connectome.primary_measure]="${2:?Need count or sift2}"; shift ;;
    --connectome-atlases)     OVERRIDES[connectome.atlases]="${2:?Need atlas list (e.g. dkt or dkt,lausanne60)}"; shift ;;
    --act-mode)             OVERRIDES[act.mode]="${2:?Need standard or lesion-aware}"; shift ;;
    --act-5tt-source)       OVERRIDES[act.five_tt_source]="${2:?Need hsvs or deep-atropos-native}"; shift ;;
    --deep-atropos-seg)     OVERRIDES[act.deep_atropos.segmentation]="${2:?Need segmentation path}"; shift ;;
    --deep-atropos-seg-mode) OVERRIDES[act.deep_atropos.segmentation_mode]="${2:?Need auto, import, or generate}"; shift ;;
    --act-streamlines)      OVERRIDES[act.streamlines]="${2:?Need streamline count}"; shift ;;
    --tractography-model)   OVERRIDES[tractography.model]="${2:?Need ifod2, sd_stream, or both}"; shift ;;
    --connectome-sift2)      OVERRIDES[connectome.sift2]=true ;;
    --experiment-arm)       OVERRIDES[experiment.arm]="${2:?Need experiment arm}"; shift ;;
    --no-disconnectome)    OVERRIDES[disconnectome.enabled]=false ;;
    --disconnection|--disconnectome) OVERRIDES[disconnectome.enabled]=true ;;
    --disconnectome-core-only) OVERRIDES[disconnectome.core_only]=true ;;
    --disconnectome-erode-voxels) OVERRIDES[disconnectome.lesion_erode_voxels]="${2:?Need N after --disconnectome-erode-voxels}"; shift ;;
    --disconnectome-weighting) OVERRIDES[disconnectome.weighting]="${2:?Need count or sift2}"; shift ;;
    --dry-run|-n)          DRY_RUN=1 ;;
    --)
      shift
      SNAKEMAKE_PASSTHROUGH+=("$@")
      break
      ;;
    -h|--help)
      awk '/^# Usage/,/^# ={10,}$/' "$0" | sed 's/^# \{0,1\}//; $d'
      exit 0
      ;;
    *)
      echo "Unknown option: $1 (see --help)"
      exit 1
      ;;
  esac
  shift
done

EXPERIMENT_ARM_EFFECTIVE="${OVERRIDES[experiment.arm]:-${EXPERIMENT_ARM:-}}"
if [[ -n "${EXPERIMENT_ARM_EFFECTIVE}" ]]; then
  case "${EXPERIMENT_ARM_EFFECTIVE}" in
    orig-std)         _arm_backend=none;     _arm_act=standard ;;
    orig-lesion)      _arm_backend=none;     _arm_act=lesion-aware ;;
    neurolit-std)     _arm_backend=neurolit; _arm_act=standard ;;
    neurolit-lesion)  _arm_backend=neurolit; _arm_act=lesion-aware ;;
    vbt-std)          _arm_backend=vbt;      _arm_act=standard ;;
    vbt-lesion)       _arm_backend=vbt;      _arm_act=lesion-aware ;;
    deep-atropos-pilot) _arm_backend=none;   _arm_act=lesion-aware ;;
    *) echo "Invalid --experiment-arm=${EXPERIMENT_ARM_EFFECTIVE}" >&2; exit 2 ;;
  esac
  OVERRIDES[experiment.arm]="${EXPERIMENT_ARM_EFFECTIVE}"
  OVERRIDES[inpaint.backend]="${_arm_backend}"
  OVERRIDES[inpaint.enabled]="$([[ "${_arm_backend}" == "none" ]] && echo false || echo true)"
  OVERRIDES[act.mode]="${_arm_act}"
  if [[ -n "${RESULTS_ROOT}" && "${EXPERIMENT_ISOLATE_OUTPUTS:-1}" == "1" ]]; then
    case "${RESULTS_ROOT}" in
      */arms/"${EXPERIMENT_ARM_EFFECTIVE}") ;;
      *) RESULTS_ROOT="${RESULTS_ROOT}/arms/${EXPERIMENT_ARM_EFFECTIVE}" ;;
    esac
  fi
  echo "Experiment arm: ${EXPERIMENT_ARM_EFFECTIVE} (anatomy=${_arm_backend}, ACT=${_arm_act})"
fi

# --- Build merged configfile (Snakemake replaces config on each --configfile) ---
OVERRIDE_YAML="$(mktemp /tmp/dwi_workflow_override_XXXXXX.yaml)"
trap 'rm -f "${OVERRIDE_YAML}"' EXIT
BASE_CONFIG="${WORKFLOW_DIR}/config/config.yaml"
LOCAL_CONFIG="${WORKFLOW_DIR}/config/config.local.yaml"
{
  echo "subject: \"${SUBJECT}\""
  [[ -n "${RESULTS_ROOT}" ]] && echo "results_root: \"${RESULTS_ROOT}\""
  [[ -n "${BIDS_DIR}" ]]     && echo "bids_dir: \"${BIDS_DIR}\""
  echo "nthreads: ${NTHREADS}"
} > "${OVERRIDE_YAML}.runtime"
${PIPELINE_PYTHON} - "${BASE_CONFIG}" "${LOCAL_CONFIG}" "${OVERRIDE_YAML}.runtime" "${OVERRIDE_YAML}" <<PY
import sys, yaml
from pathlib import Path

def merge(base, override):
    for key, val in override.items():
        if isinstance(val, dict) and isinstance(base.get(key), dict):
            merge(base[key], val)
        else:
            base[key] = val

base = yaml.safe_load(open(sys.argv[1])) or {}
local = Path(sys.argv[2])
if local.is_file():
    merge(base, yaml.safe_load(local.open()) or {})
merge(base, yaml.safe_load(open(sys.argv[3])) or {})
overrides = {
$(for k in "${!OVERRIDES[@]}"; do printf '    %s: %s,\n' "\"${k}\"" "\"${OVERRIDES[$k]}\""; done)
}
def to_scalar(v):
    if v in ("true", "false"):
        return v == "true"
    try:
        return int(v)
    except ValueError:
        return v
for dotted, raw in overrides.items():
    node = base
    parts = dotted.split(".")
    for part in parts[:-1]:
        node = node.setdefault(part, {})
    val = to_scalar(raw)
    if parts[-1] == "atlases" and isinstance(val, str):
        node[parts[-1]] = [part for part in val.replace(",", " ").split() if part]
    else:
        node[parts[-1]] = val
with open(sys.argv[4], "w") as fh:
    yaml.safe_dump(base, fh)
PY
rm -f "${OVERRIDE_YAML}.runtime"

case "${PIPELINE_MODE}" in
  all)          TARGET="all" ;;
  qsiprep)      TARGET="target_qsiprep" ;;
  recon)        TARGET="target_recon" ;;
  qsirecon)     TARGET="target_qsirecon" ;;
  act)          TARGET="target_act" ;;
  sdstream)     TARGET="target_sdstream" ;;
  sdstream-tractography) TARGET="target_sdstream_tractography" ;;
  connectome)   TARGET="target_connectome" ;;
  disconnectome) TARGET="target_disconnectome" ;;
  nodestrength) TARGET="target_nodestrength" ;;
  subject_qc)   TARGET="target_subject_qc" ;;
  inpaint)      TARGET="target_inpaint" ;;
  *)
    echo "Invalid mode=${PIPELINE_MODE} (use all, qsiprep, inpaint, recon, qsirecon, act, sdstream, sdstream-tractography, connectome, disconnectome, nodestrength, or subject_qc)"
    exit 1
    ;;
esac

# --- Step 1.1 no-op guard for standalone `inpaint` mode -----------------------
# Mirrors subject.sh's run_inpaint(): calling the plugin for a subject with
# no lesion mask is a silent no-op, not an error, unless require_mask is set.
if [[ "${PIPELINE_MODE}" == "inpaint" ]]; then
  INPAINT_ENABLED="${OVERRIDES[inpaint.enabled]:-true}"
  INPAINT_BACKEND="${OVERRIDES[inpaint.backend]:-${ANAT_MITIGATION:-neurolit}}"
  if [[ "${INPAINT_ENABLED}" != "true" || "${INPAINT_BACKEND}" == "none" ]]; then
    echo "Anatomy mitigation: disabled (backend=none)"
    exit 0
  else
    _results_root="${RESULTS_ROOT:-/path/to/dwi_pipeline/dwi_test_TBI}"
    _bids_dir="${BIDS_DIR:-/path/to/BIDS}"
    _filter_cache="${_results_root}/intermediate_results_qsiprep_single/bids_filter_sub-${SUBJECT}.json"
    mkdir -p "$(dirname "${_filter_cache}")"
    _dwi_shell_b="${OVERRIDES[dwi_select.shell_b]:-${DWI_SHELL_B:-1000}}"
    _dwi_select_json="${OVERRIDES[dwi_select.json]:-${DWI_SELECT_JSON:-${DWI_PIPELINE_DIR}/config/dwi_select_b${_dwi_shell_b}.json}}"
    _static_filter="${OVERRIDES[qsiprep.bids_filter]:-${QSIPREP_BIDS_FILTER:-}}"
    declare -a _resolve_session_args=(--bids-dir "${_bids_dir}" --subject "${SUBJECT}" --filter-cache "${_filter_cache}")
    if [[ -n "${OVERRIDES[recon.session]:-${RECON_SESSION:-}}" ]]; then
      _resolve_session_args+=(--recon-session "${OVERRIDES[recon.session]:-${RECON_SESSION}}")
    elif [[ -n "${_static_filter}" ]]; then
      _resolve_session_args+=(--static-bids-filter "${_static_filter}")
    else
      _resolve_session_args+=(--dwi-select-json "${_dwi_select_json}")
    fi
    _session="$("${PIPELINE_PYTHON}" "${RESOLVE_SESSION_PY}" "${_resolve_session_args[@]}")"
    BIDS_DIR="${_bids_dir}"
    _mask="$(find_lesion_mask "${SUBJECT}" "${_session}")"
    if [[ -z "${_mask}" ]]; then
      _require_mask="${OVERRIDES[inpaint.require_mask]:-false}"
      if [[ "${_require_mask}" == "true" ]]; then
        _pipeline_fail "inpaint" "require_mask=true but no lesion mask found for sub-${SUBJECT} ses-${_session}"
      fi
      echo "Inpaint: no lesion mask for sub-${SUBJECT} ses-${_session} — skipping Step 1.1 (no-op, same as subject.sh)"
      exit 0
    fi
  fi
fi

# --- Step 4.1 no-op guard for standalone `disconnectome` mode ----------------
if [[ "${PIPELINE_MODE}" == "disconnectome" ]]; then
  DISCONNECTOME_ENABLED="${OVERRIDES[disconnectome.enabled]:-true}"
  if [[ "${DISCONNECTOME_ENABLED}" == "true" ]]; then
    _results_root="${RESULTS_ROOT:-/path/to/dwi_pipeline/dwi_test_TBI}"
    _bids_dir="${BIDS_DIR:-/path/to/BIDS}"
    _filter_cache="${_results_root}/intermediate_results_qsiprep_single/bids_filter_sub-${SUBJECT}.json"
    mkdir -p "$(dirname "${_filter_cache}")"
    _dwi_shell_b="${OVERRIDES[dwi_select.shell_b]:-${DWI_SHELL_B:-1000}}"
    _dwi_select_json="${OVERRIDES[dwi_select.json]:-${DWI_SELECT_JSON:-${DWI_PIPELINE_DIR}/config/dwi_select_b${_dwi_shell_b}.json}}"
    _static_filter="${OVERRIDES[qsiprep.bids_filter]:-${QSIPREP_BIDS_FILTER:-}}"
    declare -a _resolve_session_args=(--bids-dir "${_bids_dir}" --subject "${SUBJECT}" --filter-cache "${_filter_cache}")
    if [[ -n "${OVERRIDES[recon.session]:-${RECON_SESSION:-}}" ]]; then
      _resolve_session_args+=(--recon-session "${OVERRIDES[recon.session]:-${RECON_SESSION}}")
    elif [[ -n "${_static_filter}" ]]; then
      _resolve_session_args+=(--static-bids-filter "${_static_filter}")
    else
      _resolve_session_args+=(--dwi-select-json "${_dwi_select_json}")
    fi
    _session="$("${PIPELINE_PYTHON}" "${RESOLVE_SESSION_PY}" "${_resolve_session_args[@]}")"
    _mask_prepared="$(find_prepared_lesion_mask "${_results_root}" "${SUBJECT}" "${_session}" || true)"
    _dkt_matrix="${_results_root}/connectomes/sub-${SUBJECT}/dkt_connectome.csv"
    if [[ -z "${_mask_prepared}" ]]; then
      echo "Disconnectome: no prepared lesion mask under ${_results_root}/{lesion_masks,inpainted,vbt}/sub-${SUBJECT}/ses-${_session}/ — skipping Step 4.1 (no-op)"
      exit 0
    fi
    if [[ ! -f "${_dkt_matrix}" ]]; then
      _pipeline_fail "disconnectome" "missing DKT connectome: ${_dkt_matrix} (run Step 4 first)"
    fi
  fi
fi

_experiment_arm="${EXPERIMENT_ARM_EFFECTIVE:-${EXPERIMENT_ARM:-}}"
if [[ -z "${SNAKEMAKE_WORKDIR:-}" && -n "${_experiment_arm}" && -n "${RESULTS_ROOT:-}" ]]; then
  # Per-arm metadata dir only; pipeline outputs stay under RESULTS_ROOT (unchanged).
  SNAKEMAKE_WORKDIR="${RESULTS_ROOT}/.snakemake_workdir"
fi
SNAKEMAKE_WORKDIR="${SNAKEMAKE_WORKDIR:-${DWI_PIPELINE_DIR}}"
mkdir -p "${SNAKEMAKE_WORKDIR}/.snakemake/locks"
if [[ -n "${_experiment_arm}" ]]; then
  rm -rf "${SNAKEMAKE_WORKDIR}/.snakemake/locks"
  mkdir -p "${SNAKEMAKE_WORKDIR}/.snakemake/locks"
fi

declare -a CMD=(
  snakemake -s "${WORKFLOW_DIR}/Snakefile"
  --directory "${SNAKEMAKE_WORKDIR}"
  # Single merged configfile: Snakemake replaces (not deep-merges) on each
  # --configfile, so runtime overrides must include the full effective config.
  --configfile "${OVERRIDE_YAML}"
  --cores "${NTHREADS}"
)
[[ "${SKIP_RERUN_INCOMPLETE:-0}" != "1" ]] && CMD+=(--rerun-incomplete)
((DRY_RUN)) && CMD+=(--dry-run)
CMD+=("${SNAKEMAKE_PASSTHROUGH[@]}")
CMD+=(-- "${TARGET}")

echo "+ ${CMD[*]}"
exec "${CMD[@]}"
