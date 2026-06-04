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
#       inside CONTAINER_FREESURFER. Defaults to the dedicated full FreeSurfer
#       7.4.1 SIF at ../others/containers/freesurfer_7.4.1.sif (pulled via
#       containers/pull_freesurfer_sif.sbatch). Falls back to FastSurfer's SIF
#       only if the dedicated image is missing — that image ships a *trimmed*
#       FreeSurfer and is missing skull-strip atlases, so prefer the dedicated
#       image for production runs.
#     RECON_TOOL=fastsurfer (CLI flag --fastsurfer): runs FastSurfer inside
#       CONTAINER_FASTSURFER (~1-2 h CPU, ~20 min GPU). Produces aparc+aseg.mgz
#       via recon-surf.
#   Skips automatically if RECON_OUT/sub-XXX/mri/aparc+aseg.mgz already exists.
#
# Step 3 — QSIRecon (container):
#   Reads QSIPrep derivatives. Default recon spec mrtrix_singleshell_ss3t_ACT-hsvs:
#   MRtrix SS3T CSD + ACT tractography with HSVS 5TT (uses FreeSurfer subject dir
#   produced by Step 2). Switch to mrtrix_singleshell_ss3t_ACT-fast via
#   QSIRECON_SPEC if you skip Step 2 (FAST 5TT, no FreeSurfer needed).
#
# Step 4 — DK connectome (container, default ON when Step 2 ran):
#   Post-step after QSIRecon. Uses FreeSurfer aparc+aseg.mgz + QSIRecon .tck.
#   Space alignment: aparc+aseg lives in FreeSurfer conformed (orig.mgz) space;
#   tractogram lives in QSIPrep DWI/T1w (ACPC) space. Before labelconvert,
#   aparc+aseg is resampled onto the DWI grid with mri_vol2vol using QSIPrep's
#   from-orig_to-T1w LTA + DWI reference image. Set DK_RESAMPLE_TO_DWI=0 to skip.
#   Tools: mri_convert, mri_vol2vol, labelconvert, tck2connectome.
#   Writes dk_connectome.csv under dk_connectomes/sub-XXX/.
#
# Usage:
#   bash subject.sh all 014                  # full pipeline (recon-all default)
#   bash subject.sh all 014 --fastsurfer     # use FastSurfer in Step 2
#   bash subject.sh all 014 --no-recon       # skip Step 2 (forces ACT-fast spec)
#   bash subject.sh all 014 --no-dk          # skip Step 4
#   bash subject.sh qsiprep 014              # preprocessing only
#   bash subject.sh recon 014                # Step 2 only (recon-all by default)
#   bash subject.sh recon 014 --fastsurfer   # Step 2 only via FastSurfer
#   bash subject.sh qsirecon 014             # Step 3 only (QSIPrep must exist)
#   bash subject.sh dk 014                   # Step 4 only (needs FS dir + .tck)
#   bash subject.sh all 014 --syn            # no BIDS fmap -> --use-syn-sdc warn
#   bash subject.sh all 014 --fmap-retry     # ignore measured fmaps, SyN SDC
#
# SDC defaults (QSIPrep):
#   BIDS fmap present  -> measured fmaps / TOPUP (no --use-syn-sdc)
#   No BIDS fmap       -> no SyN (omit --use-syn-sdc) unless --syn or QSIPREP_USE_SYN_SDC=1
#
# Outputs under RESULTS_ROOT (default: .../CIDUR_BIDS/dwi_test):
#   qsiprep_single_run_output/   freesurfer/   qsirecon_single_run_output/   dk_connectomes/
#
# Environment (optional overrides):
#   RESULTS_ROOT, BIDS_DIR, NTHREADS, OMP_NTHREADS, OUTPUT_RES
#   CONTAINER_QSIPREP, CONTAINER_QSIRECON, CONTAINER_FASTSURFER, CONTAINER_FREESURFER
#   FS_LICENSE, TEMPLATEFLOW_HOME
#   RUN_RECON=0|1          Step 2 in mode=all (default 1)
#   RECON_TOOL             freesurfer (default) or fastsurfer
#   RECON_OUT              FreeSurfer subjects dir (default: RESULTS_ROOT/freesurfer)
#   FS_SUBJECTS_DIR        same as RECON_OUT unless overridden (used by Steps 3 + 4)
#   RECON_FASTSURFER_DEVICE  cpu (default) or cuda for FastSurfer GPU runs
#   QSIRECON_SPEC          default: mrtrix_singleshell_ss3t_ACT-hsvs (auto-switches
#                          to ACT-fast when --no-recon and no FS subjects dir exists)
#   QSIRECON_ATLASES       optional QSIRecon --atlases (Schaefer100, AAL116, ...)
#   RUN_DK_CONNECTOME=0|1  DK in mode=all (default 1 when Step 2 ran)
#   DK_RESAMPLE_TO_DWI=0|1 Resample aparc+aseg onto DWI grid (default 1)
#   QSIPREP_USE_SYN_SDC=1  opt-in SyN when no measured fmaps (same as --syn)
#   QSIPREP_FMAP_RETRY=1   --ignore fieldmaps --use-syn-sdc warn (same as --fmap-retry)
# =============================================================================

