#!/usr/bin/env bash
# One-time install of jdwor/LQT for Paper 2B (host R, module, or Apptainer rocker).
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=ensure_r_for_lqt.sh
source "${SCRIPT_DIR}/ensure_r_for_lqt.sh"

LIB="${R_LIBS_USER:?R_LIBS_USER unset}"
rm -rf "${LIB}"/00LOCK-* 2>/dev/null || true
# Clean partial installs after failed attempts (image or R version changes).
if [[ "${LQT_R_CLEAN_LIB:-1}" == "1" ]]; then
    rm -rf "${LIB}"/* 2>/dev/null || true
fi
paper2b_R -e "dir.create('${LIB}', recursive=TRUE, showWarnings=FALSE); .libPaths(c('${LIB}', .libPaths()))"
# Binary CRAN deps can mismatch container R; compile core C++ stack from source.
paper2b_R -e "install.packages(c('Rcpp','RcppEigen'), lib='${LIB}', repos='https://cloud.r-project.org', type='source', Ncpus=2L)"
paper2b_R -e "install.packages('remotes', lib='${LIB}', repos='https://cloud.r-project.org', type='source')"
paper2b_R -e "remotes::install_github('jdwor/LQT', lib='${LIB}', upgrade='never', force=TRUE)"
paper2b_Rscript -e ".libPaths(c('${LIB}', .libPaths())); stopifnot(requireNamespace('LQT', quietly=TRUE)); message('LQT R package OK')"
