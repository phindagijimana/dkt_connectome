#!/bin/bash
# Other-site 2WK FastSurfer only. One C later. Not leftover y. Not 6MO. Not gold.
#SBATCH --job-name=uhat_2wk_fs
#SBATCH --partition=interactive
#SBATCH --time=12:00:00
#SBATCH --cpus-per-task=8
#SBATCH --mem=32G
#SBATCH --array=1-7%1
#SBATCH --exclude=smdodwork05
#SBATCH --output=/mnt/nfs/home/urmc-sh.rochester.edu/pndagiji/Documents/TrackTBI-Sub/dwi_pipeline/methods/mapping_uhat/work/sites_v1/logs/sites_2wk_fs_%A_%a.out
#SBATCH --error=/mnt/nfs/home/urmc-sh.rochester.edu/pndagiji/Documents/TrackTBI-Sub/dwi_pipeline/methods/mapping_uhat/work/sites_v1/logs/sites_2wk_fs_%A_%a.err
set -euo pipefail
UHAT=/mnt/nfs/home/urmc-sh.rochester.edu/pndagiji/Documents/TrackTBI-Sub/dwi_pipeline/methods/mapping_uhat
SD=/mnt/nfs/home/urmc-sh.rochester.edu/pndagiji/Documents/TrackTBI-Sub/dwi_pipeline/sample_data
SIF=/mnt/nfs/home/urmc-sh.rochester.edu/pndagiji/Documents/others/containers/fastsurfer_latest.sif
LIC=/mnt/nfs/home/urmc-sh.rochester.edu/pndagiji/Documents/others/data_mining/freesurfer/license.txt
SID="$(sed -n "${SLURM_ARRAY_TASK_ID}p" "${UHAT}/work/sites_v1/subjects_2wk.txt")"
shopt -s nullglob
T1S=("${SD}/tracktbi_othersite/bids/sub-${SID}/ses-2WK/anat/"*T1w.nii.gz)
DWS=("${SD}/tracktbi_othersite/results/sub-${SID}_2wk/sub-${SID}/ses-2WK/dwi/"*_space-T1w_dwiref.nii.gz)
T1="${T1S[0]}"
FS="${SD}/tracktbi_othersite/freeze/sub-${SID}/freesurfer"
APARC="${FS}/sub-${SID}/mri/aparc+aseg.mgz"
export APPTAINER_TMPDIR="/mnt/nfs/home/urmc-sh.rochester.edu/pndagiji/.cache/dkt-connectome/apptainer_tmp"
export SINGULARITY_TMPDIR="${APPTAINER_TMPDIR}"
mkdir -p "${FS}" "${APPTAINER_TMPDIR}" "${UHAT}/work/sites_v1/logs"
echo "[2WK-FS] task=${SLURM_ARRAY_TASK_ID} sub=${SID} host=$(hostname) $(date -Is)"
test -f "${SIF}"
test -n "${T1}" && test -f "${T1}"
test "${#DWS[@]}" -ge 1
if [[ -f "${APARC}" ]]; then
  echo "[2WK-FS] already present ${APARC}"
  exit 0
fi
apptainer exec --cleanenv --containall \
  -B "$(dirname "${T1}")":/t1w_input:ro \
  -B "${FS}":/sd \
  -B "${LIC}":/fs_license/license.txt:ro \
  "${SIF}" \
  /fastsurfer/run_fastsurfer.sh \
    --fs_license /fs_license/license.txt \
    --sid "sub-${SID}" \
    --sd /sd \
    --t1 "/t1w_input/$(basename "${T1}")" \
    --parallel \
    --threads 8 \
    --device cpu
MRI="${FS}/sub-${SID}/mri"
if [[ ! -f "${APARC}" ]]; then
  for src in "${MRI}/aparc.DKTatlas+aseg.mapped.mgz" "${MRI}/aparc.DKTatlas+aseg.mgz"; do
    if [[ -f "${src}" ]]; then
      ln -sfn "$(basename "${src}")" "${APARC}"
      break
    fi
  done
fi
test -f "${APARC}"
echo "[2WK-FS] done ${SID} $(date -Is) one C later. Not leftover."
