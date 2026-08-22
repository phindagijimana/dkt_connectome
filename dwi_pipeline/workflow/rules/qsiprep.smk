"""
qsiprep.smk — Step 1 plugin: denoise/correct DWI, register to T1w.

Supports dwi-select (default), static --bids-filter, and
--syn / --fmap-retry / --no-sdc, matching subject.sh's QSIPrep behaviour.
"""

QSIPREP_MARKER_PATTERN = f"{MARKERS_DIR}/sub-{{subject}}/qsiprep.done"


def qsiprep_marker(subject: str) -> str:
    return QSIPREP_MARKER_PATTERN.format(subject=subject)


rule qsiprep:
    output:
        marker=QSIPREP_MARKER_PATTERN,
    threads: NTHREADS
    log:
        f"{RESULTS_ROOT}/logs/sub-{{subject}}_qsiprep.log",
    params:
        filter_cache=lambda wc: f"{INTER_QSP}/bids_filter_sub-{wc.subject}.json",
        work=lambda wc: f"{INTER_QSP}/_work_qsiprep_{wc.subject}",
        bids_filter=QSIPREP_BIDS_FILTER,
        dwi_select_json=DWI_SELECT_JSON if DWI_SELECT_ENABLED else "",
        session=str(RECON_CFG.get("session") or ""),
    shell:
        r"""
        exec > {log} 2>&1
        set -euo pipefail
        source {COMMON_SH}
        SUBJECT="{wildcards.subject}"
        session_label="{params.session}"
        session_args=()
        [[ -n "${{session_label}}" ]] && session_args+=(--session "${{session_label}}")

        echo "=== QSIPrep (ACT pipeline): sub-${{SUBJECT}} ==="
        rm -rf "{params.work}"
        mkdir -p "{params.work}" "{QSIPREP_OUT}" "{TEMPLATEFLOW_HOME}"

        xtra=()
        filter_binds=()
        if [[ -n "{params.bids_filter}" ]]; then
          [[ -f "{params.bids_filter}" ]] || _pipeline_fail "bids-filter" \
            "missing static bids filter: {params.bids_filter}"
          python3 "{BUILD_BIDS_FILTER}" --bids-dir "{BIDS_DIR}" --subject "${{SUBJECT}}" \
            --static-filter "{params.bids_filter}" --output "{params.filter_cache}" \
            "${{session_args[@]}}"
          if python3 -c "import json,sys; sys.exit(0 if 'fmap' in json.load(open('{params.filter_cache}')) else 1)"; then
            has_fmap=1
          else
            has_fmap=0
          fi
          filter_binds+=( -B "{params.filter_cache}":/bids_filter.json:ro )
          xtra+=( --bids-filter-file /bids_filter.json )
          echo "QSIPrep: static bids filter {params.bids_filter} (session=${{session_label:-all}})"
        elif [[ -n "{params.dwi_select_json}" ]]; then
          python3 "{BUILD_BIDS_FILTER}" --bids-dir "{BIDS_DIR}" --subject "${{SUBJECT}}" \
            --select-json "{params.dwi_select_json}" --output "{params.filter_cache}" \
            "${{session_args[@]}}"
          if python3 -c "import json,sys; sys.exit(0 if 'fmap' in json.load(open('{params.filter_cache}')) else 1)"; then
            has_fmap=1
          else
            has_fmap=0
          fi
          filter_binds+=( -B "{params.filter_cache}":/bids_filter.json:ro )
          xtra+=( --bids-filter-file /bids_filter.json )
          echo "QSIPrep: dwi-select {params.dwi_select_json} (session=${{session_label:-all}}) -> {params.filter_cache}"
        else
          has_fmap=0
        fi

        if [[ "{QSIPREP_FMAP_RETRY}" == "True" ]]; then
          xtra+=(--ignore fieldmaps --use-syn-sdc error)
          echo "QSIPrep: sub-${{SUBJECT}}: explicit fmap_retry -> SyN SDC"
        elif [[ "${{has_fmap}}" == "1" ]]; then
          echo "QSIPrep: sub-${{SUBJECT}}: filter includes fmap -> measured SDC"
        elif [[ "{QSIPREP_USE_SYN_SDC}" == "True" ]]; then
          xtra+=(--use-syn-sdc error)
          echo "QSIPrep: sub-${{SUBJECT}}: explicit use_syn_sdc -> SyN SDC"
        elif [[ "{QSIPREP_NO_SDC}" == "True" ]]; then
          echo "QSIPrep: sub-${{SUBJECT}}: explicit no_sdc -> NO SDC (legacy no-fieldmap GE runs)"
        else
          _pipeline_fail "QSIPrep/SDC" "no distortion correction configured for sub-${{SUBJECT}}" \
            "Measured SDC requires fmaps in the dwi-select filter (IntendedFor -> target DWI)." \
            "Or set qsiprep.use_syn_sdc / qsiprep.fmap_retry / qsiprep.no_sdc in config" \
            "(equivalents: --syn, --fmap-retry, --no-sdc; env: QSIPREP_USE_SYN_SDC, QSIPREP_FMAP_RETRY, QSIPREP_NO_SDC)."
        fi

        apptainer run --cleanenv --containall \
          -B "{BIDS_DIR}":/bids_input:ro \
          -B "{QSIPREP_OUT}":/output \
          -B "{params.work}":/work \
          -B "{FS_LICENSE}":/opt/freesurfer/license.txt:ro \
          -B "{TEMPLATEFLOW_HOME}":/templateflow \
          "${{filter_binds[@]}}" \
          --env "TEMPLATEFLOW_HOME=/templateflow" \
          "{CONTAINER_QSIPREP}" \
          /bids_input /output participant \
          --participant-label "${{SUBJECT}}" \
          --fs-license-file /opt/freesurfer/license.txt \
          --work-dir /work \
          --output-resolution {OUTPUT_RES} \
          --nthreads {NTHREADS} \
          --omp-nthreads {OMP_NTHREADS} \
          --skip-bids-validation \
          "${{xtra[@]}}"

        rm -rf "{params.work}"
        mkdir -p "$(dirname "{output.marker}")"
        touch "{output.marker}"
        echo "QSIPrep: OK"
        """
