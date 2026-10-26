#!/bin/bash
#SBATCH -J dlsurfer_p3_tf
#SBATCH -p interactive
#SBATCH --gres=gpu:l40s.24g:1
#SBATCH -c 8
#SBATCH --mem=48G
#SBATCH -t 06:00:00
#SBATCH -o %x_%j.out
#SBATCH -e %x_%j.err
#
# Phase-3 TBI±LIT: TopoFit on EG with-LIT + seg-quick raw then TopoFit
# Submit:  sbatch hpc/sbatch_phase3_topofit_tbi_lit.sh
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
export DLSURFER_FASTSURFER_NV=1
export DLSURFER_FS_NV=1
export DLSURFER_MRIS_ESTIMATE_WM="${DLS}/env/bin/mris_estimate_wm"

EG_LIT="${EG_LIT:-/mnt/nfs/home/urmc-sh.rochester.edu/pndagiji/Documents/TrackTBI-Sub/dwi_pipeline/analysis/gugger_eg_lit/fastsurfer_inpainting/standalone/fastsurfer_v2.6/subjects}"
RAW_T1="${RAW_T1:-/mnt/nfs/Gugger_Lab/PTE/EG/Nii/DICOM_Ax_3D_T1_MP-RAGE_20240601152700_5.nii.gz}"
OUT="${OUT:-${DLS}/work/phase3_topofit}"
SID=sub-EG

mkdir -p "$OUT/with_lit" "$OUT/no_lit"
nvidia-smi || true
command -v mris_estimate_wm
ls -l "$(command -v mris_estimate_wm)"

if [[ ! -f "$OUT/with_lit/$SID/mri/aseg.mgz" && ! -f "$OUT/with_lit/$SID/mri/aseg.auto_noCCseg.mgz" ]]; then
  echo "Copying EG with-LIT subject tree…"
  rsync -a "${EG_LIT}/${SID}/" "$OUT/with_lit/${SID}/"
fi

# TopoFit via FS 7.4.1 SIF: torch 2.0+cu117 reports GPU but fails conv3d on
# L40S/driver stacks → run CPU (omit --gpu). FastSurfer seg-quick stays on CUDA.
python -m dlsurfer run \
  --profile surf-dl-topofit-only \
  --t1 "$RAW_T1" \
  --sd "$OUT/with_lit" \
  --sid "$SID" \
  --fs-license "$FS_LICENSE" \
  --device cpu \
  --allow-experimental \
  --execute

python -m dlsurfer run \
  --profile seg-quick \
  --t1 "$RAW_T1" \
  --sd "$OUT/no_lit" \
  --sid "$SID" \
  --fs-license "$FS_LICENSE" \
  --device cuda \
  --threads "${SLURM_CPUS_PER_TASK:-8}" \
  --batch-size 1 \
  --viewagg-device cpu \
  --execute

# TopoFit defaults to mri/norm.mgz; FastSurfer --seg_only writes orig_nu.
# surfa rejects symlinks ("is not a file") — use a hard link or copy.
MRI_NL="$OUT/no_lit/$SID/mri"
if [[ -f "$MRI_NL/orig_nu.mgz" ]]; then
  if [[ -L "$MRI_NL/norm.mgz" ]]; then rm -f "$MRI_NL/norm.mgz"; fi
  if [[ ! -f "$MRI_NL/norm.mgz" ]]; then
    ln "$MRI_NL/orig_nu.mgz" "$MRI_NL/norm.mgz" 2>/dev/null || cp -f "$MRI_NL/orig_nu.mgz" "$MRI_NL/norm.mgz"
  fi
fi
if [[ ! -f "$MRI_NL/aseg.mgz" || -L "$MRI_NL/aseg.mgz" ]]; then
  [[ -L "$MRI_NL/aseg.mgz" ]] && rm -f "$MRI_NL/aseg.mgz"
  for a in aseg.auto_noCCseg.mgz aseg.auto.mgz; do
    if [[ -f "$MRI_NL/$a" ]]; then
      ln "$MRI_NL/$a" "$MRI_NL/aseg.mgz" 2>/dev/null || cp -f "$MRI_NL/$a" "$MRI_NL/aseg.mgz"
      break
    fi
  done
fi

python -m dlsurfer run \
  --profile surf-dl-topofit-only \
  --t1 "$RAW_T1" \
  --sd "$OUT/no_lit" \
  --sid "$SID" \
  --fs-license "$FS_LICENSE" \
  --device cpu \
  --allow-experimental \
  --execute

python "${DLS}/scripts/score_topofit_tbi_lit.py" \
  --with-lit "$OUT/with_lit/$SID" \
  --no-lit "$OUT/no_lit/$SID" \
  --ref-white-dir "$EG_LIT/$SID" \
  --out "$OUT/topofit_tbi_lit_score.json"

echo "DONE phase3 TopoFit ±LIT → $OUT"
