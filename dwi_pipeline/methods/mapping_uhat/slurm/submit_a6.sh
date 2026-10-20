#!/usr/bin/env bash
# Submit A6 labels-only array + overnight continue. Absolute paths only. Not hat{U}.
set -euo pipefail
UHAT=/mnt/nfs/home/urmc-sh.rochester.edu/pndagiji/Documents/TrackTBI-Sub/dwi_pipeline/methods/mapping_uhat
mkdir -p "${UHAT}/work/a6/logs"
ARR=$(sbatch --parsable "${UHAT}/slurm/a6_array.sbatch")
CONT=$(sbatch --parsable --dependency="afterany:${ARR}" "${UHAT}/slurm/a6_continue.sbatch")
echo "A6 array ${ARR}  continue ${CONT}"
echo "${ARR}" > "${UHAT}/work/a6/slurm_array.id"
echo "${CONT}" > "${UHAT}/work/a6/slurm_continue.id"
