#!/bin/bash
# Retest-pair QSIRecon iFOD2 + DKT-78 count after FastSurfer (default Kirby KKI849; RETEST_DATASET/RETEST_SID override). Not leftover ECE. Not gold.
# Array 1=ses-1 2=ses-2. Submit only after dwiref both sessions AND FastSurfer aparc exist.
#SBATCH --job-name=uhat_kirby_ifod
#SBATCH --partition=interactive
#SBATCH --time=12:00:00
#SBATCH --cpus-per-task=8
#SBATCH --mem=32G
#SBATCH --array=1-2%1
#SBATCH --exclude=smdodwork05
#SBATCH --output=/mnt/nfs/home/urmc-sh.rochester.edu/pndagiji/Documents/TrackTBI-Sub/dwi_pipeline/methods/mapping_uhat/work/sites_v1/logs/retest_ifod_%A_%a.out
#SBATCH --error=/mnt/nfs/home/urmc-sh.rochester.edu/pndagiji/Documents/TrackTBI-Sub/dwi_pipeline/methods/mapping_uhat/work/sites_v1/logs/retest_ifod_%A_%a.err
set -euo pipefail
UHAT=/mnt/nfs/home/urmc-sh.rochester.edu/pndagiji/Documents/TrackTBI-Sub/dwi_pipeline/methods/mapping_uhat
SD=/mnt/nfs/home/urmc-sh.rochester.edu/pndagiji/Documents/TrackTBI-Sub/dwi_pipeline/sample_data
DWI=/mnt/nfs/home/urmc-sh.rochester.edu/pndagiji/Documents/TrackTBI-Sub/dwi_pipeline
QSIRECON=/mnt/nfs/home/urmc-sh.rochester.edu/pndagiji/Documents/others/containers/qsirecon.sif
CONN=/mnt/nfs/home/urmc-sh.rochester.edu/pndagiji/Documents/others/containers/dkt_connectome.sif
LIC=/mnt/nfs/home/urmc-sh.rochester.edu/pndagiji/Documents/others/data_mining/freesurfer/license.txt
TF="${DWI}/templateflow"
DS="${RETEST_DATASET:-kirby21}"
SID="${RETEST_SID:-KKI849}"
SES="${SLURM_ARRAY_TASK_ID}"
# HCP is multi-shell (b=0/1k/2k/3k); Kirby/Boekel stay singleshell ss3t.
if [[ "${DS}" == "hcp_retest" ]]; then
  RECON_SPEC=mrtrix_multishell_msmt_ACT-hsvs
else
  RECON_SPEC=mrtrix_singleshell_ss3t_ACT-hsvs
