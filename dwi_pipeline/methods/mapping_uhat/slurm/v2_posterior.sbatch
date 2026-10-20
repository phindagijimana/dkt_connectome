#!/bin/bash
# V2 posterior attempt: load published VxmDense. Sample only if use_probs.
# SynthMorph brains is a trained point estimate. Not hat{U}. Not leftover ECE.
#SBATCH --job-name=uhat_V2_post
#SBATCH --partition=interactive
#SBATCH --gres=gpu:l40s.12g:1
#SBATCH --time=04:00:00
#SBATCH --cpus-per-task=8
#SBATCH --mem=48G
#SBATCH --output=/mnt/nfs/home/urmc-sh.rochester.edu/pndagiji/Documents/TrackTBI-Sub/dwi_pipeline/methods/mapping_uhat/work/V2/logs/V2post_%j.out
#SBATCH --error=/mnt/nfs/home/urmc-sh.rochester.edu/pndagiji/Documents/TrackTBI-Sub/dwi_pipeline/methods/mapping_uhat/work/V2/logs/V2post_%j.err
set -euo pipefail
UHAT=/mnt/nfs/home/urmc-sh.rochester.edu/pndagiji/Documents/TrackTBI-Sub/dwi_pipeline/methods/mapping_uhat
VENV="${UHAT}/work/V2/tfvenv/bin/python"
mkdir -p "${UHAT}/work/V2/logs" "${UHAT}/work/V2/posterior"
export TF_CPP_MIN_LOG_LEVEL=2
export CUDA_VISIBLE_DEVICES="${CUDA_VISIBLE_DEVICES:-}"
echo "[V2POST] host=$(hostname) job=${SLURM_JOB_ID:-none} $(date -Is)"
if command -v nvidia-smi >/dev/null 2>&1; then nvidia-smi -L; fi
"${VENV}" -c 'import tensorflow as tf; print("tf", tf.__version__, "gpu", tf.config.list_physical_devices("GPU"))'
"${VENV}" -u "${UHAT}/v2_posterior_attempt.py"
echo "[V2POST] done $(date -Is)"
