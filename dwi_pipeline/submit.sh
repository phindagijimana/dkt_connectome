#!/bin/bash
# =============================================================================
# submit.sh — Build subject list and submit Slurm array (entry point)
# =============================================================================
#
# What this script does:
#   1. Scans BIDS and writes dwi_pipeline/subjects.txt (DWI participants by default)
#   2. Submits array.sh with --array=1-N%K (default K=5 concurrent jobs)
#   3. Exports env vars so each array task runs the pipeline engine with the same settings
#
# Pipeline per subject (see subject.sh / workflow/run_subject.sh):
#   QSIPrep -> Inpaint (Step 1.5, only if a lesion mask exists) ->
#   Recon (recon-all by default, FastSurfer with --fastsurfer) ->
#   QSIRecon (mrtrix_singleshell_ss3t_ACT-hsvs) -> connectome ->
#   Node strength / ENIGMA report (Step 5, auto-on when the connectome ran)
#
# Usage:
#   ./submit.sh                    # full pipeline, recon-all (slow, ~10 h/subject)
#   ./submit.sh --fastsurfer       # full pipeline, FastSurfer (~1-2 h/subject CPU)
#   ./submit.sh --fast-fs          # FastSurfer + --fsaparc (adds a DK-68 atlas too)
#   ./submit.sh --no-recon         # skip Step 2 (set ACT-fast spec or FS dir first)
#   ./submit.sh --no-connectome    # full QSIPrep+Recon+QSIRecon, no connectome CSV (skips Step 5 too)
#   ./submit.sh --no-inpaint       # force-skip Step 1.5 even for subjects with a lesion mask
#   ./submit.sh --anat-mitigation vbt      # LeAPP-compatible virtual brain transplant (Step 1.5)
#   ./submit.sh --act-mode lesion-aware    # Step 3.5: lesion in 5TT pathology channel
#   ./submit.sh --experiment-arm neurolit-lesion   # anatomy + ACT arm; writes arms/neurolit-lesion/
#   ./submit.sh --tractography-model both  # optional SD_STREAM connectomes alongside iFOD2
#   ./submit.sh --no-node-strength # skip Step 5 only (keep the connectome CSV)
#   ./submit.sh --syn              # GE / no-fmap subjects: --use-syn-sdc error
#   ./submit.sh --fmap-retry       # ignore measured fmaps, SyN SDC
#   ./submit.sh --no-sdc           # skip SDC entirely (matches previous no-fieldmap GE runs)
#   ./submit.sh --dwi-shell 1000     # default: acq-b1000 + IntendedFor fmaps for QSIPrep
#   ./submit.sh --no-dwi-filter      # legacy: no series filter
#   ./submit.sh --bids-validation    # run bids-validator on BIDS_DIR before submit
#
# Common overrides:
#   PIPELINE_ENGINE=snakemake     # default; use bash for legacy subject.sh path
#   ARRAY_CONCURRENCY=5          # Slurm %K throttle
#   PIPELINE_MODE=qsiprep        # only QSIPrep
#   PIPELINE_MODE=inpaint        # only Step 1.5 (needs a lesion mask for the subject)
#   PIPELINE_MODE=recon          # only Step 2 (recon-all / FastSurfer)
#   PIPELINE_MODE=qsirecon       # only QSIRecon (QSIPrep must already exist)
#   PIPELINE_MODE=connectome     # only Step 4 (needs QSIRecon + FS outputs)
#   PIPELINE_MODE=nodestrength   # only Step 5 (needs an existing connectome CSV)
#   RECON_TOOL=fastsurfer        # same as --fastsurfer
#   RECON_FSAPARC=1              # same as --fast-fs (with RECON_TOOL=fastsurfer)
#   RUN_RECON=0                  # same as --no-recon
#   RUN_CONNECTOME=0             # same as --no-connectome
#   RUN_INPAINT=0                # same as --no-inpaint
#   RUN_NODESTRENGTH=0           # same as --no-node-strength
#   NODESTRENGTH_OUT=/path       # Step 5 output dir (default RESULTS_ROOT/node_strength)
#   INPAINT_DEVICE=cuda          # auto (default) | cpu | cuda -- see subject.sh header
#   QSIRECON_SPEC=mrtrix_singleshell_ss3t_ACT-fast  # skip FreeSurfer requirement
#   QSIRECON_ATLASES="Schaefer100"  # parcellations baked in by QSIRecon
#   RESULTS_ROOT=/path/to/output
#   RECON_OUT=/path/freesurfer   # FreeSurfer subjects dir (default RESULTS_ROOT/freesurfer)
#   FS_SUBJECTS_DIR=/path        # point Steps 3+4 at an external FS tree
#   SUBJECT_LIST_ONLY_DWI=0      # include all sub-* folders, not only those with DWI
#   QSIPREP_USE_SYN_SDC=1        # same as --syn
#   QSIPREP_NO_SDC=1             # same as --no-sdc (skip SDC entirely)
#   DWI_SHELL_B=1000             # b-value for default dwi-select config
#   QSIPREP_NO_DWI_FILTER=1      # same as --no-dwi-filter
#   EXCLUDE_NODES=smdodwork05    # comma-list passed to sbatch --exclude
#   SBATCH_GRES=gpu:l40s.24g:1   # GPU for Step 1.5 inpainting (auto-set when inpaint on)
#   SBATCH_DEPENDENCY=afterok:JOBID
#                                # chain this submission after another Slurm job
#                                # (e.g. PIPELINE_MODE=qsirecon SBATCH_DEPENDENCY=afterok:44600)
#   SBATCH_PARTITION=interactive # override array.sh's #SBATCH --partition= line
#   SBATCH_TIME=12:00:00         # override array.sh's #SBATCH --time= line
#                                # (must fit the partition's MaxTime; default 12h
#                                # is the interactive partition cap)
#   SBATCH_CPUS=8                # override --cpus-per-task; needs to match
#                                # NTHREADS to keep eddy/recon-all/QSIPrep happy
#   SBATCH_MEM=32G               # override --mem
#   SBATCH_JOB_NAME=dwi_test2    # override --job-name (and the output filenames)
# =============================================================================

