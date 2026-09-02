#!/usr/bin/env bash
# Step 4.1 entrypoint inside dkt_connectome.sif (baked scripts, native MRtrix/ANTs).
set -euo pipefail
export DKT_DISCONNECTOME_NATIVE=1
export PATH="/opt/mrtrix3-latest/bin:/opt/ants/bin:/opt/freesurfer/bin:${PATH}"
exec python3 /opt/dkt/run_disconnectome.py --native-tools "$@"