set -euo pipefail
set +H

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
    -h|--help)
      sed -n '36,57p' "$0"
      exit 0
      ;;
    *)
      echo "Unknown option: $1 (try --syn, --fmap-retry, --fastsurfer, --no-recon, --no-dk)"
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
# dwi_pipeline/containers/pull_freesurfer_sif.sbatch). Fall back to FastSurfer's
# trimmed FreeSurfer only if the dedicated SIF is not yet on disk; that fallback
# will fail at recon-all's skull-strip step because RB_all_withskull_2020_01_02.gca
# is missing from the FastSurfer image.
_FS_SIF_DEFAULT="/mnt/nfs/home/urmc-sh.rochester.edu/pndagiji/Documents/others/containers/freesurfer_7.4.1.sif"
if [[ -z "${CONTAINER_FREESURFER:-}" ]]; then
  if [[ -f "${_FS_SIF_DEFAULT}" ]]; then
    CONTAINER_FREESURFER="${_FS_SIF_DEFAULT}"
  else
    echo "WARNING: dedicated FreeSurfer SIF not found at ${_FS_SIF_DEFAULT}"
    echo "         Falling back to ${CONTAINER_FASTSURFER}, but recon-all -all will"
    echo "         fail at the skull-strip step because that image's FreeSurfer is"
    echo "         missing /opt/freesurfer/average/RB_all_withskull_2020_01_02.gca."
    echo "         Build the dedicated image first:"
    echo "           sbatch dwi_pipeline/containers/pull_freesurfer_sif.sbatch"
    CONTAINER_FREESURFER="${CONTAINER_FASTSURFER}"
  fi
fi
TEMPLATEFLOW_HOME="${TEMPLATEFLOW_HOME:-${TRACKTBI_ROOT}/templateflow}"
FS_LICENSE="${FS_LICENSE:-/mnt/nfs/home/urmc-sh.rochester.edu/pndagiji/Documents/others/data_mining/freesurfer/license.txt}"

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

mkdir -p "${TEMPLATEFLOW_HOME}" "${QSIPREP_OUT}" "${QSIRECON_OUT}" "${RECON_OUT}" "${INTER_QSP}" "${INTER_QSI}" "${RESULTS_ROOT}/logs"
echo "RESULTS_ROOT=${RESULTS_ROOT} (ACT connectome pipeline)"

# True if this subject has any NIfTI under fmap/ in BIDS (drives SDC choice)
has_fmap() {
  find "${BIDS_DIR}/sub-${SUBJECT}" -type f \( -name '*.nii' -o -name '*.nii.gz' \) -path '*/fmap/*' 2>/dev/null | head -1 | grep -q .
}