set -euo pipefail
set +H

QSIPREP_USE_SYN_SDC="${QSIPREP_USE_SYN_SDC:-0}"
QSIPREP_FMAP_RETRY="${QSIPREP_FMAP_RETRY:-0}"
QSIPREP_NO_SDC="${QSIPREP_NO_SDC:-0}"
QSIPREP_BIDS_FILTER="${QSIPREP_BIDS_FILTER:-}"
DWI_SELECT_JSON="${DWI_SELECT_JSON:-}"
DWI_SHELL_B="${DWI_SHELL_B:-1000}"
QSIPREP_NO_DWI_FILTER="${QSIPREP_NO_DWI_FILTER:-0}"
RUN_RECON="${RUN_RECON:-1}"
RECON_TOOL="${RECON_TOOL:-freesurfer}"
RECON_FSAPARC="${RECON_FSAPARC:-0}"
RUN_INPAINT="${RUN_INPAINT:-1}"
ANAT_MITIGATION="${ANAT_MITIGATION:-neurolit}"
[[ "${RUN_INPAINT}" == "1" ]] || ANAT_MITIGATION=none
# RUN_DK_CONNECTOME was the name before Step 4 served both DK and DKT.
RUN_CONNECTOME="${RUN_CONNECTOME:-${RUN_DK_CONNECTOME:-1}}"
PRIMARY_CONNECTOME_MEASURE="${PRIMARY_CONNECTOME_MEASURE:-}"
ACT_MODE="${ACT_MODE:-standard}"
ACT_STREAMLINES="${ACT_STREAMLINES:-10000000}"
ACT_RANDOM_SEED="${ACT_RANDOM_SEED:-0}"
TRACTOGRAPHY_MODEL="${TRACTOGRAPHY_MODEL:-both}"
CONNECTOME_SIFT2="${CONNECTOME_SIFT2:-0}"
EXPERIMENT_ARM="${EXPERIMENT_ARM:-}"
RUN_NODESTRENGTH="${RUN_NODESTRENGTH:-1}"
PIPELINE_ENGINE="${PIPELINE_ENGINE:-snakemake}"
RECON_FASTSURFER_DEVICE="${RECON_FASTSURFER_DEVICE:-cpu}"
INPAINT_DEVICE="${INPAINT_DEVICE:-auto}"
INPAINT_BATCH_SIZE="${INPAINT_BATCH_SIZE:-4}"
VBT_SMOOTHING_FACTOR="${VBT_SMOOTHING_FACTOR:-2.0}"
BIDS_VALIDATE="${BIDS_VALIDATE:-0}"
BIDS_IGNORE_WARNINGS="${BIDS_IGNORE_WARNINGS:-0}"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --syn|--use-syn-sdc)
      QSIPREP_USE_SYN_SDC=1
      ;;
    --fmap-retry)
      QSIPREP_FMAP_RETRY=1
      ;;
    --no-sdc)
      QSIPREP_NO_SDC=1
      ;;
    --fastsurfer)
      RECON_TOOL=fastsurfer
      ;;
    --freesurfer)
      RECON_TOOL=freesurfer
      ;;
    --fast-fs)
      RECON_TOOL=fastsurfer
      RECON_FSAPARC=1
      ;;
    --no-recon)
      RUN_RECON=0
      ;;
    --no-connectome|--no-dk)
      RUN_CONNECTOME=0
      ;;
    --inpaint)
      RUN_INPAINT=1
      ANAT_MITIGATION=neurolit
      ;;
    --no-inpaint)
      RUN_INPAINT=0
      ANAT_MITIGATION=none
      ;;
    --anat-mitigation)
      ANAT_MITIGATION="${2:?Need none, neurolit, or vbt}"
      [[ "${ANAT_MITIGATION}" == "none" ]] && RUN_INPAINT=0 || RUN_INPAINT=1
      shift 2
      continue
      ;;
    --act-mode)
      ACT_MODE="${2:?Need standard or lesion-aware}"
      shift 2
      continue
      ;;
    --act-streamlines)
      ACT_STREAMLINES="${2:?Need streamline count}"
      shift 2
      continue
      ;;
    --tractography-model)
      TRACTOGRAPHY_MODEL="${2:?Need ifod2, sd_stream, or both}"
      shift 2
      continue
      ;;
    --connectome-sift2)
      CONNECTOME_SIFT2=1
      ;;
    --experiment-arm)
      EXPERIMENT_ARM="${2:?Need experiment arm}"
      shift 2
      continue
      ;;
    --node-strength)
      RUN_NODESTRENGTH=1
      ;;
    --no-node-strength)
      RUN_NODESTRENGTH=0
      ;;
    --bids-filter)
      QSIPREP_BIDS_FILTER="$2"
      shift 2
      continue
      ;;
    --dwi-select)
      DWI_SELECT_JSON="$2"
      shift 2
      continue
      ;;
    --dwi-shell)
      DWI_SHELL_B="$2"
      DWI_SELECT_JSON=""
      shift 2
      continue
      ;;
    --no-dwi-filter)
      QSIPREP_NO_DWI_FILTER=1
      ;;
    --bids-validation)
      BIDS_VALIDATE=1
      ;;
    --ignore-warnings)
      BIDS_IGNORE_WARNINGS=1
      ;;
    -h|--help)
      sed -n '11,63p' "$0"
      exit 0
      ;;
    *)
      echo "Unknown option: $1 (try --syn, --fmap-retry, --no-sdc, --dwi-shell, --no-dwi-filter, --fastsurfer, --fast-fs, --no-recon, --no-connectome, --anat-mitigation, --act-mode, --experiment-arm, --tractography-model, --inpaint, --no-inpaint, --node-strength, --no-node-strength)"
      exit 1
      ;;
  esac
  shift
