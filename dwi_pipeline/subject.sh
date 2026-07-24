#!/bin/bash
# =============================================================================
# subject.sh — Process ONE participant: QSIPrep, Recon, QSIRecon, DK connectome
# =============================================================================
#
# Called by array.sh (one Slurm array task = one subject).
#
# Step 1 — QSIPrep (container):
#   Denoise/correct DWI, optional fieldmap-based SDC, register to T1w, produce
#   preprocessed DWI + brain masks/segmentations + transforms. Uses FreeSurfer
#   license inside the container for anatomical steps (not a separate recon-all
#   job on the host).
#
# Step 2 — Recon (container, default ON; tools: recon-all OR FastSurfer):
#   Runs anatomical surface reconstruction on the subject's T1w from BIDS to
#   produce a FreeSurfer-style subjects directory (aparc+aseg.mgz, surfaces,
#   labels, etc.) at RECON_OUT/sub-XXX/.
#     RECON_TOOL=freesurfer (default): runs recon-all -all (~6-10 h CPU)
#       inside CONTAINER_FREESURFER. Requires the dedicated full FreeSurfer
#       7.4.1 SIF at ../others/containers/freesurfer_7.4.1.sif (pulled via
#       containers/pull_freesurfer_sif.sbatch). Pipeline fails if missing.
#     RECON_TOOL=fastsurfer (CLI flag --fastsurfer): runs FastSurfer inside
#       CONTAINER_FASTSURFER (~1-2 h CPU, ~20 min GPU). Produces aparc+aseg.mgz
#       via recon-surf.
#   Skips Step 2 only when RECON_SKIP_IF_EXISTS=1 and aparc+aseg.mgz exists;
#   otherwise fails if aparc already present (strict rerun policy).
#
# Step 3 — QSIRecon (container):
#   Reads QSIPrep derivatives. Default recon spec mrtrix_singleshell_ss3t_ACT-hsvs:
#   MRtrix SS3T CSD + ACT tractography with HSVS 5TT (uses FreeSurfer subject dir
#   produced by Step 2). With --no-recon, you must set QSIRECON_SPEC to ACT-fast
#   or provide an existing FS subjects dir — no automatic spec switch.
#
# Step 4 — DK connectome (container, default ON when Step 2 ran):
#   Post-step after QSIRecon. Uses FreeSurfer aparc+aseg.mgz + QSIRecon .tck.
#   Space alignment: aparc+aseg lives in FreeSurfer conformed (orig.mgz) space
#   (256³); tractogram lives in QSIPrep T1w (dwiref) space. Step 4a warps labels
#   to native T1w (rawavg.mgz). Step 4b affine-registers BIDS T1w -> desc-preproc_T1w
#   (QSIPrep's packaged from-T1wNative_to-T1wACPC .mat targets a reoriented
#   T1wNative frame, not FS scanner-native rawavg), applies that warp to labels,
#   then resamples onto dwiref (-n GenericLabel).
#   Runs in CONTAINER_DK_CONNECTOME (dk_connectome.sif: FreeSurfer + ANTs + MRtrix3).
#   Build: bash dwi_pipeline/containers/dk_connectome/build_dk_connectome.sh
#   Legacy dual-container path: DK_LEGACY_DUAL_CONTAINER=1 (freesurfer + qsirecon).
#   By default the parcellation follows the Step 2 tool: recon-all gives a
#   Desikan-Killiany matrix (84 nodes, fs_default.txt), FastSurfer a
#   Desikan-Killiany-Tourville one (78 nodes, fs_dkt.txt), since FastSurfer's
#   aparc+aseg.mgz is the DKT atlas.
#   DK_PARCELLATION=dkt gives a true DKT matrix from either tool, reading
#   aparc.DKTatlas+aseg.mgz on a recon-all tree — use it to keep one node set
#   across a cohort processed with a mix of the two. DK is only available from
#   recon-all; FastSurfer produces no DK atlas.
#   Writes dk_parcellation.json plus the matrix, named for the parcellation:
#   dk_connectome.csv (DK) or dkt_connectome.csv (DKT), under dk_connectomes/sub-XXX/.
#
# Usage:
#   bash subject.sh all 014                  # full pipeline (recon-all default)
#   bash subject.sh all 014 --fastsurfer     # use FastSurfer in Step 2
#   bash subject.sh all 014 --no-recon       # skip Step 2 (set ACT-fast or FS dir)
#   bash subject.sh all 014 --no-dk          # skip Step 4
#   bash subject.sh qsiprep 014              # preprocessing only
#   bash subject.sh recon 014                # Step 2 only (recon-all by default)
#   bash subject.sh recon 014 --fastsurfer   # Step 2 only via FastSurfer
#   bash subject.sh qsirecon 014             # Step 3 only (QSIPrep must exist)
#   bash subject.sh dk 014                   # Step 4 only (needs FS dir + .tck)
#   bash subject.sh all 014 --syn            # no BIDS fmap -> --use-syn-sdc warn
#   bash subject.sh all 014 --fmap-retry     # ignore measured fmaps, SyN SDC
#   bash subject.sh all 014 --dwi-shell 1000 # default: acq-b1000 DWI + IntendedFor fmaps
#   bash subject.sh all 014 --no-dwi-filter  # process all DWI/fmaps (legacy behavior)
#   bash subject.sh all 014 --dwi-select /path/dwi_select_b3000.json
#
# DWI series selection (QSIPrep, default ON):
#   Keeps one b-shell DWI (default b=1000, acq-b1000) and fmaps whose IntendedFor
#   points at that DWI. Excludes acq-rs fmaps. Override with --dwi-shell / --dwi-select
#   or disable with --no-dwi-filter / QSIPREP_NO_DWI_FILTER=1.
#
# SDC (QSIPrep) — strict: measured fmaps when dwi-select includes fmap; else require --syn or --fmap-retry.
#
# Outputs under RESULTS_ROOT (default: .../CIDUR_BIDS/dwi_test):
#   qsiprep_single_run_output/   freesurfer/   qsirecon_single_run_output/   dk_connectomes/
#
# Environment (optional overrides):
#   RESULTS_ROOT, BIDS_DIR, NTHREADS, OMP_NTHREADS, OUTPUT_RES
#   CONTAINER_QSIPREP, CONTAINER_QSIRECON, CONTAINER_DK_CONNECTOME, CONTAINER_FASTSURFER, CONTAINER_FREESURFER
#   FS_LICENSE, TEMPLATEFLOW_HOME
#   RUN_RECON=0|1          Step 2 in mode=all (default 1)
#   RECON_TOOL             freesurfer (default) or fastsurfer
#   RECON_OUT              FreeSurfer subjects dir (default: RESULTS_ROOT/freesurfer)
#   FS_SUBJECTS_DIR        same as RECON_OUT unless overridden (used by Steps 3 + 4)
#   RECON_FASTSURFER_DEVICE  cpu (default) or cuda for FastSurfer GPU runs
#   QSIRECON_SPEC          default: mrtrix_singleshell_ss3t_ACT-hsvs (with --no-recon,
#                          set ACT-fast explicitly or provide FS subjects dir)
#   QSIRECON_ATLASES       optional QSIRecon --atlases (Schaefer100, AAL116, ...)
#   RUN_DK_CONNECTOME=0|1  DK in mode=all (default 1 when Step 2 ran)
#   DK_PARCELLATION       auto|dk|dkt (default auto: dk for recon-all, dkt for
#                         FastSurfer; dkt works on either tree, dk needs recon-all)
#   DK_LUT_DKT            labelconvert LUT for the DKT parcellation (78 nodes)
#   DK_FAIL_ON_EMPTY_NODES=1  fail instead of warn when a node has no streamlines
#   DK_DETERMINISTIC=0|1  pin ITK to 1 thread for a reproducible matrix (default 1)
#   DK_RESAMPLE_TO_DWI=0|1 Resample aparc+aseg onto DWI grid (default 1)
#   QSIPREP_USE_SYN_SDC=1  opt-in SyN when no measured fmaps (same as --syn)
#   QSIPREP_FMAP_RETRY=1   --ignore fieldmaps --use-syn-sdc warn (same as --fmap-retry)
#   DWI_SHELL_B=1000         b-value for default dwi-select (config/dwi_select_b<SHELL>.json)
#   DWI_SELECT_JSON=         explicit dwi-select config (overrides DWI_SHELL_B path)
#   RECON_SKIP_IF_EXISTS=1  skip recon when aparc+aseg.mgz already exists (default: fail)
#   RECON_SESSION=2WK         override session for recon T1w (default: from dwi-select filter)
# =============================================================================

set -euo pipefail
set +H

