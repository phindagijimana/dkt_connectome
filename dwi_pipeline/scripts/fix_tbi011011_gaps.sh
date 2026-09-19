#!/usr/bin/env bash
# Fill TBI011011 factorial gaps: recon markers, SIFT2 connectome, disconnectome QC,
# nodestrength, subject QC refresh.
#
# Usage:
#   bash dwi_pipeline/scripts/fix_tbi011011_gaps.sh
#   bash dwi_pipeline/scripts/fix_tbi011011_gaps.sh --dry-run

set -euo pipefail

DRY_RUN=0
[[ "${1:-}" == "--dry-run" ]] && DRY_RUN=1

DWI_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
EXP="${EXP:-/mnt/nfs/Gugger_Lab/NIR/dwi_test_TBI_experiment/sub-TBI011011_fastsurfer_experiment}"
BIDS="${BIDS:-/mnt/nfs/Gugger_Lab/NIR/dwi_test_TBI_experiment/bids}"
SUBJECT="${SUBJECT:-TBI011011}"
SUBJECT="${SUBJECT#sub-}"
SID="sub-${SUBJECT}"

ALL_ARMS=(orig-std orig-lesion neurolit-std neurolit-lesion vbt-std vbt-lesion deep-atropos-pilot)
SIFT2_ARMS=(orig-lesion vbt-lesion deep-atropos-pilot)
DISC_SIFT2_ARMS=(orig-lesion vbt-lesion)

run_cmd() {
  if ((DRY_RUN)); then
    echo "[dry-run] $*"
  else
    echo "+ $*"
    "$@"
  fi
}

source "${DWI_ROOT}/workflow/lib/slurm_env.sh"
cd "${DWI_ROOT}"

COMMON_ARGS=(
  --recon-session 2WK
  --fastsurfer
  --no-inpaint
  --connectome-sift2
  --tractography-model ifod2
)

run_arm_mode() {
  local arm="$1" mode="$2"
  shift 2
  local arm_dir="${EXP}/arms/${arm}"
  echo ""
  echo "=== ${arm}: ${mode} ==="
  date
  BIDS_DIR="${BIDS}" \
  RESULTS_ROOT="${arm_dir}" \
  EXPERIMENT_ARM="${arm}" \
  SNAKEMAKE_WORKDIR="${arm_dir}/.snakemake_workdir/${SID}" \
  NTHREADS=8 \
  ACT_BIND_MOUNT_DEV=1 \
  SKIP_RERUN_INCOMPLETE=1 \
    run_cmd bash workflow/run_subject.sh "${mode}" "${SUBJECT}" \
      --experiment-arm "${arm}" "${COMMON_ARGS[@]}" "$@"
}

echo "=== TBI011011 gap fill ==="
date

# 1) recon.done markers (cosmetic; Snakemake skip logic)
for arm in "${ALL_ARMS[@]}"; do
  marker="${EXP}/arms/${arm}/.snakemake_markers/${SID}/recon.done"
  aparc="${EXP}/arms/${arm}/freesurfer/${SID}/mri/aparc+aseg.mgz"
  if [[ -f "${aparc}" && ! -f "${marker}" ]]; then
    run_cmd mkdir -p "$(dirname "${marker}")"
    run_cmd touch "${marker}"
    echo "  touched recon.done: ${arm}"
  fi
done

# 2) SIFT2 connectome on count-primary lesion arms
for arm in "${SIFT2_ARMS[@]}"; do
  sift2="${EXP}/arms/${arm}/connectomes/${SID}/dkt_connectome_sift2.csv"
  if [[ -f "${sift2}" ]]; then
    echo "  skip connectome sift2 (${arm}): already present"
    continue
  fi
  run_arm_mode "${arm}" connectome \
    $( [[ "${arm}" == "deep-atropos-pilot" ]] && echo --act-5tt-source deep-atropos-native )
done

# 3) Disconnectome with sift2 weighting (clears Option A WARN on count arms)
for arm in "${DISC_SIFT2_ARMS[@]}"; do
  disc_json="${EXP}/arms/${arm}/connectomes/${SID}/disconnectome/disconnectome.json"
  if [[ -f "${disc_json}" ]]; then
    weight="$(python3.12 -c "import json; print(json.load(open('${disc_json}')).get('connectome_weighting',''))")"
    if [[ "${weight}" == "sift2" ]]; then
      echo "  skip disconnectome sift2 (${arm}): already sift2"
      continue
    fi
  fi
  if (( ! DRY_RUN )); then
    rm -f "${EXP}/arms/${arm}/connectomes/${SID}/disconnectome/disconnection_matrix"*.csv \
          "${EXP}/arms/${arm}/connectomes/${SID}/disconnectome/disconnectome_qc.json"
  else
    echo "[dry-run] rm disconnectome outputs for ${arm}"
  fi
  run_arm_mode "${arm}" disconnectome --disconnection \
    --primary-connectome-measure sift2 --disconnectome-weighting sift2
done

# 4) Nodestrength on all arms
for arm in "${ALL_ARMS[@]}"; do
  ns="${EXP}/arms/${arm}/node_strength/strength/per_subject/${SID}_strength.csv"
  if [[ -f "${ns}" ]]; then
    echo "  skip nodestrength (${arm}): already present"
    continue
  fi
  run_arm_mode "${arm}" nodestrength
done

# 5) Refresh subject QC
for arm in "${ALL_ARMS[@]}"; do
  arm_dir="${EXP}/arms/${arm}"
  echo ""
  echo "=== ${arm}: subject_qc refresh ==="
  run_cmd python3.12 scripts/render_subject_qc.py \
    --results-root "${arm_dir}" --subject "${SUBJECT}"
done

echo ""
echo "=== verify ==="
run_cmd bash scripts/verify_tbi011011_arms.sh

echo ""
echo "=== gap summary ==="
python3.12 <<PY
import json
from pathlib import Path
EXP = Path("${EXP}")
SID = "${SID}"
ARMS = """orig-std orig-lesion neurolit-std neurolit-lesion vbt-std vbt-lesion deep-atropos-pilot""".split()
for arm in ARMS:
    base = EXP / "arms" / arm
    ns = base / "node_strength/strength/per_subject" / f"{SID}_strength.csv"
    sift2 = base / "connectomes" / SID / "dkt_connectome_sift2.csv"
    disc = base / "connectomes" / SID / "disconnectome/disconnectome_qc.json"
    recon = base / ".snakemake_markers" / SID / "recon.done"
    disc_st = json.load(open(disc)).get("overall_status","NA") if disc.exists() else "NA"
    print(f"{arm:20} nodestrength={'yes' if ns.exists() else 'NO':3} sift2={'yes' if sift2.exists() else 'NO':3} disc_qc={disc_st:4} recon.done={'yes' if recon.exists() else 'NO'}")
PY

echo "=== Done ==="
date
