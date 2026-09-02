#!/bin/bash
# =============================================================================
# subject.sh — Process ONE participant: QSIPrep, Recon, QSIRecon, connectome
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
# Step 1.1 — Inpaint (container, default auto-on; skipped when no lesion mask):
#   Runs neuroLIT (deepmi/lit, a DDPM lesion-inpainting model with VINN layers)
#   on the subject's T1w *before* Step 2, filling in the manually-traced lesion
#   region so a lesion doesn't throw off recon-all/FastSurfer's atlas-based
#   skull-strip, Talairach registration, or cortical parcellation.
#   Only runs when a sibling BIDS file matching *_T1w_label-lesion_roi.nii.gz
#   exists next to the T1w for the target session (see find_lesion_mask); for
#   every other subject it is a silent no-op and Step 2 uses the raw BIDS T1w
#   exactly as before. Set --no-inpaint / RUN_INPAINT=0 to force-skip even when
#   a mask is present, or INPAINT_REQUIRE_MASK=1 to fail loudly instead of
#   skipping when no mask is found (useful for demo runs where you want to be
#   sure inpainting actually happened).
#   Pipeline: dwi_pipeline/scripts/prepare_lesion_mask.py (resample/select
#   labels/binarize + provenance) -> lit-inpainting inside CONTAINER_LIT
#   (--keepgeom, so the result stays on the T1w's native grid) ->
#   dwi_pipeline/scripts/check_inpainting.py (correlation-based QC comparing
#   against a resampling-only control). Writes INPAINT_OUT/sub-XXX/ses-YYY/
#   {lesion_mask_prepared.nii.gz, inpainting_volumes/inpainting_result.nii.gz,
#   inpainting.json}. Steps 2 and 4 use inpainting_result.nii.gz in place of
#   the raw BIDS T1w whenever this stage ran for that subject/session.
#   Build the container: bash dwi_pipeline/containers/lit/build_lit.sh
#
# Step 2 — Recon (container, default ON; tools: recon-all OR FastSurfer):
#   Runs anatomical surface reconstruction on the subject's T1w (the Step 1.1
#   inpainted T1w when that ran, else the raw BIDS T1w) to produce a
#   FreeSurfer-style subjects directory (aparc+aseg.mgz, surfaces, labels,
#   etc.) at RECON_OUT/sub-XXX/.
#     RECON_TOOL=freesurfer (default): runs recon-all -all (~6-10 h CPU)
#       inside CONTAINER_FREESURFER. Requires the dedicated full FreeSurfer
#       7.4.1 SIF at ../others/containers/freesurfer_7.4.1.sif (pulled via
#       containers/pull_freesurfer_sif.sbatch). Pipeline fails if missing.
#     RECON_TOOL=fastsurfer (CLI flag --fastsurfer): runs FastSurfer inside
#       CONTAINER_FASTSURFER (~1-2 h CPU, ~20 min GPU). Produces aparc+aseg.mgz
#       via recon-surf. --fast-fs additionally sets RECON_FSAPARC=1, which
#       passes FastSurfer --fsaparc so it also writes the classic aparc/DK-68
#       segmentation and ribbon alongside its native DKT one — the only way to
#       get a DK atlas without a full recon-all run (adds ~10-20 min CPU).
#   Skips Step 2 only when RECON_SKIP_IF_EXISTS=1 and aparc+aseg.mgz exists;
#   otherwise fails if aparc already present (strict rerun policy).
#
# Step 3 — QSIRecon (container):
#   Reads QSIPrep derivatives. Default recon spec mrtrix_singleshell_ss3t_ACT-hsvs:
#   MRtrix SS3T CSD + ACT tractography with HSVS 5TT (uses FreeSurfer subject dir
#   produced by Step 2). With --no-recon, you must set QSIRECON_SPEC to ACT-fast
#   or provide an existing FS subjects dir — no automatic spec switch.
#
# Step 4 — Connectome (container, default ON when Step 2 ran):
#   Post-step after QSIRecon. Uses a FreeSurfer parcellation + QSIRecon .tck.
#   Space alignment: the segmentation lives in FreeSurfer conformed (orig.mgz)
#   space (256³); the tractogram lives in QSIPrep T1w (dwiref) space. Step 4a
#   warps labels to native T1w (rawavg.mgz). Step 4b affine-registers BIDS T1w ->
#   desc-preproc_T1w (QSIPrep's packaged from-T1wNative_to-T1wACPC .mat targets a
#   reoriented T1wNative frame, not FS scanner-native rawavg), applies that warp
#   to labels, then resamples onto dwiref (-n GenericLabel).
#   Runs in CONTAINER_CONNECTOME (dkt_connectome.sif: FreeSurfer + ANTs + MRtrix3).
#   Build: bash dwi_pipeline/containers/connectome/build_connectome.sh
#   Legacy dual-container path: CONNECTOME_LEGACY_DUAL_CONTAINER=1 (freesurfer + qsirecon).
#   Both recon tools yield the same parcellation by default: Desikan-Killiany-
#   Tourville, 78 nodes, fs_dkt.txt (CONNECTOME_PARCELLATION=dkt). FastSurfer's
#   aparc+aseg.mgz is already DKT; a recon-all tree is read via its
#   aparc.DKTatlas+aseg.mgz. So --fastsurfer changes how long Step 2 takes, not
#   the node set, and a cohort pools regardless of which tool each subject used.
#   DK (84 nodes, fs_default.txt) is available with CONNECTOME_PARCELLATION=dk,
#   but only from recon-all — FastSurfer produces no DK atlas.
#   Writes parcellation.json plus the matrix, named for the parcellation:
#   dkt_connectome.csv (DKT) or dk_connectome.csv (DK), under connectomes/sub-XXX/.
#
# Step 5 — Node strength / ENIGMA report (container, default ON when Step 4 ran):
#   Post-step after the connectome. Runs the standalone `nodestrength` container
#   (github.com/phindagijimana/dwi-AI) against CONNECTOME_OUT (bind-mounted
#   read-only, --include SUBJECT so a shared connectomes/ tree is safe to reuse
#   across subjects) plus FS_SUBJECTS_DIR (for per-node volumes from nodes.mif).
#   Atlas-agnostic: auto-detects 78-node DKT vs. 84-node DK from the connectome's
#   own shape, so it works unmodified against either of Step 4's outputs.
#   Computes node strength, interhemispheric/intrahemispheric asymmetry index,
#   and volume AI (BCT-parity `strengths_und`; see node_strength/BCT.md), renders
#   an ENIGMA-style inflated cortical surface + subcortical panel + seed
#   connectivity profiles, and writes a lean clinician-facing report.pdf.
#   Writes NODESTRENGTH_OUT/{strength,volume,compare,reports/sub-XXX/{report.pdf,
#   figures/}}, manifest.json. Set --no-node-strength / RUN_NODESTRENGTH=0 to
#   skip; --strength-only / --no-report thin it out (skip volume+compare, or
#   skip the PDF+figures, respectively).
#   Container: /path/to/node_strength/containers/nodestrength_0.1.0.sif
#   (build: bash node_strength/containers/build.sh; docs: node_strength/containers/README.md)
#
# Usage:
#   bash subject.sh all 014                  # full pipeline (recon-all default)
#   bash subject.sh all 014 --fastsurfer     # use FastSurfer in Step 2
#   bash subject.sh all 014 --fast-fs        # FastSurfer + --fsaparc (adds DK-68)
#   bash subject.sh all 014 --no-recon       # skip Step 2 (set ACT-fast or FS dir)
#   bash subject.sh all 014 --no-connectome  # skip Step 4 (and Step 5 with it)
#   bash subject.sh all 014 --no-inpaint     # force-skip Step 1.1 even if a mask exists
#   bash subject.sh all 014 --no-node-strength  # skip Step 5 only
#   bash subject.sh qsiprep 014              # preprocessing only
#   bash subject.sh inpaint 014              # Step 1.1 only (needs a lesion mask)
#   bash subject.sh recon 014                # Step 2 only (recon-all by default)
#   bash subject.sh recon 014 --fastsurfer   # Step 2 only via FastSurfer
#   bash subject.sh qsirecon 014             # Step 3 only (QSIPrep must exist)
#   bash subject.sh connectome 014           # Step 4 only (needs FS dir + .tck)
#   bash subject.sh nodestrength 014         # Step 5 only (needs an existing connectome)
#   bash subject.sh all 014 --syn            # no BIDS fmap -> --use-syn-sdc error
#   bash subject.sh all 014 --fmap-retry     # ignore measured fmaps, SyN SDC
#   bash subject.sh all 014 --no-sdc         # skip SDC entirely (matches previous no-fieldmap GE runs)
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
# Outputs under RESULTS_ROOT (default: .../dwi_pipeline/dwi_test_TBI):
#   inpainted/   qsiprep_single_run_output/   freesurfer/   qsirecon_single_run_output/   connectomes/   node_strength/
#
# Environment (optional overrides):
#   RESULTS_ROOT, BIDS_DIR, NTHREADS, OMP_NTHREADS, OUTPUT_RES
#   CONTAINER_QSIPREP, CONTAINER_QSIRECON, CONTAINER_CONNECTOME, CONTAINER_FASTSURFER, CONTAINER_FREESURFER, CONTAINER_LIT, CONTAINER_NODESTRENGTH
#   FS_LICENSE, TEMPLATEFLOW_HOME
#   RUN_INPAINT=0|1        Step 1.1 in mode=all/recon (default 1: auto-runs only if a
#                          lesion mask is found; --no-inpaint or 0 forces a skip)
#   INPAINT_REQUIRE_MASK=1 fail instead of silently skipping when no lesion mask is found
#   INPAINT_OUT            inpainted-T1w output dir (default: RESULTS_ROOT/inpainted)
#   INPAINT_DILATE         voxels to dilate the lesion mask before inpainting (default 2)
#   INPAINT_DEVICE         auto (default) | cpu | cuda -- passed to lit-inpainting
#   INPAINT_BATCH_SIZE     slices per GPU batch (default 8; lower for less VRAM)
#   INPAINT_LABELS         lesion-mask label values to inpaint, comma list or "all" (default)
#   INPAINT_BINARIZE=1     collapse selected labels to one value before inpainting (default 0)
#   INPAINT_MIN_OUTSIDE_CORR   QC threshold, correlation outside the lesion (default 0.995)
#   INPAINT_MAX_CORR_DROP  QC threshold, drop vs. resampling-only control (default 0.01)
#   INPAINT_FAIL_ON_QC=1   fail instead of warn when check_inpainting.py reports ok=false
#   INPAINT_SKIP_IF_EXISTS=0  force a rerun even if inpainting.json already exists (default 1: skip)
#   RUN_RECON=0|1          Step 2 in mode=all (default 1)
#   RECON_TOOL             freesurfer (default) or fastsurfer
#   RECON_FSAPARC=1        FastSurfer --fsaparc (adds classic DK-68 aparc/ribbon); same as --fast-fs
#   RECON_OUT              FreeSurfer subjects dir (default: RESULTS_ROOT/freesurfer)
#   FS_SUBJECTS_DIR        same as RECON_OUT unless overridden (used by Steps 3 + 4)
#   RECON_FASTSURFER_DEVICE  cpu (default) or cuda for FastSurfer GPU runs
#   QSIRECON_SPEC          default: mrtrix_singleshell_ss3t_ACT-hsvs (with --no-recon,
#                          set ACT-fast explicitly or provide FS subjects dir)
#   QSIRECON_ATLASES       optional QSIRecon --atlases (Schaefer100, AAL116, ...)
#   RUN_CONNECTOME=0|1     Step 4 in mode=all (default 1 when Step 2 ran)
#   CONNECTOME_PARCELLATION  dkt|dk|auto (default dkt for both recon tools; dk
#                          needs recon-all; auto follows the tree and so mixes
#                          node counts across a cohort)
#   CONNECTOME_LUT_DKT     labelconvert LUT for the DKT parcellation (78 nodes)
#   CONNECTOME_FAIL_ON_EMPTY_NODES=1  fail instead of warn when a node has no streamlines
#   CONNECTOME_DETERMINISTIC=0|1  pin ITK to 1 thread for a reproducible matrix (default 1)
#   CONNECTOME_RESAMPLE_TO_DWI=0|1  resample the segmentation onto the DWI grid (default 1)
#   QSIPREP_USE_SYN_SDC=1  opt-in SyN when no measured fmaps (same as --syn)
#   QSIPREP_FMAP_RETRY=1   --ignore fieldmaps --use-syn-sdc error (same as --fmap-retry)
#   QSIPREP_NO_SDC=1       skip SDC entirely — no fmap, no SyN (same as --no-sdc; matches previous no-fieldmap GE runs)
#   DWI_SHELL_B=1000         b-value for default dwi-select (config/dwi_select_b<SHELL>.json)
#   DWI_SELECT_JSON=         explicit dwi-select config (overrides DWI_SHELL_B path)
#   RECON_SKIP_IF_EXISTS=1  skip recon when aparc+aseg.mgz already exists (default: fail)
#   RECON_SESSION=2WK         override session for recon T1w (default: from dwi-select filter)
#   RUN_NODESTRENGTH=0|1   Step 5 in mode=all/connectome (default 1 when Step 4 ran)
#   RUN_DISCONNECTOME=0|1  Step 4.1 in mode=all/connectome (default 0; pass --disconnection)
#   DISCONNECTOME_CORE_ONLY=0|1
#   DISCONNECTOME_ERODE_VOXELS=N   default 0
#   NODESTRENGTH_OUT       Step 5 output dir (default: RESULTS_ROOT/node_strength; cohort-shared,
#                          not per-subject, since the container itself groups by --include)
#   NODESTRENGTH_STRENGTH_ONLY=1  same as --strength-only (skip volume/ and compare/)
#   NODESTRENGTH_NO_REPORT=1      same as --no-report (skip the PDF + figures/)
#   NODESTRENGTH_SKIP_IF_EXISTS=0  force a rerun even if this subject is already in
#                          manifest.json / has a report.pdf (default 1: skip)
#
# Renamed in this version: Step 4 was called "dk" and its variables were prefixed
# DK_, from a time when it only produced Desikan-Killiany. The step now serves
# both atlases, so it is "connectome" throughout. The old mode name, the --no-dk
# flag and the DK_* variables still work; the variables print a deprecation note.
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

