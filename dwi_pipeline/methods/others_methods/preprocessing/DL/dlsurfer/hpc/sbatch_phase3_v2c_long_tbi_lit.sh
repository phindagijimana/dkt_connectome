#!/bin/bash
#SBATCH -J dlsurfer_v2c_long
#SBATCH -p interactive
#SBATCH --gres=gpu:l40s.24g:1
#SBATCH -c 8
#SBATCH --mem=64G
#SBATCH -t 12:00:00
#SBATCH -o %x_%j.out
#SBATCH -e %x_%j.err
#
# TBI ±LIT V2C-Long gate — TrackTBI 2WK+6MO (default sub-TBI011021).
# Preflight: bash scripts/check_v2c_long_tbi_lit_ready.sh
set -euo pipefail

DLS="${SLURM_SUBMIT_DIR:-}"
if [[ -z "$DLS" || ! -f "${DLS}/env/cluster_containers.sh" ]]; then
  DLS="/mnt/nfs/home/urmc-sh.rochester.edu/pndagiji/Documents/TrackTBI-Sub/dwi_pipeline/methods/others_methods/preprocessing/DL/dlsurfer"
fi
cd "$DLS"

if ! bash "${DLS}/scripts/check_v2c_long_tbi_lit_ready.sh"; then
  echo "[v2c-long] preflight failed — not running GPU pipeline" >&2
  exit 2
fi

# shellcheck disable=SC1091
source "${DLS}/env/cluster_containers.sh"
export PATH="${DLS}/env/bin:${PATH}"
export PYTHONPATH="${DLS}${PYTHONPATH:+:$PYTHONPATH}"
export DLSURFER_V2C_LONG_STRICT=1

