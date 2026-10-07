#!/usr/bin/env bash
# Unzip LQT DSI_studio.zip via local temp (NFS unzip often fails on large archives).
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=ensure_r_for_lqt.sh
source "${SCRIPT_DIR}/ensure_r_for_lqt.sh"

EXTDATA="${R_LIBS_USER}/LQT/extdata"
DSI_URL="${LQT_DSI_STUDIO_URL:-https://figshare.com/ndownloader/files/31708106?private_link=c67b652f2056867a5648}"
WORKDIR="${TMPDIR:-/tmp}/lqt_dsi_repair_$$"
DEST="${EXTDATA}/DSI_studio"

mkdir -p "${WORKDIR}" "${EXTDATA}"
trap 'rm -rf "${WORKDIR}"' EXIT

_zip_ok() {
    local z="$1"
    [[ -f "${z}" ]] && unzip -t "${z}" >/dev/null 2>&1
}

ZIP="${EXTDATA}/DSI_studio.zip"
if ! _zip_ok "${ZIP}"; then
    echo "Downloading DSI_studio.zip to ${WORKDIR}..."
    curl -fsSL --retry 3 --retry-delay 5 -o "${WORKDIR}/DSI_studio.zip" "${DSI_URL}"
    ZIP="${WORKDIR}/DSI_studio.zip"
fi

echo "Extracting DSI Studio to ${DEST} (via ${WORKDIR})..."
rm -rf "${DEST}"
mkdir -p "${WORKDIR}/extract"
if command -v unzip >/dev/null 2>&1; then
    unzip -q "${ZIP}" -d "${WORKDIR}/extract"
else
    paper2b_Rscript -e "utils::unzip('${ZIP}', exdir='${WORKDIR}/extract')"
fi

shopt -s nullglob
entries=("${WORKDIR}/extract"/*)
if ((${#entries[@]} == 1)) && [[ -d "${entries[0]}" ]]; then
    mv "${entries[0]}" "${DEST}"
else
    mkdir -p "${DEST}"
    mv "${WORKDIR}/extract"/* "${DEST}/"
fi

if ! paper2b_Rscript -e "source('${SCRIPT_DIR}/lqt_templates_ok.R'); quit(status=if (lqt_dsi_ok()) 0 else 1)" 2>/dev/null; then
    echo "ERROR: DSI Studio still not found under ${DEST}" >&2
    exit 1
fi
echo "DSI Studio repair OK"
