#!/bin/bash
# Tracking-only control (RETEST_LOCK tracking_only_control): same tckgen, new MRTRIX_RNG_SEED, ses-1 nodes fixed, radial_4 counts. Descriptive. Not leftover ECE. Not gold.
#SBATCH --job-name=uhat_reseed
#SBATCH --partition=interactive
#SBATCH --time=12:00:00
#SBATCH --cpus-per-task=8
#SBATCH --mem=32G
#SBATCH --exclude=smdodwork05
#SBATCH --output=/mnt/nfs/home/urmc-sh.rochester.edu/pndagiji/Documents/TrackTBI-Sub/dwi_pipeline/methods/mapping_uhat/work/sites_v1/logs/reseed_%j.out
#SBATCH --error=/mnt/nfs/home/urmc-sh.rochester.edu/pndagiji/Documents/TrackTBI-Sub/dwi_pipeline/methods/mapping_uhat/work/sites_v1/logs/reseed_%j.err
set -euo pipefail
UHAT=/mnt/nfs/home/urmc-sh.rochester.edu/pndagiji/Documents/TrackTBI-Sub/dwi_pipeline/methods/mapping_uhat
SD=/mnt/nfs/home/urmc-sh.rochester.edu/pndagiji/Documents/TrackTBI-Sub/dwi_pipeline/sample_data
QSIRECON=/mnt/nfs/home/urmc-sh.rochester.edu/pndagiji/Documents/others/containers/qsirecon.sif
PKG=/mnt/nfs/home/urmc-sh.rochester.edu/pndagiji/Documents/connectome-edge-uq/src
DS="${RETEST_DATASET:-kirby21}"
SID="${RETEST_SID:-KKI849}"
SEED="${RESEED_SEED:-20261020}"
FREEZE="${SD}/${DS}/freeze/sub-${SID}"
WF="${FREEZE}/.work_qsirecon_ses-1/qsirecon_1_2_wf/sub-${SID}_mrtrix_singleshell_ss3_hsvst"
QOUT="${FREEZE}/qsirecon_single_run_output"
COUT="${FREEZE}/connectomes/sub-${SID}/ses-1"
OUT="${FREEZE}/reseed/ses-1_seed${SEED}"
export APPTAINER_TMPDIR="/mnt/nfs/home/urmc-sh.rochester.edu/pndagiji/.cache/dkt-connectome/apptainer_tmp"
mkdir -p "${OUT}" "${APPTAINER_TMPDIR}"
FTT="$(find "${WF}/recon_anatomical_wf_0/apply_header_to_5tt" -name '*_5tt_hdrxform.nii.gz' | head -1)"
FOD="$(find "${WF}" -path '*ses_1*intensity_norm*' -name '*wm_mtnorm.mif' | head -1)"
TCK0="$(find -L "${QOUT}" -type f -path "*sub-${SID}*ses-1*" \( -name '*model-ifod2_streamlines.tck' -o -name '*model-ifod2_streamlines.tck.gz' \) | head -1)"
NODES="${COUT}/dkt_nodes.mif"
[[ -f "${NODES}" ]] || NODES="${COUT}/nodes.mif"
for f in "${FTT}" "${FOD}" "${TCK0}" "${NODES}"; do
  [[ -f "${f}" ]] || { echo "[RESEED] missing input: ${f:-<empty>}" >&2; exit 1; }
done
echo "[RESEED] ${DS}/${SID} seed=${SEED} host=$(hostname) $(date -Is)"
if [[ ! -f "${OUT}/tracked.tck" ]]; then
  apptainer exec --cleanenv --env "MRTRIX_RNG_SEED=${SEED}" -B "${FREEZE}":"${FREEZE}" "${QSIRECON}" \
    tckgen -act "${FTT}" -algorithm iFOD2 -backtrack -crop_at_gmwmi -maxlength 250.000000 -minlength 30.000000 \
      -samples 4 -nthreads 8 -output_seeds "${OUT}/out_seeds.nii.gz" -power 0.330000 -quiet \
      -seed_dynamic "${FOD}" -select 10000000 "${FOD}" "${OUT}/tracked.tmp.tck" -force
  mv "${OUT}/tracked.tmp.tck" "${OUT}/tracked.tck"
fi
echo "[RESEED] tckgen done $(date -Is)"
apptainer exec --cleanenv -B "${FREEZE}":"${FREEZE}" "${QSIRECON}" mrconvert -quiet -force "${NODES}" "${OUT}/nodes.nii.gz"
PYTHONPATH="${PKG}" python3 - "${TCK0}" "${OUT}" "${COUT}/dkt_connectome_count.csv" "${SEED}" <<'PY'
import json, sys
from pathlib import Path
import numpy as np
from edgeuq.assign import assign_endpoints, connectome
from edgeuq.io import extract_endpoints, load_matrix, load_nodes, save_matrix
from edgeuq.metrics import moved_mask
tck0, out, shipped, seed = Path(sys.argv[1]), Path(sys.argv[2]), Path(sys.argv[3]), int(sys.argv[4])
nodes, aff = load_nodes(out / "nodes.nii.gz")
c = {}
for name, tck in (("run1", tck0), ("reseed", out / "tracked.tck")):
    ends = extract_endpoints(tck)
    c[name] = connectome(assign_endpoints(ends, nodes, aff), 78)
    save_matrix(out / f"count_{name}_radial4.csv", c[name], fmt="%d")
iu = np.triu_indices(78, 1)
m = np.maximum(c["run1"], c["reseed"])[iu] >= 10
ship = load_matrix(shipped)
rec = {
    "seed": seed,
    "n_edges_scored": int(m.sum()),
    "tracking_only_move_rate": float(moved_mask(c["run1"], c["reseed"])[iu][m].mean()),
    "run1_radial4_vs_shipped_count_pearson": float(np.corrcoef(c["run1"][iu], ship[iu])[0, 1]),
    "note": "descriptive (RETEST_LOCK tracking_only_control); AUROC vs U/Ucal/F computed in the retest exam",
}
(out / "reseed_control.json").write_text(json.dumps(rec, indent=2) + "\n")
print(json.dumps(rec, indent=2))
PY
echo "[RESEED] done $(date -Is)"
