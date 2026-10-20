#!/bin/bash
# Other-site 2WK QSIPrep only. Not leftover y. Not gold. Not 6MO.
#SBATCH --job-name=uhat_sites_2wk
#SBATCH --partition=interactive
#SBATCH --time=12:00:00
#SBATCH --cpus-per-task=8
#SBATCH --mem=32G
#SBATCH --array=1-7%2
#SBATCH --exclude=smdodwork05
#SBATCH --output=/mnt/nfs/home/urmc-sh.rochester.edu/pndagiji/Documents/TrackTBI-Sub/dwi_pipeline/methods/mapping_uhat/work/sites_v1/logs/qsiprep_%A_%a.out
#SBATCH --error=/mnt/nfs/home/urmc-sh.rochester.edu/pndagiji/Documents/TrackTBI-Sub/dwi_pipeline/methods/mapping_uhat/work/sites_v1/logs/qsiprep_%A_%a.err
set -euo pipefail
UHAT=/mnt/nfs/home/urmc-sh.rochester.edu/pndagiji/Documents/TrackTBI-Sub/dwi_pipeline/methods/mapping_uhat
BIDS=/mnt/nfs/home/urmc-sh.rochester.edu/pndagiji/Documents/TrackTBI-Sub/dwi_pipeline/sample_data/tracktbi_othersite/bids
ROOT=/mnt/nfs/home/urmc-sh.rochester.edu/pndagiji/Documents/TrackTBI-Sub/dwi_pipeline/sample_data/tracktbi_othersite/results
SIF=/mnt/nfs/home/urmc-sh.rochester.edu/pndagiji/Documents/others/containers/qsiprep.sif
LIC=/mnt/nfs/home/urmc-sh.rochester.edu/pndagiji/Documents/others/data_mining/freesurfer/license.txt
SID="$(sed -n "${SLURM_ARRAY_TASK_ID}p" "${UHAT}/work/sites_v1/subjects_2wk.txt")"
OUT="${ROOT}/sub-${SID}_2wk"
WORK="${OUT}/.work"
FILT="${UHAT}/work/sites_v1/bids_filter_2wk.json"
mkdir -p "${OUT}" "${WORK}" "${UHAT}/work/sites_v1/logs"
export APPTAINER_TMPDIR="/mnt/nfs/home/urmc-sh.rochester.edu/pndagiji/.cache/dkt-connectome/apptainer_tmp"
export SINGULARITY_TMPDIR="${APPTAINER_TMPDIR}"
mkdir -p "${APPTAINER_TMPDIR}"
echo "[SITES] task=${SLURM_ARRAY_TASK_ID} sub=${SID} host=$(hostname) $(date -Is)"
if [[ ! -f "${SIF}" ]]; then
  echo "missing qsiprep.sif" >&2
  exit 2
fi
apptainer run --cleanenv \
  -B "${BIDS}:/bids:ro" \
  -B "${OUT}:/out" \
  -B "${WORK}:/work" \
  -B "${LIC}:/opt/freesurfer/license.txt:ro" \
  -B "${FILT}:/filter.json:ro" \
  "${SIF}" \
  /bids /out participant \
    --participant-label "${SID}" \
    --bids-filter-file /filter.json \
    --output-resolution 2 \
    --nthreads 8 --omp-nthreads 8 \
    --fs-license-file /opt/freesurfer/license.txt \
    --use-syn-sdc warn \
    --skip-bids-validation \
    --work-dir /work
echo "[SITES] done ${SID} $(date -Is)"
