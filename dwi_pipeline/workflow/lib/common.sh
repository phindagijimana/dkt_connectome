# =============================================================================
# common.sh — Shared bash helpers used by both engines:
#   - dwi_pipeline/subject.sh          (the original imperative pipeline)
#   - dwi_pipeline/workflow/rules/*.smk (the Snakemake plugin/workflow engine)
#
# This file is the single source of truth for logic that must behave
# identically in both places (session resolution, lesion-mask discovery,
# atlas auto-detection, strict-match helpers). It is sourced, not executed:
#   source "$(dirname "${BASH_SOURCE[0]}")/common.sh"
#
# Extracted verbatim from subject.sh during the Snakemake migration (Aug 2026)
# so the two engines cannot silently drift apart while both are in use.
# =============================================================================

_pipeline_fail() {
  local label="$1" msg="$2"
  shift 2
  echo "ERROR [${label}]: ${msg}" >&2
  while (($#)); do echo "  $1" >&2; shift; done
  exit 1
}

_strict_find_one() {
  local label="$1"
  shift
  local -a matches=()
  mapfile -t matches < <("$@" 2>/dev/null | LC_ALL=C sort -u)
  ((${#matches[@]})) || _pipeline_fail "${label}" "no file found for sub-${SUBJECT}"
  ((${#matches[@]} == 1)) || _pipeline_fail "${label}" "expected exactly 1 match, found ${#matches[@]}" "${matches[@]}"
  echo "${matches[0]}"
}

# _find_ifod2_tractogram — lesion-aware ACT, staged tractography/, then QSIRecon.
_find_ifod2_tractogram() {
  local qsirecon_out="$1" tractography_out="$2" lesion_act_out="$3" subject="$4"
  local -a candidates=()
  if [[ -n "${lesion_act_out}" ]]; then
    candidates+=(
      "${lesion_act_out}/sub-${subject}/model-ifod2_streamlines.tck"
      "${lesion_act_out}/sub-${subject}/model-ifod2_streamlines.tck.gz"
    )
  fi
  if [[ -n "${tractography_out}" ]]; then
    candidates+=(
      "${tractography_out}/sub-${subject}/model-ifod2_streamlines.tck"
      "${tractography_out}/sub-${subject}/model-ifod2_streamlines.tck.gz"
    )
  fi
  local candidate
  for candidate in "${candidates[@]}"; do
    [[ -f "${candidate}" ]] && { echo "${candidate}"; return 0; }
  done
  _strict_find_one "connectome/tractogram" \
    find -L "${qsirecon_out}" -type f -path "*sub-${subject}*" \
      \( -name '*model-ifod2_streamlines.tck' -o -name '*model-ifod2_streamlines.tck.gz' \)
}

# _find_sift2_weights — prefer lesion-aware ACT weights, else QSIRecon.
_find_sift2_weights() {
  local qsirecon_out="$1" lesion_act_out="$2" subject="$3"
  local act_weights=""
  if [[ -n "${lesion_act_out}" ]]; then
    act_weights="${lesion_act_out}/sub-${subject}/model-sift2_streamlineweights.csv"
    [[ -f "${act_weights}" ]] && { echo "${act_weights}"; return 0; }
  fi
  _strict_find_one "connectome/sift2_weights" \
    find -L "${qsirecon_out}" -type f -path "*sub-${subject}*" \
      -name '*model-sift2_streamlineweights.csv'
}

# find_lesion_mask — 0 or 1 sibling *_T1w_label-lesion_roi.nii.gz next to the
# session's T1w. Echoes nothing (not an error) when none exists.
find_lesion_mask() {
  local subject="$1" session="$2"
  local anat_dir="${BIDS_DIR}/sub-${subject}/ses-${session}/anat"
  [[ -d "${anat_dir}" ]] || return 0
  local -a matches=()
  mapfile -t matches < <(find "${anat_dir}" -maxdepth 1 -type f \
    -name '*_T1w_label-lesion_roi.nii.gz' 2>/dev/null | LC_ALL=C sort -u)
  ((${#matches[@]})) || return 0
  ((${#matches[@]} == 1)) || _pipeline_fail "inpaint/lesion mask" \
    "expected 0 or 1 lesion mask for sub-${subject} ses-${session}, found ${#matches[@]}" "${matches[@]}"
  echo "${matches[0]}"
}

# find_prepared_lesion_mask — Step 1.1 prepared mask on the results tree.
find_prepared_lesion_mask() {
  local results_root="$1" subject="$2" session="$3"
  local root candidate
  for root in "${results_root}/lesion_masks" "${results_root}/inpainted" "${results_root}/vbt"; do
    candidate="${root}/sub-${subject}/ses-${session}/lesion_mask_prepared.nii.gz"
    [[ -f "${candidate}" ]] && { echo "${candidate}"; return 0; }
  done
  return 1
}

# BIDS session label from a path (e.g. "2WK" from ".../ses-2WK/dwi/...").
_bids_ses_from_path() {
  if [[ "$1" =~ /ses-([^/]+)/ ]]; then
    echo "${BASH_REMATCH[1]}"
  fi
}

# QSIPrep DWI-space derivative under ses-*/dwi/ (or subject dwi/).
# Prefers space-T1w; falls back to space-ACPC (QSIPrep 1.0 ACPC-first layouts).
find_qsiprep_dwi_space_artifact() {
  local label="$1" qsiprep_out="$2" subject="$3" session="$4" suffix="$5"
  local -a t1w=() acpc=()
  mapfile -t t1w < <(
    find -L "${qsiprep_out}" -type f -path "*sub-${subject}*" \( \
      -path "*/ses-${session}/dwi/*space-T1w_${suffix}" -o \
      -path "*/dwi/*space-T1w_${suffix}" \
    \) 2>/dev/null | LC_ALL=C sort -u
  )
  mapfile -t acpc < <(
    find -L "${qsiprep_out}" -type f -path "*sub-${subject}*" \( \
      -path "*/ses-${session}/dwi/*space-ACPC_${suffix}" -o \
      -path "*/dwi/*space-ACPC_${suffix}" \
    \) 2>/dev/null | LC_ALL=C sort -u
  )
  if ((${#t1w[@]} == 1)); then
    echo "${t1w[0]}"
    return 0
  fi
  if ((${#acpc[@]} == 1)); then
    echo "${acpc[0]}"
    return 0
  fi
  if ((${#t1w[@]} == 0 && ${#acpc[@]} == 0)); then
    _pipeline_fail "${label}" \
      "no file found for sub-${subject} (tried space-T1w and space-ACPC *_${suffix})"
  fi
  _pipeline_fail "${label}" \
    "expected exactly 1 match (space-T1w: ${#t1w[@]}, space-ACPC: ${#acpc[@]})" \
    "${t1w[@]}" "${acpc[@]}"
}

find_qsiprep_dwiref() {
  find_qsiprep_dwi_space_artifact "$1" "$2" "$3" "$4" "dwiref.nii.gz"
}

find_qsiprep_preproc_dwi() {
  find_qsiprep_dwi_space_artifact "$1" "$2" "$3" "$4" "desc-preproc_dwi.nii.gz"
}

find_qsiprep_brain_mask() {
  find_qsiprep_dwi_space_artifact "$1" "$2" "$3" "$4" "desc-brain_mask.nii.gz"
}

# QSIPrep anatomical derivative under ses-*/anat/ (or subject anat/).
# Tries plain BIDS name, then space-T1w, then space-ACPC (QSIPrep 1.0 layouts).
find_qsiprep_anat_space_artifact() {
  local label="$1" qsiprep_out="$2" subject="$3" session="$4" suffix="$5"
  local -a plain=() t1w=() acpc=()
  mapfile -t plain < <(
    find "${qsiprep_out}/sub-${subject}" \( \
      -path "*/ses-${session}/anat/*sub-${subject}_${suffix}" -o \
      -path "*/anat/*sub-${subject}_${suffix}" \
    \) -type f 2>/dev/null | LC_ALL=C sort -u
  )
  mapfile -t t1w < <(
    find "${qsiprep_out}/sub-${subject}" \( \
      -path "*/ses-${session}/anat/*sub-${subject}_space-T1w_${suffix}" -o \
      -path "*/anat/*sub-${subject}_space-T1w_${suffix}" \
    \) -type f 2>/dev/null | LC_ALL=C sort -u
  )
  mapfile -t acpc < <(
    find "${qsiprep_out}/sub-${subject}" \( \
      -path "*/ses-${session}/anat/*sub-${subject}_space-ACPC_${suffix}" -o \
      -path "*/anat/*sub-${subject}_space-ACPC_${suffix}" \
    \) -type f 2>/dev/null | LC_ALL=C sort -u
  )
  if ((${#plain[@]} == 1)); then
    echo "${plain[0]}"
    return 0
  fi
  if ((${#t1w[@]} == 1)); then
    echo "${t1w[0]}"
    return 0
  fi
  if ((${#acpc[@]} == 1)); then
    echo "${acpc[0]}"
    return 0
  fi
  if ((${#plain[@]} == 0 && ${#t1w[@]} == 0 && ${#acpc[@]} == 0)); then
    _pipeline_fail "${label}" \
      "no file found for sub-${subject} (tried plain, space-T1w, and space-ACPC *_${suffix})"
  fi
  _pipeline_fail "${label}" \
    "expected exactly 1 match (plain: ${#plain[@]}, space-T1w: ${#t1w[@]}, space-ACPC: ${#acpc[@]})" \
    "${plain[@]}" "${t1w[@]}" "${acpc[@]}"
}

# QSIPrep desc-preproc T1w: exactly one file under session anat/ or subject anat/.
find_qsiprep_preproc_t1w() {
  find_qsiprep_anat_space_artifact "connectome/QSIPrep desc-preproc T1w" "$1" "$2" "$3" \
    "desc-preproc_T1w.nii.gz"
}

# QSIPrep packaged T1wNative -> T1wACPC transform (0 or 1). Echoes nothing if absent.
find_qsiprep_native_to_acpc() {
  local qsiprep_out="$1" subject="$2" session="$3"
  local -a matches=()
  mapfile -t matches < <(
    find "${qsiprep_out}/sub-${subject}" \( \
      -path "*/ses-${session}/anat/*from-T1wNative_to-T1wACPC_mode-image_xfm.mat" -o \
      -path "*/ses-${session}/anat/*from-T1wNative_to-T1wACPC_mode-image_xfm.txt" -o \
      -path "*/anat/*from-T1wNative_to-T1wACPC_mode-image_xfm.mat" -o \
      -path "*/anat/*from-T1wNative_to-T1wACPC_mode-image_xfm.txt" \
    \) -type f 2>/dev/null | LC_ALL=C sort -u
  )
  ((${#matches[@]})) || return 0
  ((${#matches[@]} == 1)) || _pipeline_fail "lesion-aware-act/T1wNative→ACPC" \
    "expected 0 or 1 native→ACPC transform, found ${#matches[@]}" "${matches[@]}"
  echo "${matches[0]}"
}

# BIDS T1w for the target session (exactly one match required).
find_bids_t1w() {
  local subject="$1" session="$2"
  [[ -n "${session}" ]] || _pipeline_fail "connectome/BIDS T1w" "session is required"
  _strict_find_one "connectome/BIDS T1w" \
    find "${BIDS_DIR}/sub-${subject}/ses-${session}/anat" -type f \
      \( -name '*_T1w.nii.gz' -o -name '*_T1w.nii' \)
}

# Internal helper: probe a SIF for its FREESURFER_HOME (handles both
# /opt/freesurfer used by NeuroDocker/FastSurfer recipes and
# /usr/local/freesurfer used by the MGH-published freesurfer/freesurfer image).
_detect_fs_home_in_container() {
  local sif="$1"
  apptainer exec --cleanenv "${sif}" bash -lc '
    for p in "$FREESURFER_HOME" /opt/freesurfer /usr/local/freesurfer; do
      [[ -n "$p" && -x "$p/bin/recon-all" ]] && { echo "$p"; exit 0; }
    done
    ra=$(command -v recon-all || true)
    [[ -n "$ra" ]] && { dirname "$(dirname "$ra")"; exit 0; }
    exit 1
  ' 2>/dev/null | tail -1
}

# -----------------------------------------------------------------------------
# _fs_aparc_has_dk_only_labels — Does the segmentation contain DK-only regions?
#
# bankssts (1001/2001), frontal pole (1032/2032) and temporal pole (1033/2033)
# exist in Desikan-Killiany but are not defined by the DKT protocol. Prints 1
# if any are present and 0 if none are; returns non-zero (printing nothing)
# when the probe could not run. Requires CONTAINER_CONNECTOME.
# -----------------------------------------------------------------------------
_fs_aparc_has_dk_only_labels() {
  local fs_dir="$1" scratch_parent="$2"
  local scratch max

  [[ -f "${CONTAINER_CONNECTOME}" ]] || return 1
  scratch="$(mktemp -d "${scratch_parent}/.dkprobe_XXXXXX" 2>/dev/null)" || return 1

  max="$(apptainer exec --cleanenv --containall \
      --env "LD_LIBRARY_PATH=/opt/ants/lib:/opt/mrtrix3-latest/lib" \
      -B "${fs_dir}/mri":/probe:ro \
      -B "${scratch}":/scratch \
      "${CONTAINER_CONNECTOME}" bash -c '
        set -e
        a=/probe/aparc+aseg.mgz
        mrcalc -quiet -force "$a" 1001 -eq "$a" 1032 -eq -add "$a" 1033 -eq -add \
          "$a" 2001 -eq -add "$a" 2032 -eq -add "$a" 2033 -eq -add /scratch/dk_only.mif
        mrstats /scratch/dk_only.mif -output max
      ' 2>/dev/null | tr -d '[:space:]')"
  rm -rf "${scratch}"

  case "${max}" in
    0) echo 0 ;;
    1) echo 1 ;;
    *) return 1 ;;
  esac
}

# -----------------------------------------------------------------------------
# _fs_tree_is_dkt — Is this subject tree a FastSurfer (DKT) segmentation?
# Sets _CONNECTOME_DETECT_METHOD to describe which signal decided.
# -----------------------------------------------------------------------------
_fs_tree_is_dkt() {
  local fs_dir="$1" scratch_parent="$2"
  local probe

  if probe="$(_fs_aparc_has_dk_only_labels "${fs_dir}" "${scratch_parent}")"; then
    _CONNECTOME_DETECT_METHOD="aparc+aseg.mgz label content"
    [[ "${probe}" == "0" ]]
    return
  fi

  _CONNECTOME_DETECT_METHOD="file layout (label probe unavailable)"
  local aparc="${fs_dir}/mri/aparc+aseg.mgz"
  if [[ -L "${aparc}" && "$(readlink "${aparc}")" == *DKTatlas* ]]; then
    return 0
  fi
  [[ -f "${fs_dir}/mri/aparc.DKTatlas+aseg.deep.mgz" ]]
}

# _count_empty_nodes — Nodes with no connections in a connectome CSV.
_count_empty_nodes() {
  awk -F',' 'NF > 1 { s = 0; for (i = 1; i <= NF; i++) s += $i; if (s == 0) c++ }
             END { print c + 0 }' "$1"
}
