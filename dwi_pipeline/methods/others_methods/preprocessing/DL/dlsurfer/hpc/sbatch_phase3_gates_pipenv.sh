#!/bin/bash
#SBATCH -J dlsurfer_p3g
#SBATCH -p interactive
#SBATCH --gres=gpu:l40s.24g:1
#SBATCH -c 8
#SBATCH --mem=64G
#SBATCH -t 12:00:00
#SBATCH -o %x_%j.out
#SBATCH -e %x_%j.err
#
# Finish V2C / SUGAR / CortexMorph ±LIT gates (SynthSeg-PC excluded).
# Job-local venv (SUGAR docker SIF blocked by /tmp noexec on this cluster).
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

export SUGAR_ROOT="${HOME}/Documents/others/SUGAR"
export SUGAR_MODEL_PATH="${SUGAR_ROOT}/pretrained"
export SUGAR_SIF=""
export CORTEXMORPH_ROOT="${HOME}/Documents/others/CortexMorph"
export V2C_ROOT="${HOME}/Documents/others/Vox2Cortex"

# with-LIT = GPU core-lesion (inpainted); no-LIT = native lesion-mask FastSurfer (full surf)
WITH_LIT_SD="${DLS}/work/eg_gpu_core_lesion"
NO_LIT_SD="/mnt/nfs/home/urmc-sh.rochester.edu/pndagiji/Documents/TrackTBI-Sub/dwi_pipeline/analysis/gugger_eg_lit/fastsurfer_inpainting/native_lesion_mask/fastsurfer_v2.6/subjects"
SID=sub-EG
OUT="${DLS}/work/phase3_gates"
ENV="$OUT/envs/p3"
V2C_ENV="$OUT/envs/v2c"
SHIM="${DLS}/scripts/shims"
mkdir -p "$OUT"/{sugar_with_lit,sugar_no_lit,cm_with_lit,cm_no_lit,v2c_with_lit,v2c_no_lit,v2c_raw,envs}

nvidia-smi || true
export CUDA_HOME="${CUDA_HOME:-/usr/local/cuda-12.6}"
export PATH="${CUDA_HOME}/bin:${PATH}"
export LD_LIBRARY_PATH="${CUDA_HOME}/lib64:${LD_LIBRARY_PATH:-}"

