#!/usr/bin/env bash
# Resolve Rscript for Paper 2B LQT (host, Lmod, or Apptainer rocker).
#
# Usage: source ensure_r_for_lqt.sh
# Defines: paper2b_R, paper2b_Rscript (functions), exports R_LIBS_USER when using container.

_paper2b_r_setup_done="${_paper2b_r_setup_done:-}"
if [[ -n "${_paper2b_r_setup_done}" ]]; then
    return 0 2>/dev/null || exit 0
fi
_paper2b_r_setup_done=1

EXPERIMENT_ROOT="${EXPERIMENT_ROOT:-/mnt/nfs/Gugger_Lab/NIR/dwi_test_TBI_experiment}"
export R_LIBS_USER="${R_LIBS_USER:-${EXPERIMENT_ROOT}/lqt_batch/r_library}"
mkdir -p "${R_LIBS_USER}"
# Large Figshare zips: use local temp for download buffers when possible.
export TMPDIR="${TMPDIR:-/tmp}"
export APPTAINERENV_TMPDIR="${APPTAINERENV_TMPDIR:-/tmp}"

if [[ -f /etc/profile.d/modules.sh ]]; then
    # shellcheck disable=SC1091
    source /etc/profile.d/modules.sh
elif [[ -f /usr/share/Modules/init/bash ]]; then
    # shellcheck disable=SC1091
    source /usr/share/Modules/init/bash
fi

if [[ -n "${LQT_R_MODULE:-}" ]]; then
    module load "${LQT_R_MODULE}" 2>/dev/null || true
fi

if ! command -v Rscript >/dev/null 2>&1; then
    for mod in R R/4.4 R/4.3 R/4.3.3 r gnu-r; do
        module load "${mod}" 2>/dev/null || continue
        command -v Rscript >/dev/null && break
    done
fi

# geospatial includes GSL + geospatial deps required by jdwor/LQT (gsl, RNiftyReg, etc.)
LQT_R_IMAGE="${LQT_R_IMAGE:-docker://rocker/geospatial:4.3.3}"
_APPTAINER=""
command -v apptainer >/dev/null && _APPTAINER=apptainer
command -v singularity >/dev/null && [[ -z "${_APPTAINER}" ]] && _APPTAINER=singularity

paper2b_R() {
    if command -v R >/dev/null 2>&1; then
        R "$@"
        return $?
    fi
    if [[ -n "${_APPTAINER}" ]]; then
        "${_APPTAINER}" exec --bind /mnt/nfs:/mnt/nfs \
            --env "R_LIBS_USER=${R_LIBS_USER}" \
            --env "R_LIBS=${R_LIBS_USER}" \
            --env "TMPDIR=${TMPDIR}" \
            --env "LD_LIBRARY_PATH=/usr/lib/x86_64-linux-gnu:/lib/x86_64-linux-gnu" \
            "${LQT_R_IMAGE}" R "$@"
        return $?
    fi
    echo "ERROR: no R or Apptainer (${LQT_R_IMAGE})" >&2
    return 127
}

paper2b_Rscript() {
    if command -v Rscript >/dev/null 2>&1; then
        Rscript "$@"
        return $?
    fi
    if [[ -n "${_APPTAINER}" ]]; then
        "${_APPTAINER}" exec --bind /mnt/nfs:/mnt/nfs \
            --env "R_LIBS_USER=${R_LIBS_USER}" \
            --env "R_LIBS=${R_LIBS_USER}" \
            --env "TMPDIR=${TMPDIR}" \
            --env "LD_LIBRARY_PATH=/usr/lib/x86_64-linux-gnu:/lib/x86_64-linux-gnu" \
            "${LQT_R_IMAGE}" Rscript "$@"
        return $?
    fi
    echo "ERROR: no Rscript or Apptainer" >&2
    return 127
}

export -f paper2b_R paper2b_Rscript 2>/dev/null || true

if command -v Rscript >/dev/null 2>&1; then
    echo "R: host $(command -v Rscript)"
elif [[ -n "${_APPTAINER}" ]]; then
    echo "R: ${_APPTAINER} ${LQT_R_IMAGE} (R_LIBS_USER=${R_LIBS_USER})"
else
    echo "WARNING: R not found; install module or Apptainer" >&2
fi
