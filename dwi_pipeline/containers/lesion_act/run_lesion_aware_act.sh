#!/usr/bin/env bash
# Step 3.1: lesion-aware ACT — 5ttedit -path, matched iFOD2 tckgen, tcksift2.
#
# Spatial workflows:
#   hsvs (default, LeAPP ACPC-first):
#     1. Warp original BIDS lesion ROI → ACPC HSVS 5TT grid
#     2. 5ttedit -path on ACPC grid; QA pathology overlap there
#     3. Resample edited 5TT → dwiref for iFOD2 / SIFT2
#
#   deep-atropos-native:
#     1. 5ttedit -path on native BIDS T1w grid (base_5tt_native.mif)
#     2. Resample edited 5TT → dwiref via preproc T1w intermediate
#
# Factorial design: on inpainted experiment arms, base 5TT may come from mitigated
# T1w recon (HSVS) or Deep Atropos on original BIDS T1w while --lesion-mask-t1w is
# always the original BIDS ROI (LeAPP-style orthogonal anatomy x ACT contrast).
set -euo pipefail

usage() {
  cat <<'EOF'
Usage: run_lesion_aware_act.sh [OPTIONS]

Required:
  --five-tt PATH           Base 5TT (HSVS ACPC NIfTI/MRtrix, or base_5tt_native.mif)
  --wm-fod PATH            WM FOD map from QSIRecon (dwiref grid)
  --dwiref PATH            QSIPrep *_space-T1w_dwiref.nii.gz
  --lesion-mask-t1w PATH   Lesion mask on BIDS T1w grid (prepared)
  --bids-t1w PATH          BIDS T1w (moving image for empirical registration)
  --preproc-t1w PATH       QSIPrep *_desc-preproc_T1w.nii.gz (ACPC reference)
  --outdir DIR             Output directory

Optional:
  --five-tt-source SRC     hsvs (default) | deep-atropos-native
  --native-to-acpc PATH    QSIPrep from-T1wNative_to-T1wACPC xfm (.mat/.txt)
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

log() { echo "[lesion-aware-act] $*" >&2; }

FIVE_TT="" WM_FOD="" DWIREF="" LESION_T1W="" BIDS_T1W="" PREPROC_T1W="" OUTDIR=""
FIVE_TT_SOURCE="hsvs"
NATIVE_TO_ACPC=""
STREAMLINES=10000000 RANDOM_SEED=0 CUTOFF=0.05 MIN_LENGTH=30 MAX_LENGTH=250 THREADS=8

while [[ $# -gt 0 ]]; do
  case "$1" in
    --five-tt) FIVE_TT="$2"; shift 2 ;;
    --five-tt-source) FIVE_TT_SOURCE="$2"; shift 2 ;;
    --wm-fod) WM_FOD="$2"; shift 2 ;;
    --dwiref) DWIREF="$2"; shift 2 ;;
    --lesion-mask-t1w) LESION_T1W="$2"; shift 2 ;;
    --bids-t1w) BIDS_T1W="$2"; shift 2 ;;
    --preproc-t1w) PREPROC_T1W="$2"; shift 2 ;;
    --native-to-acpc) NATIVE_TO_ACPC="$2"; shift 2 ;;
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
  && -n "${BIDS_T1W}" && -n "${PREPROC_T1W}" && -n "${OUTDIR}" ]] || { usage; exit 1; }

case "${FIVE_TT_SOURCE}" in
  hsvs|deep-atropos-native) ;;
  *) fail "invalid --five-tt-source=${FIVE_TT_SOURCE} (use hsvs or deep-atropos-native)" ;;
esac

for f in "${FIVE_TT}" "${WM_FOD}" "${DWIREF}" "${LESION_T1W}" "${BIDS_T1W}" "${PREPROC_T1W}"; do
  [[ -f "${f}" ]] || fail "missing input: ${f}"
done

mkdir -p "${OUTDIR}"
export MRTRIX_RNG_SEED="${RANDOM_SEED}"

clip_renormalize_5tt() {
  local src="$1" dst="$2"
  mrcalc -force "${src}" 0 -max 1 -min "${OUTDIR}/base_5tt_clipped.mif"
  mrmath -force "${OUTDIR}/base_5tt_clipped.mif" sum "${OUTDIR}/base_5tt_sum.mif" -axis 3
  mrcalc -force "${OUTDIR}/base_5tt_sum.mif" 0.000001 -max \
    "${OUTDIR}/base_5tt_denominator.mif"
  mrcalc -force "${OUTDIR}/base_5tt_clipped.mif" \
    "${OUTDIR}/base_5tt_denominator.mif" -div "${dst}"
}

_mrstats_max() {
  mrstats -quiet "$1" -output max 2>/dev/null | awk '{print $1+0}'
}

