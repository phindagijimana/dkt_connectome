#!/bin/bash
# V2 GPU VoxelMorph point estimate on interactive L40S.
# Not p(phi|images). Not hat{U}. Not leftover ECE. Do not push through radial_4.
#SBATCH --job-name=uhat_V2_gpu
#SBATCH --partition=interactive
#SBATCH --gres=gpu:l40s.6g:1
#SBATCH --time=01:00:00
#SBATCH --cpus-per-task=4
#SBATCH --mem=16G
#SBATCH --output=/mnt/nfs/home/urmc-sh.rochester.edu/pndagiji/Documents/TrackTBI-Sub/dwi_pipeline/methods/mapping_uhat/work/V2/logs/V2_%j.out
#SBATCH --error=/mnt/nfs/home/urmc-sh.rochester.edu/pndagiji/Documents/TrackTBI-Sub/dwi_pipeline/methods/mapping_uhat/work/V2/logs/V2_%j.err
set -euo pipefail
UHAT=/mnt/nfs/home/urmc-sh.rochester.edu/pndagiji/Documents/TrackTBI-Sub/dwi_pipeline/methods/mapping_uhat
VENV="${UHAT}/work/V2/venv/bin/python"
mkdir -p "${UHAT}/work/V2/logs" "${UHAT}/work/V2/gpu_phihat"
echo "[V2] host=$(hostname) job=${SLURM_JOB_ID:-none} gres=${SLURM_JOB_GPUS:-none} $(date -Is)"
echo "[V2] CUDA_VISIBLE_DEVICES=${CUDA_VISIBLE_DEVICES:-unset}"
if command -v nvidia-smi >/dev/null 2>&1; then
  nvidia-smi -L
else
  echo "[V2] nvidia-smi not on PATH"
fi
"${VENV}" -c 'import torch; print("cuda", torch.cuda.is_available(), "n", torch.cuda.device_count(), "name", torch.cuda.get_device_name(0) if torch.cuda.is_available() else None)'
"${VENV}" -u "${UHAT}/v2_gpu_run.py"
echo "[V2] done $(date -Is)"
