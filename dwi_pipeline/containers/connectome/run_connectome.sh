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
  --preproc-dwi PATH         QSIPrep *_space-T1w_desc-preproc_dwi.nii.gz
  --bval PATH                FSL b-values corresponding to --preproc-dwi
  --bvec PATH                FSL b-vectors corresponding to --preproc-dwi
  --brain-mask PATH          QSIPrep *_space-T1w_desc-brain_mask.nii.gz
  --output-dir DIR           Write connectome matrices and intermediates here
  --fs-license PATH          FreeSurfer license.txt

Optional:
  --segmentation PATH        Parcellation to use (default: <subject>/mri/aparc+aseg.mgz;
                             pass mri/aparc.DKTatlas+aseg.mgz for DKT from recon-all)
  --fs-lut PATH              FreeSurferColorLUT.txt (default: $FREESURFER_HOME/FreeSurferColorLUT.txt)
  --mrtrix-lut PATH          MRtrix labelconvert LUT (default: fs_default.txt = DK)
  --sift2-weights PATH       Optional SIFT2 streamline weights for tck2connectome
  --primary-measure NAME     connectome.csv compatibility alias: count (default)
                             or sift2 (requires --sift2-weights)
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
PREPROC_DWI=""
BVAL=""
BVEC=""
BRAIN_MASK=""
OUTDIR=""
FS_LICENSE_PATH=""
FS_LUT_PATH=""
MRTRIX_LUT_PATH=""
SEGMENTATION=""
SUBJECT_ID=""
SIFT2_WEIGHTS=""
PRIMARY_MEASURE="count"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --freesurfer-subject) FS_SUBJECT="$2"; shift 2 ;;
    --tractogram) TRACKS="$2"; shift 2 ;;
    --dwiref) DWIREF="$2"; shift 2 ;;
    --preproc-t1w) PREPROC_T1W="$2"; shift 2 ;;
    --bids-t1w) BIDS_T1W="$2"; shift 2 ;;
    --preproc-dwi) PREPROC_DWI="$2"; shift 2 ;;
    --bval) BVAL="$2"; shift 2 ;;
    --bvec) BVEC="$2"; shift 2 ;;
    --brain-mask) BRAIN_MASK="$2"; shift 2 ;;
    --output-dir) OUTDIR="$2"; shift 2 ;;
    --fs-license) FS_LICENSE_PATH="$2"; shift 2 ;;
    --fs-lut) FS_LUT_PATH="$2"; shift 2 ;;
    --mrtrix-lut) MRTRIX_LUT_PATH="$2"; shift 2 ;;
    --sift2-weights) SIFT2_WEIGHTS="$2"; shift 2 ;;
    --primary-measure) PRIMARY_MEASURE="$2"; shift 2 ;;
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
[[ -n "${PREPROC_DWI}" ]] || fail "--preproc-dwi is required"
[[ -n "${BVAL}" ]] || fail "--bval is required"
[[ -n "${BVEC}" ]] || fail "--bvec is required"
[[ -n "${BRAIN_MASK}" ]] || fail "--brain-mask is required"
[[ -n "${OUTDIR}" ]] || fail "--output-dir is required"
[[ -n "${FS_LICENSE_PATH}" ]] || fail "--fs-license is required"
case "${PRIMARY_MEASURE}" in
  count) ;;
  sift2)
    [[ -n "${SIFT2_WEIGHTS}" ]] || fail "--primary-measure sift2 requires --sift2-weights"
    ;;
  *) fail "invalid --primary-measure ${PRIMARY_MEASURE} (use count or sift2)" ;;
esac

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
[[ -f "${PREPROC_DWI}" ]] || fail "missing preprocessed DWI: ${PREPROC_DWI}"
[[ -f "${BVAL}" ]] || fail "missing b-values: ${BVAL}"
[[ -f "${BVEC}" ]] || fail "missing b-vectors: ${BVEC}"
[[ -f "${BRAIN_MASK}" ]] || fail "missing brain mask: ${BRAIN_MASK}"
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

for c in mri_label2vol mri_convert antsRegistration antsApplyTransforms labelconvert \
  mrconvert dwi2tensor tensor2metric tcksample tck2connectome tckinfo mrinfo; do
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
echo "Using preprocessed DWI: ${PREPROC_DWI}"
echo "Using DWI brain mask: ${BRAIN_MASK}"
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

echo "[connectome] Step 4d: diffusion tensor and FA/MD maps"
mrconvert -force "${PREPROC_DWI}" "${OUTDIR}/preproc_dwi.mif" \
  -fslgrad "${BVEC}" "${BVAL}"
