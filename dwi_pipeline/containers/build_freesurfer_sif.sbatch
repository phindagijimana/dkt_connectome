#!/bin/bash
# =============================================================================
# build_freesurfer_sif.sbatch — build the standalone FreeSurfer 7.4.1 SIF.
# =============================================================================
# Runs on a compute node because the login node's /tmp is mounted with
# `noexec`, which breaks `apptainer build` (it extracts OCI layers into /tmp
# and tries to exec setup tools there).
#
# Submit:
#     sbatch dwi_pipeline/containers/build_freesurfer_sif.sbatch
#
# Watch:
#     tail -f logs/build_fs_<jobid>.out
# =============================================================================
#SBATCH --job-name=build_fs_sif
#SBATCH --partition=general
#SBATCH --cpus-per-task=4
#SBATCH --mem=16G
#SBATCH --time=02:00:00
#SBATCH --exclude=smdodwork05
#SBATCH --output=logs/build_fs_%j.out
#SBATCH --error=logs/build_fs_%j.err

set -euo pipefail

REPO_ROOT="/mnt/nfs/home/urmc-sh.rochester.edu/pndagiji/Documents/TrackTBI-Sub"
CONTAINERS_DIR="/mnt/nfs/home/urmc-sh.rochester.edu/pndagiji/Documents/others/containers"
DEF_FILE="${REPO_ROOT}/dwi_pipeline/containers/Singularity.freesurfer-7.4.1.def"
OUT_SIF="${CONTAINERS_DIR}/freesurfer_7.4.1.sif"
TMP_SIF="${OUT_SIF}.partial"

mkdir -p "${REPO_ROOT}/logs"
mkdir -p "${CONTAINERS_DIR}"

# Compute-node-local scratch for apptainer's temp + cache (exec-allowed).
# /tmp on compute nodes is normally writable+exec; /scratch is even better
# if your cluster exposes it.
TMP_BASE=${SLURM_TMPDIR:-/tmp/$USER-apptainer-$SLURM_JOB_ID}
export APPTAINER_TMPDIR="${TMP_BASE}/tmp"
export APPTAINER_CACHEDIR="${TMP_BASE}/cache"
mkdir -p "${APPTAINER_TMPDIR}" "${APPTAINER_CACHEDIR}"
echo "APPTAINER_TMPDIR=${APPTAINER_TMPDIR}"
echo "APPTAINER_CACHEDIR=${APPTAINER_CACHEDIR}"

# Sanity: source FS install exists.
SRC_FS="/mnt/nfs/home/urmc-sh.rochester.edu/pndagiji/Documents/others/data_mining/freesurfer"
[[ -d "${SRC_FS}" ]] || { echo "FATAL: ${SRC_FS} not found"; exit 1; }
[[ -f "${SRC_FS}/average/RB_all_withskull_2020_01_02.gca" ]] \
    || { echo "FATAL: missing atlas on source"; exit 1; }
echo "Source FS install: $(du -sh "${SRC_FS}" | cut -f1)"

# Build into a partial path first; atomic move on success.
rm -f "${TMP_SIF}"
echo "=== apptainer build ==="
apptainer build --fakeroot "${TMP_SIF}" "${DEF_FILE}"

echo "=== build OK; promoting to final path ==="
mv "${TMP_SIF}" "${OUT_SIF}"
ls -lh "${OUT_SIF}"

echo "=== post-build sanity ==="
apptainer exec --cleanenv "${OUT_SIF}" recon-all -version
apptainer exec --cleanenv "${OUT_SIF}" ls /opt/freesurfer/average/RB_all_withskull_2020_01_02.gca

# Clean compute-node scratch we created.
rm -rf "${TMP_BASE}" || true

echo "Done. New container:"
echo "  ${OUT_SIF}"
echo
echo "Next: update dwi_pipeline/subject.sh + submit.sh to set"
echo "  CONTAINER_FREESURFER=${OUT_SIF}"