_pipeline_fail() {
  local label="$1" msg="$2"
  shift 2
  echo "ERROR [${label}]: ${msg}" >&2
  while (($#)); do echo "  $1" >&2; shift; done
  exit 1
}

_strict_find_one() {
  local label="$1"
  shift
  local -a matches=()
  mapfile -t matches < <("$@" 2>/dev/null | LC_ALL=C sort -u)
  ((${#matches[@]})) || _pipeline_fail "${label}" "no file found for sub-${SUBJECT}"
  ((${#matches[@]} == 1)) || _pipeline_fail "${label}" "expected exactly 1 match, found ${#matches[@]}" "${matches[@]}"
  echo "${matches[0]}"
}

# --- CLI: mode, subject ID, optional flags ---
PIPELINE_MODE="${1:?Need mode: all, qsiprep, recon, qsirecon, or dk}"
SUBJECT="${2:?Need subject id}"
SUBJECT="${SUBJECT#sub-}"
shift 2 || true
while [[ $# -gt 0 ]]; do
  case "$1" in
    --syn|--use-syn-sdc)
      QSIPREP_USE_SYN_SDC=1
      ;;
    --fmap-retry)
      QSIPREP_FMAP_RETRY=1
      ;;
    --fastsurfer)
      RECON_TOOL=fastsurfer
      ;;
    --freesurfer)
      RECON_TOOL=freesurfer
      ;;
    --no-recon)
      RUN_RECON=0
      ;;
    --no-dk)
      RUN_DK_CONNECTOME=0
      ;;
    --bids-filter)
      QSIPREP_BIDS_FILTER="${2:?Need path after --bids-filter}"
      shift 2
      continue
      ;;
    --dwi-select)
      DWI_SELECT_JSON="${2:?Need path after --dwi-select}"
      shift 2
      continue
      ;;
    --dwi-shell)
      DWI_SHELL_B="${2:?Need b-value after --dwi-shell}"
      DWI_SELECT_JSON=""
      shift 2
      continue
      ;;
    --no-dwi-filter)
      QSIPREP_NO_DWI_FILTER=1
      ;;
    -h|--help)
      sed -n '50,95p' "$0"
      exit 0
      ;;
    *)
      echo "Unknown option: $1 (try --syn, --fmap-retry, --dwi-shell, --no-dwi-filter, --fastsurfer, --no-recon, --no-dk)"
      exit 1
      ;;
  esac
  shift
done

# --- Paths: repo root, BIDS input, separate output tree for ACT/connectome ---
TRACKTBI_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
RESULTS_ROOT="${RESULTS_ROOT:-/mnt/nfs/home/urmc-sh.rochester.edu/pndagiji/Documents/CIDUR_BIDS/dwi_test}"
BIDS_DIR="${BIDS_DIR:-/mnt/nfs/home/urmc-sh.rochester.edu/pndagiji/Documents/CIDUR_BIDS/data_bids}"
NTHREADS="${NTHREADS:-8}"
OMP_NTHREADS="${OMP_NTHREADS:-8}"
OUTPUT_RES="${OUTPUT_RES:-2}"

# --- Apptainer images and FreeSurfer license (required for anat + ACT) ---
CONTAINER_QSIPREP="${CONTAINER_QSIPREP:-/mnt/nfs/home/urmc-sh.rochester.edu/pndagiji/Documents/others/containers/qsiprep.sif}"
CONTAINER_QSIRECON="${CONTAINER_QSIRECON:-/mnt/nfs/home/urmc-sh.rochester.edu/pndagiji/Documents/others/containers/qsirecon.sif}"
CONTAINER_FASTSURFER="${CONTAINER_FASTSURFER:-/mnt/nfs/home/urmc-sh.rochester.edu/pndagiji/Documents/others/containers/fastsurfer_latest.sif}"
# Dedicated full FreeSurfer 7.4.1 image (pulled via
# dwi_pipeline/containers/pull_freesurfer_sif.sbatch). Pipeline fails if missing.
_FS_SIF_DEFAULT="/mnt/nfs/home/urmc-sh.rochester.edu/pndagiji/Documents/others/containers/freesurfer_7.4.1.sif"
if [[ -z "${CONTAINER_FREESURFER:-}" ]]; then
  if [[ -f "${_FS_SIF_DEFAULT}" ]]; then
    CONTAINER_FREESURFER="${_FS_SIF_DEFAULT}"
  else
    _pipeline_fail "FreeSurfer" "dedicated FreeSurfer SIF not found at ${_FS_SIF_DEFAULT}" \
      "Build it: sbatch dwi_pipeline/containers/pull_freesurfer_sif.sbatch" \
      "Or set CONTAINER_FREESURFER to a full FreeSurfer 7.4.1 image path."
  fi
fi
_DK_CONNECTOME_SIF_DEFAULT="/mnt/nfs/home/urmc-sh.rochester.edu/pndagiji/Documents/others/containers/dk_connectome.sif"
CONTAINER_DK_CONNECTOME="${CONTAINER_DK_CONNECTOME:-${_DK_CONNECTOME_SIF_DEFAULT}}"
TEMPLATEFLOW_HOME="${TEMPLATEFLOW_HOME:-${TRACKTBI_ROOT}/templateflow}"
FS_LICENSE="${FS_LICENSE:-/mnt/nfs/home/urmc-sh.rochester.edu/pndagiji/Documents/others/data_mining/freesurfer/license.txt}"
# FreeSurferColorLUT.txt — qsirecon.sif's trimmed FreeSurfer doesn't ship this
# file, but labelconvert needs it in the DK step. Default to the LUT shipped
# with the host-side FS install (next to the license).
FS_LUT="${FS_LUT:-${FS_LICENSE%/*}/FreeSurferColorLUT.txt}"

# --- Recon (Step 2) defaults ---
RUN_RECON="${RUN_RECON:-1}"
RECON_TOOL="${RECON_TOOL:-freesurfer}"           # freesurfer | fastsurfer
RECON_FASTSURFER_DEVICE="${RECON_FASTSURFER_DEVICE:-cpu}"

# --- QSIRecon (Step 3) + DK (Step 4) defaults ---
QSIRECON_SPEC="${QSIRECON_SPEC:-mrtrix_singleshell_ss3t_ACT-hsvs}"
# QSIRecon's MRtrix specs include connectivity-estimation nodes that REQUIRE
# at least one atlas. Without one, qsirecon aborts during workflow build:
#   "Connectivity estimation requires atlases. Please set --atlases ..."
#
# QSIRecon recognises these built-in atlas names (shipped inside qsirecon.sif
# at /atlas/qsirecon_atlases/ and /atlas/AtlasPack/):
#   AAL116, AICHA384Ext, Brainnetome246Ext, Gordon333Ext,
#   4S156Parcels, 4S256Parcels, ... 4S1056Parcels
# (The "4S" series = Schaefer cortex + Tian subcortex + HCP brainstem, fused.
# 4S156Parcels == Schaefer-100 cortex (100) + 56 subcortex/brainstem = 156.)
#
# Default = 4S156Parcels: modern Schaefer-based, smallest of the 4S series,
# fast (small matrix), and complements our anatomical DK connectome (Step 4).
# Override with a space-separated list, e.g. QSIRECON_ATLASES="4S156Parcels AAL116"
# or "" to opt out (only safe with specs that have no connectivity node — rare).
QSIRECON_ATLASES="${QSIRECON_ATLASES-4S156Parcels}"
RUN_DK_CONNECTOME="${RUN_DK_CONNECTOME:-1}"
# Grey-matter parcellation for the Step 4 connectome: auto | dk | dkt
#   dk  — Desikan-Killiany, 84 nodes, fs_default.txt over aparc+aseg.mgz.
#         recon-all only; FastSurfer produces no DK atlas.
#   dkt — Desikan-Killiany-Tourville, 78 nodes, fs_dkt.txt. Available from either
#         tool: FastSurfer's aparc+aseg.mgz is already DKT, and a recon-all tree
#         is read via its aparc.DKTatlas+aseg.mgz.
#   auto— follow the tree: dkt for FastSurfer, dk for recon-all.
# FastSurfer ships aparc+aseg.mgz as the DKT atlas, which by protocol has no
# bankssts and no frontal/temporal pole. Running labelconvert over it with the DK
# LUT yields 6 all-zero rows/columns, so the LUT has to follow the segmentation.
# Set dkt explicitly to keep one node set across a cohort processed with a mix of
# the two tools.
DK_PARCELLATION="${DK_PARCELLATION:-auto}"
DK_LUT_DKT="${DK_LUT_DKT:-${TRACKTBI_ROOT}/dwi_pipeline/containers/dk_connectome/mrtrix_lut/fs_dkt.txt}"
# Empty nodes normally mean the LUT does not match the segmentation, but they can
# also be genuine in severe pathology (resection, large lesion), so warn by
# default and let callers escalate.
DK_FAIL_ON_EMPTY_NODES="${DK_FAIL_ON_EMPTY_NODES:-0}"
# ITK sums its registration metric across threads in a nondeterministic order, so
# repeat runs of Step 4b differ by ~1e-10 in the affine. That is usually invisible
# after nearest-neighbour label resampling, but it can flip boundary voxels and
# shift a handful of streamline assignments. Pin ITK to one thread so the
# connectome is reproducible; set 0 to trade reproducibility for speed.
DK_DETERMINISTIC="${DK_DETERMINISTIC:-1}"
RECON_SKIP_IF_EXISTS="${RECON_SKIP_IF_EXISTS:-0}"
QSIPREP_BIDS_FILTER="${QSIPREP_BIDS_FILTER:-}"
DWI_SELECT_JSON="${DWI_SELECT_JSON:-}"
DWI_SHELL_B="${DWI_SHELL_B:-1000}"
QSIPREP_NO_DWI_FILTER="${QSIPREP_NO_DWI_FILTER:-0}"
BUILD_BIDS_FILTER="${TRACKTBI_ROOT}/dwi_pipeline/scripts/build_bids_filter.py"
MAKE_DWI_SELECT_CONFIG="${TRACKTBI_ROOT}/dwi_pipeline/scripts/make_dwi_select_config.py"

