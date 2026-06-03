#!/bin/bash
# =============================================================================
# pull_freesurfer_sif.sbatch — pull a community FreeSurfer 7.4.1 image and
# convert it to an Apptainer SIF, stored alongside our other containers.
# =============================================================================
# Runs on a compute node because the login node's /tmp is mounted noexec,
# which breaks Apptainer's OCI-to-SIF conversion step.
#
# Tries a small, ordered list of public images so we degrade gracefully if
# Docker Hub or one of the tags goes away. First success wins.
#
# Submit:    sbatch dwi_pipeline/containers/pull_freesurfer_sif.sbatch
# Watch:     tail -f logs/pull_fs_<jobid>.out
# Output:    /mnt/nfs/.../others/containers/freesurfer_7.4.1.sif
# =============================================================================
#SBATCH --job-name=pull_fs_sif
#SBATCH --partition=general
#SBATCH --cpus-per-task=4
#SBATCH --mem=64G
#SBATCH --time=02:00:00
#SBATCH --exclude=smdodwork05
#SBATCH --output=logs/pull_fs_%j.out
#SBATCH --error=logs/pull_fs_%j.err

# Memory note: the first attempt (44582) died with OUT_OF_MEMORY at the
# mksquashfs step at 8G for the docker://freesurfer/freesurfer:7.4.1 image
# (full FreeSurfer is ~25 GB uncompressed). We give it 64G to be safe; the
# squashfs writer streams but mmaps in chunks that scale with file count.

set -euo pipefail

REPO_ROOT="/mnt/nfs/home/urmc-sh.rochester.edu/pndagiji/Documents/TrackTBI-Sub"
CONTAINERS_DIR="/mnt/nfs/home/urmc-sh.rochester.edu/pndagiji/Documents/others/containers"
OUT_SIF="${CONTAINERS_DIR}/freesurfer_7.4.1.sif"
TMP_SIF="${OUT_SIF}.partial"

mkdir -p "${REPO_ROOT}/logs" "${CONTAINERS_DIR}"

# Compute-node-local scratch (exec-allowed) for Apptainer's temp + cache.
# Without these overrides we'd hit /tmp's noexec and abort.
TMP_BASE=${SLURM_TMPDIR:-/tmp/$USER-apptainer-${SLURM_JOB_ID:-$$}}
export APPTAINER_TMPDIR="${TMP_BASE}/tmp"
export APPTAINER_CACHEDIR="${TMP_BASE}/cache"
mkdir -p "${APPTAINER_TMPDIR}" "${APPTAINER_CACHEDIR}"
echo "APPTAINER_TMPDIR=${APPTAINER_TMPDIR}"
echo "APPTAINER_CACHEDIR=${APPTAINER_CACHEDIR}"
echo "Free space in CONTAINERS_DIR: $(df -h "${CONTAINERS_DIR}" | tail -1)"

# Candidate images, in priority order. First one that pulls and passes the
# atlas sanity check wins.
#
# Note: prior run (44582) showed that nipreps/freesurfer:7.4.1, bids/freesurfer:7.4.1,
# and pwighton/freesurfer:7.4.1 do not exist on Docker Hub ("manifest unknown"),
# so they're omitted. The MGH-published freesurfer/freesurfer:7.4.1 IS the
# canonical image.
CANDIDATES=(
    "docker://freesurfer/freesurfer:7.4.1"
)

rm -f "${TMP_SIF}"
SUCCEEDED=""
FREESURFER_HOME_IN_IMG=""
for src in "${CANDIDATES[@]}"; do
    echo "=== Trying: ${src} ==="
    if ! apptainer pull --force "${TMP_SIF}" "${src}" 2>&1; then
        echo "--- Pull FAILED for ${src}; trying next candidate"
        rm -f "${TMP_SIF}"
        continue
    fi

    echo "--- Pulled; introspecting image layout (don't assume /opt/freesurfer)"
    # Probe the image without deleting it: find FREESURFER_HOME, then check the
    # skull-strip atlas under that root. Older recipes used /opt/freesurfer; the
    # MGH-published freesurfer/freesurfer image uses /usr/local/freesurfer.
    FS_HOME_PROBE="$(apptainer exec --cleanenv "${TMP_SIF}" bash -lc '
        for p in "$FREESURFER_HOME" /opt/freesurfer /usr/local/freesurfer; do
            if [[ -x "$p/bin/recon-all" ]]; then echo "$p"; exit 0; fi
        done
        # Fallback: locate recon-all on PATH and walk up to FREESURFER_HOME.
        ra=$(command -v recon-all || true)
        if [[ -n "$ra" ]]; then dirname "$(dirname "$ra")"; exit 0; fi
        echo ""
    ' 2>/dev/null | tail -1)"
    echo "    detected FREESURFER_HOME: ${FS_HOME_PROBE:-<not found>}"
    if [[ -z "${FS_HOME_PROBE}" ]]; then
        echo "--- recon-all not in image ${src}; rejecting"
        rm -f "${TMP_SIF}"
        continue
    fi
    if ! apptainer exec --cleanenv "${TMP_SIF}" \
            test -f "${FS_HOME_PROBE}/average/RB_all_withskull_2020_01_02.gca"; then
        echo "--- Skull-strip atlas missing under ${FS_HOME_PROBE}; rejecting ${src}"
        rm -f "${TMP_SIF}"
        continue
    fi
    echo "--- Sanity OK (recon-all + skull-strip atlas both present at ${FS_HOME_PROBE})"
    SUCCEEDED="${src}"
    FREESURFER_HOME_IN_IMG="${FS_HOME_PROBE}"
    break
done

if [[ -z "${SUCCEEDED}" ]]; then
    echo "FATAL: none of the candidate images could be pulled + verified."
    rm -rf "${TMP_BASE}" || true
    exit 1
fi

mv "${TMP_SIF}" "${OUT_SIF}"
ls -lh "${OUT_SIF}"

echo
echo "=== Recorded source (so we can rebuild deterministically) ==="
SRC_RECORD="${CONTAINERS_DIR}/freesurfer_7.4.1.source.txt"
{
  echo "image:              ${SUCCEEDED}"
  echo "sif:                ${OUT_SIF}"
  echo "freesurfer_home:    ${FREESURFER_HOME_IN_IMG}"
  echo "pulled_at:          $(date -Is)"
  echo "pulled_by:          ${USER}@$(hostname -s)"
  echo "sha256:             $(sha256sum "${OUT_SIF}" | awk '{print $1}')"
} | tee "${SRC_RECORD}"

echo
echo "=== Post-pull sanity ==="
apptainer exec --cleanenv "${OUT_SIF}" "${FREESURFER_HOME_IN_IMG}/bin/recon-all" -version
apptainer exec --cleanenv "${OUT_SIF}" \
    ls -la "${FREESURFER_HOME_IN_IMG}/average/RB_all_withskull_2020_01_02.gca"

rm -rf "${TMP_BASE}" || true

echo
echo "Done. Update dwi_pipeline/subject.sh CONTAINER_FREESURFER default to:"
echo "    ${OUT_SIF}"