# Step 4 variables were prefixed DK_ before the step was made parcellation-
# neutral. Honour the old names: a job script still setting DK_PARCELLATION=dk
# must not silently get the DKT default it never asked for.
_renamed_var() {
  local old="$1" new="$2"
  [[ -n "${!old:-}" ]] || return 0
  if [[ -z "${!new:-}" ]]; then
    printf -v "${new}" '%s' "${!old}"
    echo "NOTE: ${old} is deprecated, use ${new} (honouring ${new}=${!new})" >&2
  fi
}
_renamed_var CONTAINER_DK_CONNECTOME        CONTAINER_CONNECTOME
_renamed_var RUN_DK_CONNECTOME              RUN_CONNECTOME
_renamed_var DK_PARCELLATION                CONNECTOME_PARCELLATION
_renamed_var DK_LUT_DKT                     CONNECTOME_LUT_DKT
_renamed_var DK_FAIL_ON_EMPTY_NODES         CONNECTOME_FAIL_ON_EMPTY_NODES
_renamed_var DK_DETERMINISTIC               CONNECTOME_DETERMINISTIC
_renamed_var DK_RESAMPLE_TO_DWI             CONNECTOME_RESAMPLE_TO_DWI
_renamed_var DK_LEGACY_DUAL_CONTAINER       CONNECTOME_LEGACY_DUAL_CONTAINER
_renamed_var DK_CONNECTOME_BIND_ENTRYPOINT  CONNECTOME_BIND_ENTRYPOINT

# --- CLI: mode, subject ID, optional flags ---
PIPELINE_MODE="${1:?Need mode: all, qsiprep, inpaint, recon, qsirecon, connectome, disconnectome, or nodestrength}"
# Step 4 used to be called "dk"; keep the old mode name working.
[[ "${PIPELINE_MODE}" == "dk" ]] && PIPELINE_MODE="connectome"
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
      ANAT_MITIGATION="${2:?Need none, neurolit, or vbt after --anat-mitigation}"
      [[ "${ANAT_MITIGATION}" == "none" ]] && RUN_INPAINT=0 || RUN_INPAINT=1
      shift
      ;;
    --node-strength)
      RUN_NODESTRENGTH=1
      ;;
    --no-node-strength)
      RUN_NODESTRENGTH=0
      ;;
    --strength-only)
      NODESTRENGTH_STRENGTH_ONLY=1
      ;;
    --no-report)
      NODESTRENGTH_NO_REPORT=1
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
    --session-filter|--recon-session)
      RECON_SESSION="${2:?Need session after $1}"
      RECON_SESSION="${RECON_SESSION#ses-}"
      shift 2
      continue
      ;;
    --connectome-weighting)
      CONNECTOME_WEIGHTING="${2:?Need count or sift2 after --connectome-weighting}"
      shift 2
      continue
      ;;
    --primary-connectome-measure)
      PRIMARY_CONNECTOME_MEASURE="${2:?Need count or sift2 after --primary-connectome-measure}"
      shift 2
      continue
      ;;
    --act-mode)
      ACT_MODE="${2:?Need standard or lesion-aware after --act-mode}"
      shift 2
      continue
      ;;
    --tractography-model)
      TRACTOGRAPHY_MODEL="${2:?Need ifod2, sd_stream, or both after --tractography-model}"
      shift 2
      continue
      ;;
    --connectome-sift2)
      CONNECTOME_SIFT2=1
      ;;
    --no-disconnectome)
      RUN_DISCONNECTOME=0
      ;;
    --disconnection|--disconnectome)
      RUN_DISCONNECTOME=1
      ;;
    --disconnectome-core-only)
      DISCONNECTOME_CORE_ONLY=1
      ;;
    --disconnectome-erode-voxels)
      DISCONNECTOME_ERODE_VOXELS="${2:?Need N after --disconnectome-erode-voxels}"
      shift 2
      continue
      ;;
    --disconnectome-weighting)
      DISCONNECTOME_WEIGHTING="${2:?Need count or sift2 after --disconnectome-weighting}"
      shift 2
      continue
      ;;
    -h|--help)
      # Print the header from "Usage:" to its closing rule, so the help text
      # cannot drift out of sync with a hardcoded line range.
      awk '/^# Usage:/,/^# ={10,}$/' "$0" | sed 's/^# \{0,1\}//; $d'
      exit 0
      ;;
    *)
      echo "Unknown option: $1 (try --syn, --fmap-retry, --no-sdc, --dwi-shell, --no-dwi-filter, --fastsurfer, --fast-fs, --no-recon, --no-connectome, --inpaint, --no-inpaint, --disconnection, --no-disconnectome, --disconnectome-core-only, --node-strength, --no-node-strength, --strength-only, --no-report)"
      exit 1
      ;;
  esac
  shift
done

# --- Paths: repo root, BIDS input, separate output tree for ACT/connectome ---
REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
RESULTS_ROOT="${RESULTS_ROOT:-/path/to/dwi_pipeline/dwi_test_TBI}"
BIDS_DIR="${BIDS_DIR:-/path/to/dwi_pipeline/dwi_test_TBI/bids}"
NTHREADS="${NTHREADS:-8}"
OMP_NTHREADS="${OMP_NTHREADS:-8}"
OUTPUT_RES="${OUTPUT_RES:-2}"

# --- Apptainer images and FreeSurfer license (required for anat + ACT) ---
CONTAINER_QSIPREP="${CONTAINER_QSIPREP:-/path/to/others/containers/qsiprep.sif}"
CONTAINER_QSIRECON="${CONTAINER_QSIRECON:-/path/to/others/containers/qsirecon.sif}"
CONTAINER_FASTSURFER="${CONTAINER_FASTSURFER:-/path/to/others/containers/fastsurfer_latest.sif}"
# Dedicated full FreeSurfer 7.4.1 image (pulled via
# dwi_pipeline/containers/pull_freesurfer_sif.sbatch). Pipeline fails if missing.
_FS_SIF_DEFAULT="/path/to/others/containers/freesurfer_7.4.1.sif"
if [[ -z "${CONTAINER_FREESURFER:-}" ]]; then
  if [[ -f "${_FS_SIF_DEFAULT}" ]]; then
    CONTAINER_FREESURFER="${_FS_SIF_DEFAULT}"
  else
    _pipeline_fail "FreeSurfer" "dedicated FreeSurfer SIF not found at ${_FS_SIF_DEFAULT}" \
      "Build it: sbatch dwi_pipeline/containers/pull_freesurfer_sif.sbatch" \
      "Or set CONTAINER_FREESURFER to a full FreeSurfer 7.4.1 image path."
  fi
fi
_CONNECTOME_SIF_DEFAULT="/path/to/others/containers/dkt_connectome.sif"
CONTAINER_CONNECTOME="${CONTAINER_CONNECTOME:-${_CONNECTOME_SIF_DEFAULT}}"
# Step 1.1 (deepmi/lit). Only required when a lesion mask is actually found for
# a subject/session; see run_inpaint(). Build: bash dwi_pipeline/containers/lit/build_lit.sh
CONTAINER_LIT="${CONTAINER_LIT:-/path/to/others/containers/lit_0.6.0.sif}"
# Step 5 (nodestrength / dwi-AI). Standalone repo+container, not built from
# dwi_pipeline; see /path/to/node_strength.
CONTAINER_NODESTRENGTH="${CONTAINER_NODESTRENGTH:-/path/to/node_strength/containers/nodestrength_0.1.0.sif}"
TEMPLATEFLOW_HOME="${TEMPLATEFLOW_HOME:-${REPO_ROOT}/templateflow}"
FS_LICENSE="${FS_LICENSE:-/path/to/others/data_mining/freesurfer/license.txt}"
# FreeSurferColorLUT.txt — qsirecon.sif's trimmed FreeSurfer doesn't ship this
# file, but labelconvert needs it in Step 4. Default to the LUT shipped
# with the host-side FS install (next to the license).
FS_LUT="${FS_LUT:-${FS_LICENSE%/*}/FreeSurferColorLUT.txt}"

