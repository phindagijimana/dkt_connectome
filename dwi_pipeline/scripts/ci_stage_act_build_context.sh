#!/usr/bin/env bash
# Stage Docker build contexts for Step 3.1 ACT containers in CI.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TARGET="${1:-all}"
STAGE_QSI="${ROOT}/scripts/stage_qsirecon_tools.sh"

stage_deep_atropos_seg() {
  local ctx="${ROOT}/containers/deep_atropos_seg/build_ctx"
  rm -rf "${ctx}"
  mkdir -p "${ctx}/antsxnet_cache"
  cp "${ROOT}/scripts/run_deep_atropos_seg.py" "${ctx}/"
  cp "${ROOT}/containers/deep_atropos_seg/run_deep_atropos_seg.sh" "${ctx}/"
  echo "  deep_atropos_seg context: ${ctx}"
}

stage_lesion_act() {
  local ctx="${ROOT}/containers/lesion_act/build_ctx"
  rm -rf "${ctx}"
  mkdir -p "${ctx}"
  bash "${STAGE_QSI}" "${ctx}/mrtrix3-latest" "${ctx}/ants"
  cp "${ROOT}/containers/lesion_act/run_lesion_aware_act.sh" "${ctx}/"
  echo "  lesion_act context: ${ctx}"
}

stage_deep_atropos() {
  local ctx="${ROOT}/containers/deep_atropos/build_ctx"
  rm -rf "${ctx}"
  mkdir -p "${ctx}"
  bash "${STAGE_QSI}" "${ctx}/mrtrix3-latest" "${ctx}/_unused_ants"
  rm -rf "${ctx}/_unused_ants"
  cp "${ROOT}/scripts/convert_deep_atropos_to_5tt.py" "${ctx}/"
  cp "${ROOT}/containers/deep_atropos/run_deep_atropos_5tt.sh" "${ctx}/"
  echo "  deep_atropos context: ${ctx}"
}

case "${TARGET}" in
  deep_atropos_seg) stage_deep_atropos_seg ;;
  lesion_act) stage_lesion_act ;;
  deep_atropos) stage_deep_atropos ;;
  all)
    stage_deep_atropos_seg
    stage_lesion_act
    stage_deep_atropos
    ;;
  *) echo "ERROR: unknown target ${TARGET}" >&2; exit 2 ;;
esac

echo "=== ACT build contexts ready (${TARGET}) ==="
