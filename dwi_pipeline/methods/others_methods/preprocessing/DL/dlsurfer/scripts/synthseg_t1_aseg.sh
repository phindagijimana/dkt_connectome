#!/usr/bin/env bash
# FreeSurfer SynthSeg → NIfTI aseg for V2C-Long staging (no SUBJECTS_DIR required).
set -euo pipefail

T1="${1:?usage: synthseg_t1_aseg.sh T1.nii.gz OUT_aseg.nii.gz}"
OUT="${2:?usage: synthseg_t1_aseg.sh T1.nii.gz OUT_aseg.nii.gz}"

DLS="${DLS:-$(cd "$(dirname "$0")/.." && pwd)}"
# shellcheck disable=SC1091
source "${DLS}/env/cluster_containers.sh"

SIF="${SIF_FREESURFER:-${DLSURFER_SIF_FREESURFER:-}}"
[[ -f "$SIF" ]] || { echo "[synthseg] missing FreeSurfer SIF: $SIF" >&2; exit 2; }
[[ -f "$T1" ]] || { echo "[synthseg] missing T1: $T1" >&2; exit 2; }

mkdir -p "$(dirname "$OUT")"
tmp="${OUT%.nii.gz}.mgz"
tmp="${tmp%.nii}.mgz"

apptainer exec -B /mnt/nfs -B "${FS_LICENSE}:${FS_LICENSE}:ro" "$SIF" bash -lc "
  export FS_LICENSE='${FS_LICENSE}'
  mri_synthseg --i '${T1}' --o '${tmp}' --robust --threads \${SLURM_CPUS_PER_TASK:-4}
"
apptainer exec -B /mnt/nfs -B "${FS_LICENSE}:${FS_LICENSE}:ro" "$SIF" bash -lc "
  export FS_LICENSE='${FS_LICENSE}'
  mri_convert '${tmp}' '${OUT}'
"
rm -f "$tmp"
echo "[synthseg] wrote ${OUT}"
