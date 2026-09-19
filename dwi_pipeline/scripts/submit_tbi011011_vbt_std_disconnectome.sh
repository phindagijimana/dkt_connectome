#!/usr/bin/env bash
# Run disconnectome + subject_qc for vbt-std only (TBI011011 factorial gap-fill).
#
# Usage:
#   bash dwi_pipeline/scripts/submit_tbi011011_vbt_std_disconnectome.sh

set -euo pipefail

DWI_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
EXP="/mnt/nfs/Gugger_Lab/NIR/dwi_test_TBI_experiment/sub-TBI011011_fastsurfer_experiment"
ARM=vbt-std
ARM_DIR="${EXP}/arms/${ARM}"
LOG_DIR="${ARM_DIR}/logs"
mkdir -p "${LOG_DIR}"

jid=$(sbatch --job-name=tbi_vbt_std_disc \
  --partition=interactive \
  --cpus-per-task=8 \
  --mem=64G \
  --time=02:00:00 \
  --output="${LOG_DIR}/vbt_std_disc_%j.out" \
  --error="${LOG_DIR}/vbt_std_disc_%j.err" \
  --wrap "set -euo pipefail
cd '${DWI_ROOT}'
source workflow/lib/slurm_env.sh
ARM_DIR='${ARM_DIR}'
BIDS='/mnt/nfs/Gugger_Lab/NIR/dwi_test_TBI_experiment/bids'
export BIDS_DIR=\"\${BIDS}\" RESULTS_ROOT=\"\${ARM_DIR}\" EXPERIMENT_ARM='${ARM}'
export SNAKEMAKE_WORKDIR=\"\${ARM_DIR}/.snakemake_workdir/sub-TBI011011\"
export NTHREADS=8 ACT_BIND_MOUNT_DEV=1 SKIP_RERUN_INCOMPLETE=1
bash workflow/run_subject.sh disconnectome TBI011011 \\
  --recon-session 2WK --experiment-arm '${ARM}' --fastsurfer --no-inpaint \\
  --connectome-sift2 --primary-connectome-measure sift2 --tractography-model both \\
  --disconnection --disconnectome-weighting sift2
python3.12 scripts/render_subject_qc.py \\
  --results-root \"\${ARM_DIR}\" --subject TBI011011
python3.12 scripts/evaluate_disconnectome_integrity.py \\
  --disconnectome-dir \"\${ARM_DIR}/connectomes/sub-TBI011011/disconnectome\"
bash scripts/verify_tbi011011_arms.sh" | awk '{print $NF}')

echo "Submitted vbt-std disconnectome: job ${jid}"
echo "Monitor: squeue -j ${jid}"
echo "Verify:  bash ${DWI_ROOT}/scripts/verify_tbi011011_arms.sh"