pathology_overlap_ok() {
  local five_tt="$1" lesion_mask="$2" tag="$3"
  mrconvert -force -quiet "${five_tt}" -coord 3 4 "${OUTDIR}/pathology_channel_${tag}.mif"
  mrcalc -force -quiet "${OUTDIR}/pathology_channel_${tag}.mif" \
    "${lesion_mask}" -sub -abs \
    "${lesion_mask}" -mult "${OUTDIR}/pathology_lesion_diff_${tag}.mif"
  [[ "$(_mrstats_max "${OUTDIR}/pathology_lesion_diff_${tag}.mif")" -eq 0 ]]
}

lesion_mask_nonempty() {
  local path="$1"
  [[ -f "${path}" ]] && [[ "$(_mrstats_max "${path}")" -gt 0 ]]
}

write_spatial_metadata() {
  printf '%s\n' "${LESION_WARP_METHOD}" > "${OUTDIR}/lesion_warp_method.txt"
  printf '%s\n' "${SPATIAL_WORKFLOW}" > "${OUTDIR}/spatial_workflow.txt"
  printf '%s\n' "${FIVE_TT_SOURCE}" > "${OUTDIR}/five_tt_source.txt"
}

run_hsvs_acpc_workflow() {
  log "convert HSVS 5TT to MRtrix format"
  mrconvert -force "${FIVE_TT}" "${OUTDIR}/base_5tt_acpc.mif"

  log "extract 5TT channel 0 as ACPC reference grid (vol0000 equivalent)"
  mrconvert -force "${OUTDIR}/base_5tt_acpc.mif" -coord 3 0 "${OUTDIR}/five_tt_ref.nii.gz"

  LESION_WARP_METHOD=""
  if [[ -n "${NATIVE_TO_ACPC}" && -f "${NATIVE_TO_ACPC}" ]]; then
    log "warp lesion → ACPC 5TT grid via QSIPrep T1wNative→ACPC"
    antsApplyTransforms -d 3 \
      -i "${LESION_T1W}" \
      -r "${OUTDIR}/five_tt_ref.nii.gz" \
      -t "${NATIVE_TO_ACPC}" \
      -n GenericLabel \
      -o "${OUTDIR}/lesion_in_acpc_5tt.nii.gz"
    if lesion_mask_nonempty "${OUTDIR}/lesion_in_acpc_5tt.nii.gz"; then
      LESION_WARP_METHOD="qsiprep_native_to_acpc"
    else
      log "packaged native→ACPC produced empty lesion; trying empirical affine"
      rm -f "${OUTDIR}/lesion_in_acpc_5tt.nii.gz"
    fi
  fi

  if [[ -z "${LESION_WARP_METHOD}" ]]; then
    log "empirical affine: BIDS T1w → desc-preproc_T1w (Step 4 connectome recipe)"
    antsRegistration --dimensionality 3 --float 0 \
      --output "[${OUTDIR}/bids_to_preproc_,${OUTDIR}/bids_to_preproc_Warped.nii.gz]" \
      --interpolation Linear \
      --winsorize-image-intensities '[0.005,0.995]' \
      --use-histogram-matching 1 \
      --transform 'Affine[0.1]' \
      --metric "MI[${PREPROC_T1W},${BIDS_T1W},1,32]" \
      --convergence '[500x250x100,1e-6,10]' \
      --shrink-factors 4x2x1 \
      --smoothing-sigmas 2x1x0vox
    antsApplyTransforms -d 3 \
      -i "${LESION_T1W}" \
      -r "${OUTDIR}/five_tt_ref.nii.gz" \
      -t "${OUTDIR}/bids_to_preproc_0GenericAffine.mat" \
      -n GenericLabel \
      -o "${OUTDIR}/lesion_in_acpc_5tt.nii.gz"
    LESION_WARP_METHOD="empirical_bids_to_preproc"
  fi

  lesion_mask_nonempty "${OUTDIR}/lesion_in_acpc_5tt.nii.gz" \
    || fail "lesion mask is empty in ACPC 5TT space after ${LESION_WARP_METHOD}"

  log "5ttedit -path on ACPC grid"
  5ttedit -force "${OUTDIR}/base_5tt_acpc.mif" "${OUTDIR}/lesion_aware_5tt_acpc.mif" \
    -path "${OUTDIR}/lesion_in_acpc_5tt.nii.gz"
  5ttcheck "${OUTDIR}/lesion_aware_5tt_acpc.mif"

  pathology_overlap_ok "${OUTDIR}/lesion_aware_5tt_acpc.mif" \
    "${OUTDIR}/lesion_in_acpc_5tt.nii.gz" acpc \
    || fail "lesion voxels were not fully assigned to 5TT pathology (ACPC grid)"

  log "resample edited 5TT → dwiref for tractography"
  mrtransform -force "${OUTDIR}/lesion_aware_5tt_acpc.mif" \
    -template "${DWIREF}" \
    -interp linear \
    "${OUTDIR}/base_5tt_resampled.mif"
  clip_renormalize_5tt "${OUTDIR}/base_5tt_resampled.mif" "${OUTDIR}/lesion_aware_5tt.mif"

  log "resample lesion mask → dwiref for provenance / QC"
  mrtransform -force "${OUTDIR}/lesion_in_acpc_5tt.nii.gz" \
    -template "${DWIREF}" \
    -interp nearest \
    "${OUTDIR}/lesion_mask_in_dwi.nii.gz"

  SPATIAL_WORKFLOW="acpc_5tt_edit_then_dwiref_resample"
}