done

case "${ANAT_MITIGATION}" in
  none|neurolit|vbt) ;;
  *) echo "ERROR: ANAT_MITIGATION must be none, neurolit, or vbt"; exit 2 ;;
esac
case "${ACT_MODE}" in
  standard|lesion-aware) ;;
  *) echo "ERROR: ACT_MODE must be standard or lesion-aware"; exit 2 ;;
esac
case "${TRACTOGRAPHY_MODEL}" in
  ifod2|sd_stream|both) ;;
  *) echo "ERROR: TRACTOGRAPHY_MODEL must be ifod2, sd_stream, or both"; exit 2 ;;
esac

DWI_ROOT="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "${DWI_ROOT}/.." && pwd)"

# --- Defaults (override via environment before ./submit.sh) ---
BIDS_DIR="${BIDS_DIR:-/path/to/dwi_pipeline/dwi_test_TBI/bids}"
RESULTS_ROOT="${RESULTS_ROOT:-/path/to/dwi_pipeline/dwi_test_TBI}"
if [[ -n "${EXPERIMENT_ARM}" ]]; then
  case "${EXPERIMENT_ARM}" in
    orig-std)         ANAT_MITIGATION=none;     ACT_MODE=standard ;;
    orig-lesion)      ANAT_MITIGATION=none;     ACT_MODE=lesion-aware ;;
    neurolit-std)     ANAT_MITIGATION=neurolit; ACT_MODE=standard ;;
    neurolit-lesion)  ANAT_MITIGATION=neurolit; ACT_MODE=lesion-aware ;;
    vbt-std)          ANAT_MITIGATION=vbt;      ACT_MODE=standard ;;
    vbt-lesion)       ANAT_MITIGATION=vbt;      ACT_MODE=lesion-aware ;;
    *) echo "ERROR: invalid EXPERIMENT_ARM=${EXPERIMENT_ARM}"; exit 2 ;;
  esac
  [[ "${ANAT_MITIGATION}" == "none" ]] && RUN_INPAINT=0 || RUN_INPAINT=1
  if [[ "${EXPERIMENT_ISOLATE_OUTPUTS:-1}" == "1" ]]; then
    case "${RESULTS_ROOT}" in
      */arms/"${EXPERIMENT_ARM}") ;;
      *) RESULTS_ROOT="${RESULTS_ROOT}/arms/${EXPERIMENT_ARM}" ;;
    esac
  fi
