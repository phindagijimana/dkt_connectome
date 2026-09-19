#!/usr/bin/env bash
# Run factorial sensitivity analysis on TBI011011 (or custom experiment root).
#
# Usage:
#   bash dwi_pipeline/scripts/run_tbi011011_factorial_analysis.sh
#   EXP=/path/to/experiment SUBJECT=TBI011011 bash dwi_pipeline/scripts/run_tbi011011_factorial_analysis.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
EXP="${EXP:-/mnt/nfs/Gugger_Lab/NIR/dwi_test_TBI_experiment/sub-TBI011011_fastsurfer_experiment}"
SUBJECT="${SUBJECT:-TBI011011}"

exec python3.12 "${SCRIPT_DIR}/analyze_factorial_arms.py" \
  --experiment-root "${EXP}" \
  --subject "${SUBJECT}"
