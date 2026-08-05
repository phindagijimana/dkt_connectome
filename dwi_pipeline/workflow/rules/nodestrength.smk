"""
nodestrength.smk — Step 5 plugin: node strength / ENIGMA-style report.
Standalone `nodestrength` container (github.com/phindagijimana/dwi-AI),
atlas-agnostic (auto-detects 78-node DKT vs 84-node DK from the connectome's
own shape). Auto-on whenever Step 4 ran.
"""

NODESTRENGTH_NO_REPORT = bool(NODESTRENGTH_CFG.get("no_report", False))
NODESTRENGTH_STRENGTH_ONLY = bool(NODESTRENGTH_CFG.get("strength_only", False))

NODESTRENGTH_CSV_PATTERN = f"{NODESTRENGTH_OUT}/strength/per_subject/sub-{{subject}}_strength.csv"


def nodestrength_strength_csv(subject: str) -> str:
    return NODESTRENGTH_CSV_PATTERN.format(subject=subject)


def nodestrength_report(subject: str) -> str:
    return f"{NODESTRENGTH_OUT}/reports/sub-{subject}/report.pdf"


rule nodestrength:
    input:
        matrix=lambda wc: connectome_matrix(wc.subject),
    output:
        # strength_csv is the file Snakemake uses to decide skip-vs-rerun.
        # report.pdf is also produced (unless no_report) but isn't declared
        # here -- its filename convention matches subject.sh's own
        # skip-if-exists check, verified explicitly in the shell block below.
        strength_csv=NODESTRENGTH_CSV_PATTERN,
    threads: 2
    log:
        f"{RESULTS_ROOT}/logs/sub-{{subject}}_nodestrength.log",
    params:
        report=lambda wc: nodestrength_report(wc.subject),
        strength_only_flag="--strength-only" if NODESTRENGTH_STRENGTH_ONLY else "",
        no_report_flag="--no-report" if NODESTRENGTH_NO_REPORT else "",
    shell:
        r"""
        exec > {log} 2>&1
        set -euo pipefail
        source {COMMON_SH}
        SUBJECT="{wildcards.subject}"

        echo "=== Node strength / ENIGMA report (Step 5): sub-${{SUBJECT}} ==="
        # Replace prior strength/report outputs for this subject (resume-safe)
        rm -f "{NODESTRENGTH_OUT}/strength/per_subject/sub-${{SUBJECT}}"_*
        rm -rf "{NODESTRENGTH_OUT}/reports/sub-${{SUBJECT}}"
        mkdir -p "{NODESTRENGTH_OUT}" "{NODESTRENGTH_OUT}/strength/per_subject"

        fs_bind=()
        fs_arg=""
        if [[ -d "{FS_SUBJECTS_DIR}" ]]; then
          fs_bind=(-B "{FS_SUBJECTS_DIR}:{FS_SUBJECTS_DIR}:ro")
          fs_arg="{FS_SUBJECTS_DIR}"
        fi

        apptainer run --cleanenv --containall \
          -B "{CONNECTOME_OUT}":"{CONNECTOME_OUT}":ro \
          "${{fs_bind[@]}}" \
          -B "{NODESTRENGTH_OUT}":"{NODESTRENGTH_OUT}" \
          "{CONTAINER_NODESTRENGTH}" \
          "{CONNECTOME_OUT}" "{NODESTRENGTH_OUT}" ${{fs_arg:+"${{fs_arg}}"}} \
          --include "${{SUBJECT}}" \
          {params.strength_only_flag} {params.no_report_flag}

        [[ -f "{output.strength_csv}" ]] || _pipeline_fail "nodestrength" \
          "nodestrength finished but {output.strength_csv} was not written"

        echo "Node strength: {output.strength_csv}"
        if [[ "{NODESTRENGTH_NO_REPORT}" == "True" ]]; then
          echo "Report: skipped (no_report=true)"
        else
          [[ -f "{params.report}" ]] || _pipeline_fail "nodestrength" "expected report at {params.report}"
          echo "Report: {params.report}"
        fi
        """
