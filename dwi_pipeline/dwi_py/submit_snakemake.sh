#!/bin/bash
# =============================================================================
# submit_snakemake.sh — long-lived Snakemake driver, submitted as one Slurm job
# =============================================================================
# The Snakemake driver itself must stay alive to submit/monitor per-rule
# Slurm jobs as the DAG unrolls. This wrapper:
#   1. asks Slurm for one small, cheap node (no GPU, low memory)
#   2. exports the PATH so the user-installed `snakemake` is reachable
#   3. runs `snakemake --profile profiles/slurm`, which then fans out one
#      `sbatch` per rule instance (qsiprep / recon / qsirecon / dk_connectome)
#
# Submit from anywhere on the cluster:
#   sbatch /path/to/dwi_pipeline/dwi_py/submit_snakemake.sh
#   sbatch dwi_pipeline/dwi_py/submit_snakemake.sh --config recon='{"tool":"fastsurfer"}'
#   sbatch dwi_pipeline/dwi_py/submit_snakemake.sh -- --forcerun recon
#
# Anything after the script name is appended verbatim to the snakemake call,
# so all Snakemake CLI flags are fair game.
#
# Log paths below are ABSOLUTE because #SBATCH directives are parsed by Slurm
# before any shell logic runs, so they're resolved against the submit cwd —
# a relative `logs/...` blows up with signal 53 if you sbatch from elsewhere
# (this killed driver job 44570).
# =============================================================================
#SBATCH --job-name=dwi_smk_driver
#SBATCH --partition=general
#SBATCH --cpus-per-task=1
#SBATCH --mem=4G
#SBATCH --time=2-00:00:00                  # 48 h cap for the orchestrator
#SBATCH --exclude=smdodwork05
#SBATCH --output=/mnt/nfs/home/urmc-sh.rochester.edu/pndagiji/Documents/TrackTBI-Sub/dwi_pipeline/dwi_py/logs/snakemake_driver.%j.out
#SBATCH --error=/mnt/nfs/home/urmc-sh.rochester.edu/pndagiji/Documents/TrackTBI-Sub/dwi_pipeline/dwi_py/logs/snakemake_driver.%j.err

set -euo pipefail

# Anchor to dwi_py/ so relative paths in profiles/config work. Inside sbatch,
# ${BASH_SOURCE[0]} points to Slurm's spool copy of the script
# (/var/spool/slurmd/job<id>/slurm_script), so deriving the dir from it lands
# us in a directory that is NOT writable by the user and breaks `mkdir -p logs`.
# That's the exact failure mode that killed driver job 44589.
# Prefer DWI_PY_DIR/SLURM_SUBMIT_DIR if exported, otherwise fall back to the
# hardcoded absolute path (matches the absolute #SBATCH log directives above).
SCRIPT_DIR="${DWI_PY_DIR:-${SLURM_SUBMIT_DIR:-/mnt/nfs/home/urmc-sh.rochester.edu/pndagiji/Documents/TrackTBI-Sub/dwi_pipeline/dwi_py}}"
if [[ ! -f "${SCRIPT_DIR}/Snakefile" ]]; then
    SCRIPT_DIR="/mnt/nfs/home/urmc-sh.rochester.edu/pndagiji/Documents/TrackTBI-Sub/dwi_pipeline/dwi_py"
fi
cd "${SCRIPT_DIR}"
# Belt-and-suspenders: the #SBATCH log paths above are absolute, but make
# sure logs/ exists in cwd too in case anyone changes those paths later.
mkdir -p logs

# Make user-site snakemake reachable on this node.
export PATH="${HOME}/.local/bin:${PATH}"

# Sanity preflight: snakemake + slurm plugin must import.
command -v snakemake >/dev/null || { echo "snakemake not on PATH"; exit 1; }
snakemake --version
python3.11 -c "import snakemake_executor_plugin_slurm" \
    || { echo "snakemake-executor-plugin-slurm not installed"; exit 1; }

echo "=== Snakemake driver starting ==="
echo "CWD          : $(pwd)"
echo "Config       : config/config.yaml"
echo "Profile      : profiles/slurm"
echo "Extra flags  : $*"
echo "================================="

# `--profile profiles/slurm` enables the slurm executor plugin and inherits
# resource defaults defined in that profile. Any extra CLI args (-- ...) are
# appended for one-off overrides (--forcerun, --until, --config k=v, ...).
exec snakemake \
    --configfile config/config.yaml \
    --profile profiles/slurm \
    --keep-going \
    --rerun-incomplete \
    --printshellcmds \
    "$@"
