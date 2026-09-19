#!/usr/bin/env bash
# Finish remaining TBI011011 factorial arms after partial failures.
#
#   orig-lesion / vbt-lesion: disconnectome -> nodestrength -> QC
#   vbt-std: qsirecon -> connectome -> disconnectome -> nodestrength -> QC
#
# Usage:
#   bash dwi_pipeline/scripts/submit_tbi011011_arms_finish.sh
#   bash dwi_pipeline/scripts/submit_tbi011011_arms_finish.sh orig-lesion

set -euo pipefail

DWI_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
EXP="/mnt/nfs/Gugger_Lab/NIR/dwi_test_TBI_experiment/sub-TBI011011_fastsurfer_experiment"
TMPL="${DWI_ROOT}/scripts/run_tbi_arm_finish.slurm"

declare -A ARM_MODE=(
  [orig-lesion]=lesion-finish
  [vbt-lesion]=lesion-finish
  [vbt-std]=vbt-std-finish
)

if (($# == 0)); then
  ARMS=(orig-lesion vbt-std vbt-lesion)
else
  ARMS=("$@")
fi

for arm in "${ARMS[@]}"; do
  mode="${ARM_MODE[${arm}]:-}"
  [[ -n "${mode}" ]] || {
    echo "Unknown arm: ${arm} (expected orig-lesion, vbt-std, or vbt-lesion)" >&2
    exit 2
  }
  mkdir -p "${EXP}/arms/${arm}/logs"
  slurm="${EXP}/arms/${arm}/run_${arm}_finish.slurm"
  sed -e "s/@ARM@/${arm}/g" -e "s/@FINISH_MODE@/${mode}/g" "${TMPL}" > "${slurm}"
  chmod +x "${slurm}"
  jid=$(sbatch "${slurm}" | awk '{print $NF}')
  echo "Submitted ${arm} (${mode}): job ${jid}"
done

echo "Monitor: squeue -u \"\$USER\" -n tbi011011_arm"
