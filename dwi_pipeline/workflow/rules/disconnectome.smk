"""
disconnectome.smk — Step 4.5 plugin: lesion-aware disconnectome (Options A/B/C).

Runs only when a lesion mask was prepared in Step 1.5 and Step 4 produced a
DKT connectome (78 nodes). Invokes scripts/run_disconnectome.py on the host.
"""

DISCONNECTOME_JSON_PATTERN = f"{CONNECTOME_OUT}/sub-{{subject}}/disconnectome/disconnectome.json"
DISCONNECTOME_MATRIX_PATTERN = f"{CONNECTOME_OUT}/sub-{{subject}}/disconnectome/disconnection_matrix.csv"
DISCONNECTOME_DKT_CONNECTOME = f"{CONNECTOME_OUT}/sub-{{subject}}/dkt_connectome.csv"

RUN_DISCONNECTOME = DWI_PIPELINE_DIR / "scripts" / "run_disconnectome.py"

DISCONNECTOME_CFG = config.get("disconnectome", {})
DISCONNECTOME_ENABLED = bool(DISCONNECTOME_CFG.get("enabled", True))
DISCONNECTOME_CORE_ONLY = bool(DISCONNECTOME_CFG.get("core_only", False))
DISCONNECTOME_ERODE = int(DISCONNECTOME_CFG.get("lesion_erode_voxels", 0))
DISCONNECTOME_SPARED = str(DISCONNECTOME_CFG.get("disconnection_spared", "C")).upper()
DISCONNECTOME_WEIGHTING = str(
    DISCONNECTOME_CFG.get("weighting") or CONNECTOME_CFG.get("weighting", "count")
).lower()
DISCONNECTOME_RUN_A = bool(DISCONNECTOME_CFG.get("option_a", True))
DISCONNECTOME_RUN_B = bool(DISCONNECTOME_CFG.get("option_b", True))
DISCONNECTOME_RUN_C = bool(DISCONNECTOME_CFG.get("option_c", True))
DISCONNECTOME_QC_HTML_PATTERN = f"{CONNECTOME_OUT}/sub-{{subject}}/disconnectome/disconnectome_qc.html"
RENDER_DISCONNECTOME_QC = DWI_PIPELINE_DIR / "scripts" / "render_disconnectome_qc.py"
DISCONNECTOME_QC_HTML = bool(DISCONNECTOME_CFG.get("qc_html", True))


def disconnectome_json(subject: str) -> str:
    return DISCONNECTOME_JSON_PATTERN.format(subject=subject)


def disconnectome_qc_html(subject: str) -> str:
    return DISCONNECTOME_QC_HTML_PATTERN.format(subject=subject)


def disconnectome_enabled_for(subject: str) -> bool:
    if not DISCONNECTOME_ENABLED or not CONNECTOME_CFG.get("enabled", True):
        return False
    if not subject_has_lesion_mask(subject):
        return False
    if resolved_parcellation(subject) != "dkt":
        return False
    return True


def _disconnectome_extra_args() -> str:
    parts: list[str] = []
    if DISCONNECTOME_CORE_ONLY:
        parts.append("--core-only")
    if DISCONNECTOME_ERODE > 0:
        parts.append(f"--lesion-erode-voxels {DISCONNECTOME_ERODE}")
    parts.append(f"--connectome-weighting {DISCONNECTOME_WEIGHTING}")
    parts.append(f"--disconnection-spared {DISCONNECTOME_SPARED}")
    if not DISCONNECTOME_RUN_A:
        parts.append("--skip-option-a")
    if not DISCONNECTOME_RUN_B:
        parts.append("--skip-option-b")
    if not DISCONNECTOME_RUN_C:
        parts.append("--skip-option-c")
    return " ".join(parts)


rule disconnectome:
    input:
        connectome=DISCONNECTOME_DKT_CONNECTOME,
        mask_prepared=lambda wc: inpaint_paths(wc.subject)["mask_prepared"],
        mask_json=lambda wc: inpaint_paths(wc.subject)["mask_json"],
        qsirecon_marker=lambda wc: qsirecon_marker(wc.subject),
    output:
        json=DISCONNECTOME_JSON_PATTERN,
        matrix=DISCONNECTOME_MATRIX_PATTERN,
    threads: 4
    log:
        f"{RESULTS_ROOT}/logs/sub-{{subject}}_disconnectome.log",
    params:
        session=lambda wc: resolve_session(wc.subject),
        extra=_disconnectome_extra_args(),
    shell:
        r"""
        exec > {log} 2>&1
        set -euo pipefail
        source {COMMON_SH}

        echo "=== Disconnectome (Step 4.5): sub-{wildcards.subject} ses-{params.session} ==="
        python3 "{RUN_DISCONNECTOME}" \
          --results-root "{RESULTS_ROOT}" \
          --subject "{wildcards.subject}" \
          --session "{params.session}" \
          --container "{CONTAINER_CONNECTOME}" \
          --lut "{CONNECTOME_LUT_DKT}" \
          {params.extra}

        [[ -f "{output.json}" ]] || _pipeline_fail "disconnectome" "missing {output.json}"
        [[ -f "{output.matrix}" ]] || _pipeline_fail "disconnectome" "missing {output.matrix}"
        echo "Disconnectome: OK — {output.matrix}"
        """


rule disconnectome_qc:
    input:
        json=DISCONNECTOME_JSON_PATTERN,
    output:
        html=DISCONNECTOME_QC_HTML_PATTERN,
    log:
        f"{RESULTS_ROOT}/logs/sub-{{subject}}_disconnectome_qc.log",
    shell:
        r"""
        exec > {log} 2>&1
        set -euo pipefail
        python3 "{RENDER_DISCONNECTOME_QC}" \
          --disconnectome-dir "$(dirname "{input.json}")" \
          --html-out "{output.html}"
        [[ -f "{output.html}" ]] || _pipeline_fail "disconnectome_qc" "missing {output.html}"
        echo "Disconnectome QC: OK — {output.html}"
        """
