#!/bin/bash
# KKI239 ses-2 rescue: skip failed mtnormalise; track+DKT from raw WM FOD.
# Document as processing note (no intensity norm on this session). Not hat{U}.
#SBATCH --job-name=uhat_kki239_skip_mtnorm
#SBATCH --partition=interactive
#SBATCH --time=12:00:00
#SBATCH --cpus-per-task=8
#SBATCH --mem=48G
#SBATCH --exclude=smdodwork05
#SBATCH --output=/mnt/nfs/home/urmc-sh.rochester.edu/pndagiji/Documents/TrackTBI-Sub/dwi_pipeline/methods/mapping_uhat/work/sites_v1/logs/kki239_skip_mtnorm_%j.out
#SBATCH --error=/mnt/nfs/home/urmc-sh.rochester.edu/pndagiji/Documents/TrackTBI-Sub/dwi_pipeline/methods/mapping_uhat/work/sites_v1/logs/kki239_skip_mtnorm_%j.err
set -euo pipefail
UHAT=/mnt/nfs/home/urmc-sh.rochester.edu/pndagiji/Documents/TrackTBI-Sub/dwi_pipeline/methods/mapping_uhat
SD=/mnt/nfs/home/urmc-sh.rochester.edu/pndagiji/Documents/TrackTBI-Sub/dwi_pipeline/sample_data
QSIRECON=/mnt/nfs/home/urmc-sh.rochester.edu/pndagiji/Documents/others/containers/qsirecon.sif
CONN=/mnt/nfs/home/urmc-sh.rochester.edu/pndagiji/Documents/others/containers/dkt_connectome.sif
LIC=/mnt/nfs/home/urmc-sh.rochester.edu/pndagiji/Documents/others/data_mining/freesurfer/license.txt
DS=kirby21
SID=KKI239
SES=2
FREEZE="${SD}/${DS}/freeze/sub-${SID}"
QSIPREP="${SD}/${DS}/results/sub-${SID}"
QOUT="${FREEZE}/qsirecon_single_run_output"
COUT="${FREEZE}/connectomes/sub-${SID}/ses-${SES}"
FS="${FREEZE}/freesurfer"
WF="${FREEZE}/.work_qsirecon_ses-${SES}/qsirecon_1_2_wf/sub-${SID}_mrtrix_singleshell_ss3_hsvst"
FOD_RAW="${WF}/sub_KKI239_ses_2_space_T1w_desc_preproc_recon_wf/ss3t_csd/estimate_fod/sub-KKI239_ses-2_space-T1w_desc-preproc_dwi_wm.mif"
FTT="${WF}/recon_anatomical_wf_0/apply_header_to_5tt/sub-KKI239_5tt_hdrxform.nii.gz"
RESCUE="${FREEZE}/rescue_ses2_skip_mtnorm"
DWIREF="${QSIPREP}/sub-${SID}/ses-${SES}/dwi/sub-${SID}_ses-${SES}_space-T1w_dwiref.nii.gz"
PREPROC_T1="${QSIPREP}/sub-${SID}/anat/sub-${SID}_desc-preproc_T1w.nii.gz"
PREPROC_DWI="${QSIPREP}/sub-${SID}/ses-${SES}/dwi/sub-${SID}_ses-${SES}_space-T1w_desc-preproc_dwi.nii.gz"
MASK="${QSIPREP}/sub-${SID}/ses-${SES}/dwi/sub-${SID}_ses-${SES}_space-T1w_desc-brain_mask.nii.gz"
BIDS_T1="${SD}/${DS}/bids/sub-${SID}/ses-1/anat/sub-${SID}_ses-1_T1w.nii.gz"
COUNT="${COUT}/dkt_connectome_count.csv"
TCK_OUT_DIR="${QOUT}/derivatives/qsirecon-MRtrix3_fork-SS3T_act-HSVS/sub-${SID}/ses-${SES}/dwi"
TCK_OUT="${TCK_OUT_DIR}/sub-${SID}_ses-${SES}_space-T1w_model-ifod2_streamlines.tck.gz"
export APPTAINER_TMPDIR="/mnt/nfs/home/urmc-sh.rochester.edu/pndagiji/.cache/dkt-connectome/apptainer_tmp"
export SINGULARITY_TMPDIR="${APPTAINER_TMPDIR}"
mkdir -p "${RESCUE}" "${COUT}" "${TCK_OUT_DIR}" "${APPTAINER_TMPDIR}" "${UHAT}/work/sites_v1/logs"

echo "[KKI239-SKIP-MTNORM] host=$(hostname) $(date -Is)"
test -f "${FOD_RAW}"
test -f "${FTT}"
test -f "${QSIRECON}"
test -f "${CONN}"

# NOTE: use raw WM FOD (mtnormalise failed: non-positive CSF balance factor)
echo "[KKI239-SKIP-MTNORM] FOD=raw (no mtnormalise) ${FOD_RAW}"
echo "{\"subject\":\"${SID}\",\"session\":${SES},\"skip_mtnormalise\":true,\"reason\":\"Non-positive tissue balance factor (CSF)\",\"fod\":\"${FOD_RAW}\",\"date\":\"$(date -Is)\"}" \
  > "${RESCUE}/provenance.json"

if [[ ! -f "${RESCUE}/tracked.tck" ]]; then
  apptainer exec --cleanenv -B "${FREEZE}":"${FREEZE}" "${QSIRECON}" \
    tckgen -act "${FTT}" -algorithm iFOD2 -backtrack -crop_at_gmwmi \
      -maxlength 250.000000 -minlength 30.000000 -samples 4 -nthreads 8 \
      -output_seeds "${RESCUE}/out_seeds.nii.gz" -power 0.330000 -quiet \
      -seed_dynamic "${FOD_RAW}" -select 10000000 \
      "${FOD_RAW}" "${RESCUE}/tracked.tmp.tck" -force
  mv "${RESCUE}/tracked.tmp.tck" "${RESCUE}/tracked.tck"
fi
echo "[KKI239-SKIP-MTNORM] tckgen done $(date -Is) size=$(du -h "${RESCUE}/tracked.tck" | awk '{print $1}')"

# install into QSIRecon derivatives path (gzip) — do NOT use mrconvert on .tck
if [[ ! -f "${TCK_OUT}" ]]; then
  gzip -c -1 "${RESCUE}/tracked.tck" > "${TCK_OUT}.tmp"
  mv "${TCK_OUT}.tmp" "${TCK_OUT}"
fi
echo "[KKI239-SKIP-MTNORM] tck installed ${TCK_OUT}"

SEG=aparc.DKTatlas+aseg.mgz
if [[ ! -f "${FS}/sub-${SID}/mri/${SEG}" ]]; then
  SEG=aparc+aseg.mgz
fi
TCK_REL="${TCK_OUT#${QOUT}/}"

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
  --subject-id "sub-${SID}_ses-${SES}"

cp -f "${COUT}/connectome_count.csv" "${COUNT}"
echo "[KKI239-SKIP-MTNORM] count=${COUNT} $(date -Is)"
test -f "${COUNT}"
echo "[KKI239-SKIP-MTNORM] DONE"
