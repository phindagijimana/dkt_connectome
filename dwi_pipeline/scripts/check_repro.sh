#!/usr/bin/env bash
# Checks that do not need step images or a dataset.
# ./dkt check runs this on every invocation.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DWI_ROOT="$(dirname "${SCRIPT_DIR}")"
# shellcheck source=../workflow/lib/repro_checks.sh
source "${DWI_ROOT}/workflow/lib/repro_checks.sh"
# shellcheck source=../workflow/lib/orchestrator.sh
source "${DWI_ROOT}/workflow/lib/orchestrator.sh"

fail() { echo "ERROR [repro]: $*" >&2; exit 1; }
errors=0
note() { echo "repro: $*"; }
bad() { echo "ERROR [repro]: $*" >&2; errors=1; }

# Session labels are stored without the ses- prefix. Paths add it back.
for raw in ses-1 1; do
  got="$(python3 "${DWI_ROOT}/workflow/lib/resolve_session.py" \
    --bids-dir "${DWI_ROOT}" \
    --subject 1 \
    --filter-cache "${DWI_ROOT}/.repro_session_unused.json" \
    --recon-session "${raw}")"
  if [[ "${got}" != "1" ]]; then
    bad "RECON_SESSION=${raw} resolved to '${got}'. Expected 1 (paths add ses- themselves)."
  else
    note "RECON_SESSION=${raw} -> 1"
  fi
done

# Host Apptainer must not be mounted over the binary inside the orchestrator.
binds=()
_orchestrator_bind_apptainer binds
if [[ ${#binds[@]} -ne 0 ]]; then
  bad "orchestrator bind list includes host apptainer (${binds[*]}). The image binary must stay in place (libsubid.so.3)."
else
  note "orchestrator does not mount host apptainer"
fi
if declare -f _orchestrator_bind_apptainer | grep -q -- '-B'; then
  bad "_orchestrator_bind_apptainer contains a bind (-B). Leave the image apptainer in place."
fi

step4="$(mktemp -d)"
trap 'rm -rf "${step4}"' EXIT
touch "${step4}/dkt_connectome.sif"
if _orchestrator_reject_step_image "${step4}/dkt_connectome.sif" 2>"${step4}/err"; then
  bad "dkt_connectome.sif was accepted as the orchestrator. That file is the Step 4 connectome image."
else
  if ! grep -q "Step 4 connectome image" "${step4}/err"; then
    bad "Step 4 rejection did not name the connectome image. Got: $(cat "${step4}/err")"
  else
    note "Step 4 image rejected as orchestrator"
  fi
fi

# Placeholder container path must tell the user to install.
msg="$(dkt_container_missing_message qsiprep /path/to/others/containers/qsiprep.sif || true)"
if [[ "${msg}" != *"container missing (qsiprep)"* || "${msg}" != *"./dkt install"* || "${msg}" != *"config.local.yaml"* ]]; then
  bad "placeholder container message is missing install instructions: ${msg}"
else
  note "placeholder container message names ./dkt install"
fi

lic="$(dkt_license_error /path/to/others/data_mining/freesurfer/license.txt || true)"
if [[ "${lic}" != *"FS_LICENSE"* || "${lic}" != *"surfer.nmr.mgh.harvard.edu"* ]]; then
  bad "placeholder license message is missing FS_LICENSE instructions: ${lic}"
else
  note "placeholder license message names FS_LICENSE"
fi

if ! tmp_msg="$(dkt_tmp_error)"; then
  bad "${tmp_msg}"
else
  note "temp directories are executable"
fi

if grep -E '^[[:space:]]*(export[[:space:]]+)?PYTHONPATH=' "${DWI_ROOT}/workflow/lib/slurm_env.sh"; then
  bad "slurm_env.sh assigns PYTHONPATH. That path is searched before the standard library."
else
  note "slurm_env.sh does not assign PYTHONPATH"
fi

gres_line='[[ -n "${SBATCH_GRES:-}" ]] && SBATCH_EXTRA+=(--gres="${SBATCH_GRES}")'
if ! grep -F -q "${gres_line}" "${DWI_ROOT}/submit.sh"; then
  bad "submit.sh must add --gres only when SBATCH_GRES is set."
else
  note "submit.sh leaves --gres unset unless SBATCH_GRES is set"
fi
(
  unset SBATCH_GRES
  SBATCH_EXTRA=()
  [[ -n "${SBATCH_GRES:-}" ]] && SBATCH_EXTRA+=(--gres="${SBATCH_GRES}")
  [[ ${#SBATCH_EXTRA[@]} -eq 0 ]]
) || bad "empty SBATCH_GRES still produced a --gres argument"

if ! arg_msg="$(dkt_check_stdlib_argparse)"; then
  bad "${arg_msg}"
else
  echo "${arg_msg}"
fi

python3 - "${DWI_ROOT}/release_manifest.json" <<'PY' || errors=1
import json, sys
path = sys.argv[1]
data = json.loads(open(path, encoding="utf-8").read())
fs = (data.get("steps") or {}).get("fastsurfer") or {}
version = str(fs.get("version") or "")
digest = str(fs.get("sha256") or "")
uri = str(fs.get("uri") or "")
if version != "2.4.2+7e53343":
    print(
        "ERROR [repro]: fastsurfer version in release_manifest.json must be the tested build 2.4.2+7e53343.",
        file=sys.stderr,
    )
    sys.exit(1)
if not digest.startswith("1baa5d51866df198"):
    print("ERROR [repro]: fastsurfer sha256 is the SIF file hash, not an OCI digest.", file=sys.stderr)
    sys.exit(1)
print(
    f"repro: fastsurfer tested build {version}; SIF sha256 {digest[:12]}…; uri {uri}"
)
note = str(fs.get("pin_note") or "")
if note:
    print(f"repro: {note}")
PY

if [[ "${errors}" -ne 0 ]]; then
  echo "ERROR [repro]: one or more checks failed" >&2
  exit 1
fi
echo "repro: OK"
