#!/usr/bin/env bash
# One-subject LQT batch: MNI lesion prep → normative SDC (R or MATLAB LQT) → CSV.
#
# Recommended on HPC (no MATLAB license): LQT_BACKEND=r + remotes::install_github("jdwor/LQT")
# and LQT_PARCEL_NII pointing at MNI DKT-78 parcellation.
#
# Usage:
#   run_lqt_one_subject.sh TBI011011
#
# Env:
#   LQT_BACKEND   — auto | r | matlab | staging (default auto)
#   LQT_ROOT      — Griffis MATLAB toolkit path (matlab backend)
#   LQT_PARCEL_NII — MNI parcellation for R LQT (required for r backend)
#   LQT_DIR       — outputs for compare_sdc_methods.py
#   DRY_RUN=1     — MNI prep only

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=ensure_r_for_lqt.sh
source "${SCRIPT_DIR}/ensure_r_for_lqt.sh"
SUBJECT="${1:?subject ID}"

EXPERIMENT_ROOT="${EXPERIMENT_ROOT:-/mnt/nfs/Gugger_Lab/NIR/dwi_test_TBI_experiment}"
LQT_STAGING="${LQT_STAGING:-${EXPERIMENT_ROOT}/lqt_batch/staging}"
LQT_DIR="${LQT_DIR:-${EXPERIMENT_ROOT}/lqt_batch/outputs}"
LQT_BACKEND="${LQT_BACKEND:-auto}"
DRY_RUN="${DRY_RUN:-0}"

SUB_STAGING="${LQT_STAGING}/sub-${SUBJECT}"
SUB_OUT="${LQT_DIR}/sub-${SUBJECT}"
LQT_ATLAS_DIR="${LQT_ATLAS_DIR:-${EXPERIMENT_ROOT}/lqt_batch/atlas}"
DEFAULT_PARCEL="${LQT_ATLAS_DIR}/dkt78_mni152nlin6asym_res-2.nii.gz"
if [[ -z "${LQT_PARCEL_NII:-}" && -f "${DEFAULT_PARCEL}" ]]; then
    export LQT_PARCEL_NII="${DEFAULT_PARCEL}"
fi
mkdir -p "${SUB_STAGING}" "${SUB_OUT}"

bash "${SCRIPT_DIR}/prepare_lesion_mni_for_lqt.sh" "${SUBJECT}"

LESION_MNI="${SUB_STAGING}/inputs/lesion_mni152nlin6asym_res-2.nii.gz"
PENDING="${SUB_OUT}/RUN_LQT.pending"

if [[ "${DRY_RUN}" == "1" || "${LQT_BACKEND}" == "staging" ]]; then
    echo "MNI lesion ready: ${LESION_MNI}"
    exit 0
fi

_r_lqt_ready() {
    [[ -n "${LQT_PARCEL_NII:-}" && -f "${LQT_PARCEL_NII}" ]] \
        && paper2b_Rscript -e 'quit(status=if (requireNamespace("LQT", quietly=TRUE)) 0 else 1)' 2>/dev/null
}

_matlab_lqt_ready() {
    [[ -n "${LQT_ROOT:-}" && -d "${LQT_ROOT}" ]] && command -v "${MATLAB_BIN:-matlab}" >/dev/null
}

_run_r() {
    echo "=== LQT R (jdwor/LQT) sub-${SUBJECT} ==="
    export LQT_PARCEL_NII
    paper2b_Rscript "${SCRIPT_DIR}/run_lqt_r_one_subject.R" "${SUBJECT}" "${LESION_MNI}" "${SUB_OUT}"
}

_run_matlab() {
    local runner="${SCRIPT_DIR}/lqt_run_subject.m"
    [[ -f "${runner}" ]] || { echo "ERROR: missing ${runner}" >&2; return 1; }
    echo "=== LQT MATLAB sub-${SUBJECT} ==="
    "${MATLAB_BIN:-matlab}" -batch \
        "addpath('${LQT_ROOT}'); lqt_run_subject('${LESION_MNI}', '${SUB_OUT}', '${LQT_ATLAS:-DKT78}');"
    python3 "${SCRIPT_DIR}/export_lqt_disconnection_csv.py" \
        --subject "${SUBJECT}" \
        --lqt-subject-dir "${SUB_OUT}" \
        --output "${SUB_OUT}/lqt_disconnection_matrix.csv"
}

backend="${LQT_BACKEND}"
if [[ "${backend}" == "auto" ]]; then
    if _r_lqt_ready; then
        backend=r
    elif _matlab_lqt_ready; then
        backend=matlab
    else
        backend=none
    fi
fi

case "${backend}" in
    r)
        _run_r
        ;;
    matlab)
        _matlab_lqt_ready || { echo "ERROR: LQT_ROOT / matlab not ready" >&2; exit 1; }
        _run_matlab
        ;;
    none)
        cat > "${PENDING}" <<EOF
Normative SDC not run yet. MNI lesion: ${LESION_MNI}

Recommended (HPC): R LQT
  remotes::install_github("jdwor/LQT")
  export LQT_PARCEL_NII=/path/to/dkt78_mni.nii.gz
  export LQT_BACKEND=r
  bash ${SCRIPT_DIR}/run_lqt_one_subject.sh ${SUBJECT}

Alternative: Griffis MATLAB LQT
  export LQT_ROOT=/path/to/lesion-quantification-toolkit
  export LQT_BACKEND=matlab
EOF
        echo "NOTE: wrote ${PENDING}"
        exit 0
        ;;
    *)
        echo "ERROR: unknown LQT_BACKEND=${LQT_BACKEND}" >&2
        exit 1
        ;;
esac

rm -f "${PENDING}"
echo "LQT output: ${SUB_OUT}/lqt_disconnection_matrix.csv"
