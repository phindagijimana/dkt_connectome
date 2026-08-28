#!/usr/bin/env bash
# Dry-run every Snakemake target in dwi_pipeline/workflow/Snakefile (CI + local).
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DWI_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

# shellcheck source=/dev/null
eval "$("${SCRIPT_DIR}/snakemake_ci_setup.sh")"

TARGETS=(
  all
  target_qsiprep
  target_inpaint
  target_recon
  target_qsirecon
  target_act
  target_sdstream
  target_connectome
  target_disconnectome
  target_nodestrength
  target_subject_qc
)

cd "${DWI_ROOT}"
for target in "${TARGETS[@]}"; do
  echo "=== snakemake dry-run: ${target} ==="
  snakemake -s workflow/Snakefile --directory . \
    --configfile "${OVERRIDE}" \
    -n "${target}"
done

echo "=== snakemake dry-run: target_act (Deep Atropos branch) ==="
# shellcheck source=/dev/null
eval "$("${SCRIPT_DIR}/snakemake_act_ci_setup.sh")"
snakemake -s workflow/Snakefile --directory . \
  --configfile "${ACT_OVERRIDE}" \
  -n target_act

echo "Snakemake full-workflow dry-run OK (${#TARGETS[@]} targets + ACT deep-atropos)"