# --- Inpaint (Step 1.1) defaults ---
# Auto-on: only actually runs when find_lesion_mask() finds a mask for this
# subject/session (see run_inpaint). Most subjects have none, so this is a
# no-op for them and the pipeline behaves exactly as it did before Step 1.1
# existed. --no-inpaint / RUN_INPAINT=0 forces a skip even when a mask exists.
RUN_INPAINT="${RUN_INPAINT:-1}"
ANAT_MITIGATION="${ANAT_MITIGATION:-neurolit}"
if [[ "${RUN_INPAINT}" != "1" ]]; then ANAT_MITIGATION=none; fi
case "${ANAT_MITIGATION}" in
  none) RUN_INPAINT=0 ;;
  neurolit|vbt) RUN_INPAINT=1 ;;
  *) _pipeline_fail "config" \
       "invalid ANAT_MITIGATION=${ANAT_MITIGATION} (use none, neurolit, or vbt)" ;;
esac
INPAINT_REQUIRE_MASK="${INPAINT_REQUIRE_MASK:-0}"
if [[ -z "${INPAINT_OUT:-}" ]]; then
  if [[ "${ANAT_MITIGATION}" == "vbt" ]]; then
    INPAINT_OUT="${RESULTS_ROOT}/vbt"
  else
    INPAINT_OUT="${RESULTS_ROOT}/inpainted"
  fi
fi
INPAINT_DILATE="${INPAINT_DILATE:-2}"
INPAINT_DEVICE="${INPAINT_DEVICE:-auto}"           # auto | cpu | cuda
INPAINT_BATCH_SIZE="${INPAINT_BATCH_SIZE:-8}"
INPAINT_LABELS="${INPAINT_LABELS:-all}"
INPAINT_BINARIZE="${INPAINT_BINARIZE:-0}"
INPAINT_MIN_OUTSIDE_CORR="${INPAINT_MIN_OUTSIDE_CORR:-0.995}"
INPAINT_MAX_CORR_DROP="${INPAINT_MAX_CORR_DROP:-0.01}"
INPAINT_FAIL_ON_QC="${INPAINT_FAIL_ON_QC:-0}"
VBT_SMOOTHING_FACTOR="${VBT_SMOOTHING_FACTOR:-2.0}"
INPAINT_SKIP_IF_EXISTS="${INPAINT_SKIP_IF_EXISTS:-1}"
PREPARE_LESION_MASK="${REPO_ROOT}/dwi_pipeline/scripts/prepare_lesion_mask.py"
CHECK_INPAINTING="${REPO_ROOT}/dwi_pipeline/scripts/check_inpainting.py"
RUN_VBT="${REPO_ROOT}/dwi_pipeline/scripts/run_vbt.py"
# Set by run_inpaint() when it actually ran and produced a result; consumed by
# run_recon() and run_connectome() in place of the raw BIDS T1w. Empty means
# "no inpainting for this subject/session -- behave exactly as before".
INPAINTED_T1W=""
_INPAINT_ATTEMPTED=0

# --- Recon (Step 2) defaults ---
RUN_RECON="${RUN_RECON:-1}"
RECON_TOOL="${RECON_TOOL:-freesurfer}"           # freesurfer | fastsurfer
RECON_FASTSURFER_DEVICE="${RECON_FASTSURFER_DEVICE:-cpu}"
# FastSurfer --fsaparc: also write the classic DK-68 aparc/ribbon alongside its
# native DKT segmentation. Set by --fast-fs (RECON_TOOL=fastsurfer + this=1).
RECON_FSAPARC="${RECON_FSAPARC:-0}"

# --- QSIRecon (Step 3) + connectome (Step 4) defaults ---
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
# fast (small matrix), and complements our anatomical connectome (Step 4).
# Override with a space-separated list, e.g. QSIRECON_ATLASES="4S156Parcels AAL116"
# or "" to opt out (only safe with specs that have no connectivity node — rare).
QSIRECON_ATLASES="${QSIRECON_ATLASES-4S156Parcels}"
RUN_CONNECTOME="${RUN_CONNECTOME:-1}"
# Step 5 (nodestrength): auto-on whenever Step 4 ran. Cheap (~20s CPU, no GPU)
# and atlas-agnostic (auto-detects 78-node DKT vs. 84-node DK from the
# connectome's own shape), so unlike Step 1.1 there is no precondition to gate
# on -- every subject with a connectome gets a report. --no-node-strength /
# RUN_NODESTRENGTH=0 to skip.
RUN_NODESTRENGTH="${RUN_NODESTRENGTH:-1}"
# Step 4.1 (disconnectome) is opt-in via --disconnection; still under validation.
RUN_DISCONNECTOME="${RUN_DISCONNECTOME:-0}"
DISCONNECTOME_CORE_ONLY="${DISCONNECTOME_CORE_ONLY:-0}"
DISCONNECTOME_ERODE_VOXELS="${DISCONNECTOME_ERODE_VOXELS:-0}"
DISCONNECTOME_WEIGHTING="${DISCONNECTOME_WEIGHTING:-${CONNECTOME_WEIGHTING:-count}}"
RUN_DISCONNECTOME_SCRIPT="${REPO_ROOT}/dwi_pipeline/scripts/run_disconnectome.py"
NODESTRENGTH_STRENGTH_ONLY="${NODESTRENGTH_STRENGTH_ONLY:-0}"
NODESTRENGTH_NO_REPORT="${NODESTRENGTH_NO_REPORT:-0}"
NODESTRENGTH_SKIP_IF_EXISTS="${NODESTRENGTH_SKIP_IF_EXISTS:-1}"
# Grey-matter parcellation for the Step 4 connectome: dkt | dk | auto
#   dkt — Desikan-Killiany-Tourville, 78 nodes, fs_dkt.txt. THE DEFAULT, and the
#         only parcellation both recon tools can produce: FastSurfer's
#         aparc+aseg.mgz is already DKT, and a recon-all tree is read via its
#         aparc.DKTatlas+aseg.mgz. Fixing it here means every subject shares one
#         node set whether or not the user passed --fastsurfer, so a cohort can
#         be pooled without caring which tool ran.
#   dk  — Desikan-Killiany, 84 nodes, fs_default.txt over aparc+aseg.mgz.
#         recon-all only; FastSurfer produces no DK atlas, so this leaves 6 empty
#         nodes on a FastSurfer tree.
#   auto— follow the tree instead: dkt for FastSurfer, dk for recon-all. Gives a
#         mix of 78- and 84-node matrices across a cohort, so pick it only when
#         you specifically want DK from recon-all subjects.
# FastSurfer ships aparc+aseg.mgz as the DKT atlas, which by protocol has no
# bankssts and no frontal/temporal pole. Running labelconvert over it with the DK
# LUT yields 6 all-zero rows/columns, so the LUT has to follow the segmentation.
_CONNECTOME_PARCELLATION_EXPLICIT=$([[ -n "${CONNECTOME_PARCELLATION:-}" ]] && echo 1 || echo 0)
CONNECTOME_PARCELLATION="${CONNECTOME_PARCELLATION:-dkt}"
CONNECTOME_LUT_DKT="${CONNECTOME_LUT_DKT:-${REPO_ROOT}/dwi_pipeline/containers/connectome/mrtrix_lut/fs_dkt.txt}"
# Empty nodes normally mean the LUT does not match the segmentation, but they can
# also be genuine in severe pathology (resection, large lesion), so warn by
# default and let callers escalate.
CONNECTOME_FAIL_ON_EMPTY_NODES="${CONNECTOME_FAIL_ON_EMPTY_NODES:-0}"
# ITK sums its registration metric across threads in a nondeterministic order, so
# repeat runs of Step 4b differ by ~1e-10 in the affine. That is usually invisible
# after nearest-neighbour label resampling, but it can flip boundary voxels and
# shift a handful of streamline assignments. Pin ITK to one thread so the
# connectome is reproducible; set 0 to trade reproducibility for speed.
CONNECTOME_DETERMINISTIC="${CONNECTOME_DETERMINISTIC:-1}"
CONNECTOME_WEIGHTING="${CONNECTOME_WEIGHTING:-count}"
PRIMARY_CONNECTOME_MEASURE="${PRIMARY_CONNECTOME_MEASURE:-count}"
CONNECTOME_SIFT2="${CONNECTOME_SIFT2:-0}"
CONNECTOME_BIND_ENTRYPOINT="${CONNECTOME_BIND_ENTRYPOINT:-0}"
CONNECTOME_BIND_DEV="${CONNECTOME_BIND_DEV:-${CONNECTOME_BIND_ENTRYPOINT:-0}}"
VBT_BIND_DEV="${VBT_BIND_DEV:-0}"
DISCONNECTOME_BIND_DEV="${DISCONNECTOME_BIND_DEV:-0}"
ACT_MODE="${ACT_MODE:-standard}"
TRACTOGRAPHY_MODEL="${TRACTOGRAPHY_MODEL:-both}"
RECON_SKIP_IF_EXISTS="${RECON_SKIP_IF_EXISTS:-0}"
QSIPREP_BIDS_FILTER="${QSIPREP_BIDS_FILTER:-}"
DWI_SELECT_JSON="${DWI_SELECT_JSON:-}"
DWI_SHELL_B="${DWI_SHELL_B:-1000}"
QSIPREP_NO_DWI_FILTER="${QSIPREP_NO_DWI_FILTER:-0}"
BUILD_BIDS_FILTER="${REPO_ROOT}/dwi_pipeline/scripts/build_bids_filter.py"
MAKE_DWI_SELECT_CONFIG="${REPO_ROOT}/dwi_pipeline/scripts/make_dwi_select_config.py"

resolve_dwi_select_config() {
  if [[ "${QSIPREP_NO_DWI_FILTER}" == "1" ]]; then
    DWI_SELECT_JSON=""
    return 0
  fi
  [[ -n "${QSIPREP_BIDS_FILTER}" ]] && return 0
  if [[ -z "${DWI_SELECT_JSON}" ]]; then
    DWI_SELECT_JSON="${REPO_ROOT}/dwi_pipeline/config/dwi_select_b${DWI_SHELL_B}.json"
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
CONNECTOME_RESAMPLE_TO_DWI="${CONNECTOME_RESAMPLE_TO_DWI:-1}"

# --- Output layout under RESULTS_ROOT ---
QSIPREP_OUT="${RESULTS_ROOT}/qsiprep_single_run_output"
QSIRECON_OUT="${RESULTS_ROOT}/qsirecon_single_run_output"
RECON_OUT="${RECON_OUT:-${RESULTS_ROOT}/freesurfer}"
FS_SUBJECTS_DIR="${FS_SUBJECTS_DIR:-${RECON_OUT}}"
CONNECTOME_OUT="${RESULTS_ROOT}/connectomes"
NODESTRENGTH_OUT="${NODESTRENGTH_OUT:-${RESULTS_ROOT}/node_strength}"
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
# Recon containers only required when we will actually run Step 2 / Step 4
if [[ "${PIPELINE_MODE}" == "all" && "${RUN_RECON}" == "1" ]] || [[ "${PIPELINE_MODE}" == "recon" ]]; then
  case "${RECON_TOOL}" in
    freesurfer) [[ -f "${CONTAINER_FREESURFER}" ]] || { echo "Missing CONTAINER_FREESURFER: ${CONTAINER_FREESURFER}"; exit 1; } ;;
    fastsurfer) [[ -f "${CONTAINER_FASTSURFER}" ]] || { echo "Missing CONTAINER_FASTSURFER: ${CONTAINER_FASTSURFER}"; exit 1; } ;;
    *) echo "Invalid RECON_TOOL=${RECON_TOOL} (use freesurfer or fastsurfer)"; exit 1 ;;
  esac
