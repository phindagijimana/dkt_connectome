#!/bin/bash
#SBATCH -J dlsurfer_eg_cl
#SBATCH -p interactive
#SBATCH --gres=gpu:l40s.24g:1
#SBATCH -c 8
#SBATCH --mem=48G
#SBATCH -t 08:00:00
#SBATCH -o %x_%j.out
#SBATCH -e %x_%j.err
#
# EG: reuse neurolit fill → dlsurfer core on GPU → lit-post
# Submit from dlsurfer/:  sbatch hpc/sbatch_eg_gpu_core_lesion.sh
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
export DLSURFER_LIT_NV=1 DLSURFER_FASTSURFER_NV=1
export DLSURFER_FS_NV=1
export DLSURFER_MRIS_ESTIMATE_WM="${DLS}/env/bin/mris_estimate_wm"

T1_INPAINT="${T1_INPAINT:-/mnt/nfs/home/urmc-sh.rochester.edu/pndagiji/Documents/TrackTBI-Sub/dwi_pipeline/analysis/gugger_eg_lit/fastsurfer_inpainting/standalone/inpaint/inpainting_volumes/inpainting_result.nii.gz}"
SD="${SD:-${DLS}/work/eg_gpu_core_lesion}"
SID="${SID:-sub-EG}"

mkdir -p "$SD"
nvidia-smi || true
python -m dlsurfer doctor --profile core || true

python -m dlsurfer run \
  --profile core \
  --t1 "$T1_INPAINT" \
  --sd "$SD" \
  --sid "$SID" \
  --fs-license "$FS_LICENSE" \
  --device cuda \
  --threads "${SLURM_CPUS_PER_TASK:-8}" \
  --batch-size 1 \
  --viewagg-device cpu \
  --execute

mkdir -p "${SD}/${SID}/mri"
cp -f "$T1_INPAINT" "${SD}/${SID}/mri/inpainted.lit.nii.gz"
lit-postprocessing -sid "$SID" -sd "$SD" || echo "WARN: lit-post failed (non-fatal)"

python - <<PY
from pathlib import Path
from dlsurfer.contract import check_contract
sd, sid = Path("$SD"), "$SID"
probs = check_contract(sd, sid)
(sd / sid / "scripts").mkdir(parents=True, exist_ok=True)
(sd / sid / "scripts" / "dlsurfer_eg_gpu_core_lesion.done").write_text(
    "ok\n" + ("\n".join(probs) if probs else "contract_clean\n")
)
print("contract:", "OK" if not probs else probs)
PY

echo "DONE → $SD/$SID"