mrconvert -force "${BRAIN_MASK}" "${OUTDIR}/brain_mask.mif"
dwi2tensor -force "${OUTDIR}/preproc_dwi.mif" "${OUTDIR}/tensor.mif" \
  -mask "${OUTDIR}/brain_mask.mif"
tensor2metric -force "${OUTDIR}/tensor.mif" \
  -fa "${OUTDIR}/desc-FA_dwi.nii.gz" \
  -adc "${OUTDIR}/desc-MD_dwi.nii.gz" \
  -mask "${OUTDIR}/brain_mask.mif"

echo "[connectome] Step 4e: sample mean FA/MD along each streamline"
tcksample -force "${tck_use}" "${OUTDIR}/desc-FA_dwi.nii.gz" \
  "${OUTDIR}/streamline_meanfa.csv" -stat_tck mean
tcksample -force "${tck_use}" "${OUTDIR}/desc-MD_dwi.nii.gz" \
  "${OUTDIR}/streamline_meanmd.csv" -stat_tck mean

echo "[connectome] Step 4f-1: streamline-count connectome"
tck2connectome -force \
  "${tck_use}" \
  "${OUTDIR}/nodes.mif" \
  "${OUTDIR}/connectome_count.csv" \
  -symmetric \
  -zero_diagonal \
  -out_assignments "${OUTDIR}/assignments.csv"

echo "[connectome] Step 4f-2: mean streamline-length connectome (mm)"
tck2connectome -force \
  "${tck_use}" \
  "${OUTDIR}/nodes.mif" \
  "${OUTDIR}/connectome_meanlength.csv" \
  -symmetric \
  -zero_diagonal \
  -scale_length \
  -stat_edge mean

if [[ -n "${SIFT2_WEIGHTS}" ]]; then
  [[ -f "${SIFT2_WEIGHTS}" ]] || fail "missing SIFT2 weights: ${SIFT2_WEIGHTS}"
  echo "[connectome] Step 4f-3: SIFT2-weighted connectome"
  echo "Using SIFT2 weights: ${SIFT2_WEIGHTS}"
  tck2connectome -force \
    "${tck_use}" \
    "${OUTDIR}/nodes.mif" \
    "${OUTDIR}/connectome_sift2.csv" \
    -symmetric \
    -zero_diagonal \
    -tck_weights_in "${SIFT2_WEIGHTS}"
else
  echo "SIFT2 matrix: skipped (no --sift2-weights)"
fi

echo "[connectome] Step 4f-4: mean tract-sampled FA connectome"
tck2connectome -force \
  "${tck_use}" \
  "${OUTDIR}/nodes.mif" \
  "${OUTDIR}/connectome_meanfa.csv" \
  -symmetric \
  -zero_diagonal \
  -scale_file "${OUTDIR}/streamline_meanfa.csv" \
  -stat_edge mean

echo "[connectome] Step 4f-5: mean tract-sampled MD connectome"
tck2connectome -force \
  "${tck_use}" \
  "${OUTDIR}/nodes.mif" \
  "${OUTDIR}/connectome_meanmd.csv" \
  -symmetric \
  -zero_diagonal \
  -scale_file "${OUTDIR}/streamline_meanmd.csv" \
  -stat_edge mean

cp -f "${OUTDIR}/connectome_${PRIMARY_MEASURE}.csv" "${OUTDIR}/connectome.csv"

[[ -n "${tck_staged}" ]] && rm -f "${tck_staged}"

echo "Primary connectome (${PRIMARY_MEASURE}): ${OUTDIR}/connectome.csv"
echo "Count connectome: ${OUTDIR}/connectome_count.csv"
echo "MeanLength connectome: ${OUTDIR}/connectome_meanlength.csv"
[[ -f "${OUTDIR}/connectome_sift2.csv" ]] && \
  echo "SIFT2 connectome: ${OUTDIR}/connectome_sift2.csv"
echo "MeanFA connectome: ${OUTDIR}/connectome_meanfa.csv"
echo "MeanMD connectome: ${OUTDIR}/connectome_meanmd.csv"
echo "FA map: ${OUTDIR}/desc-FA_dwi.nii.gz"
echo "MD map: ${OUTDIR}/desc-MD_dwi.nii.gz"
echo "Space diagnostic: ${OUTDIR}/nodes.mrinfo.txt , ${OUTDIR}/tracks.tckinfo.txt"
