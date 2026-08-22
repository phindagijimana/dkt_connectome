#!/usr/bin/env bash
# Step 3.5: lesion-aware ACT — 5ttedit -path, matched iFOD2 tckgen, tcksift2.
set -euo pipefail

usage() {
  cat <<'EOF'
Usage: run_lesion_aware_act.sh [OPTIONS]

Required:
  --five-tt PATH           QSIRecon HSVS 5TT (NIfTI or MRtrix)
  --wm-fod PATH            WM FOD map from QSIRecon
  --dwiref PATH            QSIPrep dwiref NIfTI
  --lesion-mask-t1w PATH   Lesion mask on T1w grid (prepared)
  --orig-to-t1w PATH       orig->T1w transform (.mat or .txt)
  --outdir DIR             Output directory

Optional:
  --streamlines N          Default 10000000
  --random-seed N          Default 0
  --cutoff F               Default 0.05
  --min-length-mm F        Default 30
  --max-length-mm F        Default 250
  --threads N              Default 8
  -h, --help
EOF
}

fail() { echo "ERROR [lesion-aware-act]: $*" >&2; exit 1; }

FIVE_TT="" WM_FOD="" DWIREF="" LESION_T1W="" ORIG_TO_T1W="" OUTDIR=""
STREAMLINES=10000000 RANDOM_SEED=0 CUTOFF=0.05 MIN_LENGTH=30 MAX_LENGTH=250 THREADS=8

while [[ $# -gt 0 ]]; do
  case "$1" in
    --five-tt) FIVE_TT="$2"; shift 2 ;;
    --wm-fod) WM_FOD="$2"; shift 2 ;;
    --dwiref) DWIREF="$2"; shift 2 ;;
    --lesion-mask-t1w) LESION_T1W="$2"; shift 2 ;;
    --orig-to-t1w) ORIG_TO_T1W="$2"; shift 2 ;;
    --outdir) OUTDIR="$2"; shift 2 ;;
    --streamlines) STREAMLINES="$2"; shift 2 ;;
    --random-seed) RANDOM_SEED="$2"; shift 2 ;;
    --cutoff) CUTOFF="$2"; shift 2 ;;
    --min-length-mm) MIN_LENGTH="$2"; shift 2 ;;
    --max-length-mm) MAX_LENGTH="$2"; shift 2 ;;
    --threads) THREADS="$2"; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) fail "unknown option: $1" ;;
  esac
done

[[ -n "${FIVE_TT}" && -n "${WM_FOD}" && -n "${DWIREF}" && -n "${LESION_T1W}" \
  && -n "${ORIG_TO_T1W}" && -n "${OUTDIR}" ]] || { usage; exit 1; }

for f in "${FIVE_TT}" "${WM_FOD}" "${DWIREF}" "${LESION_T1W}" "${ORIG_TO_T1W}"; do
  [[ -f "${f}" ]] || fail "missing input: ${f}"
done

mkdir -p "${OUTDIR}"
export MRTRIX_RNG_SEED="${RANDOM_SEED}"

antsApplyTransforms -d 3 \
  -i "${LESION_T1W}" \
  -r "${DWIREF}" \
  -t "${ORIG_TO_T1W}" \
  -n GenericLabel \
  -o "${OUTDIR}/lesion_mask_in_dwi.nii.gz"

[[ "$(mrstats "${OUTDIR}/lesion_mask_in_dwi.nii.gz" -output max)" != "0" ]] \
  || fail "transformed lesion mask is empty"

mrtransform -force "${FIVE_TT}" \
  -template "${DWIREF}" \
  -interp linear \
  "${OUTDIR}/base_5tt_resampled.mif"
mrcalc -force "${OUTDIR}/base_5tt_resampled.mif" 0 -max 1 -min \
  "${OUTDIR}/base_5tt_clipped.mif"
mrmath -force "${OUTDIR}/base_5tt_clipped.mif" sum "${OUTDIR}/base_5tt_sum.mif" -axis 3
mrcalc -force "${OUTDIR}/base_5tt_sum.mif" 0.000001 -max \
  "${OUTDIR}/base_5tt_denominator.mif"
mrcalc -force "${OUTDIR}/base_5tt_clipped.mif" \
  "${OUTDIR}/base_5tt_denominator.mif" -div "${OUTDIR}/base_5tt.mif"

5ttedit -force "${OUTDIR}/base_5tt.mif" "${OUTDIR}/lesion_aware_5tt.mif" \
  -path "${OUTDIR}/lesion_mask_in_dwi.nii.gz"
5ttcheck "${OUTDIR}/lesion_aware_5tt.mif"

mrconvert -force -quiet "${OUTDIR}/lesion_aware_5tt.mif" \
  -coord 3 4 "${OUTDIR}/pathology_channel.mif"
mrcalc -force -quiet "${OUTDIR}/pathology_channel.mif" \
  "${OUTDIR}/lesion_mask_in_dwi.nii.gz" -sub -abs \
  "${OUTDIR}/lesion_mask_in_dwi.nii.gz" -mult "${OUTDIR}/pathology_lesion_diff.mif"
[[ "$(mrstats "${OUTDIR}/pathology_lesion_diff.mif" -output max)" == "0" ]] \
  || fail "lesion voxels were not fully assigned to 5TT pathology"

5tt2gmwmi -force "${OUTDIR}/lesion_aware_5tt.mif" "${OUTDIR}/gmwmi.mif"
tckgen -force \
  "${WM_FOD}" \
  "${OUTDIR}/model-ifod2_streamlines.tck" \
  -algorithm iFOD2 \
  -act "${OUTDIR}/lesion_aware_5tt.mif" \
  -seed_dynamic "${WM_FOD}" \
  -backtrack -crop_at_gmwmi \
  -cutoff "${CUTOFF}" \
  -minlength "${MIN_LENGTH}" \
  -maxlength "${MAX_LENGTH}" \
  -select "${STREAMLINES}" \
  -nthreads "${THREADS}"

tcksift2 -force \
  "${OUTDIR}/model-ifod2_streamlines.tck" \
  "${WM_FOD}" \
  "${OUTDIR}/model-sift2_streamlineweights.csv" \
  -act "${OUTDIR}/lesion_aware_5tt.mif" \
  -nthreads "${THREADS}"

echo "Lesion-aware ACT OK:"
echo "  5TT: ${OUTDIR}/lesion_aware_5tt.mif"
echo "  Tractogram: ${OUTDIR}/model-ifod2_streamlines.tck"
echo "  SIFT2: ${OUTDIR}/model-sift2_streamlineweights.csv"
