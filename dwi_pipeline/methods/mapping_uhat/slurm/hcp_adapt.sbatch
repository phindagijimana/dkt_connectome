#!/bin/bash
# HCP preprocessed → QSIPrep-like layout (ses-2 rigid to ses-1 T1). Not leftover y. Not gold.
#SBATCH --job-name=uhat_hcp_adapt
#SBATCH --partition=interactive
#SBATCH --time=04:00:00
#SBATCH --cpus-per-task=4
#SBATCH --mem=16G
#SBATCH --exclude=smdodwork05
#SBATCH --output=/mnt/nfs/home/urmc-sh.rochester.edu/pndagiji/Documents/TrackTBI-Sub/dwi_pipeline/methods/mapping_uhat/work/sites_v1/logs/hcp_adapt_%A_%a.out
#SBATCH --error=/mnt/nfs/home/urmc-sh.rochester.edu/pndagiji/Documents/TrackTBI-Sub/dwi_pipeline/methods/mapping_uhat/work/sites_v1/logs/hcp_adapt_%A_%a.err
set -euo pipefail
UHAT=/mnt/nfs/home/urmc-sh.rochester.edu/pndagiji/Documents/TrackTBI-Sub/dwi_pipeline/methods/mapping_uhat
LIST="${UHAT}/work/sites_v1/subjects_hcp.txt"
SID="$(sed -n "${SLURM_ARRAY_TASK_ID}p" "${LIST}")"
export APPTAINER_TMPDIR=/mnt/nfs/home/urmc-sh.rochester.edu/pndagiji/.cache/dkt-connectome/apptainer_tmp
export SINGULARITY_TMPDIR="${APPTAINER_TMPDIR}"
mkdir -p "${APPTAINER_TMPDIR}" "${UHAT}/work/sites_v1/logs"
echo "[HCP-ADAPT] task=${SLURM_ARRAY_TASK_ID} sub=${SID} host=$(hostname) $(date -Is)"
test -n "${SID}"
python3 -u "${UHAT}/work/sites_v1/hcp_to_qsiprep.py" "${SID}"
echo "[HCP-ADAPT] done ${SID} $(date -Is)"
