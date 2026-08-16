#!/usr/bin/env bash
# Preflight for clinicians: tools, FS license, step containers, optional dry-run.
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
exec python3 "${SCRIPT_DIR}/container_install.py" doctor "$@"
