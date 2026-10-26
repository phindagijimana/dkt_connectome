#!/bin/bash
#SBATCH -J dlsurfer_sugar
#SBATCH -p interactive
#SBATCH --gres=gpu:l40s.24g:1
#SBATCH -c 8
#SBATCH --mem=64G
#SBATCH -t 02:00:00
#SBATCH -o %x_%j.out
#SBATCH -e %x_%j.err
#
# TBI ±LIT SUGAR gate (lh-only pretrained): ICO FreeSurfer templates via SUGAR_FSD.
set -euo pipefail

DLS="${SLURM_SUBMIT_DIR:-}"
if [[ -z "$DLS" || ! -f "${DLS}/env/cluster_containers.sh" ]]; then
  DLS="/mnt/nfs/home/urmc-sh.rochester.edu/pndagiji/Documents/TrackTBI-Sub/dwi_pipeline/methods/others_methods/preprocessing/DL/dlsurfer"
fi
cd "$DLS"
# shellcheck disable=SC1091
source "${DLS}/env/cluster_containers.sh"
export PATH="${DLS}/env/bin:${PATH}"

export SUGAR_ROOT="${SUGAR_ROOT:-${HOME}/Documents/others/SUGAR}"
export SUGAR_MODEL_PATH="${SUGAR_MODEL_PATH:-${SUGAR_ROOT}/pretrained}"
export SUGAR_SIF=""
WITH_LIT_SD="${WITH_LIT_SD:-${DLS}/work/eg_gpu_core_lesion}"
NO_LIT_SD="${NO_LIT_SD:-/mnt/nfs/home/urmc-sh.rochester.edu/pndagiji/Documents/TrackTBI-Sub/dwi_pipeline/analysis/gugger_eg_lit/fastsurfer_inpainting/native_lesion_mask/fastsurfer_v2.6/subjects}"
SID=sub-EG
OUT="${DLS}/work/phase3_sugar"
ENV="${DLS}/work/phase3_gates/envs/p3"
SHIM="${DLS}/scripts/shims"
INSTALL="${DLS}/env/bin/dlsurfer-install-surfaces"
PYI=(-i https://pypi.org/simple --trusted-host pypi.org --trusted-host files.pythonhosted.org)

FSD_ARG="${SUGAR_FSD:-/mnt/nfs/home/urmc-sh.rochester.edu/pndagiji/Documents/others/data_mining/freesurfer}"
export SUGAR_FSD="$FSD_ARG"
if [[ ! -d "$FSD_ARG/subjects/fsaverage6/surf" ]]; then
  echo "FATAL: missing ICO templates: $FSD_ARG/subjects/fsaverage6" >&2
  exit 2
fi

REF_FS="/mnt/nfs/home/urmc-sh.rochester.edu/pndagiji/Documents/TrackTBI-Sub/dwi_pipeline/analysis/gugger_eg_lit/fastsurfer_inpainting/standalone/fastsurfer_v2.6/subjects/fsaverage"
for SD in "$WITH_LIT_SD" "$NO_LIT_SD"; do
  if [[ -d "$SD/$SID" && ! -e "$SD/fsaverage" && -d "$REF_FS" ]]; then
    ln -sfn "$REF_FS" "$SD/fsaverage"
  fi
done

mkdir -p "$OUT"/{with_lit,no_lit}
nvidia-smi || true
export CUDA_HOME="${CUDA_HOME:-/usr/local/cuda-12.6}"
export PATH="${CUDA_HOME}/bin:${PATH}"
export LD_LIBRARY_PATH="${CUDA_HOME}/lib64:${LD_LIBRARY_PATH:-}"
export TORCH_CUDA_ARCH_LIST="${TORCH_CUDA_ARCH_LIST:-8.9}"

if [[ ! -x "$ENV/bin/python" ]]; then
  python3 -m venv "$ENV"
  "$ENV/bin/pip" install -U pip wheel setuptools "${PYI[@]}"
  "$ENV/bin/pip" install "${PYI[@]}" torch --index-url https://download.pytorch.org/whl/cu124
  "$ENV/bin/pip" install "${PYI[@]}" "numpy<2" nibabel scipy pandas tqdm scikit-learn scikit-image networkx pillow
fi
# SUGAR README: torch_geometric==2.2.0 (+ sparse wheels for current torch).
if ! "$ENV/bin/python" -c "import torch_geometric; assert torch_geometric.__version__.startswith('2.2.')" 2>/dev/null; then
  tv=$("$ENV/bin/python" -c "import torch; print(torch.__version__.split('+')[0])")
  PYG_URL="https://data.pyg.org/whl/torch-${tv}+cu124.html"
  "$ENV/bin/pip" install "${PYI[@]}" torch_scatter torch_sparse -f "$PYG_URL"
  "$ENV/bin/pip" install "${PYI[@]}" "torch_geometric==2.2.0"
fi
export PATH="$ENV/bin:$PATH"
export PYTHONPATH="${SHIM}:${SUGAR_ROOT}:${PYTHONPATH:-}"

run_sugar_arm () {
  local sd="$1" out_arm="$2" label="$3"
  echo "=== SUGAR lh $label (fsd=$FSD_ARG) ==="
  set +e
  python "${DLS}/scripts/run_sugar_predict.py" \
    --sd "$sd" --out "$out_arm" --sid "$SID" \
    --hemi lh --device cuda --model-path "$SUGAR_MODEL_PATH" --fsd "$FSD_ARG"
  local rc=$?
  mkdir -p "$out_arm/$SID/scripts"
  if [[ $rc -eq 0 ]]; then
    echo ok > "$out_arm/$SID/scripts/dlsurfer_sugar.done"
    if [[ -x "$INSTALL" ]]; then
      "$INSTALL" --sd "$out_arm" --sid "$SID" --backend sugar --mode sphere \
        --allow-partial-sphere \
        --search-dir "$out_arm" --search-dir "$out_arm/$SID" --search-dir "$sd/$SID" \
        || echo "[sugar] install-surfaces warning for $label" >&2
    fi
  else
    echo "$rc" > "$out_arm/$SID/scripts/dlsurfer_sugar.exit"
  fi
  set -e
  return "$rc"
}

rc_w=0 rc_n=0
if [[ -f "$OUT/with_lit/$SID/scripts/dlsurfer_sugar.done" ]]; then
  echo "=== skip with-LIT (dlsurfer_sugar.done present) ==="
else
  run_sugar_arm "$WITH_LIT_SD" "$OUT/with_lit" "with-LIT" || rc_w=$?
fi
if [[ -d "$NO_LIT_SD/$SID/surf" && -f "$NO_LIT_SD/$SID/surf/lh.sulc" ]]; then
  run_sugar_arm "$NO_LIT_SD" "$OUT/no_lit" "no-LIT" || rc_n=$?
else
  echo "WARN: skip no-LIT — missing $NO_LIT_SD/$SID/surf/lh.sulc" >&2
  rc_n=1
fi

python - <<PY
import json
from pathlib import Path

out = Path("${OUT}")
sid = "${SID}"

def arm(path):
    base = out / path / sid
    surf = base / "surf"
    return {
        "done": (base / "scripts" / "dlsurfer_sugar.done").is_file(),
        "exit": (base / "scripts" / "dlsurfer_sugar.exit").read_text().strip()
        if (base / "scripts" / "dlsurfer_sugar.exit").is_file()
        else None,
        "lh_sphere_reg": (surf / "lh.sphere.reg").is_file(),
        "rh_sphere_reg": (surf / "rh.sphere.reg").is_file(),
        "sugar_meshes": sorted(p.name for p in surf.glob("*sphere*reg*")) if surf.is_dir() else [],
    }

report = {
    "fsd": "${FSD_ARG}",
    "hemi_pretrained": "lh",
    "with_lit": arm("with_lit"),
    "no_lit": arm("no_lit"),
}
report["machine_ok"] = bool(
    report["with_lit"]["done"]
    and report["no_lit"]["done"]
    and report["with_lit"]["lh_sphere_reg"]
    and report["no_lit"]["lh_sphere_reg"]
)
(out / "sugar_tbi_lit_score.json").write_text(json.dumps(report, indent=2) + "\n")
print(json.dumps(report, indent=2))
PY

echo "DONE sugar rc_with=$rc_w rc_no=$rc_n"
[[ $rc_w -eq 0 && $rc_n -eq 0 ]] || exit 1