fi
SUBJECT_LIST_FILE="${SUBJECT_LIST_FILE:-${DWI_ROOT}/subjects.txt}"
SUBJECT_LIST_ONLY_DWI="${SUBJECT_LIST_ONLY_DWI:-1}"
ARRAY_SCRIPT="${DWI_ROOT}/array.sh"
ARRAY_CONCURRENCY="${ARRAY_CONCURRENCY:-5}"
NTHREADS="${NTHREADS:-8}"
OMP_NTHREADS="${OMP_NTHREADS:-8}"
PIPELINE_MODE="${PIPELINE_MODE:-all}"
# Step 4 was called "dk" before it served both DK and DKT.
[[ "${PIPELINE_MODE}" == "dk" ]] && PIPELINE_MODE="connectome"
QSIRECON_SPEC="${QSIRECON_SPEC:-mrtrix_singleshell_ss3t_ACT-hsvs}"
# QSIRecon MRtrix specs require at least one atlas for connectivity estimation.
# 4S156Parcels = Schaefer-100 cortex + Tian/HCP 56 subcortex (modern default).
# See subject.sh for the full list of recognised built-in atlas names.
QSIRECON_ATLASES="${QSIRECON_ATLASES-4S156Parcels}"
RECON_OUT="${RECON_OUT:-${RESULTS_ROOT}/freesurfer}"
FS_SUBJECTS_DIR="${FS_SUBJECTS_DIR:-${RECON_OUT}}"
# Workaround: smdodwork05 fails the Slurm prolog ("mkdir /var/spool/slurmd/logs:
# Permission denied"). Excluded by default; override with EXCLUDE_NODES="" or a
# different comma-list when the node is healthy again.
EXCLUDE_NODES="${EXCLUDE_NODES-smdodwork05}"

[[ -d "${BIDS_DIR}" ]] || { echo "BIDS directory missing: ${BIDS_DIR}"; exit 1; }
[[ -f "${ARRAY_SCRIPT}" ]] || { echo "Missing array script: ${ARRAY_SCRIPT}"; exit 1; }
if [[ -n "${QSIPREP_BIDS_FILTER}" && -n "${DWI_SELECT_JSON}" ]]; then
  echo "ERROR: use only one of --bids-filter or --dwi-select"; exit 1
