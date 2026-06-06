"""
qsiprep.smk — Step 1: BIDS DWI → preprocessed QSIPrep derivatives.

Mirrors subject.sh::run_qsiprep. The rule's "output" is a sentinel flag
because QSIPrep writes a directory tree (one subject, one HTML report, lots
of NIfTI files). The flag is touched only after apptainer returns 0.

SDC behavior (per subject, evaluated when the rule fires):
  - QSIPREP_FMAP_RETRY=1            -> --ignore fieldmaps --use-syn-sdc warn
  - BIDS has fmap                   -> measured fmaps, no SyN flag
  - No fmap + QSIPREP_USE_SYN_SDC=1 -> --use-syn-sdc warn
  - No fmap, no opt-in              -> no SDC
"""

def _qsiprep_sdc_args(subject: str) -> str:
    cfg = config["qsiprep"]
    if cfg.get("fmap_retry"):
        return "--ignore fieldmaps --use-syn-sdc warn"
    if has_fmap(subject):
        return ""
    if cfg.get("use_syn_sdc"):
        return "--use-syn-sdc warn"
    return ""


rule qsiprep:
    """Run QSIPrep on one subject; touch a sentinel on success."""
    input:
        bids_subject = lambda wc: str(BIDS_DIR / f"sub-{wc.sid}"),
    output:
        flag = touch(str(FLAGS_DIR / "qsiprep.sub-{sid}.done")),
    log:
        str(LOGS_DIR / "qsiprep.sub-{sid}.log"),
    threads: stage_threads("qsiprep")
    resources: **stage_resources("qsiprep")
    params:
        bids_dir      = str(BIDS_DIR),
        qsiprep_out   = str(QSIPREP_OUT),
        work_root     = str(WORK_QSIPREP_DIR),
        fs_license    = str(FS_LICENSE),
        tflow         = str(TEMPLATEFLOW_HOME),
        container     = str(CONTAINERS["qsiprep"]),
        omp_nthreads  = lambda wc: stage_threads("qsiprep"),
        output_res    = config["qsiprep"]["output_resolution"],
        skip_validate = "--skip-bids-validation" if config["qsiprep"].get("skip_bids_validation", True) else "",
        sdc_args      = lambda wc: _qsiprep_sdc_args(wc.sid),
    shell:
        r"""
        set -euo pipefail
        work_dir="{params.work_root}/_work_qsiprep_{wildcards.sid}"
        rm -rf "$work_dir"
        mkdir -p "$work_dir" "{params.qsiprep_out}"

        echo "=== QSIPrep sub-{wildcards.sid} (SDC: '{params.sdc_args}') ===" >&2

        apptainer run --cleanenv --containall \
            -B "{params.bids_dir}":/bids_input:ro \
            -B "{params.qsiprep_out}":/output \
            -B "$work_dir":/work \
            -B "{params.fs_license}":/opt/freesurfer/license.txt:ro \
            -B "{params.tflow}":/templateflow \
            --env "TEMPLATEFLOW_HOME=/templateflow" \
            "{params.container}" \
            /bids_input /output participant \
            --participant-label "{wildcards.sid}" \
            --fs-license-file /opt/freesurfer/license.txt \
            --work-dir /work \
            --output-resolution {params.output_res} \
            --nthreads {threads} \
            --omp-nthreads {params.omp_nthreads} \
            {params.skip_validate} \
            {params.sdc_args} \
            &> {log}

        rm -rf "$work_dir"
        """
