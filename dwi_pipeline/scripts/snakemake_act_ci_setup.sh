#!/usr/bin/env bash
# Write BIDS + config override for Snakemake ACT (Deep Atropos) CI dry-runs.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/dev/null
eval "$("${SCRIPT_DIR}/snakemake_ci_setup.sh")"

ACT_OVERRIDE="${ACT_OVERRIDE:-/tmp/dkt_ci_act_override.yaml}"

cat > "${ACT_OVERRIDE}" <<YAML
subject: "CITEST"
results_root: "${RESULTS_STUB}"
bids_dir: "${BIDS_STUB}"
recon:
  session: "1"
dwi_select:
  enabled: false
act:
  mode: lesion-aware
  five_tt_source: deep-atropos-native
  deep_atropos:
    segmentation_mode: generate
    antsxnet_cache: /tmp/dkt_ci_antsxnet_cache
containers:
  qsiprep: "/tmp/dkt_ci_qsiprep.sif"
  qsirecon: "/tmp/dkt_ci_qsirecon.sif"
  fastsurfer: "/tmp/dkt_ci_fastsurfer.sif"
  freesurfer: "/tmp/dkt_ci_freesurfer.sif"
  connectome: "/tmp/dkt_ci_connectome.sif"
  lit: "/tmp/dkt_ci_lit.sif"
  nodestrength: "/tmp/dkt_ci_nodestrength.sif"
  lesion_act: "/tmp/dkt_ci_lesion_act.sif"
  deep_atropos: "/tmp/dkt_ci_deep_atropos.sif"
  deep_atropos_seg: "/tmp/dkt_ci_deep_atropos_seg.sif"
fs_license: "/tmp/dkt_ci_license.txt"
YAML

for c in lesion_act deep_atropos deep_atropos_seg; do
  touch "/tmp/dkt_ci_${c}.sif"
done
mkdir -p /tmp/dkt_ci_antsxnet_cache

echo "ACT_OVERRIDE=${ACT_OVERRIDE}"
