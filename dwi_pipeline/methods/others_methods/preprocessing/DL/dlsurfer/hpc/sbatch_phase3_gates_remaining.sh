#!/bin/bash
#SBATCH -J dlsurfer_p3_gates
#SBATCH -p interactive
#SBATCH --gres=gpu:l40s.24g:1
#SBATCH -c 8
#SBATCH --mem=48G
#SBATCH -t 08:00:00
#SBATCH -o %x_%j.out
#SBATCH -e %x_%j.err
#
# Finish open surface gates (excl. SynthSeg-PC): V2C, SUGAR, CortexMorph (±LIT).
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
export APPTAINER_TMPDIR="${HOME}/.apptainer/tmp"
export APPTAINER_CACHEDIR="${HOME}/.apptainer/cache"
export PROOT_TMP_DIR="${HOME}/.apptainer/proot_tmp"
mkdir -p "$APPTAINER_TMPDIR" "$APPTAINER_CACHEDIR" "$PROOT_TMP_DIR"

export SUGAR_ROOT="${SUGAR_ROOT:-${HOME}/Documents/others/SUGAR}"
export SUGAR_SIF="${SUGAR_SIF:-${HOME}/Documents/others/containers/sugar_latest.sif}"
export SUGAR_MODEL_PATH="${SUGAR_MODEL_PATH:-${SUGAR_ROOT}/pretrained}"
export CORTEXMORPH_ROOT="${CORTEXMORPH_ROOT:-${HOME}/Documents/others/CortexMorph}"
export V2C_ROOT="${V2C_ROOT:-${HOME}/Documents/others/Vox2Cortex}"

WITH_LIT_SD="${WITH_LIT_SD:-${DLS}/work/eg_gpu_core_lesion}"
# no-LIT: prefer phase3_topofit no_lit tree (has aseg); else standalone without fill is N/A — use with_lit copy note
NO_LIT_SD="${NO_LIT_SD:-${DLS}/work/phase3_topofit/no_lit}"
SID="${SID:-sub-EG}"
OUT="${OUT:-${DLS}/work/phase3_gates}"
mkdir -p "$OUT"/{sugar_with_lit,sugar_no_lit,cm_with_lit,cm_no_lit,v2c_with_lit,v2c_no_lit}

nvidia-smi || true

# Ensure fsaverage for SUGAR
for SD in "$WITH_LIT_SD" "$NO_LIT_SD"; do
  if [[ -d "$SD/$SID" && ! -e "$SD/fsaverage" ]]; then
    REF_FS="/mnt/nfs/home/urmc-sh.rochester.edu/pndagiji/Documents/TrackTBI-Sub/dwi_pipeline/analysis/gugger_eg_lit/fastsurfer_inpainting/standalone/fastsurfer_v2.6/subjects/fsaverage"
    [[ -d "$REF_FS" ]] && ln -sfn "$REF_FS" "$SD/fsaverage"
  fi
done

echo "=== SUGAR ±LIT ==="
export SUBJECTS_DIR="$WITH_LIT_SD"
dlsurfer-sugar --sd "$WITH_LIT_SD" --sid "$SID" --out "$OUT/sugar_with_lit" --hemi both --device cuda \
  || dlsurfer-sugar --sd "$WITH_LIT_SD" --sid "$SID" --out "$OUT/sugar_with_lit" --hemi lh --device cuda \
  || echo "WARN sugar with-LIT failed"
if [[ -d "$NO_LIT_SD/$SID/surf" ]]; then
  export SUBJECTS_DIR="$NO_LIT_SD"
  dlsurfer-sugar --sd "$NO_LIT_SD" --sid "$SID" --out "$OUT/sugar_no_lit" --hemi both --device cuda \
    || dlsurfer-sugar --sd "$NO_LIT_SD" --sid "$SID" --out "$OUT/sugar_no_lit" --hemi lh --device cuda \
    || echo "WARN sugar no-LIT failed"
fi

echo "=== CortexMorph ±LIT ==="
# Install nnunet into job-local venv if missing
if ! python3 -c 'from nnunet.network_architecture.generic_UNet import Generic_UNet' 2>/dev/null; then
  python3 -m pip install --user -i https://pypi.org/simple --trusted-host pypi.org \
    --trusted-host files.pythonhosted.org 'nnunet==1.7.1' batchgenerators pandas 2>&1 | tail -20 || true
fi
export PYTHONPATH="$(python3 -m site --user-site):${PYTHONPATH:-}"
dlsurfer-cortexmorph --sd "$WITH_LIT_SD" --sid "$SID" --out "$OUT/cm_with_lit" --device cuda \
  || echo "WARN cortexmorph with-LIT failed"
if [[ -d "$NO_LIT_SD/$SID/mri" ]]; then
  dlsurfer-cortexmorph --sd "$NO_LIT_SD" --sid "$SID" --out "$OUT/cm_no_lit" --device cuda \
    || echo "WARN cortexmorph no-LIT failed"
fi

echo "=== V2C-Flow ±LIT (conda env if present) ==="
T1_LIT="${T1_LIT:-/mnt/nfs/home/urmc-sh.rochester.edu/pndagiji/Documents/TrackTBI-Sub/dwi_pipeline/analysis/gugger_eg_lit/fastsurfer_inpainting/standalone/inpaint/inpainting_volumes/inpainting_result.nii.gz}"
if [[ -x "$(command -v conda)" ]] || [[ -f "${HOME}/miniconda3/etc/profile.d/conda.sh" ]]; then
  # shellcheck disable=SC1091
  source "${HOME}/miniconda3/etc/profile.d/conda.sh" 2>/dev/null || true
  conda activate vox2organ 2>/dev/null || conda activate torch_1_10 2>/dev/null || true
fi
export V2C_PYTHON="${V2C_PYTHON:-$(command -v python)}"
dlsurfer-v2c --t1 "$T1_LIT" --out-dir "$OUT/v2c_with_lit" --sid "$SID" --device cuda \
  || echo "WARN v2c with-LIT failed (needs vox2organ env + dataset registration)"

echo "=== Score ==="
python3 "${DLS}/scripts/score_phase3_gates.py" --root "$OUT" --sid "$SID" \
  --out "$OUT/phase3_gates_score.json"

echo DONE
cat "$OUT/phase3_gates_score.json" || true