fi
QSIPREP="${SD}/${DS}/results/sub-${SID}"
FREEZE="${SD}/${DS}/freeze/sub-${SID}"
FS="${FREEZE}/freesurfer"
QOUT="${FREEZE}/qsirecon_single_run_output"
WORK="${FREEZE}/.work_qsirecon_ses-${SES}"
COUT="${FREEZE}/connectomes/sub-${SID}/ses-${SES}"
FILT="${UHAT}/work/sites_v1/bids_filter_kirby_ses-${SES}.json"
DWIREF="${QSIPREP}/sub-${SID}/ses-${SES}/dwi/sub-${SID}_ses-${SES}_space-T1w_dwiref.nii.gz"
PREPROC_T1="${QSIPREP}/sub-${SID}/anat/sub-${SID}_desc-preproc_T1w.nii.gz"
PREPROC_DWI="${QSIPREP}/sub-${SID}/ses-${SES}/dwi/sub-${SID}_ses-${SES}_space-T1w_desc-preproc_dwi.nii.gz"
MASK="${QSIPREP}/sub-${SID}/ses-${SES}/dwi/sub-${SID}_ses-${SES}_space-T1w_desc-brain_mask.nii.gz"
BIDS_T1="${SD}/${DS}/bids/sub-${SID}/ses-1/anat/sub-${SID}_ses-1_T1w.nii.gz"
APARC="${FS}/sub-${SID}/mri/aparc+aseg.mgz"
COUNT="${COUT}/dkt_connectome_count.csv"
export APPTAINER_TMPDIR="/mnt/nfs/home/urmc-sh.rochester.edu/pndagiji/.cache/dkt-connectome/apptainer_tmp"
export SINGULARITY_TMPDIR="${APPTAINER_TMPDIR}"
mkdir -p "${QOUT}/derivatives" "${WORK}" "${COUT}" "${APPTAINER_TMPDIR}" "${UHAT}/work/sites_v1/logs"
echo "[KIRBY-IFOD] ses-${SES} host=$(hostname) $(date -Is)"
test -f "${QSIRECON}"
test -f "${CONN}"
test -f "${DWIREF}"
test -f "${APARC}"
test -f "${FILT}"
test -d "${TF}"
if [[ ! -f "${COUNT}" ]]; then
  if ! find -L "${QOUT}" -type f -path "*sub-${SID}*ses-${SES}*" \( -name '*model-ifod2_streamlines.tck' -o -name '*model-ifod2_streamlines.tck.gz' \) | grep -q .; then
    set +e
    apptainer run --cleanenv --containall \
      -B "${QSIPREP}":/qsiprep_input:ro \
      -B "${QOUT}":/output \
      -B "${WORK}":/work \
      -B "${FS}":/freesurfer:ro \
      -B "${LIC}":/opt/freesurfer/license.txt:ro \
      -B "${TF}":/templateflow \
      -B "${FILT}":/filter.json:ro \
      --env "TEMPLATEFLOW_HOME=/templateflow" \
      "${QSIRECON}" \
      /qsiprep_input /output participant \
        --input-type qsiprep \
        --recon-spec "${RECON_SPEC}" \
        --participant-label "${SID}" \
        --fs-subjects-dir /freesurfer \
        --fs-license-file /opt/freesurfer/license.txt \
        --bids-filter-file /filter.json \
        --atlases 4S156Parcels \
        --output-resolution 2 \
        --nthreads 8 --omp-nthreads 8 \
        --work-dir /work
    qrc=$?
    set -e
    # QSIRecon often finishes tractography then dies in generate_reports (pybids session kw).
    # Keep going if streamlines landed in QOUT.
    if [[ "${qrc}" -ne 0 ]]; then
      echo "[KIRBY-IFOD] qsirecon exit=${qrc}; checking for streamlines before failing"
    fi
  fi
  TCK="$(find -L "${QOUT}" -type f -path "*sub-${SID}*ses-${SES}*" \( -name '*model-ifod2_streamlines.tck' -o -name '*model-ifod2_streamlines.tck.gz' \) | head -1)"
  test -n "${TCK}" && test -f "${TCK}"
  SIFT2="$(find -L "${QOUT}" -type f -path "*sub-${SID}*ses-${SES}*" -name '*model-sift2_streamlineweights.csv' | head -1 || true)"
  SEG=aparc.DKTatlas+aseg.mgz
  if [[ ! -f "${FS}/sub-${SID}/mri/${SEG}" ]]; then
    SEG=aparc+aseg.mgz
  fi
  TCK_REL="${TCK#${QOUT}/}"
  SIFT_ARGS=()
  if [[ -n "${SIFT2}" && -f "${SIFT2}" ]]; then
    SIFT_REL="${SIFT2#${QOUT}/}"
    SIFT_ARGS=(--sift2-weights "/qsirecon/${SIFT_REL}")
  fi
  apptainer run --cleanenv --containall \
    --home /tmp \
    --env "LD_LIBRARY_PATH=/opt/ants/lib:/opt/mrtrix3-latest/lib" \
    -B "${FS}":/subjects:ro \
    -B "${QOUT}":/qsirecon:ro \
    -B "${QSIPREP}":/qsiprep:ro \
    -B "${SD}/${DS}/bids":/bids:ro \
    -B "${COUT}":/out \
    -B "${LIC}":/opt/freesurfer/license.txt:ro \
    "${CONN}" \
    --freesurfer-subject "/subjects/sub-${SID}" \
    --segmentation "${SEG}" \
    --tractogram "/qsirecon/${TCK_REL}" \
    --dwiref "/qsiprep/sub-${SID}/ses-${SES}/dwi/$(basename "${DWIREF}")" \
    --preproc-t1w "/qsiprep/sub-${SID}/anat/$(basename "${PREPROC_T1}")" \
    --bids-t1w "/bids/sub-${SID}/ses-1/anat/$(basename "${BIDS_T1}")" \
    --preproc-dwi "/qsiprep/sub-${SID}/ses-${SES}/dwi/$(basename "${PREPROC_DWI}")" \
    --bval "/qsiprep/sub-${SID}/ses-${SES}/dwi/$(basename "${PREPROC_DWI}" .nii.gz).bval" \
    --bvec "/qsiprep/sub-${SID}/ses-${SES}/dwi/$(basename "${PREPROC_DWI}" .nii.gz).bvec" \
    --brain-mask "/qsiprep/sub-${SID}/ses-${SES}/dwi/$(basename "${MASK}")" \
    --output-dir /out \
    --fs-license /opt/freesurfer/license.txt \
    --mrtrix-lut /opt/dkt/lut/fs_dkt.txt \
    --primary-measure count \
    "${SIFT_ARGS[@]}" \
    --subject-id "sub-${SID}_ses-${SES}"
  cp -f "${COUT}/connectome_count.csv" "${COUNT}"
  python3 - "${COUNT}" "${COUT}/parcellation.json" "${FS}/sub-${SID}" "${SEG}" <<'PY'
import json, sys
from pathlib import Path
count, meta, fs, seg = Path(sys.argv[1]), Path(sys.argv[2]), sys.argv[3], sys.argv[4]
rows = [r for r in count.read_text().splitlines() if r.strip()]
mat = [[float(x) for x in r.replace(",", " ").split()] for r in rows]
n = len(mat)
empty = sum(1 for i in range(n) if all(v == 0 for v in mat[i]))
rec = {
    "parcellation": "dkt",
    "atlas": "Desikan-Killiany-Tourville",
    "nodes": n,
    "labelconvert_lut": "fs_dkt.txt",
    "primary_measure": "count",
    "act_mode": "standard",
    "assigner": "radial_4",
    "empty_nodes": empty,
    "max_empty_nodes": 10,
    "connectome_csv": "dkt_connectome_count.csv",
    "freesurfer_subject_dir": fs,
    "aparc_aseg": f"{fs}/mri/{seg}",
    "not_hatU": True,
    "not_gold": True,
}
meta.write_text(json.dumps(rec, indent=2) + "\n")
print(json.dumps({"empty_nodes": empty, "nodes": n}))
if empty != 0:
    raise SystemExit(f"empty_nodes={empty} (need 0)")
PY
fi
echo "[KIRBY-IFOD] ses-${SES} count=${COUNT} $(date -Is)"
echo "Not leftover ECE. Not gold."