resolve_dwi_select_config() {
  if [[ "${QSIPREP_NO_DWI_FILTER}" == "1" ]]; then
    DWI_SELECT_JSON=""
    return 0
  fi
  [[ -n "${QSIPREP_BIDS_FILTER}" ]] && return 0
  if [[ -z "${DWI_SELECT_JSON}" ]]; then
    DWI_SELECT_JSON="${TRACKTBI_ROOT}/dwi_pipeline/config/dwi_select_b${DWI_SHELL_B}.json"
  fi
  if [[ ! -f "${DWI_SELECT_JSON}" ]]; then
    _pipeline_fail "dwi-select" "missing config ${DWI_SELECT_JSON}" \
      "Create it: python3 ${MAKE_DWI_SELECT_CONFIG} --target-shell-b ${DWI_SHELL_B}"
  fi
}

resolve_dwi_select_config

if [[ -n "${QSIPREP_BIDS_FILTER}" && -n "${DWI_SELECT_JSON}" ]]; then
  echo "ERROR: use only one of --bids-filter or --dwi-select/--dwi-shell"
  exit 1
fi
if [[ "${QSIPREP_NO_DWI_FILTER}" == "1" ]]; then
  echo "dwi-select: disabled (QSIPREP_NO_DWI_FILTER=1 / --no-dwi-filter)"
elif [[ -n "${DWI_SELECT_JSON}" ]]; then
  echo "dwi-select: ${DWI_SELECT_JSON} (target shell b=${DWI_SHELL_B})"
fi
DK_RESAMPLE_TO_DWI="${DK_RESAMPLE_TO_DWI:-1}"

# --- Output layout under RESULTS_ROOT ---
QSIPREP_OUT="${RESULTS_ROOT}/qsiprep_single_run_output"
QSIRECON_OUT="${RESULTS_ROOT}/qsirecon_single_run_output"
RECON_OUT="${RECON_OUT:-${RESULTS_ROOT}/freesurfer}"
FS_SUBJECTS_DIR="${FS_SUBJECTS_DIR:-${RECON_OUT}}"
DK_OUT="${RESULTS_ROOT}/dk_connectomes"
INTER_QSP="${RESULTS_ROOT}/intermediate_results_qsiprep_single"
INTER_QSI="${RESULTS_ROOT}/intermediate_results_qsirecon_single"
# Per-subject nipype work dirs (removed after each stage to avoid stale cache)
WORK_QSIPREP="${INTER_QSP}/_work_qsiprep_${SUBJECT}"
WORK_QSIRECON="${INTER_QSI}/_work_qsirecon_${SUBJECT}"
BIDS_FILTER_CACHE="${INTER_QSP}/bids_filter_sub-${SUBJECT}.json"

# --- Preflight: BIDS subject, containers, license ---
[[ -d "${BIDS_DIR}" ]] || { echo "BIDS not found: ${BIDS_DIR}"; exit 1; }
[[ -d "${BIDS_DIR}/sub-${SUBJECT}" ]] || { echo "Missing ${BIDS_DIR}/sub-${SUBJECT}"; exit 1; }
[[ -f "${CONTAINER_QSIPREP}" ]] || { echo "Missing ${CONTAINER_QSIPREP}"; exit 1; }
[[ -f "${CONTAINER_QSIRECON}" ]] || { echo "Missing ${CONTAINER_QSIRECON}"; exit 1; }
[[ -f "${FS_LICENSE}" ]] || { echo "Missing FreeSurfer license: ${FS_LICENSE}"; exit 1; }
# Recon containers only required when we will actually run Step 2 / DK
if [[ "${PIPELINE_MODE}" == "all" && "${RUN_RECON}" == "1" ]] || [[ "${PIPELINE_MODE}" == "recon" ]]; then
  case "${RECON_TOOL}" in
    freesurfer) [[ -f "${CONTAINER_FREESURFER}" ]] || { echo "Missing CONTAINER_FREESURFER: ${CONTAINER_FREESURFER}"; exit 1; } ;;
    fastsurfer) [[ -f "${CONTAINER_FASTSURFER}" ]] || { echo "Missing CONTAINER_FASTSURFER: ${CONTAINER_FASTSURFER}"; exit 1; } ;;
    *) echo "Invalid RECON_TOOL=${RECON_TOOL} (use freesurfer or fastsurfer)"; exit 1 ;;
  esac
fi
if [[ "${PIPELINE_MODE}" == "dk" ]] || { [[ "${PIPELINE_MODE}" == "all" ]] && [[ "${RUN_DK_CONNECTOME}" == "1" ]]; }; then
  if [[ "${DK_LEGACY_DUAL_CONTAINER:-0}" != "1" ]]; then
    [[ -f "${CONTAINER_DK_CONNECTOME}" ]] || {
      echo "Missing CONTAINER_DK_CONNECTOME: ${CONTAINER_DK_CONNECTOME}"
      echo "  Build: bash dwi_pipeline/containers/dk_connectome/build_dk_connectome.sh"
      exit 1
    }
  fi
fi

mkdir -p "${TEMPLATEFLOW_HOME}" "${QSIPREP_OUT}" "${QSIRECON_OUT}" "${RECON_OUT}" "${INTER_QSP}" "${INTER_QSI}" "${RESULTS_ROOT}/logs"
echo "RESULTS_ROOT=${RESULTS_ROOT} (ACT connectome pipeline)"

_bids_filter_includes_fmap() {
  local filter_file="$1"
  [[ -f "${filter_file}" ]] || return 1
  python3 -c "import json,sys; sys.exit(0 if 'fmap' in json.load(open(sys.argv[1])) else 1)" "${filter_file}"
}

_ensure_bids_filter_built() {
  [[ -f "${BIDS_FILTER_CACHE}" ]] && return 0
  [[ -n "${DWI_SELECT_JSON}" || -n "${QSIPREP_BIDS_FILTER}" ]] || \
    _pipeline_fail "dwi-select" "no bids filter available" \
      "Enable dwi-select (default) or pass --bids-filter / set QSIPREP_BIDS_FILTER"
  prepare_qsiprep_bids_filter
  [[ -f "${BIDS_FILTER_CACHE}" ]] || _pipeline_fail "dwi-select" "filter was not written to ${BIDS_FILTER_CACHE}"
}

_resolve_target_session() {
  if [[ -n "${RECON_SESSION:-}" ]]; then
    echo "${RECON_SESSION}"
    return 0
  fi
  _ensure_bids_filter_built
  local ses=""
  ses="$(python3 - "${BIDS_FILTER_CACHE}" <<'PY'
import json, sys
path = sys.argv[1]
d = json.load(open(path))
dwi = d.get("dwi") or {}
ses = dwi.get("session")
if ses is None:
    print("ERROR: dwi filter has no session entity", file=sys.stderr)
    sys.exit(1)
if isinstance(ses, list):
    if len(ses) != 1:
        print(f"ERROR: ambiguous sessions in dwi filter: {ses}", file=sys.stderr)
        sys.exit(1)
    print(ses[0])
else:
    print(ses)
PY
)" || _pipeline_fail "session" "could not read target session from ${BIDS_FILTER_CACHE}" \
    "Set RECON_SESSION or ensure dwi-select matches one session-level DWI."
  echo "${ses}"
}

