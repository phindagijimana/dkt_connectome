#!/bin/bash
# Shared checks for a fresh clone. Sourced by preflight.sh and scripts/check_repro.sh.
# Functions print a message and return 1. They do not exit the caller.

dkt_path_is_placeholder() {
  local path="$1"
  [[ -n "${path}" ]] || return 1
  [[ "${path}" == /path/to/* || "${path}" == *"/path/to/"* ]]
}

dkt_container_missing_message() {
  local label="$1" path="$2"
  local env_name="CONTAINER_${label^^}"
  if dkt_path_is_placeholder "${path}"; then
    printf 'container missing (%s): %s\nRun ./dkt install. It writes workflow/config/config.local.yaml (do not commit that file), or set %s to an existing .sif.\n' \
      "${label}" "${path}" "${env_name}"
    return 1
  fi
  printf 'container missing (%s): %s\n' "${label}" "${path}"
  return 1
}

dkt_license_error() {
  local path="$1"
  if [[ -n "${path}" && -f "${path}" ]]; then
    return 0
  fi
  if [[ -z "${path}" ]] || dkt_path_is_placeholder "${path}"; then
    printf 'FreeSurfer license missing: %s\nSet FS_LICENSE to your license.txt (https://surfer.nmr.mgh.harvard.edu/registration.html).\nThe fs_license path in workflow/config/config.yaml is a placeholder.\n' \
      "${path:-unset}"
    return 1
  fi
  printf 'FreeSurfer license missing: %s\n' "${path}"
  return 1
}

dkt_bids_error() {
  local path="$1"
  if [[ -n "${path}" && -d "${path}" ]]; then
    return 0
  fi
  if dkt_path_is_placeholder "${path}"; then
    printf 'BIDS_DIR missing: %s\nSet BIDS_DIR to a BIDS dataset root. The bids_dir value in workflow/config/config.yaml is a placeholder.\n' \
      "${path}"
    return 1
  fi
  printf 'BIDS_DIR missing: %s\n' "${path}"
  return 1
}

# Return 0 when the directory's mount options include noexec.
dkt_mount_noexec() {
  local dir="$1"
  [[ -n "${dir}" && -d "${dir}" ]] || return 1
  local opts="" dev mp fstype line_opts rest best="" best_opts=""
  if command -v findmnt >/dev/null 2>&1; then
    opts="$(findmnt -n -o OPTIONS -T "${dir}" 2>/dev/null || true)"
  fi
  if [[ -z "${opts}" && -r /proc/mounts ]]; then
    while read -r dev mp fstype line_opts rest; do
      if [[ "${dir}" == "${mp}" || "${dir}" == "${mp}"/* ]]; then
        if [[ ${#mp} -gt ${#best} ]]; then
          best="${mp}"
          best_opts="${line_opts}"
        fi
      fi
    done < /proc/mounts
    opts="${best_opts}"
  fi
  [[ "${opts}" == *noexec* ]]
}

# Fail when TMPDIR, APPTAINER_TMPDIR, or PROOT_TMP_DIR points at a noexec mount.
# An unset variable is treated as /tmp.
dkt_tmp_error() {
  local -a bad=()
  local name val
  for name in TMPDIR APPTAINER_TMPDIR PROOT_TMP_DIR; do
    val="${!name-}"
    [[ -n "${val}" ]] || val=/tmp
    if dkt_mount_noexec "${val}"; then
      bad+=("${name}=${val}")
    fi
  done
  if [[ ${#bad[@]} -eq 0 ]]; then
    return 0
  fi
  local joined="" item
  for item in "${bad[@]}"; do
    if [[ -z "${joined}" ]]; then
      joined="${item}"
    else
      joined="${joined}, ${item}"
    fi
  done
  printf '%s\n' "Temp directory on a noexec mount: ${joined}."
  printf '%s\n' "Snakemake and Apptainer need an executable temp directory."
  printf '%s\n' 'export TMPDIR=${HOME}/.cache/dkt-connectome/tmp'
  printf '%s\n' 'export APPTAINER_TMPDIR=${HOME}/.cache/dkt-connectome/apptainer_tmp'
  printf '%s\n' 'export PROOT_TMP_DIR=${APPTAINER_TMPDIR}'
  printf '%s\n' 'export SINGULARITY_TMPDIR=${APPTAINER_TMPDIR}'
  printf '%s\n' 'mkdir -p "$TMPDIR" "$APPTAINER_TMPDIR"'
  return 1
}

dkt_snakemake_python() {
  local sn shebang
  sn="$(command -v snakemake 2>/dev/null || true)"
  [[ -n "${sn}" && -f "${sn}" ]] || return 1
  shebang="$(head -n 1 "${sn}" 2>/dev/null || true)"
  shebang="${shebang#\#!}"
  shebang="${shebang#"${shebang%%[![:space:]]*}"}"
  if [[ "${shebang}" == env\ * ]]; then
    shebang="${shebang#env }"
    shebang="${shebang#"${shebang%%[![:space:]]*}"}"
    echo "${shebang%% *}"
    return 0
  fi
  [[ -n "${shebang}" ]] || return 1
  echo "${shebang%% *}"
}

# Host Snakemake must see the stdlib argparse. A pip "argparse" backport on
# PYTHONPATH is searched first and hides BooleanOptionalAction.
dkt_check_stdlib_argparse() {
  local sn py
  sn="$(command -v snakemake 2>/dev/null || true)"
  if [[ -z "${sn}" ]]; then
    echo "repro: host snakemake is not on PATH. PIPELINE_ENGINE=bids_app uses Snakemake inside the orchestrator image."
    return 0
  fi
  if ! py="$(dkt_snakemake_python)"; then
    py="${PIPELINE_PYTHON:-python3}"
  fi
  if ! "${py}" -c 'import argparse, sys; sys.exit(0 if hasattr(argparse, "BooleanOptionalAction") else 1)'; then
    printf '%s\n' "repro: ${py} argparse has no BooleanOptionalAction (snakemake=${sn})."
    printf '%s\n' "A pip package named argparse is ahead of the standard library. Unset PYTHONPATH."
    printf '%s\n' "Host ./dkt run needs that stdlib class. PIPELINE_ENGINE=bids_app uses Snakemake inside the orchestrator image."
    return 1
  fi
  echo "repro: host snakemake argparse OK (${py})"
  return 0
}
