#!/usr/bin/env bash
# Warp disconnectome lesion_binary_t1w.nii.gz → MNI152NLin6Asym (LQT input).
#
# Requires: ANTs antsApplyTransforms on PATH (QSIPrep/fMRIPrep stack).
#
# Usage:
#   prepare_lesion_mni_for_lqt.sh TBI011011
#
# Env:
#   DWI_CONNECTOMES  — neurolit-lesion connectomes root
#   FMRIPREP_DIR     — fMRIPrep derivatives (inpaint cohort)
#   SESSION          — default 2WK
#   OUT_DIR          — default $LQT_STAGING/sub-<ID>/inputs

set -euo pipefail

SUBJECT="${1:?subject ID e.g. TBI011011}"
SESSION="${SESSION:-2WK}"

EXPERIMENT_ROOT="${EXPERIMENT_ROOT:-/mnt/nfs/Gugger_Lab/NIR/dwi_test_TBI_experiment}"
DWI_CONNECTOMES="${DWI_CONNECTOMES:-${EXPERIMENT_ROOT}/validation_v030/arms/neurolit-lesion/connectomes}"
FMRIPREP_DIR="${FMRIPREP_DIR:-${EXPERIMENT_ROOT}/fmri_derivatives_inpaint/fmriprep}"
LQT_STAGING="${LQT_STAGING:-${EXPERIMENT_ROOT}/lqt_batch/staging}"

LESION_T1W="${DWI_CONNECTOMES}/sub-${SUBJECT}/disconnectome/lesion_binary_t1w.nii.gz"
ANAT_DIR="${FMRIPREP_DIR}/sub-${SUBJECT}/ses-${SESSION}/anat"
REF_T1W="${ANAT_DIR}/sub-${SUBJECT}_ses-${SESSION}_acq-3D_desc-preproc_T1w.nii.gz"
XFM_T1W_TO_MNI="${ANAT_DIR}/sub-${SUBJECT}_ses-${SESSION}_acq-3D_from-T1w_to-MNI152NLin6Asym_mode-image_xfm.h5"
MNI_TEMPLATE="${MNI_TEMPLATE:-${ANAT_DIR}/sub-${SUBJECT}_ses-${SESSION}_acq-3D_space-MNI152NLin6Asym_res-2_desc-preproc_T1w.nii.gz}"

OUT_DIR="${OUT_DIR:-${LQT_STAGING}/sub-${SUBJECT}/inputs}"
OUT_MNI="${OUT_DIR}/lesion_mni152nlin6asym_res-2.nii.gz"

mkdir -p "${OUT_DIR}"

for f in "${LESION_T1W}" "${REF_T1W}" "${XFM_T1W_TO_MNI}" "${MNI_TEMPLATE}"; do
    if [[ ! -f "${f}" ]]; then
        echo "ERROR: missing ${f}" >&2
        exit 1
    fi
done

command -v antsApplyTransforms >/dev/null || {
    echo "ERROR: antsApplyTransforms not on PATH" >&2
    exit 1
}

echo "Lesion T1w: ${LESION_T1W}"
echo "MNI out:    ${OUT_MNI}"

antsApplyTransforms -d 3 \
    -i "${LESION_T1W}" \
    -r "${MNI_TEMPLATE}" \
    -t "${XFM_T1W_TO_MNI}" \
    -n GenericLabel \
    -o "${OUT_MNI}"

python3 - <<'PY' "${OUT_MNI}" "${OUT_DIR}/lesion_mni_provenance.json" "${SUBJECT}" "${SESSION}"
import json, sys
from pathlib import Path
out, prov, sub, ses = sys.argv[1:5]
Path(prov).write_text(
    json.dumps(
        {
            "subject": sub,
            "session": ses,
            "lesion_mni": out,
            "transform": "fmriprep from-T1w_to-MNI152NLin6Asym",
            "interpolation": "GenericLabel",
        },
        indent=2,
    )
    + "\n"
)
print(f"Wrote {prov}")
PY

echo "Done: ${OUT_MNI}"