fi
if [[ "${PIPELINE_MODE}" == "connectome" ]] || { [[ "${PIPELINE_MODE}" == "all" ]] && [[ "${RUN_CONNECTOME}" == "1" ]]; }; then
  if [[ "${CONNECTOME_LEGACY_DUAL_CONTAINER:-0}" != "1" ]]; then
    [[ -f "${CONTAINER_CONNECTOME}" ]] || {
      echo "Missing CONTAINER_CONNECTOME: ${CONTAINER_CONNECTOME}"
      echo "  Build: bash dwi_pipeline/containers/connectome/build_connectome.sh"
      exit 1
    }
  fi
fi

mkdir -p "${TEMPLATEFLOW_HOME}" "${QSIPREP_OUT}" "${QSIRECON_OUT}" "${RECON_OUT}" "${INPAINT_OUT}" "${INTER_QSP}" "${INTER_QSI}" "${RESULTS_ROOT}/logs"
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
    _out+=(--ignore fieldmaps --use-syn-sdc error)
    echo "QSIPrep: sub-${SUBJECT}: explicit --fmap-retry -> SyN SDC"
    return 0
  fi
  if [[ -n "${filter_file}" ]] && _bids_filter_includes_fmap "${filter_file}"; then
    echo "QSIPrep: sub-${SUBJECT}: dwi-select includes fmap -> measured SDC"
    return 0
  fi
  if [[ "${QSIPREP_USE_SYN_SDC:-0}" == "1" ]]; then
    _out+=(--use-syn-sdc error)
    echo "QSIPrep: sub-${SUBJECT}: explicit --syn -> SyN SDC"
    return 0
  fi
  if [[ "${QSIPREP_NO_SDC:-0}" == "1" ]]; then
    echo "QSIPrep: sub-${SUBJECT}: explicit --no-sdc -> NO SDC (matches previous no-fieldmap GE runs)"
    return 0
  fi
  _pipeline_fail "QSIPrep/SDC" "no distortion correction configured for sub-${SUBJECT}" \
    "Measured SDC requires fmaps in the dwi-select filter (IntendedFor -> target DWI)." \
    "Or pass --syn (QSIPREP_USE_SYN_SDC=1) or --fmap-retry (QSIPREP_FMAP_RETRY=1)." \
    "Or pass --no-sdc (QSIPREP_NO_SDC=1) to explicitly skip SDC (matches previous no-fieldmap GE runs)."
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

