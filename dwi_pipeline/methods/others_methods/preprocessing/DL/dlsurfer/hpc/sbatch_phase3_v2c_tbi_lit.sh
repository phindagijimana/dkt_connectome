#!/bin/bash
#SBATCH -J dlsurfer_v2c
#SBATCH -p interactive
#SBATCH --gres=gpu:l40s.24g:1
#SBATCH -c 8
#SBATCH --mem=64G
#SBATCH -t 10:00:00
#SBATCH -o %x_%j.out
#SBATCH -e %x_%j.err
#
# TBI ±LIT V2C-Flow gate: prep from FastSurfer SUBJECTS_DIR → main.py --test → FS surf contract.
# Does not update gates.yaml (caller scores after both arms succeed).
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

export V2C_ROOT="${V2C_ROOT:-${HOME}/Documents/others/Vox2Cortex}"
WITH_LIT_SD="${WITH_LIT_SD:-${DLS}/work/eg_gpu_core_lesion}"
NO_LIT_SD="${NO_LIT_SD:-/mnt/nfs/home/urmc-sh.rochester.edu/pndagiji/Documents/TrackTBI-Sub/dwi_pipeline/analysis/gugger_eg_lit/fastsurfer_inpainting/native_lesion_mask/fastsurfer_v2.6/subjects}"
SID=sub-EG
OUT="${DLS}/work/phase3_v2c"
V2C_ENV="${DLS}/work/phase3_gates/envs/v2c"
INSTALL="${DLS}/env/bin/dlsurfer-install-surfaces"
PYI=(-i https://pypi.org/simple --trusted-host pypi.org --trusted-host files.pythonhosted.org)

mkdir -p "$OUT"/{with_lit,no_lit,v2c_raw}
nvidia-smi || true
export CUDA_HOME="${CUDA_HOME:-/usr/local/cuda-12.6}"
export PATH="${CUDA_HOME}/bin:${PATH}"
export LD_LIBRARY_PATH="${CUDA_HOME}/lib64:${LD_LIBRARY_PATH:-}"
export TORCH_CUDA_ARCH_LIST="${TORCH_CUDA_ARCH_LIST:-8.9}"
export WANDB_MODE=disabled
export USE_WANDB=0

REF_FS="/mnt/nfs/home/urmc-sh.rochester.edu/pndagiji/Documents/TrackTBI-Sub/dwi_pipeline/analysis/gugger_eg_lit/fastsurfer_inpainting/standalone/fastsurfer_v2.6/subjects/fsaverage"
for SD in "$WITH_LIT_SD" "$NO_LIT_SD"; do
  if [[ -d "$SD/$SID" && ! -e "$SD/fsaverage" && -d "$REF_FS" ]]; then
    ln -sfn "$REF_FS" "$SD/fsaverage"
  fi
done

if [[ ! -x "$V2C_ENV/bin/python" ]]; then
  echo "[v2c] missing venv at $V2C_ENV — run sbatch_phase3_gates_pipenv.sh once or set V2C_PYTHON" >&2
  exit 2
fi
export V2C_PYTHON="${V2C_PYTHON:-$V2C_ENV/bin/python}"
export V2C_RAW_DATA_DIR="$OUT/v2c_raw"

echo "[v2c] V2C_ROOT=$V2C_ROOT V2C_PYTHON=$V2C_PYTHON RAW=$V2C_RAW_DATA_DIR"

PYTORCH3D_PATCHED_SRC="${PYTORCH3D_PATCHED_SRC:-${DLS}/work/pytorch3d_fabibo3_meshesxd}"
PYTORCH3D_PATCHED_WHEEL="${PYTORCH3D_PATCHED_WHEEL:-${DLS}/work/pytorch3d_fabibo3_meshesxd_cu126_sm89-cp39.whl}"

ensure_pytorch3d_meshesxd () {
  if "$V2C_PYTHON" -c "from pytorch3d.structures import Meshes, MeshesXD" 2>/dev/null; then
    echo "[v2c] pytorch3d OK (MeshesXD present)"
    return 0
  fi
  echo "[v2c] installing fabibo3 pytorch3d (MeshesXD); CUDA_HOME=$CUDA_HOME arch=$TORCH_CUDA_ARCH_LIST"
  set +e
  "$V2C_PYTHON" -m pip install -U pip wheel setuptools ninja "${PYI[@]}"
  if ! "$V2C_PYTHON" -c "import torch" 2>/dev/null; then
    "$V2C_PYTHON" -m pip install "${PYI[@]}" torch torchvision \
      --index-url https://download.pytorch.org/whl/cu124
  fi
  "$V2C_PYTHON" -m pip install "${PYI[@]}" fvcore iopath
  FORCE_CUDA=1 "$V2C_PYTHON" -m pip uninstall -y pytorch3d 2>/dev/null || true
  local rc=1
  if [[ -f "${PYTORCH3D_PATCHED_WHEEL}" ]]; then
    echo "[v2c] pip install ${PYTORCH3D_PATCHED_WHEEL} (prebuilt fabibo3 + CUDA12 patch)"
    FORCE_CUDA=1 "$V2C_PYTHON" -m pip install --no-deps "${PYTORCH3D_PATCHED_WHEEL}"
    rc=$?
  fi
  if [[ $rc -ne 0 && -f "${PYTORCH3D_PATCHED_SRC}/pytorch3d/structures/__init__.py" ]]; then
    echo "[v2c] pip install -e ${PYTORCH3D_PATCHED_SRC} (CUDA 12 make_float3 patch)"
    (
      cd "${PYTORCH3D_PATCHED_SRC}" || exit 1
      FORCE_CUDA=1 MAX_JOBS="${MAX_JOBS:-8}" \
        "$V2C_PYTHON" -m pip install --no-build-isolation -e .
    )
    rc=$?
  fi
  if [[ $rc -ne 0 ]]; then
    echo "[v2c] patched tree failed (rc=$rc); trying git fabibo3/pytorch3d" >&2
    FORCE_CUDA=1 MAX_JOBS="${MAX_JOBS:-8}" \
      "$V2C_PYTHON" -m pip install "${PYI[@]}" --no-build-isolation \
      "git+https://github.com/fabibo3/pytorch3d.git"
    rc=$?
  fi
  set -e
  if [[ $rc -ne 0 ]]; then
    echo "[v2c] pytorch3d build failed (rc=$rc)" >&2
    return "$rc"
  fi
  "$V2C_PYTHON" -c "from pytorch3d.structures import Meshes, MeshesXD"
}

ensure_pytorch3d_meshesxd || {
  echo "[v2c] FATAL: MeshesXD unavailable — fix pytorch3d then resubmit" >&2
  exit 2
}

ensure_pyg () {
  if "$V2C_PYTHON" -c "import torch_geometric.nn; from torch_sparse import SparseTensor" 2>/dev/null; then
    echo "[v2c] PyG OK (torch_geometric + torch_sparse)"
    return 0
  fi
  echo "[v2c] installing PyG wheels (torch 2.6+cu124)"
  set +e
  local tv cu124 PYG_URL
  tv=$("$V2C_PYTHON" -c "import torch; v=torch.__version__.split('+'); print(v[0])" 2>/dev/null || echo "2.6.0")
  cu124="${PYG_CUDA_TAG:-cu124}"
  PYG_URL="https://data.pyg.org/whl/torch-${tv}+${cu124}.html"
  "$V2C_PYTHON" -m pip install "${PYI[@]}" \
    pyg_lib torch_scatter torch_sparse torch_cluster torch_spline_conv -f "$PYG_URL"
  "$V2C_PYTHON" -m pip install "${PYI[@]}" torch_geometric
  # elasticdeform (Vox2Cortex data aug) needs NumPy 1.x ABI; nibabel 5.3+ rejects int64 Nifti1Image
  "$V2C_PYTHON" -m pip install "${PYI[@]}" "numpy<2" elasticdeform "nibabel==4.0.2" \
    "pymeshlab==2022.2.post2" "pandas==1.4.2" || true
  set -e
  if ! "$V2C_PYTHON" -c "import torch_geometric.nn; from torch_sparse import SparseTensor" 2>/dev/null; then
    echo "[v2c] FATAL: PyG import failed after pip install" >&2
    return 1
  fi
  echo "[v2c] PyG install OK"
}

ensure_pyg || {
  echo "[v2c] FATAL: torch_geometric / torch_sparse required for graph_conv" >&2
  exit 2
}

echo "=== prep V2C raw from ±LIT SUBJECTS_DIR ==="
python "${DLS}/scripts/prep_v2c_subject.py" \
  --subjects-dir "$WITH_LIT_SD" --sid "$SID" --raw-dir "$OUT/v2c_raw" \
  --fs-sif "${SIF_FREESURFER:-${DLSURFER_SIF_FREESURFER:-}}" --fs-license "${FS_LICENSE:-}"
python "${DLS}/scripts/prep_v2c_subject.py" \
  --subjects-dir "$NO_LIT_SD" --sid "$SID" --out-sid "${SID}_nolit" --raw-dir "$OUT/v2c_raw" \
  --fs-sif "${SIF_FREESURFER:-${DLSURFER_SIF_FREESURFER:-}}" --fs-license "${FS_LICENSE:-}"

mkdir -p "$V2C_ROOT/experiments"
[[ -d "$V2C_ROOT/experiments/V2C-Flow-S-ADNI" ]] || \
  cp -a "$V2C_ROOT/vox2organ/pretrained_models/V2C-Flow-S-ADNI" "$V2C_ROOT/experiments/V2C-Flow-S-ADNI"
EXP="$V2C_ROOT/experiments/V2C-Flow-S-ADNI"

run_v2c_arm () {
  local arm_sid="$1" out_arm="$2"
  echo "$arm_sid" > "$OUT/v2c_raw/dlsurfer_test.txt"
  : > "$OUT/v2c_raw/dlsurfer_train.txt"
  : > "$OUT/v2c_raw/dlsurfer_val.txt"
  mkdir -p "$out_arm/$SID/scripts"
  cat > "$out_arm/$SID/scripts/dlsurfer_v2c_cmd.txt" <<EOF
cd $V2C_ROOT/vox2organ
V2C_RAW_DATA_DIR=$OUT/v2c_raw $V2C_PYTHON ${DLS}/scripts/run_v2c_main.py --test -n V2C-Flow-S-ADNI --dataset dlsurfer_t1
# arm_sid=$arm_sid out_arm=$out_arm
EOF
  set +e
  (
    export V2C_RAW_DATA_DIR="$OUT/v2c_raw"
    export WANDB_MODE=disabled
    export V2C_ROOT
    "$V2C_PYTHON" "${DLS}/scripts/run_v2c_main.py" --test -n V2C-Flow-S-ADNI --dataset dlsurfer_t1
  )
  local rc=$?
  set -e
  echo "$rc" > "$out_arm/$SID/scripts/dlsurfer_v2c.exit"
  if [[ $rc -ne 0 ]]; then
    echo "[v2c] arm $arm_sid failed (exit $rc)" >&2
    return "$rc"
  fi
  echo ok > "$out_arm/$SID/scripts/dlsurfer_v2c.done"
  find "$EXP" -name '*.stl' -o -name '*.ply' 2>/dev/null \
    | head -20 > "$out_arm/$SID/scripts/dlsurfer_v2c_meshes.txt" || true

  if [[ -x "$INSTALL" ]]; then
    set +e
    "$INSTALL" --sd "$out_arm" --sid "$SID" --backend v2c --mode full \
      --search-dir "$EXP/$arm_sid" --search-dir "$out_arm/$SID/surf"
    local irc=$?
    set -e
    if [[ $irc -eq 0 ]]; then
      echo ok > "$out_arm/$SID/scripts/dlsurfer_v2c_fs_install.done"
    else
      echo "$irc" > "$out_arm/$SID/scripts/dlsurfer_v2c_fs_install.exit"
      echo "[v2c] warning: dlsurfer-install-surfaces exit $irc for $arm_sid" >&2
    fi
  fi
  return 0
}

echo "=== V2C-Flow test with-LIT ==="
set +e
run_v2c_arm "$SID" "$OUT/with_lit"
rc_lit=$?
echo "=== V2C-Flow test no-LIT ==="
run_v2c_arm "${SID}_nolit" "$OUT/no_lit"
rc_nolit=$?
set -e

echo "[v2c] with_lit=$rc_lit no_lit=$rc_nolit (outputs under $OUT)"
[[ $rc_lit -eq 0 && $rc_nolit -eq 0 ]] || exit 1
echo "DONE — score gates separately; do not flip gates.yaml until verified."
