#!/usr/bin/env bash
# Resolve ANTs for Paper 2B / LQT staging (host PATH or qsirecon.sif via Apptainer).
#
# Usage: source ensure_pipeline_ants.sh
# Then call pipeline_antsApplyTransforms (same args as antsApplyTransforms).

_ensure_pipeline_ants_loaded="${_ensure_pipeline_ants_loaded:-}"
if [[ -n "${_ensure_pipeline_ants_loaded}" ]]; then
    return 0 2>/dev/null || exit 0
fi
_ensure_pipeline_ants_loaded=1

CONTAINER_QSIRECON="${CONTAINER_QSIRECON:-}"
if [[ -z "${CONTAINER_QSIRECON}" ]]; then
    for cand in \
        "/mnt/nfs/home/urmc-sh.rochester.edu/pndagiji/Documents/others/containers/qsirecon.sif" \
        "/mnt/nfs/home/URMC-SH/pndagiji/Documents/others/containers/qsirecon.sif"; do
        if [[ -f "${cand}" ]]; then
            CONTAINER_QSIRECON="${cand}"
            break
        fi
    done
fi

_APPTAINER=""
if command -v apptainer >/dev/null 2>&1; then
    _APPTAINER=apptainer
elif command -v singularity >/dev/null 2>&1; then
    _APPTAINER=singularity
fi

pipeline_antsApplyTransforms() {
    if command -v antsApplyTransforms >/dev/null 2>&1; then
        antsApplyTransforms "$@"
        return $?
    fi
    if [[ -n "${_APPTAINER}" && -f "${CONTAINER_QSIRECON:-}" ]]; then
        # Bind NFS roots used by TrackTBI experiments (read/write for outputs).
        "${_APPTAINER}" exec --bind /mnt/nfs:/mnt/nfs "${CONTAINER_QSIRECON}" \
            antsApplyTransforms "$@"
        return $?
    fi
    echo "ERROR: antsApplyTransforms not found and CONTAINER_QSIRECON unavailable (${CONTAINER_QSIRECON:-unset})" >&2
    return 127
}

export -f pipeline_antsApplyTransforms 2>/dev/null || true
export CONTAINER_QSIRECON