# -----------------------------------------------------------------------------
# run_qsiprep — QSIPrep in Apptainer: BIDS -> qsiprep_single_run_output/sub-XXX
# -----------------------------------------------------------------------------
run_qsiprep() {
  local -a xtra=()

  # Susceptibility distortion correction (SDC):
  #   measured fmaps when BIDS has fmap/; no SyN by default when it does not;
  #   opt-in SyN via --syn or QSIPREP_USE_SYN_SDC=1.
  if [[ "${QSIPREP_FMAP_RETRY:-0}" == "1" ]]; then
    xtra+=(--ignore fieldmaps)
    xtra+=(--use-syn-sdc warn)
    echo "QSIPrep: sub-${SUBJECT}: fmap retry -> --ignore fieldmaps --use-syn-sdc warn"
  elif has_fmap; then
    echo "QSIPrep: sub-${SUBJECT}: fmap present -> measured fmaps (no --use-syn-sdc)"
  elif [[ "${QSIPREP_USE_SYN_SDC:-0}" == "1" ]]; then
    xtra+=(--use-syn-sdc warn)
    echo "QSIPrep: sub-${SUBJECT}: no fmap, SyN enabled -> --use-syn-sdc warn"
  else
    echo "QSIPrep: sub-${SUBJECT}: no fmap, SyN off (default; pass --syn to enable)"
  fi

  echo "=== QSIPrep (ACT pipeline): sub-${SUBJECT} ==="
  rm -rf "${WORK_QSIPREP}"
  mkdir -p "${WORK_QSIPREP}"

  # Mounts: BIDS read-only, outputs + work writable, license + TemplateFlow for registration
  apptainer run --cleanenv --containall \
    -B "${BIDS_DIR}":/bids_input:ro \
    -B "${QSIPREP_OUT}":/output \
    -B "${WORK_QSIPREP}":/work \
    -B "${FS_LICENSE}":/opt/freesurfer/license.txt:ro \
    -B "${TEMPLATEFLOW_HOME}":/templateflow \
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
    echo "Recon: ${aparc} already exists — skipping (delete ${sd_subj} to force rerun)"
    return 0
  fi
  if [[ -d "${sd_subj}" ]]; then
    echo "Recon: partial subjects dir at ${sd_subj} but no aparc+aseg.mgz."
    echo "       Remove it before resubmitting (recon-all/FastSurfer won't overwrite cleanly)."
    exit 1
  fi

  # Find BIDS T1w(s) under sub-XXX/.../anat/
  local -a t1ws=()
  mapfile -t t1ws < <(find "${BIDS_DIR}/sub-${SUBJECT}" -type f -path '*/anat/*' \
                         \( -name '*_T1w.nii.gz' -o -name '*_T1w.nii' \) 2>/dev/null | sort)
  (( ${#t1ws[@]} > 0 )) || { echo "Recon: no T1w found under ${BIDS_DIR}/sub-${SUBJECT}/.../anat/"; exit 1; }
  echo "Recon: ${#t1ws[@]} T1w input(s):"
  for t in "${t1ws[@]}"; do echo "  - $t"; done

  mkdir -p "${RECON_OUT}"

  case "${RECON_TOOL}" in
    freesurfer)
      _run_recon_freesurfer "${t1ws[@]}"
      ;;
    fastsurfer)
      _run_recon_fastsurfer "${t1ws[0]}"
      (( ${#t1ws[@]} > 1 )) && echo "Recon: FastSurfer used only the first T1w; recon-all averages multiple runs"
      ;;
    *)
      echo "Invalid RECON_TOOL=${RECON_TOOL}"; exit 1 ;;
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

# Internal: FreeSurfer recon-all inside CONTAINER_FREESURFER (dedicated full
# FreeSurfer SIF by default; fastsurfer_latest.sif as a fallback for prototyping).
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
      echo "       Either pre-run FreeSurfer/FastSurfer and set FS_SUBJECTS_DIR,"
      echo "       or switch to QSIRECON_SPEC=mrtrix_singleshell_ss3t_ACT-fast."
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

# -----------------------------------------------------------------------------
# run_dk_connectome — Build DK connectome from QSIRecon tractogram + FS aseg
# -----------------------------------------------------------------------------
run_dk_connectome() {
  echo "=== DK connectome: sub-${SUBJECT} ==="

  local fs_dir="${FS_SUBJECTS_DIR}/sub-${SUBJECT}"
  local aparc="${fs_dir}/mri/aparc+aseg.mgz"
  local outdir="${DK_OUT}/sub-${SUBJECT}"
  local tracks
  local tracks_rel
  local tracks_in_container
  local dwiref="" dwiref_rel="" dwiref_in_container=""
  local lta="" lta_rel="" lta_in_container=""
  local nodes_input_in_container="/out/aparc+aseg.nii.gz"
  local space_note="WARNING: aparc+aseg used in FS conformed space (not resampled to DWI)"

  mkdir -p "${outdir}"

  [[ -d "${fs_dir}" ]] || { echo "Missing FreeSurfer subject dir: ${fs_dir}"; exit 1; }
  [[ -f "${aparc}" ]] || {
    echo "Missing aparc+aseg.mgz: ${aparc}"
    echo "Set FS_SUBJECTS_DIR to a directory containing sub-${SUBJECT}/mri/aparc+aseg.mgz."
    exit 1
  }

  # QSIRecon's MRtrix specs save the tractogram gzipped (*.tck.gz). MRtrix3
  # tools read it transparently, but `find -name '*.tck'` does NOT match
  # *.tck.gz. Match both, prefer the uncompressed form when present so MRtrix
  # avoids the gzip decompression on every read (matters for the multi-pass
  # tckinfo + tck2connectome below).
  tracks="$(find "${QSIRECON_OUT}" -type f -path "*sub-${SUBJECT}*" -name '*.tck' 2>/dev/null | head -1)"
  if [[ -z "${tracks}" ]]; then
    tracks="$(find "${QSIRECON_OUT}" -type f -path "*sub-${SUBJECT}*" -name '*.tck.gz' 2>/dev/null | head -1)"
  fi
  [[ -n "${tracks}" ]] || {
    echo "Missing QSIRecon tractogram (.tck) for sub-${SUBJECT} under ${QSIRECON_OUT}"
    exit 1
  }
  tracks_rel="${tracks#${QSIRECON_OUT}/}"
  tracks_in_container="/qsirecon/${tracks_rel}"

  # Look for QSIPrep DWI-space reference image (in T1w/ACPC space) and the
  # fsnative -> T1w transform; both are needed to put aparc+aseg on the DWI grid.
  if [[ "${DK_RESAMPLE_TO_DWI}" == "1" ]]; then
    dwiref="$(find "${QSIPREP_OUT}" -type f -path "*sub-${SUBJECT}*" \
                -name '*space-T1w_dwiref.nii.gz' 2>/dev/null | head -1)"
    [[ -z "${dwiref}" ]] && dwiref="$(find "${QSIPREP_OUT}" -type f -path "*sub-${SUBJECT}*" \
                -name '*space-T1w*desc-preproc_dwi.nii.gz' 2>/dev/null | head -1)"
    lta="$(find "${QSIPREP_OUT}" -type f -path "*sub-${SUBJECT}*" \
            \( -name '*from-orig_to-T1w_mode-image_xfm.txt' \
            -o -name '*from-orig_to-T1w_mode-image_xfm.lta' \
            -o -name '*from-fsnative_to-T1w_mode-image_xfm.txt' \
            -o -name '*from-fsnative_to-T1w_mode-image_xfm.lta' \) 2>/dev/null | head -1)"

    if [[ -n "${dwiref}" && -n "${lta}" ]]; then
      dwiref_rel="${dwiref#${QSIPREP_OUT}/}"
      lta_rel="${lta#${QSIPREP_OUT}/}"
      dwiref_in_container="/qsiprep/${dwiref_rel}"
      lta_in_container="/qsiprep/${lta_rel}"
      nodes_input_in_container="/out/aparc+aseg_in_dwi.nii.gz"
      space_note="resampled aparc+aseg onto DWI grid via mri_vol2vol (LTA: ${lta_rel##*/})"
    else
      echo "DK warning: cannot find QSIPrep DWI reference and/or fsnative->T1w LTA;"
      echo "  dwiref=${dwiref:-<missing>}  lta=${lta:-<missing>}"
      echo "  Falling back to FS conformed space — connectome may be mis-aligned."
      echo "  Set DK_RESAMPLE_TO_DWI=0 to silence this; or check QSIPrep outputs."
    fi
  fi

  # Fast-fail: DK post-step needs FreeSurfer + MRtrix commands inside container.
  local need_cmds=(mri_convert labelconvert tck2connectome tckinfo mrinfo)
  [[ "${DK_RESAMPLE_TO_DWI}" == "1" && -n "${lta}" ]] && need_cmds+=(mri_vol2vol)
  for c in "${need_cmds[@]}"; do
    apptainer exec --cleanenv "${CONTAINER_QSIRECON}" bash -lc "command -v ${c}" >/dev/null 2>&1 || {
      echo "Missing required command in CONTAINER_QSIRECON (${CONTAINER_QSIRECON}): ${c}"
      echo "Use an image with FreeSurfer + MRtrix (or set CONTAINER_QSIRECON accordingly)."
      exit 1
    }
  done

  echo "Using tractogram: ${tracks}"
  echo "Using aparc+aseg: ${aparc}"
  [[ -n "${dwiref}" ]] && echo "Using DWI reference: ${dwiref}"
  [[ -n "${lta}"    ]] && echo "Using fsnative->T1w LTA: ${lta}"
  echo "Space handling: ${space_note}"

  # Build the bind-mount list. Mount QSIPrep r/o only when resampling.
  local -a binds=(
    -B "${fs_dir}":/fs_subject:ro
    -B "${QSIRECON_OUT}":/qsirecon:ro
    -B "${outdir}":/out
    -B "${FS_LICENSE}":/opt/freesurfer/license.txt:ro
  )
  [[ -n "${lta}" ]] && binds+=( -B "${QSIPREP_OUT}":/qsiprep:ro )

  apptainer run --cleanenv --containall \
    "${binds[@]}" \
    "${CONTAINER_QSIRECON}" \
    bash -lc "
      set -euo pipefail
      export FS_LICENSE=/opt/freesurfer/license.txt
      export SUBJECTS_DIR=/fs_subject/..

      mri_convert /fs_subject/mri/aparc+aseg.mgz /out/aparc+aseg.nii.gz

      if [[ -n '${lta_in_container}' && -n '${dwiref_in_container}' ]]; then
        echo '[dk] Resampling aparc+aseg into DWI/T1w grid (nearest-neighbour)'
        mri_vol2vol \
          --mov /fs_subject/mri/aparc+aseg.mgz \
          --targ '${dwiref_in_container}' \
          --lta  '${lta_in_container}' \
          --nearest \
          --o /out/aparc+aseg_in_dwi.nii.gz
      fi

      fs_lut=\${FREESURFER_HOME:-/opt/freesurfer}/FreeSurferColorLUT.txt
      if [[ ! -f \"\$fs_lut\" ]]; then
        fs_lut=/opt/freesurfer/FreeSurferColorLUT.txt
      fi
      mrtrix_lut=\${MRTRIX_HOME:-/opt/mrtrix3}/share/mrtrix3/labelconvert/fs_default.txt
      if [[ ! -f \"\$mrtrix_lut\" ]]; then
        mrtrix_lut=/usr/local/mrtrix3/share/mrtrix3/labelconvert/fs_default.txt
      fi

      labelconvert '${nodes_input_in_container}' \"\$fs_lut\" \"\$mrtrix_lut\" /out/dk_nodes.mif

      echo '[dk] === space-alignment diagnostic ==='
      mrinfo /out/dk_nodes.mif      | tee /out/dk_nodes.mrinfo.txt   | sed -n '1,20p'
      tckinfo '${tracks_in_container}' | tee /out/tracks.tckinfo.txt | sed -n '1,30p'
      echo '[dk] =================================='

      tck2connectome \
        '${tracks_in_container}' \
        /out/dk_nodes.mif \
        /out/dk_connectome.csv \
        -symmetric \
        -zero_diagonal \
        -out_assignments /out/dk_assignments.csv
    "

  echo "DK connectome: ${outdir}/dk_connectome.csv"
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
      # If the user disabled recon, HSVS will fail at QSIRecon. Auto-degrade to FAST spec
      # unless they have explicitly pointed at an external FreeSurfer subjects dir.
      if [[ "${QSIRECON_SPEC}" == *hsvs* && ! -d "${FS_SUBJECTS_DIR}/sub-${SUBJECT}" ]]; then
        echo "Recon: no FS subjects dir; switching QSIRECON_SPEC ${QSIRECON_SPEC} -> mrtrix_singleshell_ss3t_ACT-fast"
        QSIRECON_SPEC="mrtrix_singleshell_ss3t_ACT-fast"
        RUN_DK_CONNECTOME=0
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
