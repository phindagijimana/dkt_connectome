#!/bin/bash
# Single-subject retest QSIPrep. Env: RETEST_KIND=kirby|boekel, RETEST_SID=….
# Not leftover y. Not gold. Dir 8 scale descriptive.
#SBATCH --job-name=uhat_scale_qsi
#SBATCH --partition=general
#SBATCH --time=24:00:00
#SBATCH --cpus-per-task=8
#SBATCH --mem=32G
#SBATCH --exclude=smdodwork05
#SBATCH --output=/mnt/nfs/home/urmc-sh.rochester.edu/pndagiji/Documents/TrackTBI-Sub/dwi_pipeline/methods/mapping_uhat/work/sites_v1/logs/scale_qsi_%j.out
#SBATCH --error=/mnt/nfs/home/urmc-sh.rochester.edu/pndagiji/Documents/TrackTBI-Sub/dwi_pipeline/methods/mapping_uhat/work/sites_v1/logs/scale_qsi_%j.err
set -euo pipefail
UHAT=/mnt/nfs/home/urmc-sh.rochester.edu/pndagiji/Documents/TrackTBI-Sub/dwi_pipeline/methods/mapping_uhat
SD=/mnt/nfs/home/urmc-sh.rochester.edu/pndagiji/Documents/TrackTBI-Sub/dwi_pipeline/sample_data
SIF=/mnt/nfs/home/urmc-sh.rochester.edu/pndagiji/Documents/others/containers/qsiprep.sif
LIC=/mnt/nfs/home/urmc-sh.rochester.edu/pndagiji/Documents/others/data_mining/freesurfer/license.txt
: "${RETEST_KIND:?}" "${RETEST_SID:?}"
SID="${RETEST_SID}"
if [[ "${RETEST_KIND}" == "kirby" ]]; then
  BIDS="${SD}/kirby21/bids"
  OUT="${SD}/kirby21/results/sub-${SID}"
elif [[ "${RETEST_KIND}" == "boekel" ]]; then
  BIDS="${SD}/boekel_dwi_retest/bids"
  OUT="${SD}/boekel_dwi_retest/results/sub-${SID}"
else
  echo "bad RETEST_KIND=${RETEST_KIND}" >&2
  exit 2
fi
WORK="${OUT}/.work"
mkdir -p "${OUT}" "${WORK}" "${UHAT}/work/sites_v1/logs"
export APPTAINER_TMPDIR="/mnt/nfs/home/urmc-sh.rochester.edu/pndagiji/.cache/dkt-connectome/apptainer_tmp"
export SINGULARITY_TMPDIR="${APPTAINER_TMPDIR}"
mkdir -p "${APPTAINER_TMPDIR}"
echo "[SCALE-QSI] ${RETEST_KIND} sub=${SID} host=$(hostname) $(date -Is)"
test -f "${SIF}"
test -d "${BIDS}/sub-${SID}"
# skip if both dwirefs already exist
DW1="${OUT}/sub-${SID}/ses-1/dwi/sub-${SID}_ses-1_space-T1w_dwiref.nii.gz"
DW2="${OUT}/sub-${SID}/ses-2/dwi/sub-${SID}_ses-2_space-T1w_dwiref.nii.gz"
if [[ -f "${DW1}" && -f "${DW2}" ]]; then
  echo "[SCALE-QSI] dwiref both sessions present — skip"
  exit 0
fi
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
echo "[SCALE-QSI] done ${RETEST_KIND} ${SID} $(date -Is)"