fi

mkdir -p "${REPO_ROOT}/logs" "${RESULTS_ROOT}"

# --- Build subjects.txt (skip if SUBJECT_LIST_USE_EXISTING=1 and file already has entries) ---
if [[ "${SUBJECT_LIST_USE_EXISTING:-0}" == "1" && -s "${SUBJECT_LIST_FILE}" ]]; then
  echo "Using existing subject list: ${SUBJECT_LIST_FILE}"
elif [[ "${SUBJECT_LIST_ONLY_DWI}" == "1" ]]; then
  # Only participants with at least one DWI NIfTI (matches main cohort QC list idea)
  tmp="${SUBJECT_LIST_FILE}.$$"
  : > "${tmp}"
  shopt -s nullglob
  for d in "${BIDS_DIR}"/sub-*; do
    [[ -d "$d" ]] || continue
    id="${d##*/}"
    id="${id#sub-}"
    if find "$d" -type f \( -name '*.nii.gz' -o -name '*.nii' \) -path '*/dwi/*' -print -quit 2>/dev/null | grep -q .; then
      echo "${id}" >> "${tmp}"
    fi
  done
  shopt -u nullglob
  sort -u "${tmp}" > "${SUBJECT_LIST_FILE}"
  rm -f "${tmp}"
else
  # Every top-level sub-* folder
  find "${BIDS_DIR}" -maxdepth 1 -mindepth 1 -type d -name "sub-*" -printf "%f\n" 2>/dev/null | sed 's/^sub-//' | sort -u > "${SUBJECT_LIST_FILE}"
fi

N=$(wc -l < "${SUBJECT_LIST_FILE}")
[[ "${N}" -ge 1 ]] || { echo "Subject list is empty: ${SUBJECT_LIST_FILE}"; exit 1; }

RECON_OUT="${RECON_OUT:-${RESULTS_ROOT}/freesurfer}"
FS_SUBJECTS_DIR="${FS_SUBJECTS_DIR:-${RECON_OUT}}"
if [[ "${PIPELINE_MODE}" == "qsirecon" || "${PIPELINE_MODE}" == "connectome" ]]; then
  _first_sub="$(head -1 "${SUBJECT_LIST_FILE}")"
  if [[ ! -d "${FS_SUBJECTS_DIR}/sub-${_first_sub}" ]]; then
    echo "ERROR [submit/FS_SUBJECTS_DIR]: ${FS_SUBJECTS_DIR}/sub-${_first_sub} not found"
    echo "  Run recon (PIPELINE_MODE=recon or all) before ${PIPELINE_MODE}."
    exit 1
  fi
fi

echo "dwi_pipeline submit"
echo "  Engine: ${PIPELINE_ENGINE}"
echo "  Subjects: ${N} from ${SUBJECT_LIST_FILE}"
echo "  Array: 1-${N}%${ARRAY_CONCURRENCY}"
echo "  Mode: ${PIPELINE_MODE}"
echo "  RESULTS_ROOT: ${RESULTS_ROOT}"
[[ -n "${EXPERIMENT_ARM}" ]] && echo "  Experiment arm: ${EXPERIMENT_ARM}"
echo "  QSIRECON_SPEC: ${QSIRECON_SPEC}"
if [[ -n "${QSIRECON_ATLASES}" ]]; then
  echo "  QSIRECON_ATLASES: ${QSIRECON_ATLASES}"
fi
echo "  QSIPrep SDC: measured when dwi-select includes fmap; else requires --syn, --fmap-retry, or --no-sdc"
[[ "${QSIPREP_FMAP_RETRY}" == "1" ]] && echo "  QSIPREP_FMAP_RETRY=1 (--ignore fieldmaps --use-syn-sdc error)"
[[ "${QSIPREP_NO_SDC}"     == "1" ]] && echo "  QSIPREP_NO_SDC=1     (SDC skipped entirely — matches previous no-fieldmap GE runs)"
if [[ "${QSIPREP_NO_DWI_FILTER}" == "1" ]]; then
  echo "  dwi-select: off (--no-dwi-filter)"
elif [[ -n "${DWI_SELECT_JSON}" ]]; then
  echo "  DWI_SELECT_JSON: ${DWI_SELECT_JSON}"
