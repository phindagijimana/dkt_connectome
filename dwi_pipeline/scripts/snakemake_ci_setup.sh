#!/usr/bin/env bash
# Write minimal BIDS + config override for Snakemake CI dry-runs.
set -euo pipefail

BIDS_STUB="${BIDS_STUB:-/tmp/dkt_ci_bids}"
RESULTS_STUB="${RESULTS_STUB:-/tmp/dkt_ci_out}"
OVERRIDE="${OVERRIDE:-/tmp/dkt_ci_override.yaml}"

mkdir -p "${BIDS_STUB}/sub-CITEST/ses-1/anat" "${BIDS_STUB}/sub-CITEST/ses-1/dwi"
touch "${BIDS_STUB}/sub-CITEST/ses-1/anat/sub-CITEST_ses-1_T1w.nii.gz"
touch "${BIDS_STUB}/sub-CITEST/ses-1/anat/sub-CITEST_ses-1_T1w_label-lesion_roi.nii.gz"
touch "${BIDS_STUB}/sub-CITEST/ses-1/dwi/sub-CITEST_ses-1_dwi.nii.gz"
mkdir -p "${RESULTS_STUB}"
touch /tmp/dkt_ci_license.txt

for c in qsiprep qsirecon fastsurfer freesurfer connectome lit nodestrength; do
  touch "/tmp/dkt_ci_${c}.sif"
done
# Optional ACT stubs (also created by snakemake_act_ci_setup.sh)
for c in lesion_act deep_atropos deep_atropos_seg; do
  touch "/tmp/dkt_ci_${c}.sif" 2>/dev/null || true
done

cat > "${OVERRIDE}" <<YAML
subject: "CITEST"
results_root: "${RESULTS_STUB}"
bids_dir: "${BIDS_STUB}"
recon:
  session: "1"
dwi_select:
  enabled: false
containers:
  qsiprep: "/tmp/dkt_ci_qsiprep.sif"
  qsirecon: "/tmp/dkt_ci_qsirecon.sif"
  fastsurfer: "/tmp/dkt_ci_fastsurfer.sif"
  freesurfer: "/tmp/dkt_ci_freesurfer.sif"
  connectome: "/tmp/dkt_ci_connectome.sif"
  lit: "/tmp/dkt_ci_lit.sif"
  nodestrength: "/tmp/dkt_ci_nodestrength.sif"
fs_license: "/tmp/dkt_ci_license.txt"
YAML

echo "BIDS_STUB=${BIDS_STUB}"
echo "RESULTS_STUB=${RESULTS_STUB}"
echo "OVERRIDE=${OVERRIDE}"