prepare_qsiprep_bids_filter() {
  QSIPREP_FILTER_HOST=""
  QSIPREP_FILTER_CONTAINER=""
  [[ -z "${QSIPREP_BIDS_FILTER}" && -z "${DWI_SELECT_JSON}" ]] && return 0
  [[ -f "${BUILD_BIDS_FILTER}" ]] || _pipeline_fail "dwi-select" "missing ${BUILD_BIDS_FILTER}"
  if [[ -n "${DWI_SELECT_JSON}" ]]; then
    [[ -f "${DWI_SELECT_JSON}" ]] || _pipeline_fail "dwi-select" "missing DWI_SELECT_JSON=${DWI_SELECT_JSON}"
    python3 "${BUILD_BIDS_FILTER}" --bids-dir "${BIDS_DIR}" --subject "${SUBJECT}" \
      --select-json "${DWI_SELECT_JSON}" --output "${BIDS_FILTER_CACHE}"
    QSIPREP_FILTER_HOST="${BIDS_FILTER_CACHE}"
    QSIPREP_FILTER_CONTAINER="/work/bids_filter.json"
    echo "QSIPrep: dwi-select ${DWI_SELECT_JSON} -> ${BIDS_FILTER_CACHE}"
  else
    [[ -f "${QSIPREP_BIDS_FILTER}" ]] || _pipeline_fail "bids-filter" "missing QSIPREP_BIDS_FILTER=${QSIPREP_BIDS_FILTER}"
    QSIPREP_FILTER_HOST="${QSIPREP_BIDS_FILTER}"
    QSIPREP_FILTER_CONTAINER="/bids_filter.json"
    echo "QSIPrep: static bids filter ${QSIPREP_BIDS_FILTER}"
  fi
}

_configure_qsiprep_sdc() {
  local filter_file="$1"
  local -n _out=$2

  if [[ "${QSIPREP_FMAP_RETRY:-0}" == "1" ]]; then
    _out+=(--ignore fieldmaps --use-syn-sdc warn)
    echo "QSIPrep: sub-${SUBJECT}: explicit --fmap-retry -> SyN SDC"
    return 0
  fi
  if [[ -n "${filter_file}" ]] && _bids_filter_includes_fmap "${filter_file}"; then
    echo "QSIPrep: sub-${SUBJECT}: dwi-select includes fmap -> measured SDC"
    return 0
  fi
  if [[ "${QSIPREP_USE_SYN_SDC:-0}" == "1" ]]; then
    _out+=(--use-syn-sdc warn)
    echo "QSIPrep: sub-${SUBJECT}: explicit --syn -> SyN SDC"
    return 0
  fi
  _pipeline_fail "QSIPrep/SDC" "no distortion correction configured for sub-${SUBJECT}" \
    "Measured SDC requires fmaps in the dwi-select filter (IntendedFor -> target DWI)." \
    "Or pass --syn (QSIPREP_USE_SYN_SDC=1) or --fmap-retry (QSIPREP_FMAP_RETRY=1)."
}

# -----------------------------------------------------------------------------
# run_qsiprep — QSIPrep in Apptainer: BIDS -> qsiprep_single_run_output/sub-XXX
# -----------------------------------------------------------------------------
run_qsiprep() {
  local -a xtra=()

  echo "=== QSIPrep (ACT pipeline): sub-${SUBJECT} ==="
  rm -rf "${WORK_QSIPREP}"
  mkdir -p "${WORK_QSIPREP}"

  prepare_qsiprep_bids_filter
  _configure_qsiprep_sdc "${QSIPREP_FILTER_HOST}" xtra

  local -a filter_binds=()
  if [[ -n "${QSIPREP_FILTER_CONTAINER}" ]]; then
    if [[ "${QSIPREP_FILTER_CONTAINER}" == "/work/bids_filter.json" ]]; then
      cp -f "${QSIPREP_FILTER_HOST}" "${WORK_QSIPREP}/bids_filter.json"
    fi
    [[ "${QSIPREP_FILTER_CONTAINER}" == "/bids_filter.json" ]] && \
      filter_binds+=( -B "${QSIPREP_FILTER_HOST}":/bids_filter.json:ro )
    xtra+=( --bids-filter-file "${QSIPREP_FILTER_CONTAINER}" )
  fi

  apptainer run --cleanenv --containall \
    -B "${BIDS_DIR}":/bids_input:ro \
    -B "${QSIPREP_OUT}":/output \
    -B "${WORK_QSIPREP}":/work \
    -B "${FS_LICENSE}":/opt/freesurfer/license.txt:ro \
    -B "${TEMPLATEFLOW_HOME}":/templateflow \
    "${filter_binds[@]}" \
    --env "TEMPLATEFLOW_HOME=/templateflow" \
    "${CONTAINER_QSIPREP}" \
    /bids_input /output participant \
    --participant-label "${SUBJECT}" \
    --fs-license-file /opt/freesurfer/license.txt \
    --work-dir /work \
    --output-resolution "${OUTPUT_RES}" \
    --nthreads "${NTHREADS}" \
    --omp-nthreads "${OMP_NTHREADS}" \
    --skip-bids-validation \
    "${xtra[@]}"

  rm -rf "${WORK_QSIPREP}" && echo "Cleanup: removed QSIPrep workdir sub-${SUBJECT}" || true
}

# -----------------------------------------------------------------------------
# run_recon — Anatomical surface reconstruction: BIDS T1w -> FreeSurfer subjects dir
#   RECON_TOOL=freesurfer -> recon-all -all (slow, ~6-10 h CPU)
#   RECON_TOOL=fastsurfer -> /fastsurfer/run_fastsurfer.sh (fast, ~1-2 h CPU)
# Output: RECON_OUT/sub-XXX/{mri,surf,label,...}; idempotent if aparc+aseg.mgz exists.
# -----------------------------------------------------------------------------
run_recon() {
  local sid="sub-${SUBJECT}"
  local sd_subj="${RECON_OUT}/${sid}"
  local aparc="${sd_subj}/mri/aparc+aseg.mgz"

  echo "=== Recon (${RECON_TOOL}): ${sid} -> ${RECON_OUT} ==="

  if [[ -f "${aparc}" ]]; then
    if [[ "${RECON_SKIP_IF_EXISTS}" == "1" ]]; then
      echo "Recon: ${aparc} exists — skipping (RECON_SKIP_IF_EXISTS=1)"
      return 0
    fi
    _pipeline_fail "recon" "aparc+aseg.mgz already exists at ${aparc}" \
      "Delete ${sd_subj} to force rerun, or set RECON_SKIP_IF_EXISTS=1 to skip Step 2."
  fi
  if [[ -d "${sd_subj}" ]]; then
    echo "Recon: partial subjects dir at ${sd_subj} but no aparc+aseg.mgz."
    echo "       Remove it before resubmitting (recon-all/FastSurfer won't overwrite cleanly)."
    exit 1
  fi

  local target_ses
  target_ses="$(_resolve_target_session)" || exit 1
  echo "Recon: target session ses-${target_ses} (from dwi-select filter or RECON_SESSION)"

  local t1w
  t1w="$(_strict_find_one "recon/T1w" \
    find "${BIDS_DIR}/sub-${SUBJECT}/ses-${target_ses}/anat" -type f \
      \( -name '*_T1w.nii.gz' -o -name '*_T1w.nii' \))"

  echo "Recon: T1w input: ${t1w}"
  mkdir -p "${RECON_OUT}"

  case "${RECON_TOOL}" in
    freesurfer)
      _run_recon_freesurfer "${t1w}"
      ;;
    fastsurfer)
      _run_recon_fastsurfer "${t1w}"
      ;;
    *)
      _pipeline_fail "recon" "invalid RECON_TOOL=${RECON_TOOL} (use freesurfer or fastsurfer)"
      ;;
  esac

  [[ -f "${aparc}" ]] || {
    echo "Recon: ${RECON_TOOL} finished but ${aparc} was not produced."
    echo "       Inspect ${sd_subj}/scripts/ for tool logs."
    exit 1
  }
  echo "Recon: ${RECON_TOOL} OK — ${aparc} ($(du -h "${aparc}" | cut -f1))"
}

