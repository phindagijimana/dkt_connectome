#!/bin/bash
# Normalize Slurm compute-node environment for Snakemake.
#
# sbatch --export=ALL can inherit a wrong HOME (e.g. RESULTS_ROOT), which breaks
# Python user-site lookup for ~/.local/lib/python3.12/site-packages/snakemake.
# Source this at the top of array job scripts before calling run_subject.sh.

_pipeline_resolve_python() {
  if [[ -n "${PIPELINE_PYTHON:-}" ]]; then
    return
  fi
  if command -v python3.12 >/dev/null 2>&1; then
    export PIPELINE_PYTHON=python3.12
  elif command -v python3 >/dev/null 2>&1; then
    export PIPELINE_PYTHON=python3
  else
    export PIPELINE_PYTHON=python3.12
  fi
}

_slurm_fix_user_env() {
  local real_home=""
  if [[ -n "${USER:-}" ]]; then
    real_home="$(getent passwd "${USER}" 2>/dev/null | cut -d: -f6 || true)"
  fi
  if [[ -z "${real_home}" || ! -d "${real_home}" ]]; then
    # Fallback when getent is unavailable (e.g. some batch nodes).
    if [[ -n "${HOME:-}" && -d "${HOME}/.local/lib/python3.12/site-packages/snakemake" ]]; then
      real_home="${HOME}"
    elif [[ -n "${USER:-}" && -d "$(eval echo "~${USER}")/.local" ]]; then
      real_home="$(eval echo "~${USER}")"
    fi
  fi
  if [[ -d "${real_home}" ]]; then
    export HOME="${real_home}"
  fi
  local _inherited_path="${PATH:-}"
  export PATH="${HOME}/.local/bin:${HOME}/bin:/usr/local/bin:/usr/bin:/bin"
  if ! command -v snakemake >/dev/null 2>&1 && [[ -n "${_inherited_path}" ]]; then
    export PATH="${PATH}:${_inherited_path}"
  fi
  # Do not put ~/.local/lib on PYTHONPATH. Those entries are searched before
  # the standard library, so a pip "argparse" backport hides BooleanOptionalAction
  # and Snakemake will not start. HOME is already the real home, so site.py
  # finds the user site after the standard library.
}

_slurm_fix_user_env
_pipeline_resolve_python
