#!/usr/bin/env bash
# Stage Docker build contexts for Step 3.5 ACT containers in CI.
#
# Usage:
#   bash scripts/ci_stage_act_build_context.sh all
#   bash scripts/ci_stage_act_build_context.sh deep_atropos_seg
#   bash scripts/ci_stage_act_build_context.sh lesion_act
#   bash scripts/ci_stage_act_build_context.sh deep_atropos
#
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
QSI_IMAGE="${QSI_IMAGE:-pennlinc/qsirecon:1.2.1}"
TARGET="${1:-all}"

stage_deep_atropos_seg() {
  local ctx="${ROOT}/containers/deep_atropos_seg/build_ctx"
  rm -rf "${ctx}"
  mkdir -p "${ctx}/antsxnet_cache"
  cp "${ROOT}/scripts/run_deep_atropos_seg.py" "${ctx}/"
  cp "${ROOT}/containers/deep_atropos_seg/run_deep_atropos_seg.sh" "${ctx}/"
  echo "  deep_atropos_seg context: ${ctx}"
}

stage_from_qsirecon() {
  local dest_mrtrix="$1"
  local dest_ants="$2"
  rm -rf "${dest_mrtrix}" "${dest_ants}"
  mkdir -p "${dest_mrtrix}" "${dest_ants}"
  echo "  Pulling ${QSI_IMAGE} for MRtrix/ANTs staging..."
  docker pull "${QSI_IMAGE}"
  cid="$(docker create "${QSI_IMAGE}")"
  trap 'docker rm -f "${cid}" >/dev/null 2>&1 || true' RETURN
  docker cp "${cid}:/opt/mrtrix3-latest/." "${dest_mrtrix}/"
  docker cp "${cid}:/opt/ants/." "${dest_ants}/"
  docker rm -f "${cid}"
  trap - RETURN
  [[ -x "${dest_mrtrix}/bin/tckgen" ]] || { echo "ERROR: MRtrix staging failed"; exit 1; }
  [[ -x "${dest_ants}/bin/antsApplyTransforms" ]] || { echo "ERROR: ANTs staging failed"; exit 1; }
}

stage_lesion_act() {
  local ctx="${ROOT}/containers/lesion_act/build_ctx"
  rm -rf "${ctx}"
  mkdir -p "${ctx}"
  stage_from_qsirecon "${ctx}/mrtrix3-latest" "${ctx}/ants"
  cp "${ROOT}/containers/lesion_act/run_lesion_aware_act.sh" "${ctx}/"
  echo "  lesion_act context: ${ctx}"
}

stage_deep_atropos() {
  local ctx="${ROOT}/containers/deep_atropos/build_ctx"
  rm -rf "${ctx}"
  mkdir -p "${ctx}"
  stage_from_qsirecon "${ctx}/mrtrix3-latest" "${ctx}/_unused_ants"
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
