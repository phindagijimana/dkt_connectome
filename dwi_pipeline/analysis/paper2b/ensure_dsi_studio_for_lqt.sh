#!/usr/bin/env bash
# Linux HPC: LQT bundles macOS DSI Studio only — provide Apptainer wrapper as dsi_path.
#
# Usage: source ensure_dsi_studio_for_lqt.sh   (sets and exports LQT_DSI_PATH)
# Or:    bash ensure_dsi_studio_for_lqt.sh     (prints path on stdout)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=ensure_r_for_lqt.sh
source "${SCRIPT_DIR}/ensure_r_for_lqt.sh"

EXPERIMENT_ROOT="${EXPERIMENT_ROOT:-/mnt/nfs/Gugger_Lab/NIR/dwi_test_TBI_experiment}"
BIN="${EXPERIMENT_ROOT}/lqt_batch/bin"
CONT_DIR="${EXPERIMENT_ROOT}/lqt_batch/containers"
SIF="${LQT_DSI_SIF:-${CONT_DIR}/dsistudio.sif}"
IMAGE="${LQT_DSI_IMAGE:-docker://dsistudio/dsistudio:latest}"
WRAPPER="${LQT_DSI_WRAPPER:-${BIN}/dsi_studio}"
MARKER="${EXPERIMENT_ROOT}/lqt_batch/.lqt_dsi_wrapper"

if [[ -n "${LQT_DSI_PATH:-}" && -x "${LQT_DSI_PATH}" ]]; then
    echo "${LQT_DSI_PATH}"
    return 0 2>/dev/null || exit 0
fi

if [[ -f "${MARKER}" ]]; then
    read -r _saved < "${MARKER}"
    if [[ -n "${_saved}" && -x "${_saved}" ]]; then
        export LQT_DSI_PATH="${_saved}"
        echo "${LQT_DSI_PATH}"
        return 0 2>/dev/null || exit 0
    fi
fi

if [[ "$(uname -s)" != "Linux" ]]; then
    echo "NOTE: non-Linux host — set LQT_DSI_PATH to a local dsi_studio binary" >&2
    return 1 2>/dev/null || exit 1
fi

_APPTAINER=""
command -v apptainer >/dev/null && _APPTAINER=apptainer
command -v singularity >/dev/null && [[ -z "${_APPTAINER}" ]] && _APPTAINER=singularity
if [[ -z "${_APPTAINER}" ]]; then
    echo "ERROR: Apptainer/Singularity required for DSI Studio on Linux" >&2
    return 127 2>/dev/null || exit 127
fi

mkdir -p "${BIN}" "${CONT_DIR}"

if [[ ! -f "${SIF}" ]]; then
    echo "Pulling DSI Studio SIF: ${IMAGE} -> ${SIF}"
    "${_APPTAINER}" pull "${SIF}" "${IMAGE}"
fi

if ! "${_APPTAINER}" exec "${SIF}" dsi_studio --help >/dev/null 2>&1; then
    echo "ERROR: dsi_studio not runnable in ${SIF}" >&2
    return 1 2>/dev/null || exit 1
fi

cat > "${WRAPPER}" <<EOF
#!/usr/bin/env bash
set -euo pipefail
exec ${_APPTAINER} exec --bind /mnt/nfs:/mnt/nfs "${SIF}" dsi_studio "\$@"
EOF
chmod +x "${WRAPPER}"

echo "${WRAPPER}" > "${MARKER}"
export LQT_DSI_PATH="${WRAPPER}"
echo "LQT_DSI_PATH=${LQT_DSI_PATH} (Apptainer wrapper)"
echo "${LQT_DSI_PATH}"