# Force dedicated V2C-Long tree (cluster_containers may previously fall back to Vox2Cortex).
export V2C_LONG_ROOT="/mnt/nfs/home/urmc-sh.rochester.edu/pndagiji/Documents/others/V2C-Long"
[[ -f "${V2C_LONG_ROOT}/vox2organ/main.py" ]] || {
  echo "[v2c-long] FATAL: missing ${V2C_LONG_ROOT}/vox2organ/main.py" >&2
  exit 2
}
TRACKTBI_BIDS="${TRACKTBI_BIDS:-/mnt/nfs/home/urmc-sh.rochester.edu/pndagiji/Documents/TrackTBI-Sub/TrackTBI_Lesion}"
TRACKTBI_SUB="${TRACKTBI_SUB:-sub-TBI011021}"
TRACKTBI_SES_A="${TRACKTBI_SES_A:-ses-2WK}"
TRACKTBI_SES_B="${TRACKTBI_SES_B:-ses-6MO}"
SID="${SID:-$TRACKTBI_SUB}"
OUT="${DLS}/work/phase3_v2c_long"
V2C_ENV="${DLS}/work/phase3_gates/envs/v2c"
INSTALL="${DLS}/env/bin/dlsurfer-install-surfaces"
PREP="${DLS}/scripts/prep_v2c_long_visits.py"
SYNTHSEG="${DLS}/scripts/synthseg_t1_aseg.sh"
PYI=(-i https://pypi.org/simple --trusted-host pypi.org --trusted-host files.pythonhosted.org)

T1_A="${TRACKTBI_BIDS}/${TRACKTBI_SUB}/${TRACKTBI_SES_A}/anat/${TRACKTBI_SUB}_${TRACKTBI_SES_A}_acq-3D_T1w.nii.gz"
T1_B="${TRACKTBI_BIDS}/${TRACKTBI_SUB}/${TRACKTBI_SES_B}/anat/${TRACKTBI_SUB}_${TRACKTBI_SES_B}_acq-3D_T1w.nii.gz"
LESION="${TRACKTBI_BIDS}/${TRACKTBI_SUB}/${TRACKTBI_SES_A}/anat/${TRACKTBI_SUB}_${TRACKTBI_SES_A}_acq-3D_T1w_label-lesion_roi.nii.gz"
SCAN_A="${SID}_tp0"
SCAN_B="${SID}_tp1"

mkdir -p "$OUT"/{with_lit,no_lit,staging}
nvidia-smi || true
export CUDA_HOME="${CUDA_HOME:-/usr/local/cuda-12.6}"
export PATH="${CUDA_HOME}/bin:${PATH}"
export LD_LIBRARY_PATH="${CUDA_HOME}/lib64:${LD_LIBRARY_PATH:-}"
export TORCH_CUDA_ARCH_LIST="${TORCH_CUDA_ARCH_LIST:-8.9}"
export WANDB_MODE=disabled
export USE_WANDB=0

PYTORCH3D_PATCHED_SRC="${PYTORCH3D_PATCHED_SRC:-${DLS}/work/pytorch3d_fabibo3_meshesxd}"
PYTORCH3D_PATCHED_WHEEL="${PYTORCH3D_PATCHED_WHEEL:-${DLS}/work/pytorch3d_fabibo3_meshesxd_cu126_sm89-cp39.whl}"

if [[ ! -x "$V2C_ENV/bin/python" ]]; then
  echo "[v2c-long] bootstrapping venv at $V2C_ENV"
  python3 -m venv "$V2C_ENV"
fi
export V2C_PYTHON="${V2C_PYTHON:-$V2C_ENV/bin/python}"
for d in /usr/local/cuda-12.6 /usr/local/cuda-12 /usr/local/cuda; do
  if [[ -x "$d/bin/nvcc" ]]; then
    export CUDA_HOME="$d"
    export PATH="${CUDA_HOME}/bin:${PATH}"
    break
  fi
done

ensure_pytorch3d_meshesxd () {
  if "$V2C_PYTHON" -c "from pytorch3d.structures import Meshes, MeshesXD; from pytorch3d.ops import sample_points_from_meshes" 2>/dev/null; then
    echo "[v2c-long] pytorch3d OK (MeshesXD + _C ops)"
    return 0
  fi
  bash "${DLS}/scripts/patch_pytorch3d_cuda12_pulsar.sh" "${PYTORCH3D_PATCHED_SRC}" 2>/dev/null || true
  echo "[v2c-long] installing fabibo3 pytorch3d (MeshesXD)"
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
    FORCE_CUDA=1 "$V2C_PYTHON" -m pip install --no-deps "${PYTORCH3D_PATCHED_WHEEL}"
    rc=$?
  fi
  if [[ $rc -ne 0 && -f "${PYTORCH3D_PATCHED_SRC}/pytorch3d/structures/__init__.py" ]]; then
    (
      cd "${PYTORCH3D_PATCHED_SRC}" || exit 1
      FORCE_CUDA=1 MAX_JOBS="${MAX_JOBS:-8}" \
        "$V2C_PYTHON" -m pip install --no-build-isolation -e .
    )
    rc=$?
  fi
  if [[ $rc -ne 0 && -f "${PYTORCH3D_PATCHED_SRC}/setup.py" ]]; then
    echo "[v2c-long] pip install -e ${PYTORCH3D_PATCHED_SRC} (fabibo3 MeshesXD, pulsar stripped)"
    FORCE_CUDA=1 MAX_JOBS="${MAX_JOBS:-8}" \
      "$V2C_PYTHON" -m pip install --no-build-isolation -e "${PYTORCH3D_PATCHED_SRC}"
    rc=$?
  fi
  if [[ $rc -ne 0 ]]; then
    FORCE_CUDA=1 MAX_JOBS="${MAX_JOBS:-8}" \
      "$V2C_PYTHON" -m pip install "${PYI[@]}" --no-build-isolation \
      "git+https://github.com/fabibo3/pytorch3d.git"
    rc=$?
  fi
  set -e
  [[ $rc -eq 0 ]] || return "$rc"
  "$V2C_PYTHON" -c "from pytorch3d.structures import Meshes, MeshesXD"
}

ensure_v2c_long_extras () {
  if "$V2C_PYTHON" -c "import torchio" 2>/dev/null; then
    echo "[v2c-long] torchio OK"
    return 0
  fi
  "$V2C_PYTHON" -m pip install "${PYI[@]}" torchio
  "$V2C_PYTHON" -c "import torchio"
}

ensure_pyg () {
  if "$V2C_PYTHON" -c "import torch_geometric.nn; from torch_sparse import SparseTensor" 2>/dev/null; then
    echo "[v2c-long] PyG OK"
    return 0
  fi
  local tv cu124 PYG_URL
  tv=$("$V2C_PYTHON" -c "import torch; v=torch.__version__.split('+'); print(v[0])" 2>/dev/null || echo "2.6.0")
  cu124="${PYG_CUDA_TAG:-cu124}"
  PYG_URL="https://data.pyg.org/whl/torch-${tv}+${cu124}.html"
  "$V2C_PYTHON" -m pip install "${PYI[@]}" \
    pyg_lib torch_scatter torch_sparse torch_cluster torch_spline_conv -f "$PYG_URL"
  "$V2C_PYTHON" -m pip install "${PYI[@]}" torch_geometric
  "$V2C_PYTHON" -m pip install "${PYI[@]}" "numpy<2" elasticdeform "nibabel==4.0.2" \
    "pymeshlab==2022.2.post2" "pandas==1.4.2" scipy trimesh wandb pyyaml yacs \
    einops scikit-image pillow matplotlib tqdm cupy-cuda12x torchio monai geomloss || true
  "$V2C_PYTHON" -c "import torch_geometric.nn; from torch_sparse import SparseTensor"
}

ensure_cupy () {
  if "$V2C_PYTHON" -c "import cupy" 2>/dev/null; then
    echo "[v2c-long] cupy OK"
    return 0
  fi
  "$V2C_PYTHON" -m pip install "${PYI[@]}" cupy-cuda12x || return 1
  "$V2C_PYTHON" -c "import cupy"
}

# PyG pip installs can evict pytorch3d — install PyG first, then (re)install fabibo3 pytorch3d.
ensure_pyg || { echo "[v2c-long] FATAL: PyG unavailable" >&2; exit 2; }
ensure_pytorch3d_meshesxd || { echo "[v2c-long] FATAL: MeshesXD unavailable" >&2; exit 2; }
ensure_v2c_long_extras || { echo "[v2c-long] FATAL: torchio unavailable" >&2; exit 2; }
"$V2C_PYTHON" -c "from pytorch3d.utils import ico_sphere; from pytorch3d.structures import MeshesXD; import torchio" \
  || { echo "[v2c-long] FATAL: vox2organ python deps incomplete after bootstrap" >&2; exit 2; }
ensure_cupy || { echo "[v2c-long] FATAL: cupy unavailable (V2C-Long utils)" >&2; exit 2; }

stage_arm_visits () {
  local arm="$1" t1_a="$2" t1_b="$3" aseg_a="$4" aseg_b="$5"
  local raw="$OUT/v2c_long_raw_${arm}"
  local csv="$OUT/${SID}_${arm}_longitudinal.csv"
  rm -rf "$raw"
  mkdir -p "$raw"
  "$V2C_PYTHON" "$PREP" \
    --raw-dir "$raw" --csv-out "$csv" --ptid "$SID" \
    --visit "${SCAN_A}:${t1_a}:${aseg_a}" \
    --visit "${SCAN_B}:${t1_b}:${aseg_b}" \
    || return 2
}

prep_arm_inputs () {
  local arm="$1"
  local st="$OUT/staging/${arm}"
  mkdir -p "$st"
  local t1_a_use="$T1_A" t1_b_use="$T1_B"

  if [[ "$arm" == "with_lit" ]]; then
    [[ -f "$LESION" ]] || { echo "[v2c-long] with_lit needs lesion ROI at $LESION" >&2; return 2; }
    local lit_stable="$st/inpainted_2wk.nii.gz"
    if [[ -f "$lit_stable" ]]; then
      t1_a_use="$lit_stable"
      echo "[v2c-long] reusing stable LIT T1 $t1_a_use"
    else
      local lit_sd="$st/lit_sd"
      rm -rf "$lit_sd"
      mkdir -p "$lit_sd"
      echo "[v2c-long] LIT inpainting 2WK for arm=$arm"
      lit-inpainting -i "$T1_A" -m "$LESION" -o "$lit_sd/$SID" --device cuda --dilate 2
      local lit_cand=""
      for lit_cand in \
        "$lit_sd/$SID/inpainting_volumes/inpainting_result.nii.gz" \
        "$lit_sd/$SID/mri/inpainted.lit.nii.gz" \
        "$lit_sd/$SID/inpainting_volumes/inpainting_masked_image.nii.gz"; do
        [[ -f "$lit_cand" ]] && break
        lit_cand=""
      done
      [[ -n "$lit_cand" ]] || { echo "[v2c-long] missing inpainted T1 under $lit_sd/$SID" >&2; return 2; }
      cp -f "$lit_cand" "$lit_stable"
      t1_a_use="$lit_stable"
      echo "[v2c-long] with_lit 2WK T1=$t1_a_use (from $(basename "$lit_cand"))"
    fi
  fi

  local aseg_a="$st/${SCAN_A}_aseg.nii.gz"
  local aseg_b="$st/${SCAN_B}_aseg.nii.gz"
  if [[ -f "$aseg_a" ]]; then
    echo "[v2c-long] reusing aseg arm=$arm tp0 $aseg_a"
  else
    echo "[v2c-long] SynthSeg aseg arm=$arm tp0"
    bash "$SYNTHSEG" "$t1_a_use" "$aseg_a"
  fi
  if [[ -f "$aseg_b" ]]; then
    echo "[v2c-long] reusing aseg arm=$arm tp1 $aseg_b"
  else
    echo "[v2c-long] SynthSeg aseg arm=$arm tp1"
    bash "$SYNTHSEG" "$t1_b_use" "$aseg_b"
  fi
  stage_arm_visits "$arm" "$t1_a_use" "$t1_b_use" "$aseg_a" "$aseg_b"
}

run_long_arm () {
  local arm="$1" out_arm="$2"
  echo "=== V2C-Long arm $arm ==="
  prep_arm_inputs "$arm" || return 2
  local raw="$OUT/v2c_long_raw_${arm}"
  local n_visits=0
  for d in "$raw"/*; do
    [[ -d "$d" && -f "$d/mri.nii.gz" ]] && n_visits=$((n_visits + 1))
  done
  [[ $n_visits -ge 2 ]] || {
    echo "[v2c-long] arm=$arm need ≥2 staged visits under $raw (have $n_visits)" >&2
    return 2
  }
  mkdir -p "$out_arm/$SID/scripts"
  set +e
  V2C_PYTHON="$V2C_PYTHON" dlsurfer-v2c-long --out-dir "$out_arm" --sid "$SID" --ptid "$SID" --visits-dir "$raw"
  local rc=$?
  set -e
  echo "$rc" > "$out_arm/$SID/scripts/dlsurfer_v2c_long.exit"
  [[ $rc -eq 0 ]] || return "$rc"
  if [[ -x "$INSTALL" ]]; then
    "$INSTALL" --sd "$out_arm" --sid "$SID" --backend v2c --mode full \
      --search-dir "$V2C_LONG_ROOT/public_experiments" --search-dir "$out_arm" || true
  fi
  return 0
}

echo "[v2c-long] V2C_LONG_ROOT=$V2C_LONG_ROOT OUT=$OUT SID=$SID"
echo "[v2c-long] T1_A=$T1_A T1_B=$T1_B"
set +e
run_long_arm with_lit "$OUT/with_lit"
rc_lit=$?
run_long_arm no_lit "$OUT/no_lit"
rc_nolit=$?
set -e

echo "[v2c-long] with_lit=$rc_lit no_lit=$rc_nolit"
SCORE="${DLS}/scripts/score_v2c_long_tbi_lit.py"
"$V2C_PYTHON" "$SCORE" --root "$OUT" --sid "$SID" --job "${SLURM_JOB_ID:-0}" \
  --cohort-note "TrackTBI ${TRACKTBI_SUB} ${TRACKTBI_SES_A}+${TRACKTBI_SES_B}; with_lit=LIT 2WK+native 6MO" \
  --out "$OUT/v2c_long_tbi_lit_score.json" || true

[[ $rc_lit -eq 0 && $rc_nolit -eq 0 ]] || exit 1
echo "DONE — review $OUT/v2c_long_tbi_lit_score.json before gates.yaml"