run_deep_atropos_native_workflow() {
  log "Deep Atropos native 5TT — edit on BIDS T1w grid"
  if [[ "${FIVE_TT}" == *.mif ]]; then
    mrconvert -force "${FIVE_TT}" "${OUTDIR}/base_5tt_native.mif"
  else
    mrconvert -force "${FIVE_TT}" "${OUTDIR}/base_5tt_native.mif"
  fi

  log "extract 5TT channel 0 as native T1w reference grid"
  mrconvert -force "${OUTDIR}/base_5tt_native.mif" -coord 3 0 "${OUTDIR}/five_tt_ref.nii.gz"

  log "align prepared lesion mask to native 5TT grid"
  mrtransform -force "${LESION_T1W}" \
    -template "${OUTDIR}/five_tt_ref.nii.gz" \
    -interp nearest \
    "${OUTDIR}/lesion_in_native_5tt.nii.gz"

  lesion_mask_nonempty "${OUTDIR}/lesion_in_native_5tt.nii.gz" \
    || fail "lesion mask is empty on native 5TT grid"

  log "5ttedit -path on native BIDS T1w grid"
  5ttedit -force "${OUTDIR}/base_5tt_native.mif" "${OUTDIR}/lesion_aware_5tt_native.mif" \
    -path "${OUTDIR}/lesion_in_native_5tt.nii.gz"
  5ttcheck "${OUTDIR}/lesion_aware_5tt_native.mif"

  pathology_overlap_ok "${OUTDIR}/lesion_aware_5tt_native.mif" \
    "${OUTDIR}/lesion_in_native_5tt.nii.gz" native \
    || fail "lesion voxels were not fully assigned to 5TT pathology (native grid)"

  log "resample native edited 5TT → dwiref via preproc T1w"
  mrtransform -force "${OUTDIR}/lesion_aware_5tt_native.mif" \
    -template "${PREPROC_T1W}" \
    -interp linear \
    "${OUTDIR}/lesion_aware_5tt_preproc.mif"
  mrtransform -force "${OUTDIR}/lesion_aware_5tt_preproc.mif" \
    -template "${DWIREF}" \
    -interp linear \
    "${OUTDIR}/base_5tt_resampled.mif"
  clip_renormalize_5tt "${OUTDIR}/base_5tt_resampled.mif" "${OUTDIR}/lesion_aware_5tt.mif"

  log "resample lesion mask → dwiref for provenance / QC"
  mrtransform -force "${OUTDIR}/lesion_in_native_5tt.nii.gz" \
    -template "${DWIREF}" \
    -interp nearest \
    "${OUTDIR}/lesion_mask_in_dwi.nii.gz"

  LESION_WARP_METHOD="native_t1w_direct"
  SPATIAL_WORKFLOW="native_5tt_edit_then_dwiref_resample"
}

if [[ "${FIVE_TT_SOURCE}" == "hsvs" ]]; then
  run_hsvs_acpc_workflow
else
  run_deep_atropos_native_workflow
fi

lesion_mask_nonempty "${OUTDIR}/lesion_mask_in_dwi.nii.gz" \
  || fail "lesion mask is empty in dwiref space"

write_spatial_metadata

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
echo "  five_tt_source: ${FIVE_TT_SOURCE}"
echo "  warp method: ${LESION_WARP_METHOD}"
echo "  spatial workflow: ${SPATIAL_WORKFLOW}"
echo "  5TT (dwiref): ${OUTDIR}/lesion_aware_5tt.mif"
if [[ "${FIVE_TT_SOURCE}" == "hsvs" ]]; then
  echo "  5TT (ACPC): ${OUTDIR}/lesion_aware_5tt_acpc.mif"
  echo "  lesion (ACPC): ${OUTDIR}/lesion_in_acpc_5tt.nii.gz"
else
  echo "  5TT (native): ${OUTDIR}/lesion_aware_5tt_native.mif"
  echo "  lesion (native): ${OUTDIR}/lesion_in_native_5tt.nii.gz"
fi
echo "  lesion (dwiref): ${OUTDIR}/lesion_mask_in_dwi.nii.gz"
echo "  Tractogram: ${OUTDIR}/model-ifod2_streamlines.tck"
echo "  SIFT2: ${OUTDIR}/model-sift2_streamlineweights.csv"
