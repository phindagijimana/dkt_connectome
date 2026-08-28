"""Step 3.2 (segmentation): resolve Deep Atropos segmentation (import symlink or ANTsPyNet)."""

DEEP_ATROPOS_SEG_PATTERN = f"{DEEP_ATROPOS_SEG_OUT}/sub-{{subject}}/desc-deepatropos_seg.nii.gz"
DEEP_ATROPOS_SEG_JSON_PATTERN = f"{DEEP_ATROPOS_SEG_OUT}/sub-{{subject}}/deep_atropos_seg.json"


def deep_atropos_seg_products(subject: str) -> list[str]:
    if ACT_MODE != "lesion-aware" or ACT_FIVE_TT_SOURCE != "deep-atropos-native":
        return []
    return [
        DEEP_ATROPOS_SEG_PATTERN.format(subject=subject),
        DEEP_ATROPOS_SEG_JSON_PATTERN.format(subject=subject),
    ]


if ACT_FIVE_TT_SOURCE == "deep-atropos-native":

    rule deep_atropos_seg:
        input:
            t1w=lambda wc: _bids_t1w_for(wc.subject, resolve_session(wc.subject)),
        output:
            seg=DEEP_ATROPOS_SEG_PATTERN,
            provenance=DEEP_ATROPOS_SEG_JSON_PATTERN,
        log:
            f"{RESULTS_ROOT}/logs/sub-{{subject}}_deep_atropos_seg.log",
        params:
            outdir=lambda wc: f"{DEEP_ATROPOS_SEG_OUT}/sub-{wc.subject}",
            session=lambda wc: resolve_session(wc.subject),
            external=lambda wc: _find_external_deep_atropos_segmentation(
                wc.subject, resolve_session(wc.subject)
            )
            or "",
            cache_bind=lambda wc: (
                f"-B {DEEP_ATROPOS_CFG['antsxnet_cache']}:/opt/antsxnet_cache"
                if DEEP_ATROPOS_CFG.get("antsxnet_cache")
                else ""
            ),
            script_bind=lambda wc: (
                f'-B "{DWI_PIPELINE_DIR}/scripts/run_deep_atropos_seg.py":'
                f"/opt/deep_atropos_seg/run_deep_atropos_seg.py:ro"
                if ACT_BIND_MOUNT_DEV
                else ""
            ),
        threads: 4
        shell:
            r"""
            exec > {log} 2>&1
            set -euo pipefail
            mkdir -p "{params.outdir}"
            external="{params.external}"
            mode="{ACT_DEEP_ATROPOS_SEG_MODE}"

            if [[ -n "${{external}}" && "${{mode}}" != "generate" ]]; then
              echo "[deep-atropos-seg] import external seg -> {output.seg}"
              ln -sf "${{external}}" "{output.seg}"
              {PIPELINE_PYTHON} -c "import json; json.dump({{'segmentation_source':'import','deep_atropos_segmentation':'${{external}}','canonical_path':'{output.seg}','segmentation_mode':'{ACT_DEEP_ATROPOS_SEG_MODE}'}}, open('{output.provenance}','w'), indent=2); open('{output.provenance}','a').write('\n')"
              exit 0
            fi

            if [[ "${{mode}}" == "import" ]]; then
              echo "ERROR: segmentation_mode=import but no external Deep Atropos seg for sub-{wildcards.subject} ses-{params.session}" >&2
              exit 1
            fi

            echo "[deep-atropos-seg] running ANTsPyNet deep_atropos (mode=${{mode}})"
            apptainer run --cleanenv --containall \
              -B "$(dirname "{input.t1w}")":/bids_t1w:ro \
              -B "{params.outdir}":/out \
              {params.script_bind} \
              {params.cache_bind} \
              "{CONTAINER_DEEP_ATROPOS_SEG}" \
              --t1w "/bids_t1w/$(basename "{input.t1w}")" \
              --outdir /out
            """
