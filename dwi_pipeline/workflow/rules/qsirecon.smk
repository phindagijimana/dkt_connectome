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
        # Prefer FS_SUBJECTS_DIR (same as subject.sh); falls back to RECON_OUT via common.smk.
        if [[ -d "{FS_SUBJECTS_DIR}" ]]; then
          recon_binds+=( -B "{FS_SUBJECTS_DIR}":/freesurfer:ro )
          recon_xtra+=( --fs-subjects-dir /freesurfer )
          echo "QSIRecon: mounting FreeSurfer subjects dir {FS_SUBJECTS_DIR}"
          [[ -d "{FS_SUBJECTS_DIR}/sub-${{SUBJECT}}" ]] || _pipeline_fail "qsirecon" \
            "HSVS needs {FS_SUBJECTS_DIR}/sub-${{SUBJECT}} (run Step 2 recon first)"
        elif [[ "{QSIRECON_SPEC}" == *hsvs* ]]; then
          _pipeline_fail "qsirecon" "spec {QSIRECON_SPEC} needs a FreeSurfer subjects dir, but {FS_SUBJECTS_DIR} does not exist"
        fi

        echo "=== QSIRecon ({QSIRECON_SPEC}): sub-${{SUBJECT}} ==="
        # Wipe prior/partial outputs for this subject so a resume replaces them
        # instead of mixing old workdirs or half-written derivatives.
        rm -rf "{params.work}"
        find "{QSIRECON_OUT}" -mindepth 1 \( -type d -name "sub-${{SUBJECT}}" \) \
          -prune -exec rm -rf {{}} + 2>/dev/null || true
        rm -f "{MARKERS_DIR}/sub-${{SUBJECT}}/qsirecon.done"
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
          "${{recon_xtra[@]}}" \
          {params.atlas_args}

        rm -rf "{params.work}"
        mkdir -p "$(dirname "{output.marker}")"

        if [[ "{ACT_MODE}" == "standard" && "{ANATOMY_MITIGATION_BACKEND}" != "none" ]]; then
          staged_dir="{TRACTOGRAPHY_OUT}/sub-${{SUBJECT}}"
          mkdir -p "${{staged_dir}}"
          tck="$(_strict_find_one "qsirecon/stage-ifod2" \
            find -L "{QSIRECON_OUT}" -type f -path "*sub-${{SUBJECT}}*" \
              \( -name '*model-ifod2_streamlines.tck' -o -name '*model-ifod2_streamlines.tck.gz' \))"
          staged_tck="${{staged_dir}}/model-ifod2_streamlines.tck"
          if [[ "${{tck}}" == *.tck.gz ]]; then
            gunzip -c "${{tck}}" > "${{staged_tck}}"
          else
            cp -f "${{tck}}" "${{staged_tck}}"
          fi
          sift2="$(_find_sift2_weights "{QSIRECON_OUT}" "" "${{SUBJECT}}")"
          cp -f "${{sift2}}" "${{staged_dir}}/model-ifod2_sift2weights.csv"
          echo "QSIRecon: staged iFOD2 tractogram for {ANATOMY_MITIGATION_BACKEND} -> ${{staged_tck}}"
        fi

        touch "{output.marker}"
        echo "QSIRecon: OK"
        """
