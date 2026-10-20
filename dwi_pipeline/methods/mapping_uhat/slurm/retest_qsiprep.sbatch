#!/bin/bash
# Same-day retest QSIPrep (Kirby + Boekel A/B). Not leftover y. Not gold.
#SBATCH --job-name=uhat_retest_qsi
#SBATCH --partition=interactive
#SBATCH --time=12:00:00
#SBATCH --cpus-per-task=8
#SBATCH --mem=32G
#SBATCH --array=1-2%2
#SBATCH --exclude=smdodwork05
#SBATCH --output=/mnt/nfs/home/urmc-sh.rochester.edu/pndagiji/Documents/TrackTBI-Sub/dwi_pipeline/methods/mapping_uhat/work/sites_v1/logs/retest_qsi_%A_%a.out
#SBATCH --error=/mnt/nfs/home/urmc-sh.rochester.edu/pndagiji/Documents/TrackTBI-Sub/dwi_pipeline/methods/mapping_uhat/work/sites_v1/logs/retest_qsi_%A_%a.err
set -euo pipefail
UHAT=/mnt/nfs/home/urmc-sh.rochester.edu/pndagiji/Documents/TrackTBI-Sub/dwi_pipeline/methods/mapping_uhat
SD=/mnt/nfs/home/urmc-sh.rochester.edu/pndagiji/Documents/TrackTBI-Sub/dwi_pipeline/sample_data
SIF=/mnt/nfs/home/urmc-sh.rochester.edu/pndagiji/Documents/others/containers/qsiprep.sif
LIC=/mnt/nfs/home/urmc-sh.rochester.edu/pndagiji/Documents/others/data_mining/freesurfer/license.txt
LINE="$(sed -n "${SLURM_ARRAY_TASK_ID}p" "${UHAT}/work/sites_v1/subjects_retest.txt")"
KIND="${LINE%% *}"
SID="${LINE##* }"
if [[ "${KIND}" == "kirby" ]]; then
  BIDS="${SD}/kirby21/bids"
  OUT="${SD}/kirby21/results/sub-${SID}"
else
  BIDS="${SD}/boekel_dwi_retest/bids"
  OUT="${SD}/boekel_dwi_retest/results/sub-${SID}"
fi
WORK="${OUT}/.work"
mkdir -p "${OUT}" "${WORK}" "${UHAT}/work/sites_v1/logs"
export APPTAINER_TMPDIR="/mnt/nfs/home/urmc-sh.rochester.edu/pndagiji/.cache/dkt-connectome/apptainer_tmp"
export SINGULARITY_TMPDIR="${APPTAINER_TMPDIR}"
mkdir -p "${APPTAINER_TMPDIR}"
echo "[RETEST] task=${SLURM_ARRAY_TASK_ID} ${KIND} sub=${SID} host=$(hostname) $(date -Is)"
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
echo "[RETEST] done ${KIND} ${SID} $(date -Is)"
