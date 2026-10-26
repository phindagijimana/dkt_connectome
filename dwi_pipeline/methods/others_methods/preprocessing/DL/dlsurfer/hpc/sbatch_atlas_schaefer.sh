#!/bin/bash
#SBATCH -J dlsurfer_schaefer
#SBATCH -p interactive
#SBATCH -c 4
#SBATCH --mem=16G
#SBATCH -t 02:00:00
#SBATCH -o %x_%j.out
#SBATCH -e %x_%j.err
#
# Project Schaefer 400/17 onto an existing SUBJECTS_DIR (needs sphere.reg).
set -euo pipefail
DLS="${SLURM_SUBMIT_DIR:-}"
if [[ -z "$DLS" || ! -f "${DLS}/env/cluster_containers.sh" ]]; then
  DLS="/mnt/nfs/home/urmc-sh.rochester.edu/pndagiji/Documents/TrackTBI-Sub/dwi_pipeline/methods/others_methods/preprocessing/DL/dlsurfer"
fi
cd "$DLS"
# shellcheck disable=SC1091
source "${DLS}/env/cluster_containers.sh"
export PATH="${DLS}/env/bin:${PATH}"
export PYTHONPATH="${DLS}${PYTHONPATH:+:$PYTHONPATH}"
export SUBJECTS_DIR="${SUBJECTS_DIR:-/mnt/nfs/home/urmc-sh.rochester.edu/pndagiji/Documents/TrackTBI-Sub/dwi_pipeline/analysis/gugger_eg_lit/fastsurfer_inpainting/standalone/fastsurfer_v2.6/subjects}"
SID="${SID:-sub-EG}"
# fsaverage must be visible to mri_surf2surf
export SUBJECTS_DIR
# Ensure fsaverage symlink from FS SIF subjects if missing
if [[ ! -d "${SUBJECTS_DIR}/fsaverage" ]]; then
  echo "WARN: no fsaverage in $SUBJECTS_DIR — bind FS subjects or copy fsaverage"
fi

python -m dlsurfer run --profile atlas-schaefer \
  --t1 /dev/null \
  --sd "$SUBJECTS_DIR" --sid "$SID" \
  --fs-license "$FS_LICENSE" --device cpu --execute

ls -la "${SUBJECTS_DIR}/${SID}/label/"*schaefer* || true
echo DONE
