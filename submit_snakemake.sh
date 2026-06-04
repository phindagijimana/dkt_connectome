#!/bin/bash
# =============================================================================
# submit_snakemake.sh — long-lived Snakemake driver, submitted as one Slurm job
# =============================================================================
# The Snakemake driver itself must stay alive to submit/monitor per-rule Slurm
# jobs as the DAG unrolls. This wrapper:
#   1. asks Slurm for one small, cheap node (no GPU, low memory)
#   2. exports the PATH so the user-installed `snakemake` is reachable
#   3. runs `snakemake --profile profiles/slurm`, which then fans out one
#      `sbatch` per rule instance (qsiprep / recon / qsirecon / dk_connectome)
#
# Submit from the repo root:
#     sbatch submit_snakemake.sh
#     sbatch submit_snakemake.sh --configfile config/myconfig.yaml
#     sbatch submit_snakemake.sh --config recon='{"tool":"fastsurfer"}'
#     sbatch submit_snakemake.sh --forcerun recon
#
# Anything after the script name is appended verbatim to the snakemake call.
#
# To submit from outside the repo, set DK_REPO_DIR explicitly:
#     DK_REPO_DIR=/path/to/dk_connectome sbatch /path/to/submit_snakemake.sh
#
# -----------------------------------------------------------------------------
# GOTCHA: restarting after a killed driver + --rerun-incomplete
# -----------------------------------------------------------------------------
# Snakemake tracks per-job "started but not yet finished" markers in
# .snakemake/ . If a previous driver was scancel'd / OOM'd / wall-time-killed
# WHILE one of its child rules was running (or had been queued through the
# slurm executor and recorded as "started"), the next driver started with
# --rerun-incomplete will:
#
#   1. Treat that rule's outputs (including touch(.flags/<rule>.<sid>.done)
#      sentinels) as "possibly-incomplete".
#   2. DELETE the sentinel.
#   3. Re-run the rule from scratch.
#
# Workarounds when you KNOW the previous run finished cleanly:
#   - Drop --rerun-incomplete from this script's exec line (default), OR
#   - Run a one-shot `snakemake --touch --configfile ...` from a login shell
#     before resubmitting the driver. That marks all up-to-date outputs as
#     fresh so the next DAG build skips them.
#   - As a last resort: `touch .flags/<rule>.<sid>.done` manually for each
#     stage you know is complete (works because the rule's `output:` is
#     literally that file).
# =============================================================================
#SBATCH --job-name=dk_smk_driver
#SBATCH --cpus-per-task=1
#SBATCH --mem=4G
#SBATCH --time=12:00:00
#SBATCH --output=logs/snakemake_driver.%j.out
#SBATCH --error=logs/snakemake_driver.%j.err

set -euo pipefail

# Anchor to the repo root so relative paths in profiles/config work. Inside
# sbatch, ${BASH_SOURCE[0]} points to Slurm's spool copy of the script
# (/var/spool/slurmd/job<id>/slurm_script), so deriving the dir from it lands
# us in a directory that is NOT writable by the user and breaks `mkdir -p logs`.
# Prefer DK_REPO_DIR / SLURM_SUBMIT_DIR if exported.
SCRIPT_DIR="${DK_REPO_DIR:-${SLURM_SUBMIT_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)}}"
if [[ ! -f "${SCRIPT_DIR}/Snakefile" ]]; then
    echo "ERROR: Snakefile not found under SCRIPT_DIR=${SCRIPT_DIR}" >&2
    echo "Set DK_REPO_DIR or sbatch from the repo root." >&2
    exit 1
fi
cd "${SCRIPT_DIR}"
mkdir -p logs

# Make user-site snakemake reachable on this node.
export PATH="${HOME}/.local/bin:${PATH}"

# Sanity preflight: snakemake + slurm plugin must import.
command -v snakemake >/dev/null || { echo "snakemake not on PATH"; exit 1; }
snakemake --version
python3 -c "import snakemake_executor_plugin_slurm" 2>/dev/null \
    || { echo "snakemake-executor-plugin-slurm not installed"; exit 1; }

echo "=== Snakemake driver starting ==="
echo "CWD          : $(pwd)"
echo "Config       : config/config.yaml (override with --configfile)"
echo "Profile      : profiles/slurm"
echo "Extra flags  : $*"
echo "================================="

# --rerun-incomplete is INTENTIONALLY off by default — see GOTCHA above.
# To opt in for a single submission, pass it explicitly:
#     sbatch submit_snakemake.sh --rerun-incomplete
exec snakemake \
    --profile profiles/slurm \
    --keep-going \
    --printshellcmds \
    "$@"
