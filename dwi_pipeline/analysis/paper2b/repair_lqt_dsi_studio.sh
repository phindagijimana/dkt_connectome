#!/usr/bin/env bash
# Unzip LQT DSI_studio.zip via local temp (NFS unzip often fails on large archives).
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=ensure_r_for_lqt.sh
source "${SCRIPT_DIR}/ensure_r_for_lqt.sh"

EXTDATA="${R_LIBS_USER}/LQT/extdata"
DSI_URL="${LQT_DSI_STUDIO_URL:-https://ndownloader.figshare.com/files/31708106?private_link=c67b652f2056867a5648}"
MIN_ZIP_BYTES="${LQT_DSI_MIN_ZIP_BYTES:-5000000}"
WORKDIR="${TMPDIR:-/tmp}/lqt_dsi_repair_$$"
DEST="${EXTDATA}/DSI_studio"

mkdir -p "${WORKDIR}" "${EXTDATA}"
trap 'rm -rf "${WORKDIR}"' EXIT

_zip_ok() {
    local z="$1"
    [[ -f "${z}" ]] && unzip -t "${z}" >/dev/null 2>&1
}

ZIP="${EXTDATA}/DSI_studio.zip"
rm -f "${EXTDATA}/DSI_studio.zip" 2>/dev/null || true

if ! _zip_ok "${ZIP}"; then
    echo "Downloading DSI_studio.zip via R (Figshare) to ${WORKDIR}..."
    paper2b_Rscript -e "
      dest <- '${WORKDIR}/DSI_studio.zip'
      ok <- FALSE
      for (meth in c('libcurl', 'auto', 'wget')) {
        res <- try(
          utils::download.file(
            '${DSI_URL}',
            dest,
            mode = 'wb',
            quiet = TRUE,
            method = meth
          ),
          silent = TRUE
        )
        if (!inherits(res, 'try-error') && file.exists(dest)) {
          sz <- file.info(dest)\$size
          if (!is.na(sz) && sz >= ${MIN_ZIP_BYTES}) {
            ok <- TRUE
            break
          }
        }
      }
      if (!ok) stop('DSI_studio.zip download failed or too small')
    "
    ZIP="${WORKDIR}/DSI_studio.zip"
fi
if ! _zip_ok "${ZIP}"; then
    echo "ERROR: DSI_studio.zip missing or corrupt after download" >&2
    exit 1
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

if ! paper2b_Rscript -e "
  lib <- Sys.getenv('R_LIBS_USER', unset='');
  if (nzchar(lib)) .libPaths(c(lib, .libPaths()));
  source('${SCRIPT_DIR}/lqt_templates_ok.R');
  quit(status=if (lqt_dsi_ok()) 0 else 1)
"; then
    echo "ERROR: DSI Studio still not found under ${DEST}" >&2
    exit 1
fi
echo "DSI Studio repair OK"