else
  echo "  dwi-select: dwi_select_b${DWI_SHELL_B}.json (default)"
fi
[[ -n "${QSIPREP_BIDS_FILTER}" ]] && echo "  QSIPREP_BIDS_FILTER: ${QSIPREP_BIDS_FILTER}"
if [[ "${PIPELINE_MODE}" == "all" || "${PIPELINE_MODE}" == "recon" ]]; then
  echo "  Recon (Step 2): $([[ ${RUN_RECON} == 1 ]] && echo on || echo off)  tool=${RECON_TOOL}  fsaparc=${RECON_FSAPARC}  out=${RECON_OUT}"
fi
if [[ "${PIPELINE_MODE}" == "all" || "${PIPELINE_MODE}" == "inpaint" || "${PIPELINE_MODE}" == "recon" ]]; then
  echo "  Anatomy mitigation (Step 1.5): $([[ ${RUN_INPAINT} == 1 ]] && echo "${ANAT_MITIGATION} (runs only if a lesion mask is found)" || echo off)"
fi
echo "  FS_SUBJECTS_DIR: ${FS_SUBJECTS_DIR}"
echo "  Connectome (Step 4): $([[ ${RUN_CONNECTOME} == 1 && ( ${PIPELINE_MODE} == all || ${PIPELINE_MODE} == connectome ) ]] && echo on || echo off/skip)"
echo "  ACT mode: ${ACT_MODE}"
echo "  Tractography model(s): ${TRACTOGRAPHY_MODEL}"
echo "  Connectome SIFT2 matrix: $([[ ${CONNECTOME_SIFT2} == 1 ]] && echo on || echo off)"
[[ -n "${PRIMARY_CONNECTOME_MEASURE}" ]] && echo "  Primary connectome measure: ${PRIMARY_CONNECTOME_MEASURE}"
if [[ "${PIPELINE_MODE}" == "all" || "${PIPELINE_MODE}" == "connectome" || "${PIPELINE_MODE}" == "nodestrength" ]]; then
  echo "  Node strength (Step 5): $([[ ${RUN_NODESTRENGTH} == 1 ]] && echo on || echo off)"
fi
[[ -n "${EXCLUDE_NODES}" ]] && echo "  Exclude nodes: ${EXCLUDE_NODES}"

# Auto-request a GPU slice when inpainting may run (Step 1.5 needs >=12g MIG).
if [[ -z "${SBATCH_GRES:-}" ]]; then
  case "${PIPELINE_MODE}" in
    all|inpaint|recon)
      if [[ "${RUN_INPAINT:-1}" == "1" && "${ANAT_MITIGATION}" == "neurolit" ]]; then
        SBATCH_GRES="gpu:l40s.24g:1"
        echo "  SBATCH_GRES: ${SBATCH_GRES} (auto: Step 1.5 inpaint may need GPU)"
      elif [[ "${RECON_TOOL}" == "fastsurfer" && "${RECON_FASTSURFER_DEVICE}" == "cuda" ]]; then
        SBATCH_GRES="gpu:l40s.24g:1"
        echo "  SBATCH_GRES: ${SBATCH_GRES} (auto: FastSurfer cuda)"
      fi
      ;;
  esac
fi

if [[ "${PIPELINE_ENGINE}" != "bash" ]]; then
  preflight_args=(bash "${DWI_ROOT}/workflow/preflight.sh" --mode "${PIPELINE_MODE}" --quick)
  ((BIDS_VALIDATE)) && preflight_args+=(--bids-validation)
  ((BIDS_IGNORE_WARNINGS)) && preflight_args+=(--ignore-warnings)
  "${preflight_args[@]}" || exit 1
fi

