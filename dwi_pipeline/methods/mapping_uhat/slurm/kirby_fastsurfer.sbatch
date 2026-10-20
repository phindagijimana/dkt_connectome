#!/bin/bash
# Retest-pair FastSurfer on ses-1 T1 (default Kirby KKI849; RETEST_DATASET/RETEST_SID override). Not leftover y. Not gold. Not subject.sh.
#SBATCH --job-name=uhat_kirby_fs
#SBATCH --partition=interactive
#SBATCH --time=12:00:00
#SBATCH --cpus-per-task=8
#SBATCH --mem=32G
#SBATCH --exclude=smdodwork05
#SBATCH --output=/mnt/nfs/home/urmc-sh.rochester.edu/pndagiji/Documents/TrackTBI-Sub/dwi_pipeline/methods/mapping_uhat/work/sites_v1/logs/kirby_fs_%j.out
#SBATCH --error=/mnt/nfs/home/urmc-sh.rochester.edu/pndagiji/Documents/TrackTBI-Sub/dwi_pipeline/methods/mapping_uhat/work/sites_v1/logs/kirby_fs_%j.err
set -euo pipefail
UHAT=/mnt/nfs/home/urmc-sh.rochester.edu/pndagiji/Documents/TrackTBI-Sub/dwi_pipeline/methods/mapping_uhat
SD=/mnt/nfs/home/urmc-sh.rochester.edu/pndagiji/Documents/TrackTBI-Sub/dwi_pipeline/sample_data
SIF=/mnt/nfs/home/urmc-sh.rochester.edu/pndagiji/Documents/others/containers/fastsurfer_latest.sif
LIC=/mnt/nfs/home/urmc-sh.rochester.edu/pndagiji/Documents/others/data_mining/freesurfer/license.txt
DS="${RETEST_DATASET:-kirby21}"
SID="${RETEST_SID:-KKI849}"
T1="${SD}/${DS}/bids/sub-${SID}/ses-1/anat/sub-${SID}_ses-1_T1w.nii.gz"
DW1="${SD}/${DS}/results/sub-${SID}/sub-${SID}/ses-1/dwi/sub-${SID}_ses-1_space-T1w_dwiref.nii.gz"
DW2="${SD}/${DS}/results/sub-${SID}/sub-${SID}/ses-2/dwi/sub-${SID}_ses-2_space-T1w_dwiref.nii.gz"
FS="${SD}/${DS}/freeze/sub-${SID}/freesurfer"
APARC="${FS}/sub-${SID}/mri/aparc+aseg.mgz"
export APPTAINER_TMPDIR="/mnt/nfs/home/urmc-sh.rochester.edu/pndagiji/.cache/dkt-connectome/apptainer_tmp"
export SINGULARITY_TMPDIR="${APPTAINER_TMPDIR}"
mkdir -p "${FS}" "${APPTAINER_TMPDIR}" "${UHAT}/work/sites_v1/logs"
echo "[KIRBY-FS] sub=${SID} host=$(hostname) $(date -Is)"
test -f "${SIF}"
test -f "${T1}"
test -f "${DW1}"
test -f "${DW2}"
if [[ -f "${APARC}" ]]; then
  echo "[KIRBY-FS] already present ${APARC}"
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
      echo "[KIRBY-FS] linked aparc+aseg.mgz -> $(basename "${src}")"
      break
    fi
  done
fi
test -f "${APARC}"
echo "[KIRBY-FS] done ${APARC} $(date -Is)"
