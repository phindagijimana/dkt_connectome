#!/bin/bash
# V2 synth-probs: torch use_probs train on synthetics, then sample inventory.
# Not leftover. Not hat{U}. Do not push through radial_4.
#SBATCH --job-name=uhat_V2_sp
#SBATCH --partition=interactive
#SBATCH --gres=gpu:l40s.6g:1
#SBATCH --time=04:00:00
#SBATCH --cpus-per-task=4
#SBATCH --mem=24G
#SBATCH --output=/mnt/nfs/home/urmc-sh.rochester.edu/pndagiji/Documents/TrackTBI-Sub/dwi_pipeline/methods/mapping_uhat/work/V2/logs/V2sp_%j.out
#SBATCH --error=/mnt/nfs/home/urmc-sh.rochester.edu/pndagiji/Documents/TrackTBI-Sub/dwi_pipeline/methods/mapping_uhat/work/V2/logs/V2sp_%j.err
set -euo pipefail
UHAT=/mnt/nfs/home/urmc-sh.rochester.edu/pndagiji/Documents/TrackTBI-Sub/dwi_pipeline/methods/mapping_uhat
VENV="${UHAT}/work/V2/venv/bin/python"
mkdir -p "${UHAT}/work/V2/logs" "${UHAT}/work/V2/synth_probs"
echo "[V2SP] host=$(hostname) job=${SLURM_JOB_ID:-none} $(date -Is)"
if command -v nvidia-smi >/dev/null 2>&1; then nvidia-smi -L; fi
"${VENV}" -c 'import torch; print("cuda", torch.cuda.is_available(), torch.cuda.get_device_name(0) if torch.cuda.is_available() else None)'
"${VENV}" -u "${UHAT}/v2_synth_probs.py"
echo "[V2SP] done $(date -Is)"