# find_lesion_mask — 0 or 1 sibling *_T1w_label-lesion_roi.nii.gz next to the
# session's T1w. Echoes nothing (not an error) when none exists — most
# subjects have no lesion mask, and that's the normal case, not a failure.
# More than one match is a data problem and is treated as one.
find_lesion_mask() {
  local subject="$1" session="$2"
  local anat_dir="${BIDS_DIR}/sub-${subject}/ses-${session}/anat"
  [[ -d "${anat_dir}" ]] || return 0
  local -a matches=()
  mapfile -t matches < <(find "${anat_dir}" -maxdepth 1 -type f \
    -name '*_T1w_label-lesion_roi.nii.gz' 2>/dev/null | LC_ALL=C sort -u)
  ((${#matches[@]})) || return 0
  ((${#matches[@]} == 1)) || _pipeline_fail "inpaint/lesion mask" \
    "expected 0 or 1 lesion mask for sub-${subject} ses-${session}, found ${#matches[@]}" "${matches[@]}"
  echo "${matches[0]}"
}

# -----------------------------------------------------------------------------
# run_inpaint — Step 1.1: neuroLIT fills the lesion on the T1w before Step 2.
#   No-op (not a failure) when no lesion mask exists for this subject/session,
#   unless INPAINT_REQUIRE_MASK=1. Sets INPAINTED_T1W when it actually ran, so
#   run_recon/run_connectome can pick up the result; leaves it empty otherwise
#   so they fall back to the raw BIDS T1w exactly as before Step 1.1 existed.
#   Idempotent per call (only does real work once per subject.sh invocation)
#   and, across invocations, skips when INPAINT_SKIP_IF_EXISTS=1 (default) and
#   a prior inpainting.json + result already exist.
# -----------------------------------------------------------------------------
run_inpaint() {
  ((_INPAINT_ATTEMPTED)) && return 0
  _INPAINT_ATTEMPTED=1

  if [[ "${RUN_INPAINT}" != "1" ]]; then
    echo "Inpaint: skipped (RUN_INPAINT=0 / --no-inpaint)"
    return 0
  fi

  local target_ses
  target_ses="$(_resolve_target_session)" || exit 1

  local t1w
  t1w="$(_strict_find_one "inpaint/T1w" \
    find "${BIDS_DIR}/sub-${SUBJECT}/ses-${target_ses}/anat" -type f \
      \( -name '*_T1w.nii.gz' -o -name '*_T1w.nii' \))"

  local mask
  mask="$(find_lesion_mask "${SUBJECT}" "${target_ses}")"
  if [[ -z "${mask}" ]]; then
    if [[ "${INPAINT_REQUIRE_MASK}" == "1" ]]; then
      _pipeline_fail "inpaint" "INPAINT_REQUIRE_MASK=1 but no lesion mask found for sub-${SUBJECT} ses-${target_ses}" \
        "Expected ${BIDS_DIR}/sub-${SUBJECT}/ses-${target_ses}/anat/*_T1w_label-lesion_roi.nii.gz"
    fi
    echo "Inpaint: no lesion mask for sub-${SUBJECT} ses-${target_ses} — skipping Step 1.1 (Step 2 uses the raw T1w)"
    return 0
  fi
  echo "Inpaint: found lesion mask ${mask}"

  local mitigation_container="${CONTAINER_LIT}"
  if [[ "${ANAT_MITIGATION}" == "neurolit" ]]; then
    [[ -f "${CONTAINER_LIT}" ]] || _pipeline_fail "inpaint" "missing CONTAINER_LIT: ${CONTAINER_LIT}" \
      "Build it: bash dwi_pipeline/containers/lit/build_lit.sh"
  else
    mitigation_container="${CONTAINER_VBT:-${CONTAINER_QSIPREP}}"
    if [[ "${VBT_BIND_DEV}" == "1" ]]; then
      [[ -f "${RUN_VBT}" ]] || _pipeline_fail "inpaint" "missing ${RUN_VBT}"
      [[ -f "${CONTAINER_QSIPREP}" ]] || _pipeline_fail "inpaint" \
        "VBT_BIND_DEV=1 requires QSIPrep container: ${CONTAINER_QSIPREP}"
    else
      [[ -f "${CONTAINER_VBT}" ]] || _pipeline_fail "inpaint" "missing CONTAINER_VBT: ${CONTAINER_VBT}" \
        "Run: bash dwi_pipeline/containers/vbt/build_vbt.sh or ./dkt install"
    fi
  fi
  [[ -f "${PREPARE_LESION_MASK}" ]] || _pipeline_fail "inpaint" "missing ${PREPARE_LESION_MASK}"
  [[ -f "${CHECK_INPAINTING}" ]] || _pipeline_fail "inpaint" "missing ${CHECK_INPAINTING}"

  local outdir="${INPAINT_OUT}/sub-${SUBJECT}/ses-${target_ses}"
  local final_json="${outdir}/inpainting.json"
  local result="${outdir}/inpainting_volumes/inpainting_result.nii.gz"

  if [[ "${INPAINT_SKIP_IF_EXISTS}" == "1" && -f "${final_json}" && -f "${result}" ]]; then
    echo "Inpaint: ${final_json} already exists — skipping (INPAINT_SKIP_IF_EXISTS=1)"
    INPAINTED_T1W="${result}"
    return 0
  fi

  echo "=== Anatomical mitigation (${ANAT_MITIGATION}): sub-${SUBJECT} ses-${target_ses} ==="
  mkdir -p "${outdir}"

  local mask_prepared="${outdir}/lesion_mask_prepared.nii.gz"
  local mask_json="${outdir}/lesion_mask_prepared.json"
  local -a prep_xtra=()
  [[ "${INPAINT_BINARIZE}" == "1" ]] && prep_xtra+=(--binarize)
  python3 "${PREPARE_LESION_MASK}" \
    --t1w "${t1w}" --mask "${mask}" \
    --out "${mask_prepared}" --json "${mask_json}" \
    --labels "${INPAINT_LABELS}" \
    "${prep_xtra[@]}"

  if [[ "${ANAT_MITIGATION}" == "neurolit" ]]; then
    # --nv is a no-op (not a hard failure) on nodes with no visible GPU/driver.
    local -a nv_args=()
    [[ "${INPAINT_DEVICE}" != "cpu" ]] && nv_args+=(--nv)
    apptainer exec "${nv_args[@]}" --cleanenv --containall \
      -B "$(dirname "${t1w}")":/t1w_input:ro \
      -B "${mask_prepared}":/mask/lesion_mask_prepared.nii.gz:ro \
      -B "${outdir}":/out \
      "${CONTAINER_LIT}" \
      lit-inpainting \
        -i "/t1w_input/$(basename "${t1w}")" \
        -m /mask/lesion_mask_prepared.nii.gz \
        -o /out \
        --dilate "${INPAINT_DILATE}" \
        --keepgeom \
        --device "${INPAINT_DEVICE}" \
        --batch_size "${INPAINT_BATCH_SIZE}"
  else
    mkdir -p "$(dirname "${result}")"
    if [[ "${VBT_BIND_DEV}" == "1" ]]; then
      apptainer exec --cleanenv --containall \
        -B "$(dirname "${t1w}")":/t1w_input:ro \
        -B "${mask_prepared}":/mask/lesion_mask_prepared.nii.gz:ro \
        -B "${outdir}":/out \
        -B "${RUN_VBT}":/run_vbt.py:ro \
        "${CONTAINER_QSIPREP}" \
        python3 /run_vbt.py \
          --t1w "/t1w_input/$(basename "${t1w}")" \
          --mask /mask/lesion_mask_prepared.nii.gz \
          --output /out/inpainting_volumes/inpainting_result.nii.gz \
          --smoothing-factor "${VBT_SMOOTHING_FACTOR}" \
          --work-dir /out/.vbt_work
    else
      apptainer exec --cleanenv --containall \
        -B "$(dirname "${t1w}")":/t1w_input:ro \
        -B "${mask_prepared}":/mask/lesion_mask_prepared.nii.gz:ro \
        -B "${outdir}":/out \
        "${CONTAINER_VBT}" \
        --t1w "/t1w_input/$(basename "${t1w}")" \
        --mask /mask/lesion_mask_prepared.nii.gz \
        --output /out/inpainting_volumes/inpainting_result.nii.gz \
        --smoothing-factor "${VBT_SMOOTHING_FACTOR}" \
        --work-dir /out/.vbt_work
    fi
    rm -rf "${outdir}/.vbt_work"
  fi

  [[ -f "${result}" ]] || _pipeline_fail "inpaint" "${ANAT_MITIGATION} finished but ${result} was not produced" \
    "Inspect ${outdir} for tool output."

  local qc_json="${outdir}/inpainting_qc.json"
  python3 "${CHECK_INPAINTING}" \
    --original "${t1w}" --inpainted "${result}" --mask "${mask_prepared}" \
    --json "${qc_json}" \
    --min-outside-corr "${INPAINT_MIN_OUTSIDE_CORR}" \
    --max-corr-drop "${INPAINT_MAX_CORR_DROP}"

  local qc_ok
  qc_ok="$(python3 -c "import json; print(json.load(open('${qc_json}'))['ok'])")"
  if [[ "${qc_ok}" != "True" ]]; then
    echo "WARNING: Inpaint QC failed for sub-${SUBJECT} ses-${target_ses} — see ${qc_json}"
    if [[ "${INPAINT_FAIL_ON_QC}" == "1" ]]; then
      _pipeline_fail "inpaint" "QC failed for sub-${SUBJECT} ses-${target_ses} (INPAINT_FAIL_ON_QC=1)" "See ${qc_json}"
    fi
  fi

  python3 - "${t1w}" "${mask}" "${mask_prepared}" "${result}" "${mask_json}" "${qc_json}" "${final_json}" \
    "sub-${SUBJECT}" "ses-${target_ses}" "${mitigation_container}" "${INPAINT_LABELS}" "${INPAINT_DILATE}" \
    "${INPAINT_DEVICE}" "${INPAINT_BATCH_SIZE}" "${ANAT_MITIGATION}" "${VBT_SMOOTHING_FACTOR}" <<'PY'
import json, sys
(t1w, mask, mask_prepared, result, mask_json, qc_json, final_json,
 subject, session, container, labels, dilate, device, batch_size,
 backend, vbt_smoothing) = sys.argv[1:17]
out = {
    "subject": subject,
    "session": session,
    "backend": backend,
    "tool": "neuroLIT (FastSurfer-LIT)" if backend == "neurolit" else "virtual brain transplant",
    "container": container,
    "input_t1w": t1w,
    "lesion_mask_source": mask,
    "lesion_mask_prepared": mask_prepared,
    "mask_labels": labels,
    "dilate": int(dilate),
    "device": device,
    "batch_size": int(batch_size),
    "vbt_smoothing_factor": float(vbt_smoothing) if backend == "vbt" else None,
    "vbt_smoothing_units": "voxel sigma (LeAPP code default)" if backend == "vbt" else None,
    "keepgeom": True,
    "inpainted_t1w": result,
    "mask_summary": json.load(open(mask_json)),
    "qc": json.load(open(qc_json)),
}
with open(final_json, "w") as fh:
    json.dump(out, fh, indent=2)
    fh.write("\n")
PY

  echo "Inpaint: OK — inpainted T1w: ${result}"
  echo "         Provenance: ${final_json}"
  INPAINTED_T1W="${result}"
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

  run_inpaint

  local t1w
  if [[ -n "${INPAINTED_T1W}" ]]; then
    t1w="${INPAINTED_T1W}"
    echo "Recon: T1w input: ${t1w} (Step 1.1 inpainted — lesion mask was found)"
  else
    t1w="$(_strict_find_one "recon/T1w" \
      find "${BIDS_DIR}/sub-${SUBJECT}/ses-${target_ses}/anat" -type f \
        \( -name '*_T1w.nii.gz' -o -name '*_T1w.nii' \))"
    echo "Recon: T1w input: ${t1w}"
  fi
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

  # Bind each T1w's own parent directory at a neutral mount point rather than
  # assuming it lives under BIDS_DIR — the Step 1.1 inpainted T1w lives under
  # INPAINT_OUT instead, and this way recon-all doesn't care which it got.
  local -a i_args=()
  local -a t1_binds=()
  local idx=0
  for t in "$@"; do
    local mnt="/t1w_input_${idx}"
    t1_binds+=( -B "$(dirname "${t}")":"${mnt}":ro )
    i_args+=( -i "${mnt}/$(basename "${t}")" )
    idx=$((idx + 1))
  done
  # We bind the license at a neutral path and let FreeSurfer pick it up via the
  # FS_LICENSE env var (modern FS honours this over $FREESURFER_HOME/license.txt).
  # That way we don't have to know the image's FREESURFER_HOME ahead of time.
  apptainer exec --cleanenv --containall \
    "${t1_binds[@]}" \
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
  apptainer exec --cleanenv "${CONTAINER_FASTSURFER}" bash -lc 'test -x /fastsurfer/run_fastsurfer.sh' || {
    echo "Recon: /fastsurfer/run_fastsurfer.sh not found in CONTAINER_FASTSURFER=${CONTAINER_FASTSURFER}"
    exit 1
  }
  # --nv is a no-op (not a hard failure) on nodes with no visible GPU/driver.
  local -a nv_args=()
  [[ "${RECON_FASTSURFER_DEVICE}" != "cpu" ]] && nv_args+=(--nv)
  # --fsaparc: also write the classic DK-68 aparc/ribbon (set by --fast-fs).
  local -a fsaparc_args=()
  [[ "${RECON_FSAPARC}" == "1" ]] && fsaparc_args+=(--fsaparc)
  apptainer exec "${nv_args[@]}" --cleanenv --containall \
    -B "$(dirname "${t1}")":/t1w_input:ro \
    -B "${RECON_OUT}":/sd \
    -B "${FS_LICENSE}":/fs_license/license.txt:ro \
    "${CONTAINER_FASTSURFER}" \
    /fastsurfer/run_fastsurfer.sh \
      --fs_license /fs_license/license.txt \
      --sid "sub-${SUBJECT}" \
      --sd /sd \
      --t1 "/t1w_input/$(basename "${t1}")" \
      --parallel \
      --threads "${NTHREADS}" \
      --device "${RECON_FASTSURFER_DEVICE}" \
      "${fsaparc_args[@]}"
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

# QSIPrep DWI-space derivative under ses-*/dwi/ (or subject dwi/).
# Prefers space-T1w; falls back to space-ACPC (QSIPrep 1.0 ACPC-first layouts).
find_qsiprep_dwi_space_artifact() {
  local label="$1" qsiprep_out="$2" subject="$3" session="$4" suffix="$5"
  local -a t1w=() acpc=()
  mapfile -t t1w < <(
    find -L "${qsiprep_out}" -type f -path "*sub-${subject}*" \( \
      -path "*/ses-${session}/dwi/*space-T1w_${suffix}" -o \
      -path "*/dwi/*space-T1w_${suffix}" \
    \) 2>/dev/null | LC_ALL=C sort -u
  )
  mapfile -t acpc < <(
    find -L "${qsiprep_out}" -type f -path "*sub-${subject}*" \( \
      -path "*/ses-${session}/dwi/*space-ACPC_${suffix}" -o \
      -path "*/dwi/*space-ACPC_${suffix}" \
    \) 2>/dev/null | LC_ALL=C sort -u
  )
  if ((${#t1w[@]} == 1)); then
    echo "${t1w[0]}"
    return 0
  fi
  if ((${#acpc[@]} == 1)); then
    echo "${acpc[0]}"
    return 0
  fi
  if ((${#t1w[@]} == 0 && ${#acpc[@]} == 0)); then
    _pipeline_fail "${label}" \
      "no file found for sub-${subject} (tried space-T1w and space-ACPC *_${suffix})"
  fi
  _pipeline_fail "${label}" \
    "expected exactly 1 match (space-T1w: ${#t1w[@]}, space-ACPC: ${#acpc[@]})" \
    "${t1w[@]}" "${acpc[@]}"
}

find_qsiprep_dwiref() {
  find_qsiprep_dwi_space_artifact "$1" "$2" "$3" "$4" "dwiref.nii.gz"
}

find_qsiprep_preproc_dwi() {
  find_qsiprep_dwi_space_artifact "$1" "$2" "$3" "$4" "desc-preproc_dwi.nii.gz"
}

find_qsiprep_brain_mask() {
  find_qsiprep_dwi_space_artifact "$1" "$2" "$3" "$4" "desc-brain_mask.nii.gz"
}

# QSIPrep desc-preproc T1w: exactly one file under session anat/ or subject anat/.
find_qsiprep_preproc_t1w() {
  local qsiprep_out="$1" subject="$2" session="$3"
  _strict_find_one "connectome/QSIPrep desc-preproc T1w" \
    find "${qsiprep_out}/sub-${subject}" \( \
      -path "*/ses-${session}/anat/*sub-${subject}_desc-preproc_T1w.nii.gz" -o \
      -path "*/anat/*sub-${subject}_desc-preproc_T1w.nii.gz" \
    \) -type f
}

# BIDS T1w for the target session (exactly one match required).
find_bids_t1w() {
  local subject="$1" session="$2"
  [[ -n "${session}" ]] || _pipeline_fail "connectome/BIDS T1w" "session is required"
  _strict_find_one "connectome/BIDS T1w" \
    find "${BIDS_DIR}/sub-${subject}/ses-${session}/anat" -type f \
      \( -name '*_T1w.nii.gz' -o -name '*_T1w.nii' \)
}

# T1w to use as the Step 4b-1 affine-registration source. Step 2's recon-all/
# FastSurfer read whichever T1w run_inpaint() (in this invocation, or a prior
# one) actually produced a subjects dir from; if that was the Step 1.1
# inpainted T1w, register *that* to QSIPrep's T1w rather than the still-
# lesioned raw BIDS one, since --keepgeom means their geometry is identical
# but only the inpainted one is intensity-consistent with what recon-all saw.
# Falls back to the raw BIDS T1w whenever no inpainting result exists yet
# (the common case, and the pre-Step-1.1 behaviour of this pipeline).
_resolve_registration_t1w() {
  local subject="$1" session="$2"
  if [[ -n "${INPAINTED_T1W}" ]]; then
    echo "${INPAINTED_T1W}"
    return 0
  fi
  local cached="${INPAINT_OUT}/sub-${subject}/ses-${session}/inpainting_volumes/inpainting_result.nii.gz"
  if [[ "${RUN_INPAINT}" == "1" && -f "${cached}" ]]; then
    echo "Connectome: reusing cached Step 1.1 result from a prior run: ${cached}" >&2
    echo "${cached}"
    return 0
  fi
  find_bids_t1w "${subject}" "${session}"
}

# -----------------------------------------------------------------------------
# _run_connectome_dual_container — Legacy Step 4 (freesurfer.sif + qsirecon.sif)
# -----------------------------------------------------------------------------
_run_connectome_dual_container() {
  local fs_dir="$1" aparc="$2" rawavg="$3" outdir="$4"
  local tracks="$5" tracks_in_container="$6"
  local dwiref_in_container="$7" preproc_t1w_in_container="$8" bids_t1w_in_container="$9"
  local warp_labels="${10}" space_note="${11}"
  local nodes_input_in_container="/out/aparc+aseg_in_dwi.nii.gz"

  echo "Using tractogram: ${tracks}"
  echo "Using aparc+aseg: ${aparc}"
  echo "Space handling: ${space_note}"

  if [[ "${warp_labels}" == "1" ]]; then
    apptainer exec --cleanenv "${CONTAINER_FREESURFER}" bash -lc "command -v mri_label2vol" >/dev/null 2>&1 || {
      echo "Missing mri_label2vol in CONTAINER_FREESURFER (${CONTAINER_FREESURFER})"
      exit 1
    }
    echo "[connectome] Warping aparc+aseg from FS conformed -> native (mri_label2vol / rawavg.mgz)"
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
  [[ "${warp_labels}" == "1" ]] && binds+=(
    -B "${QSIPREP_OUT}":/qsiprep:ro
    -B "${BIDS_DIR}":/bids:ro
    "${_CONNECTOME_T1W_OVERRIDE_BINDS[@]}"
  )

  apptainer exec --cleanenv --containall \
    "${binds[@]}" \
    "${CONTAINER_QSIRECON}" \
    bash -lc "
      set -euo pipefail
      export FS_LICENSE=/opt/freesurfer/license.txt

      mri_convert /fs_subject/mri/aparc+aseg.mgz /out/aparc+aseg.nii.gz

      if [[ '${warp_labels}' == '1' ]]; then
        mri_convert /out/aparc+aseg_in_rawavg.mgz /out/aparc+aseg_in_rawavg.nii.gz
        echo '[connectome] Step 4b-1: affine register BIDS T1w -> QSIPrep desc-preproc_T1w'
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
        echo '[connectome] Step 4b-2: warp native labels -> QSIPrep T1w (GenericLabel)'
        antsApplyTransforms -d 3 \
          -i /out/aparc+aseg_in_rawavg.nii.gz \
          -r '${preproc_t1w_in_container}' \
          -t /out/native_to_preproc_T1w_0GenericAffine.mat \
          -n GenericLabel \
          -o /out/aparc+aseg_in_t1w.nii.gz
        echo '[connectome] Step 4b-3: QSIPrep T1w -> dwiref grid (GenericLabel resample)'
        antsApplyTransforms -d 3 \
          -i /out/aparc+aseg_in_t1w.nii.gz \
          -r '${dwiref_in_container}' \
          -n GenericLabel \
          -o /out/aparc+aseg_in_dwi.nii.gz
      fi

      fs_lut=/opt/freesurfer/FreeSurferColorLUT.txt
      mrtrix_lut=/opt/mrtrix3-latest/share/mrtrix3/labelconvert/fs_default.txt

      labelconvert -force '${nodes_input_in_container}' \"\$fs_lut\" \"\$mrtrix_lut\" /out/nodes.mif

      tck_in='${tracks_in_container}'
      tck_use=\"\$tck_in\"
      tck_staged=\"\"
      if [[ \"\$tck_in\" == *.tck.gz ]]; then
        tck_staged=/out/streamlines.tck
        echo \"[connectome] Decompressing \$tck_in -> \$tck_staged\"
        gunzip -c \"\$tck_in\" > \"\$tck_staged\"
        tck_use=\"\$tck_staged\"
      fi

      echo '[connectome] === space-alignment diagnostic ==='
      mrinfo /out/nodes.mif      | tee /out/nodes.mrinfo.txt   | sed -n '1,20p'
      tckinfo \"\$tck_use\"         | tee /out/tracks.tckinfo.txt    | sed -n '1,30p'
      echo '[connectome] =================================='

      tck2connectome -force \
        \"\$tck_use\" \
        /out/nodes.mif \
        /out/connectome.csv \
        -symmetric \
        -zero_diagonal \
        -out_assignments /out/assignments.csv

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

  [[ -f "${CONTAINER_CONNECTOME}" ]] || return 1
  scratch="$(mktemp -d "${scratch_parent}/.dkprobe_XXXXXX" 2>/dev/null)" || return 1

  max="$(apptainer exec --cleanenv --containall \
      --env "LD_LIBRARY_PATH=/opt/ants/lib:/opt/mrtrix3-latest/lib" \
      -B "${fs_dir}/mri":/probe:ro \
      -B "${scratch}":/scratch \
      "${CONTAINER_CONNECTOME}" bash -c '
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
# Sets _CONNECTOME_DETECT_METHOD to describe which signal decided.
# -----------------------------------------------------------------------------
_fs_tree_is_dkt() {
  local fs_dir="$1" scratch_parent="$2"
  local probe

  if probe="$(_fs_aparc_has_dk_only_labels "${fs_dir}" "${scratch_parent}")"; then
    _CONNECTOME_DETECT_METHOD="aparc+aseg.mgz label content"
    [[ "${probe}" == "0" ]]
    return
  fi

  _CONNECTOME_DETECT_METHOD="file layout (label probe unavailable)"
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
# run_connectome — Build the structural connectome from the QSIRecon tractogram
# -----------------------------------------------------------------------------
run_connectome() {
  echo "=== Connectome: sub-${SUBJECT} ==="
  if [[ "${ACT_MODE}" == "lesion-aware" ]]; then
    _pipeline_fail "lesion-aware-act" \
      "ACT_MODE=lesion-aware is implemented in the Snakemake engine only" \
      "Run with PIPELINE_ENGINE=snakemake (the default)."
  fi
  if [[ "${TRACTOGRAPHY_MODEL}" != "ifod2" ]]; then
    _pipeline_fail "sd-stream" \
      "TRACTOGRAPHY_MODEL=${TRACTOGRAPHY_MODEL} is implemented in the Snakemake engine only" \
      "Run with PIPELINE_ENGINE=snakemake (the default)."
  fi

  local fs_dir="${FS_SUBJECTS_DIR}/sub-${SUBJECT}"
  local aparc="${fs_dir}/mri/aparc+aseg.mgz"
  local rawavg="${fs_dir}/mri/rawavg.mgz"
  local outdir="${CONNECTOME_OUT}/sub-${SUBJECT}"
  local tracks
  local tracks_rel
  local tracks_in_container
  local dwiref="" dwiref_rel="" dwiref_in_container=""
  local preproc_t1w="" preproc_t1w_rel="" preproc_t1w_in_container=""
  local bids_t1w="" bids_t1w_rel="" bids_t1w_in_container=""
  local warp_labels=0
  local space_note=""

  mkdir -p "${outdir}"

  [[ "${CONNECTOME_RESAMPLE_TO_DWI}" == "1" ]] || \
    _pipeline_fail "connectome" "CONNECTOME_RESAMPLE_TO_DWI must be 1 (strict pipeline — no FS-conformed fallback)"

  [[ -d "${fs_dir}" ]] || _pipeline_fail "connectome" "missing FreeSurfer subject dir: ${fs_dir}"
  [[ -f "${aparc}" ]] || _pipeline_fail "connectome" "missing aparc+aseg.mgz: ${aparc}" \
    "Set FS_SUBJECTS_DIR to a tree containing sub-${SUBJECT}/mri/aparc+aseg.mgz."
  [[ -f "${rawavg}" ]] || _pipeline_fail "connectome" "missing rawavg.mgz: ${rawavg}" \
    "Rerun Step 2 (recon) or check FS_SUBJECTS_DIR."

  # Read what Step 2 actually produced rather than trusting RECON_TOOL, so that
  # `subject.sh dk` on an existing tree is correct regardless of which flags this
  # invocation was given.
  local parc="${CONNECTOME_PARCELLATION}"
  local parc_source=""
  local tree_is_dkt=0
  _CONNECTOME_DETECT_METHOD=""
  if _fs_tree_is_dkt "${fs_dir}" "${outdir}"; then tree_is_dkt=1; fi

  case "${parc}" in
    auto)
      if [[ "${tree_is_dkt}" == "1" ]]; then parc="dkt"; else parc="dk"; fi
      parc_source="auto-detected from ${_CONNECTOME_DETECT_METHOD}"
      echo "Parcellation: ${parc} (auto-detected from ${_CONNECTOME_DETECT_METHOD})"
      ;;
    dk|dkt)
      if [[ "${_CONNECTOME_PARCELLATION_EXPLICIT}" == "1" ]]; then
        parc_source="CONNECTOME_PARCELLATION=${parc}"
        echo "Parcellation: ${parc} (set via CONNECTOME_PARCELLATION)"
      else
        parc_source="pipeline default (${parc}, same for both recon tools)"
        echo "Parcellation: ${parc} (pipeline default — same for recon-all and FastSurfer)"
      fi
      ;;
    *)
      _pipeline_fail "connectome" "invalid CONNECTOME_PARCELLATION=${parc} (use auto, dk, or dkt)"
      ;;
  esac

  # DKT is available from either recon tool, but only by reading the right image.
  # recon-all writes both atlases, so a DKT request there must use
  # aparc.DKTatlas+aseg.mgz: applying the DKT LUT to the DK image would silently
  # *drop* bankssts and the poles rather than reassign their territory to
  # neighbours the way DKT does (12,112 cortical voxels on a test subject).
  # FastSurfer's aparc+aseg.mgz is already DKT, so it needs no substitution.
  # Whatever is chosen here is passed to the container as --segmentation; the
  # container defaults to aparc+aseg.mgz and cannot infer the choice on its own.
  if [[ "${parc}" == "dkt" && "${tree_is_dkt}" != "1" ]]; then
    aparc="${fs_dir}/mri/aparc.DKTatlas+aseg.mgz"
    [[ -f "${aparc}" ]] || _pipeline_fail "connectome" \
      "DKT requested but this recon-all tree has no DKT segmentation: ${aparc}" \
      "recon-all normally writes it; rerun Step 2, or use CONNECTOME_PARCELLATION=dk."
    echo "Using the recon-all DKT segmentation: ${aparc}"
  fi

  # FastSurfer never produces a DK atlas (no lh.aparc.annot), so DK there can only
  # mean the DK LUT over DKT labels, which leaves the 6 DK-only nodes empty.
  if [[ "${parc}" == "dk" && "${tree_is_dkt}" == "1" ]]; then
    echo "WARNING: CONNECTOME_PARCELLATION=dk on a FastSurfer tree, which has no DK atlas —" \
         "expect 6 empty nodes (bankssts, frontal pole, temporal pole, bilaterally)."
  fi

  tracks="$(_strict_find_one "connectome/tractogram" \
    find "${QSIRECON_OUT}" -type f -path "*sub-${SUBJECT}*" \
      \( -name '*.tck' -o -name '*.tck.gz' \))"
  tracks_rel="${tracks#${QSIRECON_OUT}/}"
  tracks_in_container="/qsirecon/${tracks_rel}"

  local ses=""
  ses="$(_bids_ses_from_path "${tracks}")"
  [[ -n "${ses}" ]] || _pipeline_fail "connectome/session" "tractogram path has no ses-* entity: ${tracks}"

  dwiref="$(find_qsiprep_dwiref "connectome/dwiref" "${QSIPREP_OUT}" "${SUBJECT}" "${ses}")"
  local preproc_dwi bval bvec brain_mask
  preproc_dwi="$(find_qsiprep_preproc_dwi "connectome/preproc_dwi" "${QSIPREP_OUT}" "${SUBJECT}" "${ses}")"
  bval="${preproc_dwi%.nii.gz}.bval"
  bvec="${preproc_dwi%.nii.gz}.bvec"
  [[ -f "${bval}" ]] || _pipeline_fail "connectome/tensor" "missing b-values: ${bval}"
  [[ -f "${bvec}" ]] || _pipeline_fail "connectome/tensor" "missing b-vectors: ${bvec}"
  brain_mask="$(find_qsiprep_brain_mask "connectome/brain_mask" "${QSIPREP_OUT}" "${SUBJECT}" "${ses}")"
  preproc_t1w="$(find_qsiprep_preproc_t1w "${QSIPREP_OUT}" "${SUBJECT}" "${ses}")"
  bids_t1w="$(_resolve_registration_t1w "${SUBJECT}" "${ses}")"

  dwiref_rel="${dwiref#${QSIPREP_OUT}/}"
  preproc_t1w_rel="${preproc_t1w#${QSIPREP_OUT}/}"
  local preproc_dwi_rel="${preproc_dwi#${QSIPREP_OUT}/}"
  local bval_rel="${bval#${QSIPREP_OUT}/}"
  local bvec_rel="${bvec#${QSIPREP_OUT}/}"
  local brain_mask_rel="${brain_mask#${QSIPREP_OUT}/}"
  dwiref_in_container="/qsiprep/${dwiref_rel}"
  preproc_t1w_in_container="/qsiprep/${preproc_t1w_rel}"
  local preproc_dwi_in_container="/qsiprep/${preproc_dwi_rel}"
  local bval_in_container="/qsiprep/${bval_rel}"
  local bvec_in_container="/qsiprep/${bvec_rel}"
  local brain_mask_in_container="/qsiprep/${brain_mask_rel}"

  # bids_t1w is usually under BIDS_DIR (already bound at /bids below), but
  # when Step 1.1 ran it's the inpainted T1w under INPAINT_OUT instead — bind
  # its own parent directory rather than assuming BIDS_DIR covers it.
  local -a _CONNECTOME_T1W_OVERRIDE_BINDS=()
  if [[ "${bids_t1w}" == "${BIDS_DIR}"/* ]]; then
    bids_t1w_rel="${bids_t1w#${BIDS_DIR}/}"
    bids_t1w_in_container="/bids/${bids_t1w_rel}"
  else
    _CONNECTOME_T1W_OVERRIDE_BINDS=( -B "$(dirname "${bids_t1w}")":/bids_t1w_override:ro )
    bids_t1w_in_container="/bids_t1w_override/$(basename "${bids_t1w}")"
  fi
  warp_labels=1
  space_note="FS conformed -> native (mri_label2vol/rawavg) -> QSIPrep T1w (affine BIDS T1w->desc-preproc_T1w) -> dwiref"

  echo "Using tractogram: ${tracks}"
  echo "Using aparc+aseg: ${aparc}"
  [[ -n "${dwiref}" ]] && echo "Using DWI reference: ${dwiref}"
  [[ -n "${preproc_t1w}" ]] && echo "Using QSIPrep T1w reference: ${preproc_t1w}"
  echo "Using preprocessed DWI: ${preproc_dwi}"
  echo "Using DWI brain mask: ${brain_mask}"
  [[ -n "${bids_t1w}"     ]] && echo "Using BIDS T1w (affine reg source): ${bids_t1w}"
  echo "Space handling: ${space_note}"
  echo "Connectome weighting: ${CONNECTOME_WEIGHTING}"
  case "${PRIMARY_CONNECTOME_MEASURE}" in
    count|sift2) ;;
    *) _pipeline_fail "connectome" \
         "invalid PRIMARY_CONNECTOME_MEASURE=${PRIMARY_CONNECTOME_MEASURE} (use count or sift2)" ;;
  esac
  if [[ "${PRIMARY_CONNECTOME_MEASURE}" == "sift2" && "${CONNECTOME_SIFT2}" != "1" ]]; then
    _pipeline_fail "connectome" \
      "PRIMARY_CONNECTOME_MEASURE=sift2 requires CONNECTOME_SIFT2=1 or --connectome-sift2"
  fi

  local sift2_weights="" sift2_args=()
  if [[ "${CONNECTOME_WEIGHTING}" != "count" && "${CONNECTOME_WEIGHTING}" != "sift2" ]]; then
    _pipeline_fail "connectome" "invalid CONNECTOME_WEIGHTING=${CONNECTOME_WEIGHTING} (use count or sift2)"
  fi
  if [[ "${CONNECTOME_SIFT2}" == "1" ]]; then
    sift2_weights="$(_strict_find_one "connectome/sift2_weights" \
      find "${QSIRECON_OUT}" -type f -path "*sub-${SUBJECT}*" \
        -name '*model-sift2_streamlineweights.csv')"
    local w_rel="${sift2_weights#${QSIRECON_OUT}/}"
    sift2_args=(--sift2-weights "/qsirecon/${w_rel}")
    echo "Using SIFT2 weights: ${sift2_weights}"
  fi

  if [[ "${CONNECTOME_LEGACY_DUAL_CONTAINER:-0}" == "1" ]]; then
    echo "[connectome] Using legacy dual-container path (CONNECTOME_LEGACY_DUAL_CONTAINER=1)"
    [[ "${parc}" == "dk" ]] || _pipeline_fail "connectome" \
      "the legacy dual-container path only supports the DK LUT, but this subject needs ${parc}" \
      "Drop CONNECTOME_LEGACY_DUAL_CONTAINER, or set CONNECTOME_PARCELLATION=dk to accept 6 empty nodes."
    _run_connectome_dual_container \
      "${fs_dir}" "${aparc}" "${rawavg}" "${outdir}" \
      "${tracks}" "${tracks_in_container}" \
      "${dwiref_in_container}" "${preproc_t1w_in_container}" "${bids_t1w_in_container}" \
      "${warp_labels}" "${space_note}"
  else
    [[ -f "${CONTAINER_CONNECTOME}" ]] || \
      _pipeline_fail "connectome" "missing CONTAINER_CONNECTOME: ${CONTAINER_CONNECTOME}" \
        "Build: bash dwi_pipeline/containers/connectome/build_connectome.sh"

    local -a binds=()
    if [[ "${CONNECTOME_BIND_DEV:-0}" == "1" ]]; then
      binds+=(-B "${REPO_ROOT}/dwi_pipeline/containers/connectome/run_connectome.sh":/usr/local/bin/run_connectome:ro)
    fi

    # The image only ships fs_default.txt, so a DKT run binds its LUT in.
    local -a lut_args=()
    if [[ "${parc}" == "dkt" ]]; then
      if [[ "${CONNECTOME_BIND_DEV:-0}" == "1" ]]; then
        [[ -f "${CONNECTOME_LUT_DKT}" ]] || _pipeline_fail "connectome" "missing DKT LUT: ${CONNECTOME_LUT_DKT}" \
          "Generate it: python3 dwi_pipeline/scripts/make_dkt_lut.py"
        binds+=(-B "${CONNECTOME_LUT_DKT}":/lut/fs_dkt.txt:ro)
        lut_args+=(--mrtrix-lut /lut/fs_dkt.txt)
        echo "Using DKT LUT: ${CONNECTOME_LUT_DKT}"
      else
        lut_args+=(--mrtrix-lut /opt/dkt/lut/fs_dkt.txt)
        echo "Using baked DKT LUT: /opt/dkt/lut/fs_dkt.txt"
      fi
    fi

    local -a env_args=()
    if [[ "${CONNECTOME_DETERMINISTIC}" == "1" ]]; then
      env_args+=(--env "ITK_GLOBAL_DEFAULT_NUMBER_OF_THREADS=1" --env "ANTS_RANDOM_SEED=1")
      echo "Deterministic mode: ITK pinned to 1 thread (CONNECTOME_DETERMINISTIC=1)"
    fi

    apptainer run --cleanenv --containall \
      --home /tmp \
      --env "LD_LIBRARY_PATH=/opt/ants/lib:/opt/mrtrix3-latest/lib" \
      "${env_args[@]}" \
      "${binds[@]}" \
      "${_CONNECTOME_T1W_OVERRIDE_BINDS[@]}" \
      -B "${FS_SUBJECTS_DIR}":/subjects:ro \
      -B "${QSIRECON_OUT}":/qsirecon:ro \
      -B "${QSIPREP_OUT}":/qsiprep:ro \
      -B "${BIDS_DIR}":/bids:ro \
      -B "${outdir}":/out \
      -B "${FS_LICENSE}":/opt/freesurfer/license.txt:ro \
      "${CONTAINER_CONNECTOME}" \
      --freesurfer-subject "/subjects/sub-${SUBJECT}" \
      --segmentation "${aparc##*/}" \
      --tractogram "${tracks_in_container}" \
      --dwiref "${dwiref_in_container}" \
      --preproc-t1w "${preproc_t1w_in_container}" \
      --bids-t1w "${bids_t1w_in_container}" \
      --preproc-dwi "${preproc_dwi_in_container}" \
      --bval "${bval_in_container}" \
      --bvec "${bvec_in_container}" \
      --brain-mask "${brain_mask_in_container}" \
      --output-dir /out \
      --fs-license /opt/freesurfer/license.txt \
      --primary-measure "${PRIMARY_CONNECTOME_MEASURE}" \
      "${sift2_args[@]}" \
      "${lut_args[@]}" \
      --subject-id "sub-${SUBJECT}"
  fi

  # Matrix size depends on the LUT (84 for DK, 78 for DKT), so record which one
  # produced this connectome next to it.
  local lut_used="fs_default.txt"
  local atlas="Desikan-Killiany"
  local node_count=84
  if [[ "${parc}" == "dkt" ]]; then
    lut_used="fs_dkt.txt"
    atlas="Desikan-Killiany-Tourville"
    node_count=78
  fi

  # The container writes a parcellation-neutral connectome.csv. Name the final
  # matrix after the parcellation so an 84-node DK and a 78-node DKT result can
  # never be mistaken for each other, and clear any matrix left behind by the
  # other parcellation so a stale file of the wrong dimension cannot be picked up.
  local matrix="${outdir}/${parc}_connectome.csv"
  local count_matrix="${outdir}/${parc}_connectome_count.csv"
  local sift2_matrix="${outdir}/${parc}_connectome_sift2.csv"
  local meanlength_matrix="${outdir}/${parc}_connectome_meanlength.csv"
  local meanfa_matrix="${outdir}/${parc}_connectome_meanfa.csv"
  local meanmd_matrix="${outdir}/${parc}_connectome_meanmd.csv"
  local fa_map="${outdir}/${parc}_desc-FA_dwi.nii.gz"
  local md_map="${outdir}/${parc}_desc-MD_dwi.nii.gz"
  local count_json sift2_json meanlength_json meanfa_json meanmd_json fa_json md_json
  mv -f "${outdir}/connectome.csv" "${matrix}"
  if [[ "${CONNECTOME_LEGACY_DUAL_CONTAINER:-0}" != "1" ]]; then
    mv -f "${outdir}/connectome_count.csv" "${count_matrix}"
    if [[ "${CONNECTOME_SIFT2}" == "1" ]]; then
      mv -f "${outdir}/connectome_sift2.csv" "${sift2_matrix}"
      sift2_json="\"${sift2_matrix##*/}\""
    else
      rm -f "${outdir}/connectome_sift2.csv"
      sift2_json="null"
    fi
    mv -f "${outdir}/connectome_meanlength.csv" "${meanlength_matrix}"
    mv -f "${outdir}/connectome_meanfa.csv" "${meanfa_matrix}"
    mv -f "${outdir}/connectome_meanmd.csv" "${meanmd_matrix}"
    mv -f "${outdir}/desc-FA_dwi.nii.gz" "${fa_map}"
    mv -f "${outdir}/desc-MD_dwi.nii.gz" "${md_map}"
    count_json="\"${count_matrix##*/}\""
    meanlength_json="\"${meanlength_matrix##*/}\""
    meanfa_json="\"${meanfa_matrix##*/}\""
    meanmd_json="\"${meanmd_matrix##*/}\""
    fa_json="\"${fa_map##*/}\""
    md_json="\"${md_map##*/}\""
  else
    count_matrix="${matrix}"
    count_json="\"${matrix##*/}\""
    sift2_json="null"
    meanlength_json="null"
    meanfa_json="null"
    meanmd_json="null"
    fa_json="null"
    md_json="null"
  fi
  local other
  for other in dk dkt; do
    if [[ "${other}" != "${parc}" ]]; then
      rm -f "${outdir}/${other}_connectome"*.csv
      rm -f "${outdir}/${other}_desc-FA_dwi.nii.gz" \
            "${outdir}/${other}_desc-MD_dwi.nii.gz"
    fi
  done
  # Briefly-lived earlier naming, removed so it cannot be mistaken for output.
  rm -f "${outdir}/DKT_connectome.csv"

  # A node with no streamlines almost always means the LUT does not match the
  # segmentation, which is exactly the failure this parcellation logic exists to
  # prevent, so surface it rather than let it reach group analysis unnoticed.
  local empty_nodes
  empty_nodes="$(_count_empty_nodes "${count_matrix}")"
  if [[ "${empty_nodes}" -gt 0 ]]; then
    echo "WARNING: ${empty_nodes} of ${node_count} ${atlas} nodes received no streamlines."
    echo "         Usually a LUT/segmentation mismatch; can be genuine after resection"
    echo "         or a large lesion. Check ${outdir}/parcellation.json."
    if [[ "${CONNECTOME_FAIL_ON_EMPTY_NODES}" == "1" ]]; then
      _pipeline_fail "connectome" "${empty_nodes} empty nodes in ${matrix} (CONNECTOME_FAIL_ON_EMPTY_NODES=1)"
    fi
  fi

  cat > "${outdir}/parcellation.json" <<EOF
{
  "parcellation": "${parc}",
  "atlas": "${atlas}",
  "nodes": ${node_count},
  "labelconvert_lut": "${lut_used}",
  "primary_measure": "${PRIMARY_CONNECTOME_MEASURE}",
  "connectome_csv": "${matrix##*/}",
  "matrices": {
    "count": ${count_json},
    "sift2": ${sift2_json},
    "meanlength": ${meanlength_json},
    "meanfa": ${meanfa_json},
    "meanmd": ${meanmd_json}
  },
  "tensor_maps": {
    "fa": ${fa_json},
    "md": ${md_json}
  },
  "empty_nodes": ${empty_nodes},
  "deterministic": ${CONNECTOME_DETERMINISTIC},
  "selected_by": "${parc_source}",
  "freesurfer_subject_dir": "${fs_dir}",
  "aparc_aseg": "${aparc}"
}
EOF

  echo "Primary connectome: ${matrix} (${PRIMARY_CONNECTOME_MEASURE})"
  echo "Count: ${count_matrix}"
  if [[ "${CONNECTOME_LEGACY_DUAL_CONTAINER:-0}" != "1" ]]; then
    [[ "${CONNECTOME_SIFT2}" == "1" ]] && echo "SIFT2: ${sift2_matrix}"
    echo "MeanLength: ${meanlength_matrix}"
    echo "MeanFA: ${meanfa_matrix}"
    echo "MeanMD: ${meanmd_matrix}"
    echo "FA map: ${fa_map}"
    echo "MD map: ${md_map}"
  fi
  echo "Atlas: ${atlas} (${node_count} nodes)"
  echo "Parcellation provenance: ${outdir}/parcellation.json"
  echo "Space diagnostic: ${outdir}/nodes.mrinfo.txt , ${outdir}/tracks.tckinfo.txt"

  run_disconnectome
  run_nodestrength
}

_DISCONNECTOME_ATTEMPTED=0

run_disconnectome() {
  ((_DISCONNECTOME_ATTEMPTED)) && return 0
  _DISCONNECTOME_ATTEMPTED=1

  if [[ "${RUN_DISCONNECTOME}" != "1" ]]; then
    if [[ "${PIPELINE_MODE}" == "disconnectome" ]]; then
      RUN_DISCONNECTOME=1
    else
      echo "Disconnectome (Step 4.1): skipped (pass --disconnection to opt in; method still under validation)"
      return 0
    fi
  fi

  local target_ses mask_raw mask_prepared mask_json t1w dkt_matrix
  target_ses="$(_resolve_target_session)" || return 0
  mask_raw="$(find_lesion_mask "${SUBJECT}" "${target_ses}")"
  if [[ -z "${mask_raw}" ]]; then
    echo "Disconnectome (Step 4.1): no BIDS lesion mask — skipping"
    return 0
  fi
  mask_prepared="${RESULTS_ROOT}/lesion_masks/sub-${SUBJECT}/ses-${target_ses}/lesion_mask_prepared.nii.gz"
  mask_json="${RESULTS_ROOT}/lesion_masks/sub-${SUBJECT}/ses-${target_ses}/lesion_mask_prepared.json"
  dkt_matrix="${CONNECTOME_OUT}/sub-${SUBJECT}/dkt_connectome.csv"

  if [[ ! -f "${mask_prepared}" ]]; then
    t1w="$(_strict_find_one "disconnectome/T1w" \
      find "${BIDS_DIR}/sub-${SUBJECT}/ses-${target_ses}/anat" -type f \
        \( -name '*_T1w.nii.gz' -o -name '*_T1w.nii' \))"
    mkdir -p "$(dirname "${mask_prepared}")"
    local -a prep_xtra=()
    [[ "${INPAINT_BINARIZE}" == "1" ]] && prep_xtra+=(--binarize)
    python3 "${PREPARE_LESION_MASK}" \
      --t1w "${t1w}" --mask "${mask_raw}" \
      --out "${mask_prepared}" --json "${mask_json}" \
      --labels "${INPAINT_LABELS}" \
      "${prep_xtra[@]}"
  fi
  if [[ ! -f "${dkt_matrix}" ]]; then
    _pipeline_fail "disconnectome" "missing ${dkt_matrix}" "Run Step 4 (connectome) first."
  fi

  echo "=== Disconnectome (Step 4.1): sub-${SUBJECT} ses-${target_ses} ==="

  local -a extra_args=(--connectome-weighting "${DISCONNECTOME_WEIGHTING}")
  [[ "${DISCONNECTOME_CORE_ONLY}" == "1" ]] && extra_args+=(--core-only)
  ((DISCONNECTOME_ERODE_VOXELS > 0)) && extra_args+=(--lesion-erode-voxels "${DISCONNECTOME_ERODE_VOXELS}")

  python3 "${RUN_DISCONNECTOME_SCRIPT}" \
    --results-root "${RESULTS_ROOT}" \
    --subject "${SUBJECT}" \
    --session "${target_ses}" \
    --container "${CONTAINER_CONNECTOME}" \
    --lut "${CONNECTOME_LUT_DKT}" \
    "${extra_args[@]}"

  echo "Disconnectome: ${CONNECTOME_OUT}/sub-${SUBJECT}/disconnectome/disconnection_matrix.csv"
}

_NODESTRENGTH_ATTEMPTED=0

run_nodestrength() {
  ((_NODESTRENGTH_ATTEMPTED)) && return 0
  _NODESTRENGTH_ATTEMPTED=1

  if [[ "${RUN_NODESTRENGTH}" != "1" ]]; then
    echo "Node strength (Step 5): skipped (RUN_NODESTRENGTH=0 / --no-node-strength)"
    return 0
  fi

  echo "=== Node strength / ENIGMA report (Step 5): sub-${SUBJECT} ==="

  [[ -f "${CONTAINER_NODESTRENGTH}" ]] || _pipeline_fail "nodestrength" \
    "missing CONTAINER_NODESTRENGTH: ${CONTAINER_NODESTRENGTH}" \
    "Build/pull it: see node_strength/containers/README.md, or" \
    "set CONTAINER_NODESTRENGTH to an existing nodestrength_*.sif."

  local subj_dir="${CONNECTOME_OUT}/sub-${SUBJECT}"
  [[ -d "${subj_dir}" ]] || _pipeline_fail "nodestrength" "missing connectome dir: ${subj_dir}" \
    "Run Step 4 (connectome) first."
  local has_matrix=0
  [[ -f "${subj_dir}/dkt_connectome.csv" || -f "${subj_dir}/dk_connectome.csv" \
     || -f "${subj_dir}/connectome.csv" ]] && has_matrix=1
  ((has_matrix)) || _pipeline_fail "nodestrength" \
    "no dkt_connectome.csv / dk_connectome.csv in ${subj_dir}" \
    "Run Step 4 (connectome) first."

  local manifest="${NODESTRENGTH_OUT}/manifest.json"
  local report="${NODESTRENGTH_OUT}/reports/sub-${SUBJECT}/report.pdf"
  local strength_csv="${NODESTRENGTH_OUT}/strength/per_subject/sub-${SUBJECT}_strength.csv"
  if [[ "${NODESTRENGTH_SKIP_IF_EXISTS}" == "1" && -f "${strength_csv}" \
        && ( "${NODESTRENGTH_NO_REPORT}" == "1" || -f "${report}" ) ]]; then
    echo "Node strength: ${strength_csv} already exists — skipping (NODESTRENGTH_SKIP_IF_EXISTS=1)"
    return 0
  fi

  mkdir -p "${NODESTRENGTH_OUT}"

  local -a extra_args=()
  [[ "${NODESTRENGTH_STRENGTH_ONLY}" == "1" ]] && extra_args+=(--strength-only)
  [[ "${NODESTRENGTH_NO_REPORT}" == "1" ]] && extra_args+=(--no-report)

  # FS_SUBJECTS_DIR is optional to the container (only used for nodes.mif lookup
  # when it isn't already beside the connectome); it may not exist yet if Step 5
  # is invoked standalone against a connectome tree with no local FS output.
  local -a fs_bind=()
  local fs_arg=""
  if [[ -d "${FS_SUBJECTS_DIR}" ]]; then
    fs_bind=(-B "${FS_SUBJECTS_DIR}:${FS_SUBJECTS_DIR}:ro")
    fs_arg="${FS_SUBJECTS_DIR}"
  fi

  apptainer run --cleanenv --containall \
    -B "${CONNECTOME_OUT}":"${CONNECTOME_OUT}":ro \
    "${fs_bind[@]}" \
    -B "${NODESTRENGTH_OUT}":"${NODESTRENGTH_OUT}" \
    "${CONTAINER_NODESTRENGTH}" \
    "${CONNECTOME_OUT}" "${NODESTRENGTH_OUT}" ${fs_arg:+"${fs_arg}"} \
    --include "${SUBJECT}" \
    "${extra_args[@]}"

  [[ -f "${manifest}" ]] || _pipeline_fail "nodestrength" \
    "nodestrength finished but ${manifest} was not written" \
    "Inspect ${NODESTRENGTH_OUT} for the container's own error output."

  echo "Node strength: ${strength_csv}"
  if [[ "${NODESTRENGTH_NO_REPORT}" == "1" ]]; then
    echo "Report: skipped (--no-report / NODESTRENGTH_NO_REPORT=1)"
  else
    echo "Report: ${report}"
  fi
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
    if [[ "${RUN_CONNECTOME}" == "1" ]]; then
      run_connectome
    fi
    ;;
  qsiprep)      run_qsiprep ;;
  inpaint)      run_inpaint ;;
  recon)        run_recon ;;
  qsirecon)     run_qsirecon ;;
  connectome)   run_connectome ;;
  disconnectome) run_disconnectome ;;
  nodestrength) run_nodestrength ;;
  *)
    echo "Invalid PIPELINE_MODE=${PIPELINE_MODE} (use all, qsiprep, inpaint, recon, qsirecon, connectome, disconnectome, or nodestrength)"
    exit 1
    ;;
esac

echo "QSIPrep output:  ${QSIPREP_OUT}"
echo "Recon output:    ${RECON_OUT}"
echo "QSIRecon output: ${QSIRECON_OUT}"
echo "Connectome output: ${CONNECTOME_OUT}"
echo "Node strength output: ${NODESTRENGTH_OUT}"
