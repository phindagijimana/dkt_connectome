"""
qsirecon.smk — Step 3: QSIPrep derivatives (+ FreeSurfer) → QSIRecon outputs.

The HSVS spec needs the FreeSurfer subjects dir; FAST spec does not. If
`config['run_recon']` is true, we wire the recon rule's aparc+aseg as an
input so the DAG respects the dependency. If it's false, we still mount the
FS dir at runtime *iff* it happens to exist (matches subject.sh behaviour).
"""

def _qsirecon_inputs(wc):
    inputs = {"qsiprep_flag": qsiprep_flag(wc.sid)}
    if RUN_RECON:
        inputs["aparc"] = recon_target(wc.sid)
    return inputs


rule qsirecon:
    """QSIRecon ACT (SS3T) tractography & connectome; sentinel on success."""
    input:
        unpack(_qsirecon_inputs),
    output:
        flag = touch(str(FLAGS_DIR / "qsirecon.sub-{sid}.done")),
    log:
        str(LOGS_DIR / "qsirecon.sub-{sid}.log"),
    benchmark:
        stage_benchmark("qsirecon")
    threads: stage_threads("qsirecon")
    resources: **stage_resources("qsirecon")
    retries: stage_retries("qsirecon")
    params:
        qsiprep_out  = str(QSIPREP_OUT),
        qsirecon_out = str(QSIRECON_OUT),
        work_root    = str(WORK_QSIRECON_DIR),
        fs_dir       = str(RECON_OUT),
        fs_license   = str(FS_LICENSE),
        tflow        = str(TEMPLATEFLOW_HOME),
        container    = str(CONTAINERS["qsirecon"]),
        # QSIRECON_SPEC (defined in plugins/_common/common.smk) honours the
        # `qsirecon.multi_shell` toggle: true swaps the single-shell SS3T+ACT
        # default for the multi-shell MSMT+ACT one. An explicit `qsirecon.spec`
        # in config wins over both.
        spec         = QSIRECON_SPEC,
        atlases      = " ".join(config["qsirecon"].get("atlases", []) or []),
        output_res   = config["qsiprep"]["output_resolution"],
    shell:
        r"""
        set -euo pipefail
        work_dir="{params.work_root}/_work_qsirecon_{wildcards.sid}"
        rm -rf "$work_dir"
        mkdir -p "$work_dir" "{params.qsirecon_out}/derivatives"

        fs_args=()
        fs_binds=()
        if [[ -d "{params.fs_dir}" ]]; then
            fs_binds+=( -B "{params.fs_dir}":/freesurfer:ro )
            fs_args+=( --fs-subjects-dir /freesurfer )
            echo "QSIRecon: mounting FS dir {params.fs_dir}" | tee -a {log} >&2
        else
            if [[ "{params.spec}" == *hsvs* ]]; then
                echo "ERROR: spec {params.spec} requires FreeSurfer dir but {params.fs_dir} missing." \
                    | tee -a {log} >&2
                exit 1
            fi
        fi

        atlas_args=()
        if [[ -n "{params.atlases}" ]]; then
            atlas_args+=( --atlases {params.atlases} )
        fi

        echo "=== QSIRecon ({params.spec}): sub-{wildcards.sid} ===" | tee -a {log} >&2
        apptainer run --cleanenv --containall \
            -B "{params.qsiprep_out}":/qsiprep_input:ro \
            -B "{params.qsirecon_out}":/output \
            -B "$work_dir":/work \
            "${{fs_binds[@]}}" \
            -B "{params.fs_license}":/opt/freesurfer/license.txt:ro \
            -B "{params.tflow}":/templateflow \
            --env "TEMPLATEFLOW_HOME=/templateflow" \
            "{params.container}" \
            /qsiprep_input /output participant \
            --input-type qsiprep \
            --recon-spec "{params.spec}" \
            --participant-label "{wildcards.sid}" \
            --fs-license-file /opt/freesurfer/license.txt \
            --work-dir /work \
            --nthreads {threads} \
            --omp-nthreads {threads} \
            --output-resolution {params.output_res} \
            "${{fs_args[@]}}" \
            "${{atlas_args[@]}}" \
            &>> {log}

        rm -rf "$work_dir"
        """
