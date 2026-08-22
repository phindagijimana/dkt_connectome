#!/usr/bin/env bash
# Production-scale vbt-lesion E2E for one subject (reuse QSIPrep/QSIRecon).
set -euo pipefail

SUBJECT="${1:?Need subject id (e.g. TBI011011)}"
DWI_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SUBJECT="${SUBJECT#sub-}"
SRC="${RESULTS_SRC:-${DWI_ROOT}/dwi_test_TBI/sub-${SUBJECT}_fastsurfer_inpaint}"
E2E="${RESULTS_ROOT:-${DWI_ROOT}/dwi_test_TBI/sub-${SUBJECT}_vbt_lesion_e2e}"
BIDS_DIR="${BIDS_DIR:-${DWI_ROOT}/dwi_test_TBI/bids}"
RUN="${DWI_ROOT}/workflow/run_subject.sh"
LOG="${E2E}/logs/vbt_lesion_e2e.log"

mkdir -p "${E2E}/logs"
exec > >(tee -a "${LOG}") 2>&1

echo "=== vbt-lesion E2E: sub-${SUBJECT} ==="
echo "Source (QSIPrep/QSIRecon): ${SRC}"
echo "E2E results: ${E2E}"
echo "ACT streamlines: ${ACT_STREAMLINES:-10000000}"
echo "Started: $(date -Is)"

[[ -d "${SRC}/qsiprep_single_run_output" ]] || { echo "ERROR: missing ${SRC}/qsiprep_single_run_output"; exit 1; }
[[ -d "${SRC}/qsirecon_single_run_output" ]] || { echo "ERROR: missing ${SRC}/qsirecon_single_run_output"; exit 1; }

link_upstream() {
  local name="$1"
  local target="${SRC}/${name}"
  local dest="${E2E}/${name}"
  if [[ -L "${dest}" || -e "${dest}" ]]; then
    rm -rf "${dest}"
  fi
  ln -sfn "$(realpath "${target}")" "${dest}"
  echo "Linked ${name} -> ${target}"
}

for name in \
  qsiprep_single_run_output \
  qsirecon_single_run_output \
  intermediate_results_qsiprep_single \
  intermediate_results_qsirecon_single; do
  link_upstream "${name}"
done

if [[ -d "${SRC}/.snakemake_markers" ]]; then
  mkdir -p "${E2E}/.snakemake_markers"
  cp -a "${SRC}/.snakemake_markers/." "${E2E}/.snakemake_markers/"
  echo "Copied Snakemake markers from ${SRC}"
fi

export RESULTS_ROOT="${E2E}"
export BIDS_DIR
export NTHREADS="${NTHREADS:-8}"
export OMP_NTHREADS="${OMP_NTHREADS:-8}"
export ACT_STREAMLINES="${ACT_STREAMLINES:-10000000}"
export ACT_MODE=lesion-aware
export ANAT_MITIGATION=vbt
export RUN_INPAINT=1
export RECON_SESSION="${RECON_SESSION:-2WK}"
export EXPERIMENT_ISOLATE_OUTPUTS=0
export XDG_CACHE_HOME="${XDG_CACHE_HOME:-$(dirname "${DWI_ROOT}")/.cache}"
mkdir -p "${XDG_CACHE_HOME}"

COMMON=(
  --anat-mitigation vbt
  --act-mode lesion-aware
  --recon-session "${RECON_SESSION}"
)

bash "${DWI_ROOT}/workflow/preflight.sh" --mode inpaint --subject "${SUBJECT}" --quick \
  || { echo "Preflight inpaint failed"; exit 1; }

echo "--- Step 1.5: VBT ---"
bash "${RUN}" inpaint "${SUBJECT}" "${COMMON[@]}"

echo "--- Step 2: Recon (FastSurfer on VBT T1w) ---"
bash "${RUN}" recon "${SUBJECT}" "${COMMON[@]}" --fastsurfer

echo "--- Step 3.5: Lesion-aware ACT (${ACT_STREAMLINES} streamlines) ---"
bash "${RUN}" act "${SUBJECT}" "${COMMON[@]}" --act-streamlines "${ACT_STREAMLINES}"

echo "--- Step 4: Connectome (+ SD_STREAM when tractography.model=both) ---"
bash "${RUN}" connectome "${SUBJECT}" "${COMMON[@]}"

echo "--- Validation ---"
python3 "${DWI_ROOT}/scripts/validate_vbt_lesion_act.py" \
  --vbt-json "${E2E}/vbt/sub-${SUBJECT}/ses-${RECON_SESSION}/inpainting.json" \
  --lesion-act-json "${E2E}/lesion_aware_act/sub-${SUBJECT}/lesion_aware_act.json"

python3 - <<PY
import json
from pathlib import Path
parc = Path("${E2E}/connectomes/sub-${SUBJECT}/parcellation.json")
if not parc.is_file():
    raise SystemExit(f"missing connectome parcellation.json: {parc}")
payload = json.loads(parc.read_text())
if payload.get("act_mode") != "lesion-aware":
    raise SystemExit(f"connectome act_mode={payload.get('act_mode')!r}, expected lesion-aware")
print("Connectome act_mode: lesion-aware OK")
print("Primary matrix:", payload.get("connectome_csv"))
PY

echo "Finished: $(date -Is)"
echo "Log: ${LOG}"
