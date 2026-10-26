#!/usr/bin/env bash
# Preflight for tbi_lit_v2c_long — clone, weights, ≥2 T1 timepoints, optional v2c venv.
set -euo pipefail

DLS="${DLS:-/mnt/nfs/home/urmc-sh.rochester.edu/pndagiji/Documents/TrackTBI-Sub/dwi_pipeline/methods/others_methods/preprocessing/DL/dlsurfer}"
V2C_LONG_ROOT="${V2C_LONG_ROOT:-/mnt/nfs/home/urmc-sh.rochester.edu/pndagiji/Documents/others/V2C-Long}"
TRACKTBI_BIDS="${TRACKTBI_BIDS:-/mnt/nfs/home/urmc-sh.rochester.edu/pndagiji/Documents/TrackTBI-Sub/TrackTBI_Lesion}"
TRACKTBI_SUB="${TRACKTBI_SUB:-sub-TBI011021}"
TRACKTBI_SES_A="${TRACKTBI_SES_A:-ses-2WK}"
TRACKTBI_SES_B="${TRACKTBI_SES_B:-ses-6MO}"
GUGGER_T1_DIR="${GUGGER_T1_DIR:-/mnt/nfs/Gugger_Lab/PTE/EG/Nii}"
V2C_ENV="${DLS}/work/phase3_gates/envs/v2c"

if [[ ! -f "${V2C_LONG_ROOT}/vox2organ/main.py" ]]; then
  echo "[v2c-long-preflight] missing V2C-Long checkout at V2C_LONG_ROOT=${V2C_LONG_ROOT}" >&2
  exit 2
fi
if [[ ! -f "${V2C_LONG_ROOT}/public_experiments/v2c-flow-s_base/best.pt" ]]; then
  echo "[v2c-long-preflight] missing public_experiments weights under ${V2C_LONG_ROOT}" >&2
  exit 2
fi
if [[ ! -f "${V2C_LONG_ROOT}/public_experiments/v2c-long/best.pt" ]]; then
  echo "[v2c-long-preflight] missing v2c-long/best.pt under ${V2C_LONG_ROOT}" >&2
  exit 2
fi

t1_a="${TRACKTBI_BIDS}/${TRACKTBI_SUB}/${TRACKTBI_SES_A}/anat/${TRACKTBI_SUB}_${TRACKTBI_SES_A}_acq-3D_T1w.nii.gz"
t1_b="${TRACKTBI_BIDS}/${TRACKTBI_SUB}/${TRACKTBI_SES_B}/anat/${TRACKTBI_SUB}_${TRACKTBI_SES_B}_acq-3D_T1w.nii.gz"
lesion="${TRACKTBI_BIDS}/${TRACKTBI_SUB}/${TRACKTBI_SES_A}/anat/${TRACKTBI_SUB}_${TRACKTBI_SES_A}_acq-3D_T1w_label-lesion_roi.nii.gz"
DATA_MODE="tracktbi_longitudinal"

if [[ ! -f "$t1_a" || ! -f "$t1_b" ]]; then
  mapfile -t mprage < <(find "$GUGGER_T1_DIR" -maxdepth 1 -iname '*MP-RAGE*.nii.gz' 2>/dev/null | sort)
  if [[ ${#mprage[@]} -ge 2 ]]; then
    DATA_MODE="gugger_eg_longitudinal"
  else
    echo "[v2c-long-preflight] DATA_GAP: TrackTBI missing T1 pair (${t1_a}, ${t1_b})" >&2
    echo "[v2c-long-preflight] Gugger sub-EG has ${#mprage[@]} MP-RAGE under ${GUGGER_T1_DIR}" >&2
    echo "[v2c-long-preflight] need ≥2 native T1 timepoints (TrackTBI 2WK/6MO preferred)" >&2
    exit 2
  fi
fi

if [[ "$DATA_MODE" == "tracktbi_longitudinal" && ! -f "$lesion" ]]; then
  echo "[v2c-long-preflight] warning: missing LIT lesion ROI for 2WK ($lesion); with_lit arm may fail" >&2
fi

if [[ ! -x "${V2C_ENV}/bin/python" ]]; then
  echo "[v2c-long-preflight] note: v2c venv missing at ${V2C_ENV} — sbatch will bootstrap on GPU node" >&2
fi

echo "[v2c-long-preflight] OK — V2C_LONG_ROOT=${V2C_LONG_ROOT} DATA_MODE=${DATA_MODE} SUB=${TRACKTBI_SUB}"
exit 0
