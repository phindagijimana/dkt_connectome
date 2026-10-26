#!/bin/bash
# Fallback: same as run_fastsurfer when host srun/brun not in SIF
exec "$(dirname "$0")/run_fastsurfer.sh" "$@"
