#!/bin/bash
# Within-site mini-scale QSIPrep (Kirby list). Interactive. Not full scale.
#SBATCH --job-name=uhat_mini_qsi
#SBATCH --partition=interactive
#SBATCH --time=12:00:00
#SBATCH --cpus-per-task=8
#SBATCH --mem=32G
#SBATCH --array=1-4%2
#SBATCH --exclude=smdodwork05
#SBATCH --output=/mnt/nfs/home/urmc-sh.rochester.edu/pndagiji/Documents/TrackTBI-Sub/dwi_pipeline/methods/mapping_uhat/work/sites_v1/logs/mini_qsi_%A_%a.out
#SBATCH --error=/mnt/nfs/home/urmc-sh.rochester.edu/pndagiji/Documents/TrackTBI-Sub/dwi_pipeline/methods/mapping_uhat/work/sites_v1/logs/mini_qsi_%A_%a.err
set -euo pipefail
UHAT=/mnt/nfs/home/urmc-sh.rochester.edu/pndagiji/Documents/TrackTBI-Sub/dwi_pipeline/methods/mapping_uhat
SD=/mnt/nfs/home/urmc-sh.rochester.edu/pndagiji/Documents/TrackTBI-Sub/dwi_pipeline/sample_data
SIF=/mnt/nfs/home/urmc-sh.rochester.edu/pndagiji/Documents/others/containers/qsiprep.sif
LIC=/mnt/nfs/home/urmc-sh.rochester.edu/pndagiji/Documents/others/data_mining/freesurfer/license.txt
LIST="${UHAT}/work/sites_v1/subjects_within_site_kirby.txt"
LINE="$(sed -n "${SLURM_ARRAY_TASK_ID}p" "${LIST}")"
KIND="${LINE%% *}"
SID="${LINE##* }"
BIDS="${SD}/kirby21/bids"
OUT="${SD}/kirby21/results/sub-${SID}"
WORK="${OUT}/.work"
mkdir -p "${OUT}" "${WORK}" "${UHAT}/work/sites_v1/logs"
export APPTAINER_TMPDIR="/mnt/nfs/home/urmc-sh.rochester.edu/pndagiji/.cache/dkt-connectome/apptainer_tmp"
export SINGULARITY_TMPDIR="${APPTAINER_TMPDIR}"
mkdir -p "${APPTAINER_TMPDIR}"
echo "[MINI-QSI] task=${SLURM_ARRAY_TASK_ID} ${KIND} sub=${SID} host=$(hostname) $(date -Is)"
# skip if both dwirefs exist
DW1="${OUT}/sub-${SID}/ses-1/dwi/sub-${SID}_ses-1_space-T1w_dwiref.nii.gz"
DW2="${OUT}/sub-${SID}/ses-2/dwi/sub-${SID}_ses-2_space-T1w_dwiref.nii.gz"
if [[ -f "${DW1}" && -f "${DW2}" ]]; then
  echo "[MINI-QSI] already have dwiref both sessions; skip"
  exit 0
fi
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
# free work dir after success to protect disk
if [[ -f "${DW1}" && -f "${DW2}" ]]; then
  rm -rf "${WORK}"
  echo "[MINI-QSI] removed work dir"
fi
echo "[MINI-QSI] done ${SID} $(date -Is)"
