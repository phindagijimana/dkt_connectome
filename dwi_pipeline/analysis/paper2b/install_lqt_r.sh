#!/usr/bin/env bash
# One-time install of jdwor/LQT for Paper 2B (interactive node with R ≥ 4.0).
set -euo pipefail
command -v R >/dev/null || { echo "ERROR: R not on PATH" >&2; exit 1; }
R -e 'if (!requireNamespace("remotes", quietly=TRUE)) install.packages("remotes", repos="https://cloud.r-project.org")'
R -e 'remotes::install_github("jdwor/LQT")'
Rscript -e 'stopifnot(requireNamespace("LQT", quietly=TRUE)); message("LQT R package OK")'
