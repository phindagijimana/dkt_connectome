#!/bin/bash
#SBATCH -J dlsurfer_sv2c
#SBATCH -p interactive
#SBATCH --gres=gpu:l40s.24g:1
#SBATCH -c 8
#SBATCH --mem=64G
#SBATCH -t 10:00:00
#SBATCH -o %x_%j.out
#SBATCH -e %x_%j.err
#
# Finish SUGAR + V2C only (CortexMorph ±LIT already passed on job 191968).
set -euo pipefail

DLS="${SLURM_SUBMIT_DIR:-}"
if [[ -z "$DLS" || ! -f "${DLS}/env/cluster_containers.sh" ]]; then
  DLS="/mnt/nfs/home/urmc-sh.rochester.edu/pndagiji/Documents/TrackTBI-Sub/dwi_pipeline/methods/others_methods/preprocessing/DL/dlsurfer"
fi
cd "$DLS"
# shellcheck disable=SC1091
source "${DLS}/env/cluster_containers.sh"
export PATH="${DLS}/env/bin:${PATH}"

export SUGAR_ROOT="${HOME}/Documents/others/SUGAR"
export SUGAR_MODEL_PATH="${SUGAR_ROOT}/pretrained"
export V2C_ROOT="${HOME}/Documents/others/Vox2Cortex"
WITH_LIT_SD="${DLS}/work/eg_gpu_core_lesion"
NO_LIT_SD="/mnt/nfs/home/urmc-sh.rochester.edu/pndagiji/Documents/TrackTBI-Sub/dwi_pipeline/analysis/gugger_eg_lit/fastsurfer_inpainting/native_lesion_mask/fastsurfer_v2.6/subjects"
SID=sub-EG
OUT="${DLS}/work/phase3_gates"
ENV="$OUT/envs/p3"
V2C_ENV="$OUT/envs/v2c"
SHIM="${DLS}/scripts/shims"
export CUDA_HOME="${CUDA_HOME:-/usr/local/cuda-12.6}"
export PATH="${CUDA_HOME}/bin:${PATH}"
export TORCH_CUDA_ARCH_LIST="${TORCH_CUDA_ARCH_LIST:-8.9}"
PYI=(-i https://pypi.org/simple --trusted-host pypi.org --trusted-host files.pythonhosted.org)

nvidia-smi || true
export PATH="$ENV/bin:$PATH"
export PYTHONPATH="${SHIM}:${SUGAR_ROOT}:${PYTHONPATH:-}"

REF_FS="/mnt/nfs/home/urmc-sh.rochester.edu/pndagiji/Documents/TrackTBI-Sub/dwi_pipeline/analysis/gugger_eg_lit/fastsurfer_inpainting/standalone/fastsurfer_v2.6/subjects/fsaverage"
FSD_ARG="${SUGAR_FSD:-/mnt/nfs/home/urmc-sh.rochester.edu/pndagiji/Documents/others/data_mining/freesurfer}"
export SUGAR_FSD="$FSD_ARG"
if [[ ! -d "$FSD_ARG/subjects/fsaverage6/surf" ]]; then
  echo "FATAL: SUGAR needs ICO templates under $FSD_ARG/subjects/fsaverage{3..6}" >&2
  exit 2
fi
for SD in "$WITH_LIT_SD" "$NO_LIT_SD"; do
  [[ -d "$SD/$SID" && ! -e "$SD/fsaverage" && -d "$REF_FS" ]] && ln -sfn "$REF_FS" "$SD/fsaverage"
done

echo "=== SUGAR lh ±LIT ==="
set +e
export SUGAR_ROOT
python "${DLS}/scripts/run_sugar_predict.py" --sd "$WITH_LIT_SD" --out "$OUT/sugar_with_lit" --sid "$SID" \
  --hemi lh --device cuda --model-path "$SUGAR_MODEL_PATH" --fsd "$FSD_ARG"
rc=$?
mkdir -p "$OUT/sugar_with_lit/$SID/scripts"
[[ $rc -eq 0 ]] && echo ok > "$OUT/sugar_with_lit/$SID/scripts/dlsurfer_sugar.done" || echo $rc > "$OUT/sugar_with_lit/$SID/scripts/dlsurfer_sugar.exit"

python "${DLS}/scripts/run_sugar_predict.py" --sd "$NO_LIT_SD" --out "$OUT/sugar_no_lit" --sid "$SID" \
  --hemi lh --device cuda --model-path "$SUGAR_MODEL_PATH" --fsd "$FSD_ARG"
rc=$?
mkdir -p "$OUT/sugar_no_lit/$SID/scripts"
[[ $rc -eq 0 ]] && echo ok > "$OUT/sugar_no_lit/$SID/scripts/dlsurfer_sugar.done" || echo $rc > "$OUT/sugar_no_lit/$SID/scripts/dlsurfer_sugar.exit"
set -e

echo "=== V2C pytorch3d + inference ==="
set +e
[[ -x "$V2C_ENV/bin/python" ]] || python3 -m venv "$V2C_ENV"
"$V2C_ENV/bin/pip" install -U pip wheel setuptools ninja "${PYI[@]}"
"$V2C_ENV/bin/python" -c "import torch" 2>/dev/null || \
  "$V2C_ENV/bin/pip" install "${PYI[@]}" torch torchvision --index-url https://download.pytorch.org/whl/cu124
"$V2C_ENV/bin/pip" install "${PYI[@]}" nibabel numpy scipy pandas tqdm trimesh wandb pyyaml yacs \
  einops scikit-image pillow matplotlib fvcore iopath
if ! "$V2C_ENV/bin/python" -c "from pytorch3d.structures import Meshes" 2>/dev/null; then
  FORCE_CUDA=1 "$V2C_ENV/bin/pip" install "${PYI[@]}" --no-build-isolation \
    "git+https://github.com/facebookresearch/pytorch3d.git@stable" \
    || FORCE_CUDA=1 "$V2C_ENV/bin/pip" install "${PYI[@]}" --no-build-isolation \
    "git+https://github.com/fabibo3/pytorch3d.git"
fi
"$V2C_ENV/bin/pip" install "${PYI[@]}" torchio monai geomloss || true

export V2C_PYTHON="$V2C_ENV/bin/python"
export V2C_RAW_DATA_DIR="$OUT/v2c_raw"
export WANDB_MODE=disabled
mkdir -p "$OUT/v2c_raw"
python "${DLS}/scripts/prep_v2c_subject.py" \
  --subjects-dir "$WITH_LIT_SD" --sid "$SID" --raw-dir "$OUT/v2c_raw" \
  --fs-sif "${SIF_FREESURFER:-}" --fs-license "${FS_LICENSE:-}"
python "${DLS}/scripts/prep_v2c_subject.py" \
  --subjects-dir "$NO_LIT_SD" --sid "$SID" --out-sid "${SID}_nolit" --raw-dir "$OUT/v2c_raw" \
  --fs-sif "${SIF_FREESURFER:-}" --fs-license "${FS_LICENSE:-}"

mkdir -p "$V2C_ROOT/experiments"
[[ -d "$V2C_ROOT/experiments/V2C-Flow-S-ADNI" ]] || \
  cp -a "$V2C_ROOT/vox2organ/pretrained_models/V2C-Flow-S-ADNI" "$V2C_ROOT/experiments/V2C-Flow-S-ADNI"

run_v2c_arm () {
  local arm_sid="$1" out_arm="$2"
  echo "$arm_sid" > "$OUT/v2c_raw/dlsurfer_test.txt"
  : > "$OUT/v2c_raw/dlsurfer_train.txt"
  : > "$OUT/v2c_raw/dlsurfer_val.txt"
  mkdir -p "$out_arm/$SID/scripts"
  (
    cd "$V2C_ROOT/vox2organ"
    export V2C_RAW_DATA_DIR="$OUT/v2c_raw" WANDB_MODE=disabled
    "$V2C_PYTHON" main.py --test -n V2C-Flow-S-ADNI --dataset dlsurfer_t1
  )
  local rc=$?
  echo "$rc" > "$out_arm/$SID/scripts/dlsurfer_v2c.exit"
  [[ $rc -eq 0 ]] && echo ok > "$out_arm/$SID/scripts/dlsurfer_v2c.done"
  return $rc
}
run_v2c_arm "$SID" "$OUT/v2c_with_lit"
run_v2c_arm "${SID}_nolit" "$OUT/v2c_no_lit"
set -e

python "${DLS}/scripts/score_phase3_gates.py" --root "$OUT" --sid "$SID" --out "$OUT/phase3_gates_score.json"
cat "$OUT/phase3_gates_score.json"
echo DONE