# Passed through to array.sh -> run_subject.sh / subject.sh (sbatch --export=ALL)
# DWI_ROOT/REPO_ROOT are critical: inside sbatch $0 points to Slurm's spool
# copy of the script, so array.sh cannot derive them on the compute node.
export DWI_ROOT REPO_ROOT PIPELINE_ENGINE
export BIDS_DIR RESULTS_ROOT SUBJECT_LIST_FILE PIPELINE_MODE NTHREADS OMP_NTHREADS QSIRECON_SPEC QSIRECON_ATLASES
export QSIPREP_USE_SYN_SDC QSIPREP_FMAP_RETRY QSIPREP_NO_SDC QSIPREP_BIDS_FILTER DWI_SELECT_JSON
export DWI_SHELL_B QSIPREP_NO_DWI_FILTER
export RUN_RECON RECON_TOOL RECON_FSAPARC RECON_OUT RUN_CONNECTOME RUN_INPAINT RUN_NODESTRENGTH FS_SUBJECTS_DIR
export RECON_FASTSURFER_DEVICE RECON_SESSION
export INPAINT_DEVICE INPAINT_BATCH_SIZE INPAINT_DILATE INPAINT_LABELS INPAINT_BINARIZE INPAINT_REQUIRE_MASK INPAINT_FAIL_ON_QC
export ANAT_MITIGATION VBT_SMOOTHING_FACTOR
export CONNECTOME_PARCELLATION CONNECTOME_FAIL_ON_EMPTY_NODES CONNECTOME_DETERMINISTIC CONNECTOME_RESAMPLE_TO_DWI
export PRIMARY_CONNECTOME_MEASURE
export ACT_MODE ACT_STREAMLINES ACT_RANDOM_SEED
export TRACTOGRAPHY_MODEL
export CONNECTOME_SIFT2
export EXPERIMENT_ARM EXPERIMENT_ISOLATE_OUTPUTS
export NODESTRENGTH_STRENGTH_ONLY NODESTRENGTH_NO_REPORT NODESTRENGTH_OUT
# Optional container/license overrides (else workflow/config/config.local.yaml)
export CONTAINER_QSIPREP CONTAINER_QSIRECON CONTAINER_FASTSURFER CONTAINER_FREESURFER
export CONTAINER_CONNECTOME CONTAINER_VBT CONTAINER_LESION_ACT CONTAINER_LIT CONTAINER_NODESTRENGTH FS_LICENSE TEMPLATEFLOW_HOME
export BIDS_VALIDATE BIDS_IGNORE_WARNINGS

SBATCH_EXTRA=()
[[ -n "${EXCLUDE_NODES}" ]] && SBATCH_EXTRA+=(--exclude="${EXCLUDE_NODES}")
[[ -n "${SBATCH_GRES:-}" ]] && SBATCH_EXTRA+=(--gres="${SBATCH_GRES}")
# Optional job-chaining hook used when stages are submitted as separate arrays
# (recon -> qsirecon -> connectome), so downstream stages only fire after upstream OK.
[[ -n "${SBATCH_DEPENDENCY:-}" ]] && SBATCH_EXTRA+=(--dependency="${SBATCH_DEPENDENCY}")
# Optional one-shot overrides of the #SBATCH directives baked into array.sh.
# Useful for picking a different partition (must allow the requested time),
# bumping per-task CPUs/mem for a fresh recon-all subject, or routing output
# files to a per-experiment log name.
[[ -n "${SBATCH_PARTITION:-}" ]] && SBATCH_EXTRA+=(--partition="${SBATCH_PARTITION}")
[[ -n "${SBATCH_TIME:-}"      ]] && SBATCH_EXTRA+=(--time="${SBATCH_TIME}")
[[ -n "${SBATCH_CPUS:-}"      ]] && SBATCH_EXTRA+=(--cpus-per-task="${SBATCH_CPUS}")
[[ -n "${SBATCH_MEM:-}"       ]] && SBATCH_EXTRA+=(--mem="${SBATCH_MEM}")
if [[ -n "${SBATCH_JOB_NAME:-}" ]]; then
  SBATCH_EXTRA+=(--job-name="${SBATCH_JOB_NAME}"
                 --output="${REPO_ROOT}/logs/${SBATCH_JOB_NAME}_%A_%a.out"
                 --error="${REPO_ROOT}/logs/${SBATCH_JOB_NAME}_%A_%a.err")
fi
exec sbatch --array="1-${N}%${ARRAY_CONCURRENCY}" --export=ALL "${SBATCH_EXTRA[@]}" "${ARRAY_SCRIPT}"
