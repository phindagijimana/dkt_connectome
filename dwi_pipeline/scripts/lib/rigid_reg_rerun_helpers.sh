#!/bin/bash
# Shared helpers for rigid FS->ACPC connectome backfill (Step 4+5).
# Source from array/submit scripts; do not execute directly.

# Remove IFOD2 + SD_STREAM connectome products (not tractography .tck).
clear_connectome_outputs_for_rigid_reg() {
  local results_root="$1" subject="$2"
  local conn="${results_root}/connectomes/sub-${subject}"
  [[ -d "${conn}" ]] || return 0
  rm -f "${conn}"/dkt_connectome*.csv \
        "${conn}"/dk_connectome*.csv \
        "${conn}"/dkt_model-SDSTREAM_*.csv \
        "${conn}"/dk_model-SDSTREAM_*.csv \
        "${conn}"/dkt_model-SDSTREAM_connectome.json \
        "${conn}"/dk_model-SDSTREAM_connectome.json \
        "${conn}"/dkt_nodes.mif \
        "${conn}"/dk_nodes.mif \
        "${conn}"/dkt_desc-*.nii.gz \
        "${conn}"/dk_desc-*.nii.gz \
        "${conn}"/aparc+aseg*.nii.gz \
        "${conn}"/aparc+aseg*.mgz \
        "${conn}"/connectome*.csv \
        "${conn}"/desc-*.nii.gz \
        "${conn}"/native_to_preproc* \
        "${conn}"/fs_to_preproc* \
        "${conn}"/T1.nii.gz \
        "${conn}"/nodes.mif \
        "${conn}"/parcellation.json \
        "${conn}"/lausanne60_*.csv \
        "${conn}"/lausanne60_*.mif 2>/dev/null || true
}

_find_ifod2_tck_path() {
  local results_root="$1" subject="$2"
  local candidate
  for candidate in \
    "${results_root}/tractography/sub-${subject}/model-ifod2_streamlines.tck" \
    "${results_root}/lesion_aware_act/sub-${subject}/model-ifod2_streamlines.tck"; do
    [[ -f "${candidate}" ]] && { echo "${candidate}"; return 0; }
  done
  find -L "${results_root}/qsirecon_single_run_output" -type f -path "*sub-${subject}*" \
    \( -name '*model-ifod2_streamlines.tck' -o -name '*model-ifod2_streamlines.tck.gz' \) \
    2>/dev/null | LC_ALL=C sort -u | head -1
}

_find_sdstream_tck_path() {
  local results_root="$1" subject="$2"
  local candidate="${results_root}/tractography/sub-${subject}/model-SDSTREAM_streamlines.tck"
  [[ -f "${candidate}" ]] && echo "${candidate}"
}

# Echo effective tractography model: ifod2 | sd_stream | both
resolve_tractography_model_for_rigid_rerun() {
  local results_root="$1" subject="$2" requested="${3:-both}"
  requested="${requested,,}"
  local ifod2 sdstream
  ifod2="$(_find_ifod2_tck_path "${results_root}" "${subject}")"
  sdstream="$(_find_sdstream_tck_path "${results_root}" "${subject}")"

  case "${requested}" in
    ifod2)
      [[ -n "${ifod2}" ]] || return 1
      echo "ifod2"
      ;;
    sd_stream|sdstream)
      [[ -n "${sdstream}" ]] || return 1
      echo "sd_stream"
      ;;
    both)
      if [[ -n "${ifod2}" && -n "${sdstream}" ]]; then
        echo "both"
      elif [[ -n "${ifod2}" ]]; then
        echo "ifod2"
      elif [[ -n "${sdstream}" ]]; then
        echo "sd_stream"
      else
        return 1
      fi
      ;;
    *)
      echo "ERROR: invalid tractography model request: ${requested}" >&2
      return 1
      ;;
  esac
}

# Build missing SD_STREAM .tck only (never connectome). Sets SKIP_RERUN_INCOMPLETE=1
# when tractography is present so Step 4 does not rebuild streamlines.
# Echoes the effective tractography model on stdout.
prepare_rigid_reg_tractography() {
  local results_root="$1" subject="$2" pipeline="$3" requested_model="${4:-both}"
  shift 4
  local -a subject_args=("$@")

  local ifod2 sdstream effective
  ifod2="$(_find_ifod2_tck_path "${results_root}" "${subject}")"
  sdstream="$(_find_sdstream_tck_path "${results_root}" "${subject}")"

  if [[ -z "${sdstream}" && "${requested_model}" =~ ^(both|sd_stream|sdstream)$ ]]; then
    echo "sub-${subject}: missing SD_STREAM tractography — running sdstream-tractography only" >&2
    SKIP_RERUN_INCOMPLETE=0 bash "${pipeline}" sdstream-tractography "${subject}" \
      "${subject_args[@]}" --tractography-model sd_stream
    sdstream="$(_find_sdstream_tck_path "${results_root}" "${subject}")"
    [[ -n "${sdstream}" ]] || {
      echo "ERROR: sub-${subject}: SD_STREAM tractography still missing after sdstream-tractography" >&2
      return 1
    }
  fi

  if [[ -z "${ifod2}" && "${requested_model}" =~ ^(both|ifod2)$ ]]; then
    echo "WARN: sub-${subject}: no IFOD2 .tck under tractography/lesion_act/qsirecon (will skip IFOD2 connectome)" >&2
  fi

  effective="$(resolve_tractography_model_for_rigid_rerun "${results_root}" "${subject}" "${requested_model}")" || {
    echo "ERROR: sub-${subject}: no usable tractography for rigid-reg rerun (need IFOD2 and/or SD_STREAM .tck)" >&2
    return 1
  }

  if [[ -n "${ifod2}" || -n "${sdstream}" ]]; then
    export SKIP_RERUN_INCOMPLETE=1
    echo "sub-${subject}: reusing existing tractography (SKIP_RERUN_INCOMPLETE=1); effective model=${effective}" >&2
  fi

  echo "${effective}"
}
