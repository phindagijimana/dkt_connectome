#!/bin/bash
# Slurm job: pull FreeSurfer Apptainer image (pinned in workflow/config/config.yaml).
#SBATCH --job-name=dkt_pull_fs
#SBATCH --output=logs/pull_freesurfer_%j.out
#SBATCH --error=logs/pull_freesurfer_%j.err
#SBATCH --time=04:00:00
#SBATCH --cpus-per-task=2
#SBATCH --mem=8G

set -euo pipefail

REPO="${SLURM_SUBMIT_DIR:-$(pwd)}"
if [[ -d "${REPO}/dwi_pipeline" ]]; then
  DWI="${REPO}/dwi_pipeline"
else
  DWI="${REPO}"
fi

CACHE="${DKT_CONTAINER_CACHE:-${HOME}/.cache/dkt-connectome/containers}"
mkdir -p "${DWI}/logs" "${CACHE}"

module load apptainer 2>/dev/null || true

echo "=== pull FreeSurfer SIF -> ${CACHE} ==="
bash "${DWI}/scripts/pull_containers.sh" \
  --cache "${CACHE}" \
  --only freesurfer \
  --write-config \
  --config "${DWI}/workflow/config/config.local.yaml"

echo "=== done ==="
