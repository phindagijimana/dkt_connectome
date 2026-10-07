#!/usr/bin/env bash
# Serial LQT Figshare template download (flock). Required before parallel LQT array.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=ensure_r_for_lqt.sh
source "${SCRIPT_DIR}/ensure_r_for_lqt.sh"

EXPERIMENT_ROOT="${EXPERIMENT_ROOT:-/mnt/nfs/Gugger_Lab/NIR/dwi_test_TBI_experiment}"
MARKER="${EXPERIMENT_ROOT}/lqt_batch/.lqt_templates_ready"
LOCK="${EXPERIMENT_ROOT}/lqt_batch/.template_download.lock"
EXTDATA="${R_LIBS_USER}/LQT/extdata"

paper2b_Rscript -e 'quit(status=if (requireNamespace("LQT", quietly=TRUE)) 0 else 1)'

_templates_ok() {
  export LQT_SCRIPT_DIR="${SCRIPT_DIR}"
  paper2b_Rscript -e "
    source('${SCRIPT_DIR}/lqt_templates_ok.R');
    quit(status=if (lqt_templates_ok()) 0 else 1)
  " 2>/dev/null
}

if [[ -f "${MARKER}" ]] && _templates_ok; then
    echo "LQT templates already installed (${MARKER})"
    exit 0
fi
rm -f "${MARKER}"

if [[ "${LQT_CLEAN_TEMPLATES:-0}" == "1" && -d "${EXTDATA}" ]]; then
    echo "Cleaning partial LQT extdata under ${EXTDATA}"
    rm -f "${EXTDATA}"/*.zip 2>/dev/null || true
    rm -rf \
        "${EXTDATA}/Tractography_Atlas" \
        "${EXTDATA}/DSI_studio" \
        "${EXTDATA}/Schaefer_Yeo_Plus_Subcort" \
        "${EXTDATA}/Other_Atlases" \
        2>/dev/null || true
fi

mkdir -p "$(dirname "${LOCK}")"
(
    flock -w 7200 9 || {
        echo "ERROR: could not acquire template download lock (${LOCK})" >&2
        exit 1
    }
    if [[ -f "${MARKER}" ]] && _templates_ok; then
        exit 0
    fi
    export LQT_SCRIPT_DIR="${SCRIPT_DIR}"
    set +e
    paper2b_Rscript "${SCRIPT_DIR}/install_lqt_templates.R"
    rc=$?
    set -e
    if [[ "$(uname -s)" == "Linux" ]]; then
        # shellcheck source=ensure_dsi_studio_for_lqt.sh
        source "${SCRIPT_DIR}/ensure_dsi_studio_for_lqt.sh"
    elif (( rc == 2 )) || ! _templates_ok; then
        echo "Running DSI Studio unzip repair (local temp)..."
        bash "${SCRIPT_DIR}/repair_lqt_dsi_studio.sh"
    fi
    _templates_ok || {
        echo "ERROR: LQT templates still incomplete" >&2
        exit 1
    }
    touch "${MARKER}"
) 9>"${LOCK}"

echo "LQT templates ready: ${MARKER}"
