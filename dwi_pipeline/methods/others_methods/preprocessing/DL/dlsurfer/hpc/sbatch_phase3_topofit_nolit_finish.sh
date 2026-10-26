#!/bin/bash
#SBATCH -J dlsurfer_p3_tf_nl
#SBATCH -p interactive
#SBATCH --gres=gpu:l40s.24g:1
#SBATCH -c 8
#SBATCH --mem=48G
#SBATCH -t 03:00:00
#SBATCH -o %x_%j.out
#SBATCH -e %x_%j.err
#
# Finish Phase-3 no_lit: tal_reg (for TopoFit) → TopoFit → score JSON
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
export DLSURFER_FASTSURFER_NV=1 DLSURFER_FS_NV=1
export DLSURFER_MRIS_ESTIMATE_WM="${DLS}/env/bin/mris_estimate_wm"

RAW_T1="${RAW_T1:-/mnt/nfs/Gugger_Lab/PTE/EG/Nii/DICOM_Ax_3D_T1_MP-RAGE_20240601152700_5.nii.gz}"
EG_LIT="${EG_LIT:-/mnt/nfs/home/urmc-sh.rochester.edu/pndagiji/Documents/TrackTBI-Sub/dwi_pipeline/analysis/gugger_eg_lit/fastsurfer_inpainting/standalone/fastsurfer_v2.6/subjects}"
OUT="${OUT:-${DLS}/work/phase3_topofit}"
SID=sub-EG
MRI_NL="$OUT/no_lit/$SID/mri"

# Hardlink orig_nu → norm (surfa rejects symlinks)
if [[ -f "$MRI_NL/orig_nu.mgz" ]]; then
  [[ -L "$MRI_NL/norm.mgz" ]] && rm -f "$MRI_NL/norm.mgz"
  if [[ ! -f "$MRI_NL/norm.mgz" ]]; then
    ln "$MRI_NL/orig_nu.mgz" "$MRI_NL/norm.mgz" 2>/dev/null || cp -f "$MRI_NL/orig_nu.mgz" "$MRI_NL/norm.mgz"
  fi
fi

# TopoFit needs talairach.lta — add via FastSurfer --seg_only --tal_reg
if [[ ! -f "$MRI_NL/transforms/talairach.lta" && ! -f "$MRI_NL/transforms/talairach.xfm.lta" ]]; then
  echo "Running FastSurfer --seg_only --tal_reg for no_lit talairach…"
  "${FASTSURFER_HOME}/run_fastsurfer.sh" \
    --t1 "$RAW_T1" \
    --sid "$SID" \
    --sd "$OUT/no_lit" \
    --fs_license "$FS_LICENSE" \
    --device cuda \
    --threads "${SLURM_CPUS_PER_TASK:-8}" \
    --3T \
    --batch 1 \
    --viewagg_device cpu \
    --seg_only \
    --tal_reg
fi

# Prefer a real file for talairach.lta (not a dangling symlink)
if [[ -f "$MRI_NL/transforms/talairach.xfm.lta" && ! -f "$MRI_NL/transforms/talairach.lta" ]]; then
  ln "$MRI_NL/transforms/talairach.xfm.lta" "$MRI_NL/transforms/talairach.lta" 2>/dev/null \
    || cp -f "$MRI_NL/transforms/talairach.xfm.lta" "$MRI_NL/transforms/talairach.lta"
fi
if [[ -L "$MRI_NL/transforms/talairach.lta" ]]; then
  tgt=$(readlink -f "$MRI_NL/transforms/talairach.lta")
  rm -f "$MRI_NL/transforms/talairach.lta"
  ln "$tgt" "$MRI_NL/transforms/talairach.lta" 2>/dev/null || cp -f "$tgt" "$MRI_NL/transforms/talairach.lta"
fi

ls -la "$MRI_NL/norm.mgz" "$MRI_NL/transforms/talairach.lta"

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

echo "DONE phase3 TopoFit no_lit finish → $OUT/topofit_tbi_lit_score.json"
python -m json.tool "$OUT/topofit_tbi_lit_score.json"
