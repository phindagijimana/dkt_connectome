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
  export PATH="${HOME}/.local/bin:${HOME}/bin:/usr/local/bin:/usr/bin:/bin"
  local py_site="${HOME}/.local/lib/python3.12/site-packages"
  if [[ -d "${py_site}/snakemake" ]]; then
    case ":${PYTHONPATH:-}:" in
      *:"${py_site}":*) ;;
      *)
        if [[ -n "${PYTHONPATH:-}" ]]; then
          export PYTHONPATH="${py_site}:${PYTHONPATH}"
        else
          export PYTHONPATH="${py_site}"
        fi
        ;;
    esac
  fi
}

_slurm_fix_user_env
_pipeline_resolve_python
