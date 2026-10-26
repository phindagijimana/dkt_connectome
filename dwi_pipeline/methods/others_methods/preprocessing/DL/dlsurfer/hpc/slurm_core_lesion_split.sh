#!/bin/bash
# Separable LIT + GPU seg / CPU surf split for core-lesion (or core-lesion-native).
#
# Upstream FastSurfer --lesion_mask cannot use --seg_only/--surf_only. DLSurfer
# therefore runs standalone lit-inpainting first, then ordinary FastSurfer with a
# clean GPU/CPU partition split.
#
# Usage:
#   export T1=… LESION=… SD=… SID=… FS_LICENSE=… FASTSURFER_HOME=… FREESURFER_HOME=…
#   export EXECUTE=1          # omit for dry-run only
#   sbatch hpc/slurm_core_lesion_split.sh
#
# Optional: PART_GPU PART_CPU ACCOUNT PROFILE (default core-lesion)
set -euo pipefail

#SBATCH -J dlsurfer_lit_split
#SBATCH -o dlsurfer_lit_split_%j.out

: "${T1:?set T1}" "${LESION:?set LESION}" "${SD:?set SD}" "${SID:?set SID}"
: "${FS_LICENSE:?set FS_LICENSE}"
: "${FASTSURFER_HOME:?set FASTSURFER_HOME}" "${FREESURFER_HOME:?set FREESURFER_HOME}"
export FS_LICENSE FASTSURFER_HOME FREESURFER_HOME
DLS=${DLSURFER_ROOT:-$(cd "$(dirname "$0")/.." && pwd)}
export PYTHONPATH="${DLS}${PYTHONPATH:+:$PYTHONPATH}"

PROFILE=${PROFILE:-core-lesion}
PART_GPU=${PART_GPU:-gpu}
PART_CPU=${PART_CPU:-cpu}
ACCOUNT=${ACCOUNT:-}
EXEC_ARGS=""
if [[ "${EXECUTE:-0}" == "1" ]]; then
  EXEC_ARGS="--execute"
fi

acct=()
[[ -n "$ACCOUNT" ]] && acct=(-A "$ACCOUNT")

echo "[dlsurfer] separable LIT split profile=$PROFILE EXECUTE=${EXECUTE:-0}"

# Stage A — GPU: lit-inpaint + FastSurfer --seg_only
JOBA=$(sbatch --parsable "${acct[@]}" -p "$PART_GPU" --gres=gpu:1 --wrap \
  "cd '$DLS' && export PYTHONPATH='$DLS'\${PYTHONPATH:+:\$PYTHONPATH} && \
   python -m dlsurfer run --profile '$PROFILE' \
     --t1 '$T1' --lesion-mask '$LESION' --sd '$SD' --sid '$SID' \
     --fs-license '$FS_LICENSE' --device cuda \
     --stage gpu --no-post-lit $EXEC_ARGS")
echo "submitted GPU stage (fill+seg) job=$JOBA"

# Stage B — CPU: FastSurfer --surf_only + lit-post
JOBB=$(sbatch --parsable "${acct[@]}" -p "$PART_CPU" --dependency=afterok:"$JOBA" --wrap \
  "cd '$DLS' && export PYTHONPATH='$DLS'\${PYTHONPATH:+:\$PYTHONPATH} && \
   python -m dlsurfer run --profile '$PROFILE' \
     --t1 '$T1' --lesion-mask '$LESION' --sd '$SD' --sid '$SID' \
     --fs-license '$FS_LICENSE' --device cpu \
     --stage cpu $EXEC_ARGS")
echo "submitted CPU stage (surf+post) job=$JOBB (afterok:$JOBA)"

echo "Local dry-run:"
echo "  PYTHONPATH=. python -m dlsurfer run --profile $PROFILE --t1 \$T1 --lesion-mask \$LESION --sd \$SD --sid \$SID --stage gpu -q"
echo "  PYTHONPATH=. python -m dlsurfer run --profile $PROFILE --t1 \$T1 --lesion-mask \$LESION --sd \$SD --sid \$SID --stage cpu -q"
echo "Docs: docs/reference/LIT_SPLIT.md"
