#!/usr/bin/env bash
# Single-container BIDS App entrypoint for the meta-SIF / host install.
# Usage (inside image or with PYTHONPATH=dlsurfer root):
#   entrypoint_bids.sh /bids /out participant --participant_label 01 …
set -euo pipefail
ROOT="${DLSURFER_ROOT:-/opt/dlsurfer}"
export PYTHONPATH="${ROOT}${PYTHONPATH:+:$PYTHONPATH}"
export PATH="${ROOT}/env/bin:${PATH}"
exec python -m dlsurfer bids-app "$@"
