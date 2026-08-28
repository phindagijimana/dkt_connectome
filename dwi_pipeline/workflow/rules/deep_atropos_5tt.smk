"""Step 3.5a: Deep Atropos segmentation → base_5tt_native.mif."""

DEEP_ATROPOS_5TT_PATTERN = f"{DEEP_ATROPOS_OUT}/sub-{{subject}}/base_5tt_native.mif"
DEEP_ATROPOS_JSON_PATTERN = f"{DEEP_ATROPOS_OUT}/sub-{{subject}}/deep_atropos_5tt.json"


def deep_atropos_base_5tt(subject: str) -> str:
    return DEEP_ATROPOS_5TT_PATTERN.format(subject=subject)


def deep_atropos_products(subject: str) -> list[str]:
    if ACT_MODE != "lesion-aware" or ACT_FIVE_TT_SOURCE != "deep-atropos-native":
        return []
    return [
        DEEP_ATROPOS_5TT_PATTERN.format(subject=subject),
        DEEP_ATROPOS_JSON_PATTERN.format(subject=subject),
    ]


if ACT_FIVE_TT_SOURCE == "deep-atropos-native":

    rule deep_atropos_5tt:
        input:
            t1w=lambda wc: _bids_t1w_for(wc.subject, resolve_session(wc.subject)),
            segmentation=DEEP_ATROPOS_SEG_PATTERN,
        output:
            five_tt=DEEP_ATROPOS_5TT_PATTERN,
            provenance=DEEP_ATROPOS_JSON_PATTERN,
        log:
            f"{RESULTS_ROOT}/logs/sub-{{subject}}_deep_atropos_5tt.log",
        params:
            outdir=lambda wc: f"{DEEP_ATROPOS_OUT}/sub-{wc.subject}",
        shell:
            r"""
            exec > {log} 2>&1
            set -euo pipefail
            [[ -f "{input.segmentation}" ]] || {{
              echo "ERROR: missing Deep Atropos segmentation: {input.segmentation}" >&2
              exit 1
            }}
            mkdir -p "{params.outdir}"

            apptainer run --cleanenv --containall \
              --env "LD_LIBRARY_PATH=/opt/mrtrix3-latest/lib" \
              -B "$(dirname "{input.t1w}")":/bids_t1w:ro \
              -B "$(dirname "{input.segmentation}")":/seg:ro \
              -B "{params.outdir}":/out \
              -B "{DWI_PIPELINE_DIR}/scripts/convert_deep_atropos_to_5tt.py":/opt/deep_atropos/convert_deep_atropos_to_5tt.py:ro \
              "{CONTAINER_DEEP_ATROPOS}" \
              --t1w "/bids_t1w/$(basename "{input.t1w}")" \
              --segmentation "/seg/$(basename "{input.segmentation}")" \
              --outdir /out
            """
