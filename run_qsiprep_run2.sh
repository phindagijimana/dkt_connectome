#!/bin/bash
#SBATCH --job-name=qsiprep_run2
#SBATCH --output=/mnt/nfs/home/urmc-sh.rochester.edu/pndagiji/Documents/TrackTBI-Sub/logs/qsiprep_run2_%j.out
#SBATCH --error=/mnt/nfs/home/urmc-sh.rochester.edu/pndagiji/Documents/TrackTBI-Sub/logs/qsiprep_run2_%j.err
#SBATCH --time=24:00:00
#SBATCH --cpus-per-task=8
#SBATCH --mem=32G
#SBATCH --partition=general

set +H  # disable history expansion

# Create output and work directories if not exist
mkdir -p /mnt/nfs/home/urmc-sh.rochester.edu/pndagiji/Documents/TrackTBI-Sub/qsiprep_run2_output
mkdir -p /mnt/nfs/home/urmc-sh.rochester.edu/pndagiji/Documents/TrackTBI-Sub/intermediate_results_run2
mkdir -p /mnt/nfs/home/urmc-sh.rochester.edu/pndagiji/Documents/TrackTBI-Sub/logs

# Define paths
CONTAINER_PATH=/mnt/nfs/home/urmc-sh.rochester.edu/pndagiji/Documents/containers/qsiprep.sif
TEMPLATEFLOW_HOME=/mnt/nfs/home/urmc-sh.rochester.edu/pndagiji/Documents/TrackTBI-Sub/templateflow
BIDS_DIR="/mnt/nfs/home/urmc-sh.rochester.edu/pndagiji/Documents/CIDUR_BIDS/data_bids"
OUTPUT_DIR=/mnt/nfs/home/urmc-sh.rochester.edu/pndagiji/Documents/TrackTBI-Sub/qsiprep_run2_output
WORK_DIR=/mnt/nfs/home/urmc-sh.rochester.edu/pndagiji/Documents/TrackTBI-Sub/intermediate_results_run2
FS_LICENSE=/mnt/nfs/home/urmc-sh.rochester.edu/pndagiji/Documents/data_mining/freesurfer/license.txt
BIDS_FILTER=/mnt/nfs/home/urmc-sh.rochester.edu/pndagiji/Documents/TrackTBI-Sub/bids_filter_run2.json

# Subject to process (without 'sub-' prefix). Real study IDs are kept out of
# this repository, so override it: SUBJECT=<id> bash run_qsiprep_run2.sh
SUBJECT="${SUBJECT:-SUBJ03}"

# Create TemplateFlow directory
mkdir -p $TEMPLATEFLOW_HOME

# Download QSIPrep container if it doesn't exist
if [ ! -f "$CONTAINER_PATH" ]; then
    echo "QSIPrep container not found. Downloading..."
    cd /mnt/nfs/home/urmc-sh.rochester.edu/pndagiji/Documents/containers
    apptainer pull docker://pennbbl/qsiprep:0.23.0
    mv qsiprep_0.23.0.sif qsiprep.sif
    echo "Download complete."
else
    echo "QSIPrep container found at $CONTAINER_PATH"
fi

# Export TemplateFlow home for this session
export TEMPLATEFLOW_HOME

# Validate paths
echo "Validating paths..."
if [ ! -d "${BIDS_DIR}" ]; then
    echo "ERROR: BIDS directory not found: ${BIDS_DIR}"
    exit 1
fi

if [ ! -f "${FS_LICENSE}" ]; then
    echo "ERROR: FreeSurfer license not found: ${FS_LICENSE}"
    exit 1
fi

# Check if subject exists
if [ ! -d "${BIDS_DIR}/sub-${SUBJECT}" ]; then
    echo "ERROR: Subject sub-${SUBJECT} not found in BIDS directory"
    exit 1
fi

# Check if DWI data exists (accounts for session-based layout)
if ! find "${BIDS_DIR}/sub-${SUBJECT}" -type d -name "dwi" | grep -q .; then
    echo "ERROR: No DWI data found for sub-${SUBJECT}"
    exit 1
fi

echo "Processing run-2 only for subject: sub-${SUBJECT}"
echo "BIDS filter: ${BIDS_FILTER}"
echo "Output Directory: ${OUTPUT_DIR}"
echo ""

# Run QSIPrep inside Apptainer container — run-2 only via bids-filter-file
apptainer run --cleanenv --containall \
  -B "${BIDS_DIR}":/bids_input:ro \
  -B "${OUTPUT_DIR}":/output \
  -B "${WORK_DIR}":/work \
  -B "${FS_LICENSE}":/opt/freesurfer/license.txt:ro \
  -B "${TEMPLATEFLOW_HOME}":/templateflow \
  -B "${BIDS_FILTER}":/bids_filter.json:ro \
  --env "TEMPLATEFLOW_HOME=/templateflow" \
  $CONTAINER_PATH \
  /bids_input /output participant \
  --participant-label ${SUBJECT} \
  --fs-license-file /opt/freesurfer/license.txt \
  --work-dir /work \
  --output-resolution 2 \
  --nthreads 8 \
  --omp-nthreads 8 \
  --skip-bids-validation \
  --bids-filter-file /bids_filter.json

echo ""
echo "QSIPrep run-2 completed for sub-${SUBJECT}"
echo "Output location: ${OUTPUT_DIR}"
