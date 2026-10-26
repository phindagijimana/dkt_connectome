#!/bin/bash
# EG Gugger PTE — dlsurfer core-lesion smoke (standalone LIT → FastSurfer)
# Usage:
#   source env/cluster_containers.sh
#   bash scripts/eg_core_lesion_smoke.sh          # dry-run
#   EXECUTE=1 bash scripts/eg_core_lesion_smoke.sh
#   EXECUTE=1 FILL_ONLY=1 bash scripts/eg_core_lesion_smoke.sh
set -euo pipefail

DLS="$(cd "$(dirname "$0")/.." && pwd)"
# shellcheck disable=SC1091
source "${DLS}/env/cluster_containers.sh"
export PYTHONPATH="${DLS}${PYTHONPATH:+:$PYTHONPATH}"

T1="${T1:-/mnt/nfs/Gugger_Lab/PTE/EG/Nii/DICOM_Ax_3D_T1_MP-RAGE_20240601152700_5.nii.gz}"
LESION="${LESION:-/mnt/nfs/Gugger_Lab/PTE/EG/Nii/Lesion.nii.gz}"
SD="${SD:-${DLS}/work/eg_smoke_subjects}"
SID="${SID:-sub-EG}"
DEVICE="${DEVICE:-cpu}"

mkdir -p "$SD"
echo "[eg-smoke] T1=$T1"
echo "[eg-smoke] LESION=$LESION"
echo "[eg-smoke] SD=$SD SID=$SID DEVICE=$DEVICE"

python -m dlsurfer doctor --profile core-lesion

EXTRA=()
if [[ "${EXECUTE:-0}" == "1" ]]; then
  EXTRA+=(--execute)
fi
if [[ "${FILL_ONLY:-0}" == "1" ]]; then
  # Execute only LIT fill by building plan and running first runnable step
  python - <<'PY' "$T1" "$LESION" "$SD" "$SID" "$DEVICE"
import sys
from pathlib import Path
from dlsurfer.adapters.plan import build_plan, runnable_steps
from dlsurfer.runner import execute_plan

t1, les, sd, sid, device = sys.argv[1:6]
plan = build_plan(
    "core-lesion",
    t1=Path(t1),
    sd=Path(sd),
    sid=sid,
    lesion_mask=Path(les),
    fs_license=Path(__import__("os").environ["FS_LICENSE"]),
    device=device,
    post_lit=False,
)
# Keep only neurolit fill for FILL_ONLY
fill = [s for s in plan.steps if s.engine_id == "neurolit" and s.stage == "fill"]
plan.steps = fill
raise SystemExit(execute_plan(plan, dry_run=False, sd=Path(sd), sid=sid))
PY
  echo "[eg-smoke] FILL_ONLY done — inpainted under $SD/$SID"
  exit 0
fi

python -m dlsurfer run \
  --profile core-lesion \
  --t1 "$T1" \
  --lesion-mask "$LESION" \
  --sd "$SD" \
  --sid "$SID" \
  --fs-license "$FS_LICENSE" \
  --device "$DEVICE" \
  "${EXTRA[@]}"

echo "[eg-smoke] finished (EXECUTE=${EXECUTE:-0})"