# Internal helper: probe a SIF for its FREESURFER_HOME (handles both
# /opt/freesurfer used by NeuroDocker/FastSurfer recipes and /usr/local/freesurfer
# used by the MGH-published freesurfer/freesurfer image).
_detect_fs_home_in_container() {
  local sif="$1"
  apptainer exec --cleanenv "${sif}" bash -lc '
    for p in "$FREESURFER_HOME" /opt/freesurfer /usr/local/freesurfer; do
      [[ -n "$p" && -x "$p/bin/recon-all" ]] && { echo "$p"; exit 0; }
    done
    ra=$(command -v recon-all || true)
    [[ -n "$ra" ]] && { dirname "$(dirname "$ra")"; exit 0; }
    exit 1
  ' 2>/dev/null | tail -1
}

# Internal: FreeSurfer recon-all inside CONTAINER_FREESURFER (dedicated full FreeSurfer SIF required).
_run_recon_freesurfer() {
  # Layout-agnostic preflight: detect FREESURFER_HOME inside the chosen image
  # so we work with both /opt/freesurfer (NeuroDocker/FastSurfer) and
  # /usr/local/freesurfer (MGH-published freesurfer/freesurfer image).
  local fs_home
  fs_home="$(_detect_fs_home_in_container "${CONTAINER_FREESURFER}" || true)"
  if [[ -z "${fs_home}" ]]; then
    echo "Recon: recon-all not found in CONTAINER_FREESURFER=${CONTAINER_FREESURFER}"
    echo "       Set CONTAINER_FREESURFER to an image with FreeSurfer, or use --fastsurfer."
    exit 1
  fi
  # The atlas check is what catches the trimmed-FreeSurfer-in-FastSurfer image
  # (bash job 44563 failed exactly here ~30 min into recon-all).
  apptainer exec --cleanenv "${CONTAINER_FREESURFER}" \
      test -f "${fs_home}/average/RB_all_withskull_2020_01_02.gca" || {
    echo "Recon: CONTAINER_FREESURFER=${CONTAINER_FREESURFER} is missing"
    echo "       ${fs_home}/average/RB_all_withskull_2020_01_02.gca, which"
    echo "       recon-all needs for skull-strip / Talairach. This image ships a"
    echo "       trimmed FreeSurfer."
    echo "       Build the dedicated full FreeSurfer SIF and rerun:"
    echo "           sbatch dwi_pipeline/containers/pull_freesurfer_sif.sbatch"
    echo "       Or switch to FastSurfer for this run: --fastsurfer"
    exit 1
  }
  echo "Recon: FREESURFER_HOME inside container = ${fs_home}"

  local -a i_args=()
  for t in "$@"; do
    local rel="${t#${BIDS_DIR}/}"
    i_args+=( -i "/bids/${rel}" )
  done
  # We bind the license at a neutral path and let FreeSurfer pick it up via the
  # FS_LICENSE env var (modern FS honours this over $FREESURFER_HOME/license.txt).
  # That way we don't have to know the image's FREESURFER_HOME ahead of time.
  apptainer exec --cleanenv --containall \
    -B "${BIDS_DIR}":/bids:ro \
    -B "${RECON_OUT}":/sd \
    -B "${FS_LICENSE}":/.fs_license.txt:ro \
    "${CONTAINER_FREESURFER}" \
    bash -lc "
      set -euo pipefail
      export FS_LICENSE=/.fs_license.txt
      export SUBJECTS_DIR=/sd
      recon-all -all -s 'sub-${SUBJECT}' ${i_args[*]} -openmp ${NTHREADS}
    "
}

# Internal: FastSurfer (segmentation + surface) inside CONTAINER_FASTSURFER.
_run_recon_fastsurfer() {
  local t1="$1"
  local rel="${t1#${BIDS_DIR}/}"
  apptainer exec --cleanenv "${CONTAINER_FASTSURFER}" bash -lc 'test -x /fastsurfer/run_fastsurfer.sh' || {
    echo "Recon: /fastsurfer/run_fastsurfer.sh not found in CONTAINER_FASTSURFER=${CONTAINER_FASTSURFER}"
    exit 1
  }
  apptainer exec --cleanenv --containall \
    -B "${BIDS_DIR}":/bids:ro \
    -B "${RECON_OUT}":/sd \
    -B "${FS_LICENSE}":/fs_license/license.txt:ro \
    "${CONTAINER_FASTSURFER}" \
    /fastsurfer/run_fastsurfer.sh \
      --fs_license /fs_license/license.txt \
      --sid "sub-${SUBJECT}" \
      --sd /sd \
      --t1 "/bids/${rel}" \
      --parallel \
      --threads "${NTHREADS}" \
      --device "${RECON_FASTSURFER_DEVICE}"
}

# -----------------------------------------------------------------------------
# run_qsirecon — QSIRecon in Apptainer: QSIPrep derivatives -> connectome outputs
# -----------------------------------------------------------------------------
run_qsirecon() {
  local -a recon_xtra=()
  local -a recon_binds=()

  # Optional parcellation atlases for connectome nodes (e.g. Schaefer100, AAL116)
  if [[ -n "${QSIRECON_ATLASES}" ]]; then
    # shellcheck disable=SC2206
    atlas_arr=(${QSIRECON_ATLASES})
    recon_xtra+=(--atlases "${atlas_arr[@]}")
  fi

  # Only mount + pass --fs-subjects-dir when the directory actually exists.
  # HSVS specs require it; FAST specs do not. Mounting a missing dir makes
  # apptainer abort with "mount source ... doesn't exist" (the bug that broke 44504).
  if [[ -d "${FS_SUBJECTS_DIR}" ]]; then
    recon_binds+=( -B "${FS_SUBJECTS_DIR}":/freesurfer:ro )
    recon_xtra+=( --fs-subjects-dir /freesurfer )
    echo "QSIRecon: mounting FreeSurfer subjects dir ${FS_SUBJECTS_DIR}"
  else
    if [[ "${QSIRECON_SPEC}" == *hsvs* ]]; then
      echo "ERROR: QSIRECON_SPEC=${QSIRECON_SPEC} needs a FreeSurfer subjects dir,"
      echo "       but FS_SUBJECTS_DIR=${FS_SUBJECTS_DIR} does not exist."
      echo "       Pre-run recon (Step 2) or set FS_SUBJECTS_DIR to an existing subjects tree."
      echo "       For no-recon runs, set QSIRECON_SPEC=mrtrix_singleshell_ss3t_ACT-fast before submit."
      exit 1
    fi
    echo "QSIRecon: no FreeSurfer subjects dir at ${FS_SUBJECTS_DIR} (OK for FAST spec)"
  fi

  echo "=== QSIRecon (${QSIRECON_SPEC}): sub-${SUBJECT} ==="
  rm -rf "${WORK_QSIRECON}"
  mkdir -p "${WORK_QSIRECON}" "${QSIRECON_OUT}/derivatives"

  apptainer run --cleanenv --containall \
    -B "${QSIPREP_OUT}":/qsiprep_input:ro \
    -B "${QSIRECON_OUT}":/output \
    -B "${WORK_QSIRECON}":/work \
    "${recon_binds[@]}" \
    -B "${FS_LICENSE}":/opt/freesurfer/license.txt:ro \
    -B "${TEMPLATEFLOW_HOME}":/templateflow \
    --env "TEMPLATEFLOW_HOME=/templateflow" \
    "${CONTAINER_QSIRECON}" \
    /qsiprep_input /output participant \
    --input-type qsiprep \
    --recon-spec "${QSIRECON_SPEC}" \
    --participant-label "${SUBJECT}" \
    --fs-license-file /opt/freesurfer/license.txt \
    --work-dir /work \
    --nthreads "${NTHREADS}" \
    --omp-nthreads "${OMP_NTHREADS}" \
    --output-resolution "${OUTPUT_RES}" \
    "${recon_xtra[@]}"

  rm -rf "${WORK_QSIRECON}" && echo "Cleanup: removed QSIRecon workdir sub-${SUBJECT}" || true
}

# BIDS session label from a path (e.g. "2WK" from ".../ses-2WK/dwi/...").
_bids_ses_from_path() {
  if [[ "$1" =~ /ses-([^/]+)/ ]]; then
    echo "${BASH_REMATCH[1]}"
  fi
}

# QSIPrep desc-preproc T1w: exactly one file under session anat/ or subject anat/.
find_qsiprep_preproc_t1w() {
  local qsiprep_out="$1" subject="$2" session="$3"
  _strict_find_one "DK/QSIPrep desc-preproc T1w" \
    find "${qsiprep_out}/sub-${subject}" \( \
      -path "*/ses-${session}/anat/*sub-${subject}_desc-preproc_T1w.nii.gz" -o \
      -path "*/anat/*sub-${subject}_desc-preproc_T1w.nii.gz" \
    \) -type f
}

