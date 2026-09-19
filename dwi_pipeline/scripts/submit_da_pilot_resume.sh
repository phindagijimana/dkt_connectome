#!/bin/bash
# Resume deep-atropos-pilot (sub-TBI011011) on interactive (12 h max).
#
# Keeps a complete 10M-streamline .tck and finishes tcksift2 + downstream only.
#
# Usage:
#   bash dwi_pipeline/scripts/submit_da_pilot_resume.sh

set -euo pipefail

DWI_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
ARCH="${TBI_EXPERIMENT_ARCH:-/mnt/nfs/Gugger_Lab/NIR/dwi_test_TBI_experiment}"
PILOT="${ARCH}/sub-TBI011011_fastsurfer_experiment/arms/deep-atropos-pilot"
BIDS="${ARCH}/bids"
CACHE="${ARCH}/.cache/antsxnet"
SLURM="${PILOT}/run_deep_atropos_act.slurm"
T1W="${BIDS}/sub-TBI011011/ses-2WK/anat/sub-TBI011011_ses-2WK_acq-3D_T1w.nii.gz"
SEG_DIR="${PILOT}/deep_atropos_seg/sub-TBI011011"
SEG="${SEG_DIR}/desc-deepatropos_seg.nii.gz"
FIVE="${PILOT}/deep_atropos/sub-TBI011011/base_5tt_native.mif"
ACT_DIR="${PILOT}/lesion_aware_act/sub-TBI011011"
TCK="${ACT_DIR}/model-ifod2_streamlines.tck"
CONTAINER="${DEEP_ATROPOS_SEG_CONTAINER:-/mnt/nfs/home/urmc-sh.rochester.edu/pndagiji/Documents/others/containers/dkt_deep_atropos_seg.sif}"

unset BIDS_DIR RESULTS_ROOT EXPERIMENT_ARM RECON_SESSION CIDUR_RESULTS_ROOT
export TBI_EXPERIMENT_ARCH="${ARCH}"

[[ -f "${SLURM}" ]] || {
  echo "Missing Slurm script: ${SLURM}" >&2
  exit 1
}
[[ -f "${T1W}" ]] || {
  echo "Missing T1w: ${T1W}" >&2
  exit 1
}
[[ -f "${CONTAINER}" ]] || {
  echo "Missing seg container: ${CONTAINER}" >&2
  exit 1
}

mkdir -p "${CACHE}" "${SEG_DIR}" "${PILOT}/logs"

echo "=== Prep deep-atropos-pilot ==="
rm -rf "${PILOT}/.snakemake_workdir/.snakemake/locks" 2>/dev/null || true
mkdir -p "${PILOT}/.snakemake_workdir/.snakemake/locks"

if [[ -f "${TCK}" && ! -f "${ACT_DIR}/lesion_aware_act.json" ]]; then
  tck_bytes="$(stat -c '%s' "${TCK}" 2>/dev/null || echo 0)"
  if (( tck_bytes >= 7000000000 )); then
    echo "  keep complete tckgen output (${tck_bytes} bytes); will resume at tcksift2"
  else
    echo "  remove partial tckgen (${tck_bytes} bytes, no lesion_aware_act.json)"
    rm -f "${TCK}" "${ACT_DIR}/model-sift2_streamlineweights.csv"
  fi
fi

if [[ ! -f "${SEG}" && -f "${FIVE}" ]]; then
  echo "  backfill deep_atropos_seg (5TT present, seg missing)"
  apptainer run --cleanenv --containall \
    -B "$(dirname "${T1W}")":/bids_t1w:ro \
    -B "${SEG_DIR}":/out \
    -B "${DWI_ROOT}/scripts/run_deep_atropos_seg.py":/opt/deep_atropos_seg/run_deep_atropos_seg.py:ro \
    -B "${CACHE}":/opt/antsxnet_cache \
    "${CONTAINER}" \
    --t1w "/bids_t1w/$(basename "${T1W}")" \
    --outdir /out
fi

if [[ -f "${SEG}" && ! -f "${SEG_DIR}/deep_atropos_seg.json" ]]; then
  python3.12 -c "
import json
from pathlib import Path
p = Path('${SEG_DIR}/deep_atropos_seg.json')
p.write_text(json.dumps({
    'segmentation_source': 'generated',
    'deep_atropos_segmentation': str(Path('${SEG}').resolve()),
    'canonical_path': str(Path('${SEG}').resolve()),
    'segmentation_mode': 'generate',
}, indent=2) + '\n')
"
  echo "  wrote ${SEG_DIR}/deep_atropos_seg.json"
fi

echo "=== Submit da_pilot resume (12h, interactive) ==="
sbatch --partition="${SBATCH_PARTITION:-interactive}" \
  --time="${SBATCH_TIME:-12:00:00}" \
  --mem="${SBATCH_MEM:-64G}" \
  "${SLURM}"

echo "Monitor: squeue -u \"\$USER\" -n da_pilot_TBI011011"
