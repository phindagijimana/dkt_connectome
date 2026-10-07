#!/usr/bin/env bash
# One-subject LQT batch step: MNI lesion prep → (optional) MATLAB LQT → CSV export.
#
# Until LQT_ROOT is configured, runs staging only and writes RUN_LQT.pending.
#
# Usage:
#   run_lqt_one_subject.sh TBI011011
#
# Env:
#   LQT_ROOT      — clone of github.com/JDGriffis/lesion-quantification-toolkit
#   LQT_DIR       — final outputs for compare_sdc_methods.py
#   LQT_ATLAS     — LQT parcellation key (default: configure for DKT-78 — see LQT docs)
#   DRY_RUN=1     — prep only, skip MATLAB

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SUBJECT="${1:?subject ID}"

EXPERIMENT_ROOT="${EXPERIMENT_ROOT:-/mnt/nfs/Gugger_Lab/NIR/dwi_test_TBI_experiment}"
LQT_STAGING="${LQT_STAGING:-${EXPERIMENT_ROOT}/lqt_batch/staging}"
LQT_DIR="${LQT_DIR:-${EXPERIMENT_ROOT}/lqt_batch/outputs}"
DRY_RUN="${DRY_RUN:-0}"

SUB_STAGING="${LQT_STAGING}/sub-${SUBJECT}"
SUB_OUT="${LQT_DIR}/sub-${SUBJECT}"
mkdir -p "${SUB_STAGING}" "${SUB_OUT}"

bash "${SCRIPT_DIR}/prepare_lesion_mni_for_lqt.sh" "${SUBJECT}"

LESION_MNI="${SUB_STAGING}/inputs/lesion_mni152nlin6asym_res-2.nii.gz"
PENDING="${SUB_OUT}/RUN_LQT.pending"

if [[ -z "${LQT_ROOT:-}" || ! -d "${LQT_ROOT}" ]]; then
    cat > "${PENDING}" <<EOF
LQT_ROOT unset or missing.
Next: install Griffis 2021 LQT, set LQT_ROOT, pick atlas aligned to DKT-78 (see docs/papers/LQT.md).
Lesion MNI ready: ${LESION_MNI}
Then re-run: LQT_ROOT=/path/to/lqt bash ${SCRIPT_DIR}/run_lqt_one_subject.sh ${SUBJECT}
EOF
    echo "NOTE: LQT not run — wrote ${PENDING}"
    exit 0
fi

if [[ "${DRY_RUN}" == "1" ]]; then
    echo "DRY_RUN=1 — lesion MNI only."
    exit 0
fi

MATLAB_BIN="${MATLAB_BIN:-matlab}"
LQT_RUNNER="${SCRIPT_DIR}/lqt_run_subject.m"

if [[ ! -f "${LQT_RUNNER}" ]]; then
    echo "ERROR: missing ${LQT_RUNNER} (MATLAB driver)" >&2
    exit 1
fi

echo "=== LQT MATLAB (${SUBJECT}) ==="
"${MATLAB_BIN}" -batch "addpath('${LQT_ROOT}'); lqt_run_subject('${LESION_MNI}', '${SUB_OUT}', '${LQT_ATLAS:-DKT78}');"

python3 "${SCRIPT_DIR}/export_lqt_disconnection_csv.py" \
    --subject "${SUBJECT}" \
    --lqt-subject-dir "${SUB_OUT}" \
    --output "${SUB_OUT}/lqt_disconnection_matrix.csv"

rm -f "${PENDING}"
echo "LQT output: ${SUB_OUT}/lqt_disconnection_matrix.csv"
