#!/bin/bash
# Deprecated alias — use submit_dwi_35.sh
set -euo pipefail
exec "$(cd "$(dirname "$0")" && pwd)/submit_dwi_35.sh" "$@"
