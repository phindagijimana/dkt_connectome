#!/bin/bash
# Boekel pp01 QSIPrep resubmit after TRT sidecar + trace-volume repair. Not leftover y. Not gold.
#SBATCH --job-name=uhat_boekel_pp01
#SBATCH --partition=interactive
#SBATCH --time=12:00:00
#SBATCH --cpus-per-task=8
#SBATCH --mem=32G
#SBATCH --exclude=smdodwork05
#SBATCH --output=/mnt/nfs/home/urmc-sh.rochester.edu/pndagiji/Documents/TrackTBI-Sub/dwi_pipeline/methods/mapping_uhat/work/sites_v1/logs/boekel_pp01_%j.out
#SBATCH --error=/mnt/nfs/home/urmc-sh.rochester.edu/pndagiji/Documents/TrackTBI-Sub/dwi_pipeline/methods/mapping_uhat/work/sites_v1/logs/boekel_pp01_%j.err
set -euo pipefail
UHAT=/mnt/nfs/home/urmc-sh.rochester.edu/pndagiji/Documents/TrackTBI-Sub/dwi_pipeline/methods/mapping_uhat
SD=/mnt/nfs/home/urmc-sh.rochester.edu/pndagiji/Documents/TrackTBI-Sub/dwi_pipeline/sample_data
SIF=/mnt/nfs/home/urmc-sh.rochester.edu/pndagiji/Documents/others/containers/qsiprep.sif
LIC=/mnt/nfs/home/urmc-sh.rochester.edu/pndagiji/Documents/others/data_mining/freesurfer/license.txt
SID=pp01
BIDS="${SD}/boekel_dwi_retest/bids"
OUT="${SD}/boekel_dwi_retest/results/sub-${SID}"
WORK="${OUT}/.work"
mkdir -p "${OUT}" "${WORK}" "${UHAT}/work/sites_v1/logs"
export APPTAINER_TMPDIR="/mnt/nfs/home/urmc-sh.rochester.edu/pndagiji/.cache/dkt-connectome/apptainer_tmp"
export SINGULARITY_TMPDIR="${APPTAINER_TMPDIR}"
mkdir -p "${APPTAINER_TMPDIR}"
echo "[BOEKEL] sub=${SID} host=$(hostname) trt_repaired $(date -Is)"
test -f "${SIF}"
test -d "${BIDS}/sub-${SID}"
apptainer run --cleanenv \
  -B "${BIDS}:/bids:ro" \
  -B "${OUT}:/out" \
  -B "${WORK}:/work" \
  -B "${LIC}:/opt/freesurfer/license.txt:ro" \
  "${SIF}" \
  /bids /out participant \
    --participant-label "${SID}" \
    --output-resolution 2 \
    --nthreads 8 --omp-nthreads 8 \
    --fs-license-file /opt/freesurfer/license.txt \
    --use-syn-sdc warn \
    --skip-bids-validation \
    --work-dir /work
echo "[BOEKEL] done ${SID} $(date -Is)"