# BIDS T1w for the target session (exactly one match required).
find_bids_t1w() {
  local subject="$1" session="$2"
  [[ -n "${session}" ]] || _pipeline_fail "DK/BIDS T1w" "session is required"
  _strict_find_one "DK/BIDS T1w" \
    find "${BIDS_DIR}/sub-${subject}/ses-${session}/anat" -type f \
      \( -name '*_T1w.nii.gz' -o -name '*_T1w.nii' \)
}

# -----------------------------------------------------------------------------
# _run_dk_connectome_dual_container — Legacy Step 4 (freesurfer.sif + qsirecon.sif)
# -----------------------------------------------------------------------------
_run_dk_connectome_dual_container() {
  local fs_dir="$1" aparc="$2" rawavg="$3" outdir="$4"
  local tracks="$5" tracks_in_container="$6"
  local dwiref_in_container="$7" preproc_t1w_in_container="$8" bids_t1w_in_container="$9"
  local dk_warp="${10}" space_note="${11}"
  local nodes_input_in_container="/out/aparc+aseg_in_dwi.nii.gz"

  echo "Using tractogram: ${tracks}"
  echo "Using aparc+aseg: ${aparc}"
  echo "Space handling: ${space_note}"

  if [[ "${dk_warp}" == "1" ]]; then
    apptainer exec --cleanenv "${CONTAINER_FREESURFER}" bash -lc "command -v mri_label2vol" >/dev/null 2>&1 || {
      echo "Missing mri_label2vol in CONTAINER_FREESURFER (${CONTAINER_FREESURFER})"
      exit 1
    }
    echo "[dk] Warping aparc+aseg from FS conformed -> native (mri_label2vol / rawavg.mgz)"
    apptainer exec --cleanenv --containall \
      -B "${fs_dir}":/fs_subject:ro \
      -B "${outdir}":/out \
      -B "${FS_LICENSE}":/.fs_license.txt:ro \
      "${CONTAINER_FREESURFER}" \
      bash -lc "
        set -euo pipefail
        export FS_LICENSE=/.fs_license.txt
        mri_label2vol --seg /fs_subject/mri/aparc+aseg.mgz \
          --temp /fs_subject/mri/rawavg.mgz \
          --o /out/aparc+aseg_in_rawavg.mgz \
          --regheader /fs_subject/mri/aparc+aseg.mgz
      "
  fi

  for c in mri_convert antsRegistration antsApplyTransforms labelconvert tck2connectome tckinfo mrinfo; do
    apptainer exec --cleanenv "${CONTAINER_QSIRECON}" bash -lc "command -v ${c}" >/dev/null 2>&1 || {
      echo "Missing required command in CONTAINER_QSIRECON (${CONTAINER_QSIRECON}): ${c}"
      exit 1
    }
  done

  [[ -f "${FS_LUT}" ]] || {
    echo "Missing FreeSurferColorLUT.txt at FS_LUT=${FS_LUT}"
    echo "  qsirecon.sif's trimmed FreeSurfer doesn't ship this file; set FS_LUT to"
    echo "  the host-side FreeSurfer LUT (e.g. /usr/local/freesurfer/FreeSurferColorLUT.txt)."
    exit 1
  }

  local -a binds=(
    -B "${fs_dir}":/fs_subject:ro
    -B "${QSIRECON_OUT}":/qsirecon:ro
    -B "${outdir}":/out
    -B "${FS_LICENSE}":/opt/freesurfer/license.txt:ro
    -B "${FS_LUT}":/opt/freesurfer/FreeSurferColorLUT.txt:ro
  )
  [[ "${dk_warp}" == "1" ]] && binds+=(
    -B "${QSIPREP_OUT}":/qsiprep:ro
    -B "${BIDS_DIR}":/bids:ro
  )

  apptainer exec --cleanenv --containall \
    "${binds[@]}" \
    "${CONTAINER_QSIRECON}" \
    bash -lc "
      set -euo pipefail
      export FS_LICENSE=/opt/freesurfer/license.txt

      mri_convert /fs_subject/mri/aparc+aseg.mgz /out/aparc+aseg.nii.gz

      if [[ '${dk_warp}' == '1' ]]; then
        mri_convert /out/aparc+aseg_in_rawavg.mgz /out/aparc+aseg_in_rawavg.nii.gz
        echo '[dk] Step 4b-1: affine register BIDS T1w -> QSIPrep desc-preproc_T1w'
        antsRegistration --dimensionality 3 --float 0 \
          --output [/out/native_to_preproc_T1w_,/out/native_to_preproc_T1w_Warped.nii.gz] \
          --interpolation Linear \
          --winsorize-image-intensities [0.005,0.995] \
          --use-histogram-matching 1 \
          --transform Affine[0.1] \
          --metric MI['${preproc_t1w_in_container}','${bids_t1w_in_container}',1,32] \
          --convergence [500x250x100,1e-6,10] \
          --shrink-factors 4x2x1 \
          --smoothing-sigmas 2x1x0vox
        echo '[dk] Step 4b-2: warp native labels -> QSIPrep T1w (GenericLabel)'
        antsApplyTransforms -d 3 \
          -i /out/aparc+aseg_in_rawavg.nii.gz \
          -r '${preproc_t1w_in_container}' \
          -t /out/native_to_preproc_T1w_0GenericAffine.mat \
          -n GenericLabel \
          -o /out/aparc+aseg_in_t1w.nii.gz
        echo '[dk] Step 4b-3: QSIPrep T1w -> dwiref grid (GenericLabel resample)'
        antsApplyTransforms -d 3 \
          -i /out/aparc+aseg_in_t1w.nii.gz \
          -r '${dwiref_in_container}' \
          -n GenericLabel \
          -o /out/aparc+aseg_in_dwi.nii.gz
      fi

      fs_lut=/opt/freesurfer/FreeSurferColorLUT.txt
      mrtrix_lut=/opt/mrtrix3-latest/share/mrtrix3/labelconvert/fs_default.txt

      labelconvert -force '${nodes_input_in_container}' \"\$fs_lut\" \"\$mrtrix_lut\" /out/dk_nodes.mif

      tck_in='${tracks_in_container}'
      tck_use=\"\$tck_in\"
      tck_staged=\"\"
      if [[ \"\$tck_in\" == *.tck.gz ]]; then
        tck_staged=/out/streamlines.tck
        echo \"[dk] Decompressing \$tck_in -> \$tck_staged\"
        gunzip -c \"\$tck_in\" > \"\$tck_staged\"
        tck_use=\"\$tck_staged\"
      fi

      echo '[dk] === space-alignment diagnostic ==='
      mrinfo /out/dk_nodes.mif      | tee /out/dk_nodes.mrinfo.txt   | sed -n '1,20p'
      tckinfo \"\$tck_use\"         | tee /out/tracks.tckinfo.txt    | sed -n '1,30p'
      echo '[dk] =================================='

      tck2connectome -force \
        \"\$tck_use\" \
        /out/dk_nodes.mif \
        /out/dk_connectome.csv \
        -symmetric \
        -zero_diagonal \
        -out_assignments /out/dk_assignments.csv

      [[ -n \"\$tck_staged\" ]] && rm -f \"\$tck_staged\"
    "
}

# -----------------------------------------------------------------------------
# _fs_aparc_has_dk_only_labels — Does the segmentation contain DK-only regions?
#
# The authoritative DK/DKT test: bankssts (1001/2001), frontal pole (1032/2032)
# and temporal pole (1033/2033) exist in Desikan-Killiany but are not defined by
# the DKT protocol. Prints 1 if any are present and 0 if none are; returns
# non-zero (printing nothing) when the probe could not run.
# -----------------------------------------------------------------------------
_fs_aparc_has_dk_only_labels() {
  local fs_dir="$1" scratch_parent="$2"
  local scratch max

  [[ -f "${CONTAINER_DK_CONNECTOME}" ]] || return 1
  scratch="$(mktemp -d "${scratch_parent}/.dkprobe_XXXXXX" 2>/dev/null)" || return 1

  max="$(apptainer exec --cleanenv --containall \
      --env "LD_LIBRARY_PATH=/opt/ants/lib:/opt/mrtrix3-latest/lib" \
      -B "${fs_dir}/mri":/probe:ro \
      -B "${scratch}":/scratch \
      "${CONTAINER_DK_CONNECTOME}" bash -c '
        set -e
        a=/probe/aparc+aseg.mgz
        mrcalc -quiet -force "$a" 1001 -eq "$a" 1032 -eq -add "$a" 1033 -eq -add \
          "$a" 2001 -eq -add "$a" 2032 -eq -add "$a" 2033 -eq -add /scratch/dk_only.mif
        mrstats /scratch/dk_only.mif -output max
      ' 2>/dev/null | tr -d '[:space:]')"
  rm -rf "${scratch}"

  case "${max}" in
    0) echo 0 ;;
    1) echo 1 ;;
    *) return 1 ;;
  esac
}

# -----------------------------------------------------------------------------
# _fs_tree_is_dkt — Is this subject tree a FastSurfer (DKT) segmentation?
#
# Prefers the label content of aparc+aseg.mgz, which cannot be fooled by naming.
# If that probe is unavailable, falls back to FastSurfer's file layout: it
# publishes aparc+aseg.mgz as a symlink to aparc.DKTatlas+aseg.mapped.mgz and
# keeps its deep-learning segmentation beside it, while recon-all writes a real
# aparc+aseg.mgz and never produces a *.deep.mgz. Note that a recon-all tree does
# contain aparc.DKTatlas+aseg.mgz, so that name alone cannot be the test.
#
# Sets _DK_DETECT_METHOD to describe which signal decided.
# -----------------------------------------------------------------------------
_fs_tree_is_dkt() {
  local fs_dir="$1" scratch_parent="$2"
  local probe

  if probe="$(_fs_aparc_has_dk_only_labels "${fs_dir}" "${scratch_parent}")"; then
    _DK_DETECT_METHOD="aparc+aseg.mgz label content"
    [[ "${probe}" == "0" ]]
    return
  fi

  _DK_DETECT_METHOD="file layout (label probe unavailable)"
  local aparc="${fs_dir}/mri/aparc+aseg.mgz"
  if [[ -L "${aparc}" && "$(readlink "${aparc}")" == *DKTatlas* ]]; then
    return 0
  fi
  [[ -f "${fs_dir}/mri/aparc.DKTatlas+aseg.deep.mgz" ]]
}

# -----------------------------------------------------------------------------
# _count_empty_nodes — Nodes with no connections in a connectome CSV
#
# The matrix is symmetric with a zero diagonal, so an all-zero row means the node
# received no streamlines at all.
# -----------------------------------------------------------------------------
_count_empty_nodes() {
  awk -F',' 'NF > 1 { s = 0; for (i = 1; i <= NF; i++) s += $i; if (s == 0) c++ }
             END { print c + 0 }' "$1"
}

# -----------------------------------------------------------------------------
# run_dk_connectome — Build DK connectome from QSIRecon tractogram + FS aseg
# -----------------------------------------------------------------------------
run_dk_connectome() {
  echo "=== DK connectome: sub-${SUBJECT} ==="

  local fs_dir="${FS_SUBJECTS_DIR}/sub-${SUBJECT}"
  local aparc="${fs_dir}/mri/aparc+aseg.mgz"
  local rawavg="${fs_dir}/mri/rawavg.mgz"
  local outdir="${DK_OUT}/sub-${SUBJECT}"
  local tracks
  local tracks_rel
  local tracks_in_container
  local dwiref="" dwiref_rel="" dwiref_in_container=""
  local preproc_t1w="" preproc_t1w_rel="" preproc_t1w_in_container=""
  local bids_t1w="" bids_t1w_rel="" bids_t1w_in_container=""
  local dk_warp=0
  local space_note=""

  mkdir -p "${outdir}"

  [[ "${DK_RESAMPLE_TO_DWI}" == "1" ]] || \
    _pipeline_fail "DK" "DK_RESAMPLE_TO_DWI must be 1 (strict pipeline — no FS-conformed fallback)"

  [[ -d "${fs_dir}" ]] || _pipeline_fail "DK" "missing FreeSurfer subject dir: ${fs_dir}"
  [[ -f "${aparc}" ]] || _pipeline_fail "DK" "missing aparc+aseg.mgz: ${aparc}" \
    "Set FS_SUBJECTS_DIR to a tree containing sub-${SUBJECT}/mri/aparc+aseg.mgz."
  [[ -f "${rawavg}" ]] || _pipeline_fail "DK" "missing rawavg.mgz: ${rawavg}" \
    "Rerun Step 2 (recon) or check FS_SUBJECTS_DIR."

  # Read what Step 2 actually produced rather than trusting RECON_TOOL, so that
  # `subject.sh dk` on an existing tree is correct regardless of which flags this
  # invocation was given.
  local dk_parc="${DK_PARCELLATION}"
  local dk_parc_source=""
  local tree_is_dkt=0
  _DK_DETECT_METHOD=""
  if _fs_tree_is_dkt "${fs_dir}" "${outdir}"; then tree_is_dkt=1; fi

  case "${dk_parc}" in
    auto)
      if [[ "${tree_is_dkt}" == "1" ]]; then dk_parc="dkt"; else dk_parc="dk"; fi
      dk_parc_source="auto-detected from ${_DK_DETECT_METHOD}"
      echo "DK parcellation: ${dk_parc} (auto-detected from ${_DK_DETECT_METHOD})"
      ;;
    dk|dkt)
      dk_parc_source="DK_PARCELLATION=${dk_parc}"
      echo "DK parcellation: ${dk_parc} (set via DK_PARCELLATION)"
      ;;
    *)
      _pipeline_fail "DK" "invalid DK_PARCELLATION=${dk_parc} (use auto, dk, or dkt)"
      ;;
  esac

  # DKT is available from either recon tool, but only by reading the right image.
  # recon-all writes both atlases, so a DKT request there must use
  # aparc.DKTatlas+aseg.mgz: applying the DKT LUT to the DK image would silently
  # *drop* bankssts and the poles rather than reassign their territory to
  # neighbours the way DKT does (12,112 cortical voxels on a test subject).
  # FastSurfer's aparc+aseg.mgz is already DKT, so it needs no substitution.
  if [[ "${dk_parc}" == "dkt" && "${tree_is_dkt}" != "1" ]]; then
    aparc="${fs_dir}/mri/aparc.DKTatlas+aseg.mgz"
    [[ -f "${aparc}" ]] || _pipeline_fail "DK" \
      "DKT requested but this recon-all tree has no DKT segmentation: ${aparc}" \
      "recon-all normally writes it; rerun Step 2, or use DK_PARCELLATION=dk."
    echo "Using the recon-all DKT segmentation: ${aparc}"
  fi

  # FastSurfer never produces a DK atlas (no lh.aparc.annot), so DK there can only
  # mean the DK LUT over DKT labels, which leaves the 6 DK-only nodes empty.
  if [[ "${dk_parc}" == "dk" && "${tree_is_dkt}" == "1" ]]; then
    echo "WARNING: DK_PARCELLATION=dk on a FastSurfer tree, which has no DK atlas —" \
         "expect 6 empty nodes (bankssts, frontal pole, temporal pole, bilaterally)."
  fi

  tracks="$(_strict_find_one "DK/tractogram" \
    find "${QSIRECON_OUT}" -type f -path "*sub-${SUBJECT}*" \
      \( -name '*.tck' -o -name '*.tck.gz' \))"
  tracks_rel="${tracks#${QSIRECON_OUT}/}"
  tracks_in_container="/qsirecon/${tracks_rel}"

  local dk_ses=""
  dk_ses="$(_bids_ses_from_path "${tracks}")"
  [[ -n "${dk_ses}" ]] || _pipeline_fail "DK/session" "tractogram path has no ses-* entity: ${tracks}"

  dwiref="$(_strict_find_one "DK/dwiref" \
    find "${QSIPREP_OUT}" -type f -path "*sub-${SUBJECT}*/ses-${dk_ses}/*" \
      -name '*space-T1w_dwiref.nii.gz')"
  preproc_t1w="$(find_qsiprep_preproc_t1w "${QSIPREP_OUT}" "${SUBJECT}" "${dk_ses}")"
  bids_t1w="$(find_bids_t1w "${SUBJECT}" "${dk_ses}")"

  dwiref_rel="${dwiref#${QSIPREP_OUT}/}"
  preproc_t1w_rel="${preproc_t1w#${QSIPREP_OUT}/}"
  bids_t1w_rel="${bids_t1w#${BIDS_DIR}/}"
  dwiref_in_container="/qsiprep/${dwiref_rel}"
  preproc_t1w_in_container="/qsiprep/${preproc_t1w_rel}"
  bids_t1w_in_container="/bids/${bids_t1w_rel}"
  dk_warp=1
  space_note="FS conformed -> native (mri_label2vol/rawavg) -> QSIPrep T1w (affine BIDS T1w->desc-preproc_T1w) -> dwiref"

  echo "Using tractogram: ${tracks}"
  echo "Using aparc+aseg: ${aparc}"
  [[ -n "${dwiref}" ]] && echo "Using DWI reference: ${dwiref}"
  [[ -n "${preproc_t1w}" ]] && echo "Using QSIPrep T1w reference: ${preproc_t1w}"
  [[ -n "${bids_t1w}"     ]] && echo "Using BIDS T1w (affine reg source): ${bids_t1w}"
  echo "Space handling: ${space_note}"

  if [[ "${DK_LEGACY_DUAL_CONTAINER:-0}" == "1" ]]; then
    echo "[dk] Using legacy dual-container path (DK_LEGACY_DUAL_CONTAINER=1)"
    [[ "${dk_parc}" == "dk" ]] || _pipeline_fail "DK" \
      "the legacy dual-container path only supports the DK LUT, but this subject needs ${dk_parc}" \
      "Drop DK_LEGACY_DUAL_CONTAINER, or set DK_PARCELLATION=dk to accept 6 empty nodes."
    _run_dk_connectome_dual_container \
      "${fs_dir}" "${aparc}" "${rawavg}" "${outdir}" \
      "${tracks}" "${tracks_in_container}" \
      "${dwiref_in_container}" "${preproc_t1w_in_container}" "${bids_t1w_in_container}" \
      "${dk_warp}" "${space_note}"
  else
    [[ -f "${CONTAINER_DK_CONNECTOME}" ]] || \
      _pipeline_fail "DK" "missing CONTAINER_DK_CONNECTOME: ${CONTAINER_DK_CONNECTOME}" \
        "Build: bash dwi_pipeline/containers/dk_connectome/build_dk_connectome.sh"

    local -a dk_binds=()
    if [[ "${DK_CONNECTOME_BIND_ENTRYPOINT:-0}" == "1" ]]; then
      dk_binds+=(-B "${TRACKTBI_ROOT}/dwi_pipeline/containers/dk_connectome/run_dk_connectome.sh":/usr/local/bin/run_dk_connectome:ro)
    fi

    # The image only ships fs_default.txt, so a DKT run binds its LUT in.
    local -a dk_lut_args=()
    if [[ "${dk_parc}" == "dkt" ]]; then
      [[ -f "${DK_LUT_DKT}" ]] || _pipeline_fail "DK" "missing DKT LUT: ${DK_LUT_DKT}" \
        "Generate it: python3 dwi_pipeline/scripts/make_dkt_lut.py"
      dk_binds+=(-B "${DK_LUT_DKT}":/lut/fs_dkt.txt:ro)
      dk_lut_args+=(--mrtrix-lut /lut/fs_dkt.txt)
      echo "Using DKT LUT: ${DK_LUT_DKT}"
    fi

    local -a dk_env_args=()
    if [[ "${DK_DETERMINISTIC}" == "1" ]]; then
      dk_env_args+=(--env "ITK_GLOBAL_DEFAULT_NUMBER_OF_THREADS=1" --env "ANTS_RANDOM_SEED=1")
      echo "Deterministic mode: ITK pinned to 1 thread (DK_DETERMINISTIC=1)"
    fi

    apptainer run --cleanenv --containall \
      --home /tmp \
      --env "LD_LIBRARY_PATH=/opt/ants/lib:/opt/mrtrix3-latest/lib" \
      "${dk_env_args[@]}" \
      "${dk_binds[@]}" \
      -B "${FS_SUBJECTS_DIR}":/subjects:ro \
      -B "${QSIRECON_OUT}":/qsirecon:ro \
      -B "${QSIPREP_OUT}":/qsiprep:ro \
      -B "${BIDS_DIR}":/bids:ro \
      -B "${outdir}":/out \
      -B "${FS_LICENSE}":/opt/freesurfer/license.txt:ro \
      "${CONTAINER_DK_CONNECTOME}" \
      --freesurfer-subject "/subjects/sub-${SUBJECT}" \
      --tractogram "${tracks_in_container}" \
      --dwiref "${dwiref_in_container}" \
      --preproc-t1w "${preproc_t1w_in_container}" \
      --bids-t1w "${bids_t1w_in_container}" \
      --output-dir /out \
      --fs-license /opt/freesurfer/license.txt \
      "${dk_lut_args[@]}" \
      --subject-id "sub-${SUBJECT}"
  fi

  # Matrix size depends on the LUT (84 for DK, 78 for DKT), so record which one
  # produced this connectome next to it.
  local dk_lut_used="fs_default.txt"
  local dk_atlas="Desikan-Killiany"
  local dk_nodes=84
  if [[ "${dk_parc}" == "dkt" ]]; then
    dk_lut_used="fs_dkt.txt"
    dk_atlas="Desikan-Killiany-Tourville"
    dk_nodes=78
  fi

  # The container always writes dk_connectome.csv. Name the final matrix after the
  # parcellation so an 84-node DK and a 78-node DKT result can never be mistaken
  # for each other, and clear any matrix left behind by the other parcellation so
  # a stale file of the wrong dimension cannot be picked up later.
  local dk_matrix="${outdir}/dk_connectome.csv"
  if [[ "${dk_parc}" == "dkt" ]]; then
    dk_matrix="${outdir}/dkt_connectome.csv"
    mv -f "${outdir}/dk_connectome.csv" "${dk_matrix}"
  else
    rm -f "${outdir}/dkt_connectome.csv"
  fi
  # Briefly-lived earlier naming, removed so it cannot be mistaken for output.
  rm -f "${outdir}/DKT_connectome.csv"

  # A node with no streamlines almost always means the LUT does not match the
  # segmentation, which is exactly the failure this parcellation logic exists to
  # prevent, so surface it rather than let it reach group analysis unnoticed.
  local dk_empty
  dk_empty="$(_count_empty_nodes "${dk_matrix}")"
  if [[ "${dk_empty}" -gt 0 ]]; then
    echo "WARNING: ${dk_empty} of ${dk_nodes} ${dk_atlas} nodes received no streamlines."
    echo "         Usually a LUT/segmentation mismatch; can be genuine after resection"
    echo "         or a large lesion. Check ${outdir}/dk_parcellation.json."
    if [[ "${DK_FAIL_ON_EMPTY_NODES}" == "1" ]]; then
      _pipeline_fail "DK" "${dk_empty} empty nodes in ${dk_matrix} (DK_FAIL_ON_EMPTY_NODES=1)"
    fi
  fi

  cat > "${outdir}/dk_parcellation.json" <<EOF
{
  "parcellation": "${dk_parc}",
  "atlas": "${dk_atlas}",
  "nodes": ${dk_nodes},
  "labelconvert_lut": "${dk_lut_used}",
  "connectome_csv": "${dk_matrix##*/}",
  "empty_nodes": ${dk_empty},
  "deterministic": ${DK_DETERMINISTIC},
  "selected_by": "${dk_parc_source}",
  "freesurfer_subject_dir": "${fs_dir}",
  "aparc_aseg": "${aparc}"
}
EOF

  echo "DK connectome: ${dk_matrix} (${dk_atlas}, ${dk_nodes} nodes)"
  echo "Parcellation provenance: ${outdir}/dk_parcellation.json"
  echo "Space diagnostic: ${outdir}/dk_nodes.mrinfo.txt , ${outdir}/tracks.tckinfo.txt"
}

