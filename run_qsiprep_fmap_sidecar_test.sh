#!/bin/bash
# -----------------------------------------------------------------------------
# Test: QSIPrep on a minimal BIDS copy of one subject with fmap/ EPI but NO
#   *.bval / *.bvec next to the EPI (see test_bids_fmap_no_sidecars/).
# Uses measured fmaps if QSIPrep accepts them (no QSIPREP_FMAP_RETRY).
#
# Submit:  sbatch run_qsiprep_fmap_sidecar_test.sh
# Or run interactively (long):  bash run_qsiprep_fmap_sidecar_test.sh
# -----------------------------------------------------------------------------

#SBATCH --job-name=qsiprep_fmaptest
#SBATCH --output=/mnt/nfs/home/urmc-sh.rochester.edu/pndagiji/Documents/TrackTBI-Sub/logs/qsiprep_fmap_sidecar_test_%j.out
#SBATCH --error=/mnt/nfs/home/urmc-sh.rochester.edu/pndagiji/Documents/TrackTBI-Sub/logs/qsiprep_fmap_sidecar_test_%j.err
#SBATCH --time=24:00:00
#SBATCH --partition=general
#SBATCH --cpus-per-task=8
#SBATCH --mem=32G

set -euo pipefail
set +H

PROJECT_ROOT=/mnt/nfs/home/urmc-sh.rochester.edu/pndagiji/Documents/TrackTBI-Sub
BIDS_DIR="${BIDS_DIR:-${PROJECT_ROOT}/test_bids_fmap_no_sidecars}"
QSIPREP_OUT="${QSIPREP_OUT:-${BIDS_DIR}/qsiprep_output}"
WORK_QSIPREP="${WORK_QSIPREP:-${BIDS_DIR}/qsiprep_work}"
CONTAINER_QSIPREP=/mnt/nfs/home/urmc-sh.rochester.edu/pndagiji/Documents/containers/qsiprep.sif
TEMPLATEFLOW_HOME="${TEMPLATEFLOW_HOME:-${PROJECT_ROOT}/templateflow}"
FS_LICENSE=/mnt/nfs/home/urmc-sh.rochester.edu/pndagiji/Documents/data_mining/freesurfer/license.txt

SUBJECT="${SUBJECT:-031}"
NTHREADS="${NTHREADS:-8}"
OMP_NTHREADS="${OMP_NTHREADS:-8}"
OUTPUT_RES="${OUTPUT_RES:-2}"

mkdir -p "${PROJECT_ROOT}/logs" "${TEMPLATEFLOW_HOME}" "${QSIPREP_OUT}" "${WORK_QSIPREP}"

[[ -f "${CONTAINER_QSIPREP}" ]] || { echo "Missing ${CONTAINER_QSIPREP}"; exit 1; }
[[ -f "${BIDS_DIR}/dataset_description.json" ]] || { echo "Missing BIDS: ${BIDS_DIR}"; exit 1; }
[[ -d "${BIDS_DIR}/sub-${SUBJECT}" ]] || { echo "Missing ${BIDS_DIR}/sub-${SUBJECT}"; exit 1; }

echo "BIDS_DIR=${BIDS_DIR}"
echo "sub-${SUBJECT} fmap files:"
find "${BIDS_DIR}/sub-${SUBJECT}" -path '*/fmap/*' -type f | sort
echo "=== QSIPrep (measured fmaps if possible; NO --ignore fieldmaps) ==="

apptainer run --cleanenv --containall \
  -B "${BIDS_DIR}":/bids_input:ro \
  -B "${QSIPREP_OUT}":/output \
  -B "${WORK_QSIPREP}":/work \
  -B "${FS_LICENSE}":/opt/freesurfer/license.txt:ro \
  -B "${TEMPLATEFLOW_HOME}":/templateflow \
  --env "TEMPLATEFLOW_HOME=/templateflow" \
  "${CONTAINER_QSIPREP}" \
  /bids_input /output participant \
  --participant-label "${SUBJECT}" \
  --fs-license-file /opt/freesurfer/license.txt \
  --work-dir /work \
  --output-resolution "${OUTPUT_RES}" \
  --nthreads "${NTHREADS}" \
  --omp-nthreads "${OMP_NTHREADS}" \
  --skip-bids-validation

echo "Done. Output: ${QSIPREP_OUT}"
