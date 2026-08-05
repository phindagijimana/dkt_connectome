"""
qsirecon.smk — Step 3 plugin: QSIPrep derivatives -> tractography (MRtrix SS3T
CSD + ACT, HSVS 5TT using Step 2's FreeSurfer subjects dir by default).
"""

QSIRECON_SPEC = str(QSIRECON_CFG.get("spec", "mrtrix_singleshell_ss3t_ACT-hsvs"))
QSIRECON_ATLASES = QSIRECON_CFG.get("atlases", ["4S156Parcels"]) or []

QSIRECON_MARKER_PATTERN = f"{MARKERS_DIR}/sub-{{subject}}/qsirecon.done"


def qsirecon_marker(subject: str) -> str:
    return QSIRECON_MARKER_PATTERN.format(subject=subject)


def qsirecon_recon_input(subject: str):
    """Step 3 needs Step 2's output whenever the spec requires FreeSurfer
    (e.g. any *-hsvs spec); otherwise it has no upstream dependency here."""
    if "hsvs" in QSIRECON_SPEC and RECON_CFG.get("enabled", True):
        return recon_aparc(subject)
    return []


rule qsirecon:
    input:
        fs=lambda wc: qsirecon_recon_input(wc.subject),
        qsiprep_marker=lambda wc: qsiprep_marker(wc.subject),
    output:
        marker=QSIRECON_MARKER_PATTERN,
    threads: NTHREADS
    log:
        f"{RESULTS_ROOT}/logs/sub-{{subject}}_qsirecon.log",
    params:
        work=lambda wc: f"{INTER_QSI}/_work_qsirecon_{wc.subject}",
        atlas_args=(f"--atlases {' '.join(QSIRECON_ATLASES)}" if QSIRECON_ATLASES else ""),
    shell:
        r"""
        exec > {log} 2>&1
        set -euo pipefail
        source {COMMON_SH}
        SUBJECT="{wildcards.subject}"

        recon_binds=()
        recon_xtra=()
        if [[ -d "{RECON_OUT}" ]]; then
          recon_binds+=( -B "{RECON_OUT}":/freesurfer:ro )
          recon_xtra+=( --fs-subjects-dir /freesurfer )
          echo "QSIRecon: mounting FreeSurfer subjects dir {RECON_OUT}"
        elif [[ "{QSIRECON_SPEC}" == *hsvs* ]]; then
          _pipeline_fail "qsirecon" "spec {QSIRECON_SPEC} needs a FreeSurfer subjects dir, but {RECON_OUT} does not exist"
        fi

        echo "=== QSIRecon ({QSIRECON_SPEC}): sub-${{SUBJECT}} ==="
        rm -rf "{params.work}"
        mkdir -p "{params.work}" "{QSIRECON_OUT}/derivatives"

        apptainer run --cleanenv --containall \
          -B "{QSIPREP_OUT}":/qsiprep_input:ro \
          -B "{QSIRECON_OUT}":/output \
          -B "{params.work}":/work \
          "${{recon_binds[@]}}" \
          -B "{FS_LICENSE}":/opt/freesurfer/license.txt:ro \
          -B "{TEMPLATEFLOW_HOME}":/templateflow \
          --env "TEMPLATEFLOW_HOME=/templateflow" \
          "{CONTAINER_QSIRECON}" \
          /qsiprep_input /output participant \
          --input-type qsiprep \
          --recon-spec "{QSIRECON_SPEC}" \
          --participant-label "${{SUBJECT}}" \
          --fs-license-file /opt/freesurfer/license.txt \
          --work-dir /work \
          --nthreads {NTHREADS} \
          --omp-nthreads {OMP_NTHREADS} \
          --output-resolution {OUTPUT_RES} \
          {params.atlas_args}

        rm -rf "{params.work}"
        mkdir -p "$(dirname "{output.marker}")"
        touch "{output.marker}"
        echo "QSIRecon: OK"
        """