# --- Dispatch: run one or more stages ---
case "${PIPELINE_MODE}" in
  all)
    run_qsiprep
    if [[ "${RUN_RECON}" == "1" ]]; then
      run_recon
    else
      echo "Recon: skipped (RUN_RECON=0 / --no-recon)"
      if [[ "${QSIRECON_SPEC}" == *hsvs* && ! -d "${FS_SUBJECTS_DIR}/sub-${SUBJECT}" ]]; then
        _pipeline_fail "qsirecon" "QSIRECON_SPEC=${QSIRECON_SPEC} requires FreeSurfer but recon was skipped" \
          "Run Step 2, set FS_SUBJECTS_DIR to an existing subjects tree," \
          "or set QSIRECON_SPEC=mrtrix_singleshell_ss3t_ACT-fast before submit."
      fi
    fi
    run_qsirecon
    if [[ "${RUN_DK_CONNECTOME}" == "1" ]]; then
      run_dk_connectome
    fi
    ;;
  qsiprep)  run_qsiprep ;;
  recon)    run_recon ;;
  qsirecon) run_qsirecon ;;
  dk)       run_dk_connectome ;;
  *)
    echo "Invalid PIPELINE_MODE=${PIPELINE_MODE} (use all, qsiprep, recon, qsirecon, or dk)"
    exit 1
    ;;
esac

echo "QSIPrep output:  ${QSIPREP_OUT}"
echo "Recon output:    ${RECON_OUT}"
echo "QSIRecon output: ${QSIRECON_OUT}"
echo "DK output:       ${DK_OUT}"
