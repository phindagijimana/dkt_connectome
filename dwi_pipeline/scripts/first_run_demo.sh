#!/usr/bin/env bash
# IDEAS II first-run command.
# Checks the DWI shells, then prints the ./dkt run line.
# Does not start Snakemake unless you pass --dry-run or --run.
# Does not request a GPU.
#
# From dwi_pipeline/:
#   bash scripts/first_run_demo.sh \
#     --bids sample_data/ideas/bids \
#     --results sample_data/ideas/results/sub-1_tutorial
#   bash scripts/first_run_demo.sh --bids ... --results ... --dry-run
#   bash scripts/first_run_demo.sh --bids ... --results ... --run
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DWI_ROOT="$(dirname "${SCRIPT_DIR}")"
# shellcheck source=../workflow/lib/repro_checks.sh
source "${DWI_ROOT}/workflow/lib/repro_checks.sh"

BIDS=""
RESULTS=""
SUBJECT="1"
SESSION="ses-1"
ACTION="print"
ENGINE="host"

usage() {
  sed -n '2,14p' "$0" | sed 's/^# \{0,1\}//'
  cat <<'EOF'

Options:
  --bids DIR         BIDS root (required)
  --results DIR      Results directory (required unless --check-shells-only)
  --subject ID       Participant label (default: 1)
  --session LABEL    ses-1 or 1 (default: ses-1). Stored as 1.
  --dry-run          Shell check, then ./dkt run ... --dry-run
  --run              Shell check, then ./dkt run (hours on CPU)
  --check-shells-only
                     Stop after the shell check
  --engine host|bids_app
                     host prints ./dkt run. bids_app prints submit.sh env.
                     Neither form sets SBATCH_GRES.
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --bids) BIDS="${2:?}"; shift 2 ;;
    --results) RESULTS="${2:?}"; shift 2 ;;
    --subject) SUBJECT="${2:?}"; shift 2 ;;
    --session) SESSION="${2:?}"; shift 2 ;;
    --dry-run) ACTION="dry-run"; shift ;;
    --run) ACTION="run"; shift ;;
    --check-shells-only) ACTION="shells"; shift ;;
    --engine) ENGINE="${2:?}"; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown option: $1" >&2; usage; exit 2 ;;
  esac
done

[[ -n "${BIDS}" ]] || { echo "ERROR: --bids is required" >&2; exit 2; }
SUBJECT="${SUBJECT#sub-}"
SESSION="${SESSION#ses-}"
SELECT="${DWI_ROOT}/config/dwi_select_ideas_b2500.json"
[[ -f "${SELECT}" ]] || { echo "ERROR: missing ${SELECT}" >&2; exit 1; }

if [[ "${ACTION}" != "shells" && -z "${RESULTS}" ]]; then
  echo "ERROR: --results is required" >&2
  exit 2
fi

# A noexec /tmp breaks Apptainer. Fill unset temp vars. An explicit noexec path still fails.
if dkt_mount_noexec /tmp; then
  cache_root="${HOME}/.cache/dkt-connectome"
  if [[ -z "${TMPDIR:-}" ]]; then
    export TMPDIR="${cache_root}/tmp"
    mkdir -p "${TMPDIR}"
    echo "first-run: TMPDIR=${TMPDIR} (/tmp is noexec)"
  fi
  if [[ -z "${APPTAINER_TMPDIR:-}" ]]; then
    export APPTAINER_TMPDIR="${cache_root}/apptainer_tmp"
    mkdir -p "${APPTAINER_TMPDIR}"
    echo "first-run: APPTAINER_TMPDIR=${APPTAINER_TMPDIR}"
  fi
  if [[ -z "${PROOT_TMP_DIR:-}" ]]; then
    export PROOT_TMP_DIR="${APPTAINER_TMPDIR}"
  fi
  export SINGULARITY_TMPDIR="${SINGULARITY_TMPDIR:-${APPTAINER_TMPDIR}}"
fi
if ! tmp_msg="$(dkt_tmp_error)"; then
  echo "ERROR [first-run]: ${tmp_msg}" >&2
  exit 1
fi

unset SBATCH_GRES

filter_out="$(mktemp)"
trap 'rm -f "${filter_out}"' EXIT
if ! python3 "${DWI_ROOT}/scripts/build_bids_filter.py" \
  --bids-dir "${BIDS}" \
  --subject "${SUBJECT}" \
  --session "${SESSION}" \
  --select-json "${SELECT}" \
  --output "${filter_out}"; then
  exit 1
fi
echo "first-run: shells match ${SELECT} (session ${SESSION})"

if [[ "${ACTION}" == "shells" ]]; then
  exit 0
fi

cmd=(
  ./dkt run "${BIDS}" "${RESULTS}" participant
  --participant-label "${SUBJECT}"
  --session-filter "ses-${SESSION}"
  --fastsurfer
  --syn
  --dwi-select "${SELECT}"
  --n-cpus "${NTHREADS:-8}"
)

case "${ENGINE}" in
  host) ;;
  bids_app|orchestrator|bids-app)
    echo "first-run: orchestrator launch (no GPU requested)"
    echo "  PIPELINE_ENGINE=bids_app"
    echo "  CONTAINER_ORCHESTRATOR=\${HOME}/.cache/dkt-connectome/containers/dkt_connectome_orchestrator_0.3.1.sif"
    echo "  dkt_connectome.sif is the Step 4 connectome image, not the orchestrator."
    echo "  RECON_SESSION=${SESSION}"
    echo "  unset SBATCH_GRES"
    echo "  From dwi_pipeline/, with BIDS_DIR and RESULTS_ROOT set:"
    echo "    PIPELINE_ENGINE=bids_app bash submit.sh"
    ;;
  *)
    echo "ERROR: --engine must be host or bids_app" >&2
    exit 2
    ;;
esac

if [[ "${ACTION}" == "print" ]]; then
  echo "first-run: command (not started). Pass --dry-run or --run to execute."
  printf '%q ' "${cmd[@]}"
  printf '\n'
  if [[ -z "${FS_LICENSE:-}" || ! -f "${FS_LICENSE}" ]]; then
    echo "first-run: FS_LICENSE is not a license file. Set it before --dry-run or --run." >&2
    echo "Register: https://surfer.nmr.mgh.harvard.edu/registration.html" >&2
  fi
  exit 0
fi

if [[ -z "${FS_LICENSE:-}" || ! -f "${FS_LICENSE}" ]]; then
  echo "ERROR [first-run]: Set FS_LICENSE to your license.txt (https://surfer.nmr.mgh.harvard.edu/registration.html)." >&2
  exit 1
fi

if [[ "${ENGINE}" != "host" ]]; then
  echo "ERROR [first-run]: --dry-run and --run execute the host ./dkt run path. The bids_app lines above are the Slurm launch; this script does not call sbatch." >&2
  exit 2
fi

if [[ "${ACTION}" == "dry-run" ]]; then
  cmd+=(--dry-run)
fi
cd "${DWI_ROOT}"
exec "${cmd[@]}"
