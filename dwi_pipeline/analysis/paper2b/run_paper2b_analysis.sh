#!/usr/bin/env bash
# Paper 2B imaging-only analysis batch.
#
# Usage:
#   bash run_paper2b_analysis.sh
#   bash run_paper2b_analysis.sh TBI011011 TBI011007 ...

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO="$(cd "$SCRIPT_DIR/../../.." && pwd)"
FMRI_SCRIPTS="$REPO/fMRI_pipeline/scripts"

EXPERIMENT_ROOT="${EXPERIMENT_ROOT:-/mnt/nfs/Gugger_Lab/NIR/dwi_test_TBI_experiment}"
DWI_CONNECTOMES="${DWI_CONNECTOMES:-${EXPERIMENT_ROOT}/validation_v030/arms/neurolit-lesion/connectomes}"
OUT_ROOT="${OUT_ROOT:-${EXPERIMENT_ROOT}/fmri_derivatives_inpaint}"
LQT_DIR="${LQT_DIR:-}"
SESSION="${SESSION:-2WK}"
ANALYSIS_OUT="${ANALYSIS_OUT:-${OUT_ROOT}/analysis/paper2b}"

if [[ $# -gt 0 ]]; then
    SUBJECTS=("$@")
else
    SUBJECTS=(
        TBI011011 TBI011204 TBI011007 TBI011021
        TBI011029 TBI011140 TBI021030
    )
fi

SUBJ_ARGS=()
for s in "${SUBJECTS[@]}"; do
    SUBJ_ARGS+=(--subject "$s")
done

LQT_ARGS=()
if [[ -n "${LQT_DIR}" && -d "${LQT_DIR}" ]]; then
    LQT_ARGS=(--lqt-dir "${LQT_DIR}")
    echo "LQT dir: ${LQT_DIR}"
else
    echo "NOTE: LQT_DIR unset or missing — RQ1 will list patient-only rows."
fi

mkdir -p "${ANALYSIS_OUT}"
echo "=== Paper 2B analysis ==="
echo "  DWI_CONNECTOMES: ${DWI_CONNECTOMES}"
echo "  OUT_ROOT:         ${OUT_ROOT}"
echo "  ANALYSIS_OUT:     ${ANALYSIS_OUT}"
echo "  N subjects:       ${#SUBJECTS[@]}"
echo

python3 "${SCRIPT_DIR}/compare_sdc_methods.py" \
    --dwi-connectomes "${DWI_CONNECTOMES}" \
    "${LQT_ARGS[@]}" \
    --output-dir "${ANALYSIS_OUT}" \
    "${SUBJ_ARGS[@]}"

python3 "${SCRIPT_DIR}/compare_sc_fc_association.py" \
    --dwi-connectomes "${DWI_CONNECTOMES}" \
    --out-root "${OUT_ROOT}" \
    --fc-stream xcp_d \
    --session "${SESSION}" \
    "${LQT_ARGS[@]}" \
    --output-dir "${ANALYSIS_OUT}" \
    "${SUBJ_ARGS[@]}"

python3 "${SCRIPT_DIR}/compare_sc_fc_association.py" \
    --dwi-connectomes "${DWI_CONNECTOMES}" \
    --out-root "${OUT_ROOT}" \
    --fc-stream fmristroke \
    --session "${SESSION}" \
    "${LQT_ARGS[@]}" \
    --output-dir "${ANALYSIS_OUT}" \
    "${SUBJ_ARGS[@]}"

if [[ -x "${FMRI_SCRIPTS}/run_pilot_fc_analysis.sh" ]]; then
    echo
    echo "--- fMRI pilot QC (streams + BOLD provenance) ---"
    ANALYSIS_OUT="${OUT_ROOT}/analysis/pilot_fc" \
        bash "${FMRI_SCRIPTS}/run_pilot_fc_analysis.sh" "${SUBJECTS[@]}"
fi

echo
echo "Paper 2B outputs: ${ANALYSIS_OUT}/"
ls -la "${ANALYSIS_OUT}/" 2>/dev/null || true
