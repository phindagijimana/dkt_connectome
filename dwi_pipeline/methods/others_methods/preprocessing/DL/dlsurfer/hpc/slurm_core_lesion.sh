#!/bin/bash
# DLSurfer HPC template: GPU fill+seg → CPU surf → CPU lit-post
# Usage: edit paths, then sbatch this script OR submit the two array stages separately.
set -euo pipefail

#SBATCH -J dlsurfer
#SBATCH -o dlsurfer_%j.out

T1=${T1:?}
LESION=${LESION:?}
SD=${SD:?}
SID=${SID:?}
FS_LICENSE=${FS_LICENSE:?}
export FASTSURFER_HOME=${FASTSURFER_HOME:?}
export FS_LICENSE

PROFILE=${PROFILE:-core-lesion}
DEVICE=${DEVICE:-cuda}

# Stage A — GPU (fill + seg_only plan steps). Prefer a GPU partition.
# Stage B — CPU (surf_only + lit-post). Prefer a CPU partition.
#
# For automation, run:
#   dlsurfer run --profile "$PROFILE" --t1 "$T1" --lesion-mask "$LESION" \
#     --sd "$SD" --sid "$SID" --fs-license "$FS_LICENSE" --device "$DEVICE" --execute
#
# Or dry-run first:
dlsurfer run --profile "$PROFILE" --t1 "$T1" --lesion-mask "$LESION" \
  --sd "$SD" --sid "$SID" --fs-license "$FS_LICENSE" --device "$DEVICE"

echo "Re-run with --execute on the appropriate partitions after reviewing the plan."
echo "Native profile core-lesion-native cannot split seg/surf across partitions."