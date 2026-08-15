#!/usr/bin/env bash
# Structural connectome from a FreeSurfer parcellation + QSIRecon tractogram.
# Intended to run inside dkt_connectome.sif (or on host with tools on PATH).
#
# The node set follows whichever segmentation and labelconvert LUT the caller
# passes in — Desikan-Killiany or Desikan-Killiany-Tourville — so nothing here
# is specific to either atlas.
#
# Warp chain: FS conformed -> native (mri_label2vol/rawavg) -> QSIPrep T1w
#             (affine BIDS T1w -> desc-preproc_T1w) -> dwiref grid.
#
set -euo pipefail

usage() {
  cat <<'EOF'
Usage: run_connectome.sh [OPTIONS]

Required:
  --freesurfer-subject DIR   FreeSurfer subject dir (mri/aparc+aseg.mgz, rawavg.mgz)
  --tractogram PATH          QSIRecon streamlines (.tck or .tck.gz)
  --dwiref PATH              QSIPrep *_space-T1w_dwiref.nii.gz
  --preproc-t1w PATH         QSIPrep *_desc-preproc_T1w.nii.gz
  --bids-t1w PATH            BIDS session T1w (affine registration source)
  --output-dir DIR           Write connectome.csv and intermediates here
  --fs-license PATH          FreeSurfer license.txt

Optional:
  --segmentation PATH        Parcellation to use (default: <subject>/mri/aparc+aseg.mgz;
                             pass mri/aparc.DKTatlas+aseg.mgz for DKT from recon-all)
  --fs-lut PATH              FreeSurferColorLUT.txt (default: $FREESURFER_HOME/FreeSurferColorLUT.txt)
  --mrtrix-lut PATH          MRtrix labelconvert LUT (default: fs_default.txt = DK)
  --sift2-weights PATH       Optional SIFT2 streamline weights for tck2connectome
  --subject-id ID            Label for log messages only
  -h, --help

Environment overrides:
  FS_LICENSE, FREESURFER_HOME, MRTRIX_LUT, FS_LUT
EOF
}

fail() {
  echo "ERROR [connectome]: $*" >&2
  exit 1
}

require_cmd() {
  local c="$1"
  command -v "$c" >/dev/null 2>&1 || fail "missing required command: ${c}"
}

FS_SUBJECT=""
TRACKS=""
DWIREF=""
PREPROC_T1W=""
BIDS_T1W=""
OUTDIR=""
FS_LICENSE_PATH=""
FS_LUT_PATH=""
MRTRIX_LUT_PATH=""
SEGMENTATION=""
SUBJECT_ID=""
SIFT2_WEIGHTS=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --freesurfer-subject) FS_SUBJECT="$2"; shift 2 ;;
    --tractogram) TRACKS="$2"; shift 2 ;;
    --dwiref) DWIREF="$2"; shift 2 ;;
    --preproc-t1w) PREPROC_T1W="$2"; shift 2 ;;
    --bids-t1w) BIDS_T1W="$2"; shift 2 ;;
    --output-dir) OUTDIR="$2"; shift 2 ;;
    --fs-license) FS_LICENSE_PATH="$2"; shift 2 ;;
    --fs-lut) FS_LUT_PATH="$2"; shift 2 ;;
    --mrtrix-lut) MRTRIX_LUT_PATH="$2"; shift 2 ;;
    --sift2-weights) SIFT2_WEIGHTS="$2"; shift 2 ;;
    --segmentation) SEGMENTATION="$2"; shift 2 ;;
    --subject-id) SUBJECT_ID="$2"; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) fail "unknown argument: $1 (try --help)" ;;
  esac
done

[[ -n "${FS_SUBJECT}" ]] || fail "--freesurfer-subject is required"
[[ -n "${TRACKS}" ]] || fail "--tractogram is required"
[[ -n "${DWIREF}" ]] || fail "--dwiref is required"
[[ -n "${PREPROC_T1W}" ]] || fail "--preproc-t1w is required"
[[ -n "${BIDS_T1W}" ]] || fail "--bids-t1w is required"
[[ -n "${OUTDIR}" ]] || fail "--output-dir is required"
[[ -n "${FS_LICENSE_PATH}" ]] || fail "--fs-license is required"

