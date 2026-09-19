#!/bin/bash
#SBATCH --job-name=tbi011011_arm
#SBATCH --partition=interactive
#SBATCH --cpus-per-task=8
#SBATCH --mem=64G
#SBATCH --time=12:00:00
#SBATCH --output=/mnt/nfs/Gugger_Lab/NIR/dwi_test_TBI_experiment/sub-TBI011011_fastsurfer_experiment/arms/@ARM@/logs/tbi_arm_%j.out
#SBATCH --error=/mnt/nfs/Gugger_Lab/NIR/dwi_test_TBI_experiment/sub-TBI011011_fastsurfer_experiment/arms/@ARM@/logs/tbi_arm_%j.err

set -euo pipefail

ARM="@ARM@"
FINISH_MODE="@FINISH_MODE@"
EXP="/mnt/nfs/Gugger_Lab/NIR/dwi_test_TBI_experiment/sub-TBI011011_fastsurfer_experiment"
ARM_DIR="${EXP}/arms/${ARM}"
BIDS="/mnt/nfs/Gugger_Lab/NIR/dwi_test_TBI_experiment/bids"
DWI="/mnt/nfs/home/urmc-sh.rochester.edu/pndagiji/Documents/TrackTBI-Sub/dwi_pipeline"
SUBJECT=TBI011011
SESSION=2WK

export TMPDIR="${EXP}/.cache/snakemake_tmp"
mkdir -p "${TMPDIR}" "${ARM_DIR}/logs" "${ARM_DIR}/.snakemake_workdir/sub-${SUBJECT}"

_real_home="$(getent passwd "${USER}" 2>/dev/null | cut -d: -f6 || true)"
[[ -n "${_real_home}" && -d "${_real_home}" ]] && export HOME="${_real_home}"

source "${DWI}/workflow/lib/slurm_env.sh"
cd "${DWI}"

MARKERS="${ARM_DIR}/.snakemake_markers/sub-${SUBJECT}"
mkdir -p "${MARKERS}"

_has_ifod2_in_qsirecon() {
  find "${ARM_DIR}/qsirecon_single_run_output" -type f -path "*sub-${SUBJECT}*" \
    \( -name '*model-ifod2_streamlines.tck' -o -name '*model-ifod2_streamlines.tck.gz' \) \
    2>/dev/null | grep -q .
}

_has_qsirecon_wm_fod() {
  find "${ARM_DIR}/qsirecon_single_run_output" -type f -path "*sub-${SUBJECT}*" \
    -name '*model-ss3t_param-fod_label-WM_dwimap.mif.gz' \
    2>/dev/null | grep -q .
}

_has_lesion_act_tractogram() {
  [[ -f "${ARM_DIR}/lesion_aware_act/sub-${SUBJECT}/model-ifod2_streamlines.tck" ]]
}

[[ -f "${ARM_DIR}/qsiprep_single_run_output/sub-${SUBJECT}.html" ]] && touch "${MARKERS}/qsiprep.done"
[[ -f "${ARM_DIR}/freesurfer/sub-${SUBJECT}/mri/aparc+aseg.mgz" ]] && touch "${MARKERS}/recon.done"

# QSIRecon marker: mode-specific so lesion finish jobs do not rerun Step 3.
if [[ "${FINISH_MODE}" == "lesion-finish" ]]; then
  if _has_qsirecon_wm_fod || _has_lesion_act_tractogram; then
    touch "${MARKERS}/qsirecon.done"
    echo "Marker: qsirecon.done (lesion finish — WM-FOD or lesion-aware ACT present)"
  else
    rm -f "${MARKERS}/qsirecon.done"
    echo "WARNING: qsirecon.done cleared — no WM-FOD or lesion-aware tractogram"
  fi
elif [[ "${FINISH_MODE}" == "vbt-std-finish" ]]; then
  if _has_ifod2_in_qsirecon \
     || [[ -f "${ARM_DIR}/tractography/sub-${SUBJECT}/model-ifod2_streamlines.tck" ]]; then
    touch "${MARKERS}/qsirecon.done"
  else
    rm -f "${MARKERS}/qsirecon.done"
  fi
else
  if _has_ifod2_in_qsirecon; then
    touch "${MARKERS}/qsirecon.done"
  else
    rm -f "${MARKERS}/qsirecon.done"
  fi
fi

COMMON_ARGS=(
  --recon-session "${SESSION}"
  --experiment-arm "${ARM}"
  --fastsurfer
  --no-inpaint
  --connectome-sift2
  --tractography-model both
)

run_mode() {
  local mode="$1"
  shift
  local skip_rerun="${SKIP_RERUN_INCOMPLETE:-0}"
  echo ""
  echo "=== ${ARM}: ${mode} ==="
  date
  BIDS_DIR="${BIDS}" \
  RESULTS_ROOT="${ARM_DIR}" \
  EXPERIMENT_ARM="${ARM}" \
  SNAKEMAKE_WORKDIR="${ARM_DIR}/.snakemake_workdir/sub-${SUBJECT}" \
  NTHREADS=8 \
  ACT_BIND_MOUNT_DEV=1 \
  SKIP_RERUN_INCOMPLETE="${skip_rerun}" \
    bash workflow/run_subject.sh "${mode}" "${SUBJECT}" \
      "${COMMON_ARGS[@]}" "$@"
}

echo "=== TBI011011 finish arm: ${ARM} (${FINISH_MODE}) ==="
echo "  results: ${ARM_DIR}"
date

case "${FINISH_MODE}" in
  lesion-finish)
    rm -rf "${ARM_DIR}/.snakemake_workdir/sub-${SUBJECT}/.snakemake/incomplete"
    SKIP_RERUN_INCOMPLETE=1 run_mode disconnectome --disconnection \
      --primary-connectome-measure sift2 --disconnectome-weighting sift2
    run_mode nodestrength
    run_mode subject_qc
    ;;
  vbt-std-finish)
    run_mode qsirecon
    run_mode connectome
    SKIP_RERUN_INCOMPLETE=1 run_mode disconnectome --disconnection \
      --primary-connectome-measure sift2 --disconnectome-weighting sift2
    run_mode nodestrength
    run_mode subject_qc
    ;;
  *)
    echo "Unknown FINISH_MODE=${FINISH_MODE}" >&2
    exit 2
    ;;
esac

echo "=== Done ${ARM} (${FINISH_MODE}) ==="
date
ls -la "${ARM_DIR}/connectomes/sub-${SUBJECT}/" 2>/dev/null | head -10 || true
ls -la "${ARM_DIR}/qc/sub-${SUBJECT}/" 2>/dev/null || true
