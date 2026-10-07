#!/usr/bin/env bash
# Build shared DKT-78 parcellation in MNI152NLin6Asym (res-2) for R/MATLAB LQT.
#
# Source: disconnectome nodes.nii.gz (78 labels, matrix row order) resampled to
# fMRIPrep desc-preproc T1w, then warped with the same transform as lesion MNI prep.
#
# Usage:
#   prepare_dkt78_mni_parcellation.sh [REFERENCE_SUBJECT]
#
# Env: same as prepare_lesion_mni_for_lqt.sh + CONTAINER_CONNECTOME

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=ensure_pipeline_ants.sh
source "${SCRIPT_DIR}/ensure_pipeline_ants.sh"

SUBJECT="${1:-TBI011011}"
SESSION="${SESSION:-2WK}"

REPO="$(cd "${SCRIPT_DIR}/../../.." && pwd)"
EXPERIMENT_ROOT="${EXPERIMENT_ROOT:-/mnt/nfs/Gugger_Lab/NIR/dwi_test_TBI_experiment}"
DWI_CONNECTOMES="${DWI_CONNECTOMES:-${EXPERIMENT_ROOT}/validation_v030/arms/neurolit-lesion/connectomes}"
FMRIPREP_DIR="${FMRIPREP_DIR:-${EXPERIMENT_ROOT}/fmri_derivatives_inpaint/fmriprep}"
LQT_ATLAS_DIR="${LQT_ATLAS_DIR:-${EXPERIMENT_ROOT}/lqt_batch/atlas}"

CONTAINER_CONNECTOME="${CONTAINER_CONNECTOME:-}"
for cand in \
    "/mnt/nfs/home/urmc-sh.rochester.edu/pndagiji/Documents/others/containers/dkt_connectome.sif" \
    "/mnt/nfs/home/URMC-SH/pndagiji/Documents/others/containers/dkt_connectome.sif"; do
    if [[ -z "${CONTAINER_CONNECTOME}" && -f "${cand}" ]]; then
        CONTAINER_CONNECTOME="${cand}"
    fi
done

NODES_DWI="${DWI_CONNECTOMES}/sub-${SUBJECT}/disconnectome/nodes.nii.gz"
T1W="${FMRIPREP_DIR}/sub-${SUBJECT}/ses-${SESSION}/anat/sub-${SUBJECT}_ses-${SESSION}_acq-3D_desc-preproc_T1w.nii.gz"
XFM_T1W_TO_MNI="${FMRIPREP_DIR}/sub-${SUBJECT}/ses-${SESSION}/anat/sub-${SUBJECT}_ses-${SESSION}_acq-3D_from-T1w_to-MNI152NLin6Asym_mode-image_xfm.h5"
MNI_TEMPLATE="${FMRIPREP_DIR}/sub-${SUBJECT}/ses-${SESSION}/anat/sub-${SUBJECT}_ses-${SESSION}_acq-3D_space-MNI152NLin6Asym_res-2_desc-preproc_T1w.nii.gz"

OUT_MNI="${LQT_ATLAS_DIR}/dkt78_mni152nlin6asym_res-2.nii.gz"
STAGING="${LQT_ATLAS_DIR}/.staging/sub-${SUBJECT}"
NODES_T1W="${STAGING}/dkt78_nodes_desc-preproc_T1w.nii.gz"
LUT="${REPO}/dwi_pipeline/containers/connectome/mrtrix_lut/fs_dkt.txt"

mkdir -p "${LQT_ATLAS_DIR}" "${STAGING}"

for f in "${NODES_DWI}" "${T1W}" "${XFM_T1W_TO_MNI}" "${MNI_TEMPLATE}" "${LUT}"; do
    [[ -f "${f}" ]] || { echo "ERROR: missing ${f}" >&2; exit 1; }
done
[[ -f "${CONTAINER_CONNECTOME}" ]] || {
    echo "ERROR: set CONTAINER_CONNECTOME (dkt_connectome.sif)" >&2
    exit 1
}

echo "=== DKT-78 MNI atlas (reference sub-${SUBJECT}) ==="
echo "  nodes (DWI grid): ${NODES_DWI}"
echo "  T1w template:     ${T1W}"
echo "  MNI out:          ${OUT_MNI}"

apptainer exec --bind /mnt/nfs:/mnt/nfs "${CONTAINER_CONNECTOME}" bash -lc \
    "mrtransform -force '${NODES_DWI}' -template '${T1W}' -interp nearest '${NODES_T1W}'"

pipeline_antsApplyTransforms -d 3 \
    -i "${NODES_T1W}" \
    -r "${MNI_TEMPLATE}" \
    -t "${XFM_T1W_TO_MNI}" \
    -n GenericLabel \
    -o "${OUT_MNI}"

python3 "${SCRIPT_DIR}/validate_dkt78_mni_atlas.py" \
    --atlas-nii "${OUT_MNI}" \
    --lut "${LUT}" \
    --output-json "${LQT_ATLAS_DIR}/dkt78_atlas_provenance.json" \
    --reference-subject "${SUBJECT}" \
    --reference-session "${SESSION}"

cp -f "${LUT}" "${LQT_ATLAS_DIR}/fs_dkt.txt"

echo
echo "LQT_PARCEL_NII=${OUT_MNI}"
echo "Export: export LQT_PARCEL_NII=${OUT_MNI}"
