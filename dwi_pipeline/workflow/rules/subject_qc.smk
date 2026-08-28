"""
subject_qc.smk — Unified HTML QC dashboard aggregating Steps 1–5.
"""

SUBJECT_QC_HTML_PATTERN = f"{RESULTS_ROOT}/qc/sub-{{subject}}/subject_qc.html"
SUBJECT_QC_JSON_PATTERN = f"{RESULTS_ROOT}/qc/sub-{{subject}}/subject_qc.json"
RENDER_SUBJECT_QC = DWI_PIPELINE_DIR / "scripts" / "render_subject_qc.py"

QC_CFG = config.get("qc", {})
SUBJECT_QC_ENABLED = bool(QC_CFG.get("enabled", True)) and bool(QC_CFG.get("subject_html", True))


def subject_qc_html(subject: str) -> str:
    return SUBJECT_QC_HTML_PATTERN.format(subject=subject)


def subject_qc_json(subject: str) -> str:
    return SUBJECT_QC_JSON_PATTERN.format(subject=subject)


def subject_qc_upstream(subject: str) -> str:
    """Run QC after the last enabled pipeline stage for this subject."""
    if NODESTRENGTH_CFG.get("enabled", True) and CONNECTOME_CFG.get("enabled", True):
        return nodestrength_strength_csv(subject)
    if disconnectome_enabled_for(subject):
        if DISCONNECTOME_QC_HTML:
            return disconnectome_qc_html(subject)
        return disconnectome_json(subject)
    if CONNECTOME_CFG.get("enabled", True):
        return connectome_matrix(subject)
    if RECON_CFG.get("enabled", True):
        return qsirecon_marker(subject)
    return qsiprep_marker(subject)


rule subject_qc:
    input:
        upstream=lambda wc: subject_qc_upstream(wc.subject),
    output:
        html=SUBJECT_QC_HTML_PATTERN,
        json=SUBJECT_QC_JSON_PATTERN,
    log:
        f"{RESULTS_ROOT}/logs/sub-{{subject}}_subject_qc.log",
    shell:
        r"""
        exec > {log} 2>&1
        set -euo pipefail
        {PIPELINE_PYTHON} "{RENDER_SUBJECT_QC}" \
          --results-root "{RESULTS_ROOT}" \
          --subject "{wildcards.subject}" \
          --html-out "{output.html}" \
          --json-out "{output.json}"
        [[ -f "{output.html}" ]] || _pipeline_fail "subject_qc" "missing {output.html}"
        echo "Subject QC dashboard: OK — {output.html}"
        """