PYI=(-i https://pypi.org/simple --trusted-host pypi.org --trusted-host files.pythonhosted.org)

# ---- shared p3 env: SUGAR + CortexMorph ----
if [[ ! -x "$ENV/bin/python" ]]; then
  python3 -m venv "$ENV"
fi
"$ENV/bin/pip" install -U pip wheel setuptools "${PYI[@]}"
if ! "$ENV/bin/python" -c "import torch" 2>/dev/null; then
  "$ENV/bin/pip" install "${PYI[@]}" torch --index-url https://download.pytorch.org/whl/cu124
fi
"$ENV/bin/pip" install "${PYI[@]}" "numpy<2" nibabel scipy pandas tqdm scikit-learn scikit-image \
  networkx pillow
# skip rebuilding pytorch3d from source (knn shim is enough for SUGAR; saves ~30min)
"$ENV/bin/pip" install "${PYI[@]}" torch_geometric || true
"$ENV/bin/pip" install "${PYI[@]}" --no-deps nnunet==1.7.1 batchgenerators || true
# nnunet transitive deps used at import
"$ENV/bin/pip" install "${PYI[@]}" batchgenerators scikit-image || true

export PATH="$ENV/bin:$PATH"
# Always prefer knn shim for SUGAR (avoids 30+ min pytorch3d build; chunked cdist)
export PYTHONPATH="${SHIM}:${SUGAR_ROOT}:${CORTEXMORPH_ROOT}:${PYTHONPATH:-}"
echo "[sugar] PYTHONPATH shim+SUGAR+CortexMorph"

REF_FS="/mnt/nfs/home/urmc-sh.rochester.edu/pndagiji/Documents/TrackTBI-Sub/dwi_pipeline/analysis/gugger_eg_lit/fastsurfer_inpainting/standalone/fastsurfer_v2.6/subjects/fsaverage"
for SD in "$WITH_LIT_SD" "$NO_LIT_SD"; do
  if [[ -d "$SD/$SID" && ! -e "$SD/fsaverage" && -d "$REF_FS" ]]; then
    ln -sfn "$REF_FS" "$SD/fsaverage"
  fi
done

FSD_ARG="${SUGAR_FSD:-/mnt/nfs/home/urmc-sh.rochester.edu/pndagiji/Documents/others/data_mining/freesurfer}"
export SUGAR_FSD="$FSD_ARG"
if [[ ! -d "$FSD_ARG/subjects/fsaverage6/surf" ]]; then
  echo "FATAL: SUGAR needs ICO templates under $FSD_ARG/subjects/fsaverage{3..6}" >&2
  exit 2
fi

echo "=== SUGAR lh ±LIT (pretrained folder is lh-only) ==="
set +e
python "${DLS}/scripts/run_sugar_predict.py" --sd "$WITH_LIT_SD" --out "$OUT/sugar_with_lit" --sid "$SID" \
  --hemi lh --device cuda --model-path "$SUGAR_MODEL_PATH" --fsd "$FSD_ARG"
rc_sw=$?
mkdir -p "$OUT/sugar_with_lit/$SID/scripts"
if [[ $rc_sw -eq 0 ]]; then echo ok > "$OUT/sugar_with_lit/$SID/scripts/dlsurfer_sugar.done"; else echo $rc_sw > "$OUT/sugar_with_lit/$SID/scripts/dlsurfer_sugar.exit"; fi

if [[ -d "$NO_LIT_SD/$SID/surf" && -f "$NO_LIT_SD/$SID/surf/lh.sulc" ]]; then
  python "${DLS}/scripts/run_sugar_predict.py" --sd "$NO_LIT_SD" --out "$OUT/sugar_no_lit" --sid "$SID" \
    --hemi lh --device cuda --model-path "$SUGAR_MODEL_PATH" --fsd "$FSD_ARG"
  rc_sn=$?
  mkdir -p "$OUT/sugar_no_lit/$SID/scripts"
  if [[ $rc_sn -eq 0 ]]; then echo ok > "$OUT/sugar_no_lit/$SID/scripts/dlsurfer_sugar.done"; else echo $rc_sn > "$OUT/sugar_no_lit/$SID/scripts/dlsurfer_sugar.exit"; fi
fi
set -e

echo "=== CortexMorph ±LIT ==="
set +e
export CORTEXMORPH_ROOT SUBJECTS_DIR="$WITH_LIT_SD" DLSURFER_SID="$SID" DLSURFER_OUT="$OUT/cm_with_lit" DLSURFER_DEVICE=cuda
python "${DLS}/scripts/run_cortexmorph_subject.py"
if [[ -d "$NO_LIT_SD/$SID/mri" ]]; then
  export SUBJECTS_DIR="$NO_LIT_SD" DLSURFER_OUT="$OUT/cm_no_lit"
  python "${DLS}/scripts/run_cortexmorph_subject.py"
fi
set -e

echo "=== V2C-Flow env + stage + test ±LIT ==="
set +e
if [[ ! -x "$V2C_ENV/bin/python" ]]; then
  python3 -m venv "$V2C_ENV"
fi
"$V2C_ENV/bin/pip" install -U pip wheel setuptools "${PYI[@]}"
if ! "$V2C_ENV/bin/python" -c "import torch" 2>/dev/null; then
  "$V2C_ENV/bin/pip" install "${PYI[@]}" torch torchvision --index-url https://download.pytorch.org/whl/cu124
fi
"$V2C_ENV/bin/pip" install "${PYI[@]}" nibabel numpy scipy pandas tqdm trimesh wandb pyyaml yacs \
  einops scikit-image pillow matplotlib
# pytorch3d required for Meshes — must use --no-build-isolation so setup sees torch
if ! "$V2C_ENV/bin/python" -c "from pytorch3d.structures import Meshes" 2>/dev/null; then
  FORCE_CUDA=1 "$V2C_ENV/bin/pip" install "${PYI[@]}" fvcore iopath ninja
  export TORCH_CUDA_ARCH_LIST="${TORCH_CUDA_ARCH_LIST:-8.9}"
  FORCE_CUDA=1 "$V2C_ENV/bin/pip" install "${PYI[@]}" --no-build-isolation \
    "git+https://github.com/facebookresearch/pytorch3d.git@stable" \
    || FORCE_CUDA=1 "$V2C_ENV/bin/pip" install "${PYI[@]}" --no-build-isolation \
    "git+https://github.com/fabibo3/pytorch3d.git" \
    || true
fi
# Optional heavier deps (best-effort)
"$V2C_ENV/bin/pip" install "${PYI[@]}" torchio monai geomloss || true

export V2C_PYTHON="$V2C_ENV/bin/python"
export V2C_RAW_DATA_DIR="$OUT/v2c_raw"
export WANDB_MODE=disabled
export USE_WANDB=0

# Stage both arms into the same RAW_DATA_DIR with distinct sids
python "${DLS}/scripts/prep_v2c_subject.py" \
  --subjects-dir "$WITH_LIT_SD" --sid "$SID" --raw-dir "$OUT/v2c_raw" \
  --fs-sif "${SIF_FREESURFER:-}" --fs-license "${FS_LICENSE:-}"
# no-LIT as sibling id so one dataset can hold both; rewrite test split per arm
python "${DLS}/scripts/prep_v2c_subject.py" \
  --subjects-dir "$NO_LIT_SD" --sid "$SID" --out-sid "${SID}_nolit" --raw-dir "$OUT/v2c_raw" \
  --fs-sif "${SIF_FREESURFER:-}" --fs-license "${FS_LICENSE:-}"

# Ensure experiment dir
mkdir -p "$V2C_ROOT/experiments"
[[ -d "$V2C_ROOT/experiments/V2C-Flow-S-ADNI" ]] || \
  cp -a "$V2C_ROOT/vox2organ/pretrained_models/V2C-Flow-S-ADNI" "$V2C_ROOT/experiments/V2C-Flow-S-ADNI"

run_v2c_arm () {
  local arm_sid="$1" out_arm="$2"
  echo "$arm_sid" > "$OUT/v2c_raw/dlsurfer_test.txt"
  : > "$OUT/v2c_raw/dlsurfer_train.txt"
  : > "$OUT/v2c_raw/dlsurfer_val.txt"
  mkdir -p "$out_arm/$SID/scripts"
  cat > "$out_arm/$SID/scripts/dlsurfer_v2c_cmd.txt" <<EOF
cd $V2C_ROOT/vox2organ
V2C_RAW_DATA_DIR=$OUT/v2c_raw $V2C_PYTHON main.py --test -n V2C-Flow-S-ADNI --dataset dlsurfer_t1
# arm_sid=$arm_sid
EOF
  (
    cd "$V2C_ROOT/vox2organ"
    export V2C_RAW_DATA_DIR="$OUT/v2c_raw"
    export WANDB_MODE=disabled
    "$V2C_PYTHON" main.py --test -n V2C-Flow-S-ADNI --dataset dlsurfer_t1
  )
  local rc=$?
  echo "$rc" > "$out_arm/$SID/scripts/dlsurfer_v2c.exit"
  if [[ $rc -eq 0 ]]; then
    echo ok > "$out_arm/$SID/scripts/dlsurfer_v2c.done"
    # Collect predicted meshes if present
    find "$V2C_ROOT/experiments/V2C-Flow-S-ADNI" -name '*.stl' -o -name '*.ply' 2>/dev/null \
      | head -20 > "$out_arm/$SID/scripts/dlsurfer_v2c_meshes.txt" || true
  fi
  return $rc
}

run_v2c_arm "$SID" "$OUT/v2c_with_lit"
run_v2c_arm "${SID}_nolit" "$OUT/v2c_no_lit"
set -e

python "${DLS}/scripts/score_phase3_gates.py" --root "$OUT" --sid "$SID" --out "$OUT/phase3_gates_score.json"
cat "$OUT/phase3_gates_score.json"
echo DONE
