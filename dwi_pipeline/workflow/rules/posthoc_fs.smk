"""
posthoc_fs.smk — Optional neurolit LIT packaging after standalone Step 2.

Enabled by recon.post_hoc_fs / --post-hoc-fs. Skipped when native
recon.lesion_mask is on (LIT already written in-recon). Requires a BIDS lesion
mask. Uses prepared mask from Step 1.1 when standalone fill ran; otherwise
prepare_lesion_mask.
"""

POSTHOC_FS_MARKER = f"{MARKERS_DIR}/posthoc_fs_sub-{{subject}}.done"


def posthoc_fs_marker(subject: str) -> str:
    return POSTHOC_FS_MARKER.format(subject=subject)


def _posthoc_mask_input(subject: str) -> str:
    if mitigation_enabled_for(subject):
        return inpaint_paths(subject)["mask_prepared"]
    return lesion_mask_paths(subject)["mask"]


def _posthoc_t1w_input(subject: str) -> str:
    """Original BIDS T1w (neurolit packaging expects raw anatomy + mask)."""
    return _bids_t1w_for(subject, resolve_session(subject))


rule posthoc_fs:
    input:
        aparc=lambda wc: recon_aparc(wc.subject),
        t1w=lambda wc: _posthoc_t1w_input(wc.subject),
        mask=lambda wc: _posthoc_mask_input(wc.subject),
    output:
        marker=POSTHOC_FS_MARKER,
    threads: 4
    resources:
        gpu=0,
    log:
        f"{RESULTS_ROOT}/logs/sub-{{subject}}_posthoc_fs.log",
    params:
        sd_subj=lambda wc: f"{RECON_OUT}/sub-{wc.subject}",
        sid=lambda wc: f"sub-{wc.subject}",
    shell:
        r"""
        exec > {log} 2>&1
        set -euo pipefail
        source {COMMON_SH}
        SUBJECT="{wildcards.subject}"
        SID="{params.sid}"
        SD_HOST="{RECON_OUT}"
        SUBJ_HOST="{params.sd_subj}"
        T1_HOST="{input.t1w}"
        MASK_HOST="{input.mask}"
        MRI="${{SUBJ_HOST}}/mri"

        echo "=== Post-hoc FS LIT packaging: ${{SID}} ==="
        mkdir -p "{MARKERS_DIR}" "$MRI" "${{SUBJ_HOST}}/stats" "${{SUBJ_HOST}}/label"

        # Prefer FastSurfer image with embedded neurolit (2.6+); else lit.sif tools.
        run_packaging() {{
          local sif="$1"
          if apptainer exec --cleanenv "$sif" bash -lc 'command -v lit-postprocessing' >/dev/null 2>&1; then
            echo "Post-hoc: lit-postprocessing via $(basename "$sif")"
            apptainer exec --cleanenv --containall \
              -B "$SD_HOST":/sd \
              -B "$(dirname "$MASK_HOST")":/mask_input:ro \
              "$sif" \
              bash -lc "
                set -euo pipefail
                # Ensure mask.lit exists for lit-postprocessing consumers
                if [[ ! -f /sd/${{SID}}/mri/mask.lit.nii.gz ]]; then
                  cp -f /mask_input/$(basename "$MASK_HOST") /sd/${{SID}}/mri/mask.lit.nii.gz
                fi
                lit-postprocessing --subject-id '${{SID}}' --subjects-dir /sd
              "
            return 0
          fi
          if apptainer exec --cleanenv "$sif" bash -lc 'python3 -c \"import neurolit\"' >/dev/null 2>&1; then
            echo "Post-hoc: neurolit.cli --fastsurfer_dir via $(basename "$sif")"
            apptainer exec --cleanenv --containall \
              -B "$(dirname "$T1_HOST")":/t1w_input:ro \
              -B "$(dirname "$MASK_HOST")":/mask_input:ro \
              -B "$SD_HOST":/sd \
              "$sif" \
              python3 -s -m neurolit.cli \
                --input_image "/t1w_input/$(basename "$T1_HOST")" \
                --lesion_mask "/mask_input/$(basename "$MASK_HOST")" \
                --sd "/sd/${{SID}}" \
                --fastsurfer_dir \
                --dilate 2 \
                --keepgeom \
                --device cpu \
                --batch_size 1
            return 0
          fi
          return 1
        }}

        if run_packaging "{CONTAINER_FASTSURFER}"; then
          :
        elif run_packaging "{CONTAINER_LIT}"; then
          :
        else
          _pipeline_fail "posthoc_fs" \
            "Neither CONTAINER_FASTSURFER nor CONTAINER_LIT exposes lit-postprocessing or neurolit.cli" \
            "Use FastSurfer ≥ 2.6 (neurolit) or a neurolit/lit image with postprocessing."
        fi

        # Conformed mask for surface steps (avoids native-grid STEP3 IndexError)
        if [[ -f "$MRI/mask.lit.nii.gz" && ! -f "$MRI/mask.lit.mgz" && -f "$MRI/orig.mgz" ]]; then
          if apptainer exec --cleanenv "{CONTAINER_FASTSURFER}" bash -lc 'command -v mri_convert' >/dev/null 2>&1; then
            echo "Post-hoc: resampling mask.lit.nii.gz -> mask.lit.mgz (orig space)"
            apptainer exec --cleanenv --containall \
              -B "$MRI":/mri \
              "{CONTAINER_FASTSURFER}" \
              bash -lc '
                set -euo pipefail
                mri_convert /mri/mask.lit.nii.gz /tmp/mask.lit.mgz
                mri_vol2vol --mov /tmp/mask.lit.mgz --targ /mri/orig.mgz \
                  --o /mri/mask.lit.mgz --nearest --regheader || \
                mri_convert --like /mri/orig.mgz /tmp/mask.lit.mgz /mri/mask.lit.mgz
              ' || echo "Post-hoc: WARNING — mask.lit.mgz resample failed (non-fatal)"
          fi
        fi

        date -Is > "{output.marker}"
        echo "Post-hoc FS: OK — {output.marker}"
        """