# The LUT and the segmentation have to describe the same atlas: labelconvert
# matches regions by name, so a DKT LUT over a DK image silently drops bankssts
# and the poles instead of reassigning them. The caller picks both.
case "${SEGMENTATION}" in
  "")  APARC="${FS_SUBJECT}/mri/aparc+aseg.mgz" ;;
  /*)  APARC="${SEGMENTATION}" ;;
  *)   APARC="${FS_SUBJECT}/mri/${SEGMENTATION}" ;;
esac
RAWAVG="${FS_SUBJECT}/mri/rawavg.mgz"
[[ -f "${APARC}" ]] || fail "missing segmentation: ${APARC}"
[[ -f "${RAWAVG}" ]] || fail "missing ${RAWAVG}"
[[ -f "${TRACKS}" ]] || fail "missing tractogram: ${TRACKS}"
[[ -f "${DWIREF}" ]] || fail "missing dwiref: ${DWIREF}"
[[ -f "${PREPROC_T1W}" ]] || fail "missing preproc T1w: ${PREPROC_T1W}"
[[ -f "${BIDS_T1W}" ]] || fail "missing BIDS T1w: ${BIDS_T1W}"
[[ -f "${FS_LICENSE_PATH}" ]] || fail "missing FS license: ${FS_LICENSE_PATH}"

mkdir -p "${OUTDIR}"
export FS_LICENSE="${FS_LICENSE_PATH}"
export LD_LIBRARY_PATH="${LD_LIBRARY_PATH:-/opt/ants/lib:/opt/mrtrix3-latest/lib}"
# mri_label2vol requires SUBJECTS_DIR even when paths are explicit.
if [[ "$(basename "${FS_SUBJECT}")" == sub-* ]]; then
  export SUBJECTS_DIR="${SUBJECTS_DIR:-$(dirname "${FS_SUBJECT}")}"
else
  export SUBJECTS_DIR="${SUBJECTS_DIR:-${FS_SUBJECT}}"
fi
# Container images set PATH via %environment; do not source SetUpFreeSurfer.sh.

FS_LUT_PATH="${FS_LUT_PATH:-${FS_LUT:-${FREESURFER_HOME:-/opt/freesurfer}/FreeSurferColorLUT.txt}}"
MRTRIX_LUT_PATH="${MRTRIX_LUT_PATH:-${MRTRIX_LUT:-}}"

if [[ -z "${MRTRIX_LUT_PATH}" ]]; then
  for candidate in \
    /opt/mrtrix3-latest/share/mrtrix3/labelconvert/fs_default.txt \
    /usr/share/mrtrix3/labelconvert/fs_default.txt \
    /opt/mrtrix3/share/mrtrix3/labelconvert/fs_default.txt; do
    if [[ -f "${candidate}" ]]; then
      MRTRIX_LUT_PATH="${candidate}"
      break
    fi
  done
fi
[[ -f "${FS_LUT_PATH}" ]] || fail "FreeSurfer LUT not found: ${FS_LUT_PATH}"
[[ -n "${MRTRIX_LUT_PATH}" && -f "${MRTRIX_LUT_PATH}" ]] || fail "MRtrix fs_default.txt not found (set --mrtrix-lut or MRTRIX_LUT)"

for c in mri_label2vol mri_convert antsRegistration antsApplyTransforms labelconvert tck2connectome tckinfo mrinfo; do
  require_cmd "${c}"
done

log_id="${SUBJECT_ID:-$(basename "${FS_SUBJECT}")}"
echo "=== Connectome: ${log_id} ==="
echo "Using tractogram: ${TRACKS}"
echo "Using segmentation: ${APARC}"
echo "Using labelconvert LUT: ${MRTRIX_LUT_PATH}"
echo "Using DWI reference: ${DWIREF}"
echo "Using QSIPrep T1w reference: ${PREPROC_T1W}"
echo "Using BIDS T1w (affine reg source): ${BIDS_T1W}"
echo "Space handling: FS conformed -> native (mri_label2vol/rawavg) -> QSIPrep T1w (affine BIDS T1w->desc-preproc_T1w) -> dwiref"

echo "[connectome] Step 4a: FS conformed -> native (mri_label2vol / rawavg.mgz)"
mri_label2vol --seg "${APARC}" \
  --temp "${RAWAVG}" \
  --o "${OUTDIR}/aparc+aseg_in_rawavg.mgz" \
  --regheader "${APARC}"

mri_convert "${APARC}" "${OUTDIR}/aparc+aseg.nii.gz"
mri_convert "${OUTDIR}/aparc+aseg_in_rawavg.mgz" "${OUTDIR}/aparc+aseg_in_rawavg.nii.gz"

echo "[connectome] Step 4b-1: affine register BIDS T1w -> QSIPrep desc-preproc_T1w"
antsRegistration --dimensionality 3 --float 0 \
  --output "[${OUTDIR}/native_to_preproc_T1w_,${OUTDIR}/native_to_preproc_T1w_Warped.nii.gz]" \
  --interpolation Linear \
  --winsorize-image-intensities '[0.005,0.995]' \
  --use-histogram-matching 1 \
  --transform 'Affine[0.1]' \
  --metric "MI[${PREPROC_T1W},${BIDS_T1W},1,32]" \
  --convergence '[500x250x100,1e-6,10]' \
  --shrink-factors 4x2x1 \
  --smoothing-sigmas 2x1x0vox

echo "[connectome] Step 4b-2: warp native labels -> QSIPrep T1w (GenericLabel)"
antsApplyTransforms -d 3 \
  -i "${OUTDIR}/aparc+aseg_in_rawavg.nii.gz" \
  -r "${PREPROC_T1W}" \
  -t "${OUTDIR}/native_to_preproc_T1w_0GenericAffine.mat" \
  -n GenericLabel \
  -o "${OUTDIR}/aparc+aseg_in_t1w.nii.gz"

echo "[connectome] Step 4b-3: QSIPrep T1w -> dwiref grid (GenericLabel resample)"
antsApplyTransforms -d 3 \
  -i "${OUTDIR}/aparc+aseg_in_t1w.nii.gz" \
  -r "${DWIREF}" \
  -n GenericLabel \
  -o "${OUTDIR}/aparc+aseg_in_dwi.nii.gz"

echo "[connectome] Step 4c: labelconvert -> nodes.mif"
labelconvert -force "${OUTDIR}/aparc+aseg_in_dwi.nii.gz" \
  "${FS_LUT_PATH}" "${MRTRIX_LUT_PATH}" "${OUTDIR}/nodes.mif"

tck_use="${TRACKS}"
tck_staged=""
if [[ "${TRACKS}" == *.tck.gz ]]; then
  tck_staged="${OUTDIR}/streamlines.tck"
  echo "[connectome] Decompressing ${TRACKS} -> ${tck_staged}"
  gunzip -c "${TRACKS}" > "${tck_staged}"
  tck_use="${tck_staged}"
fi

echo "[connectome] === space-alignment diagnostic ==="
mrinfo "${OUTDIR}/nodes.mif" | tee "${OUTDIR}/nodes.mrinfo.txt" | sed -n '1,20p'
tckinfo "${tck_use}" | tee "${OUTDIR}/tracks.tckinfo.txt" | sed -n '1,30p'
echo "[connectome] =================================="

echo "[connectome] Step 4f: tck2connectome"
tck_weights_args=()
if [[ -n "${SIFT2_WEIGHTS}" ]]; then
  [[ -f "${SIFT2_WEIGHTS}" ]] || fail "missing SIFT2 weights: ${SIFT2_WEIGHTS}"
  tck_weights_args=(-tck_weights_in "${SIFT2_WEIGHTS}")
  echo "Using SIFT2 weights: ${SIFT2_WEIGHTS}"
else
  echo "Using streamline counts (no SIFT2 weights)"
fi
tck2connectome -force \
  "${tck_use}" \
  "${OUTDIR}/nodes.mif" \
  "${OUTDIR}/connectome.csv" \
  -symmetric \
  -zero_diagonal \
  -out_assignments "${OUTDIR}/assignments.csv" \
  "${tck_weights_args[@]}"

[[ -n "${tck_staged}" ]] && rm -f "${tck_staged}"

echo "Connectome: ${OUTDIR}/connectome.csv"
echo "Space diagnostic: ${OUTDIR}/nodes.mrinfo.txt , ${OUTDIR}/tracks.tckinfo.txt"
