"""
recon.smk — Step 2 plugin: anatomical surface reconstruction.

recon.tool: freesurfer (recon-all -all) | fastsurfer (run_fastsurfer.sh).
recon.fsaparc: FastSurfer --fsaparc (adds classic DK-68 aparc/ribbon); the
--fast-fs CLI flag on run_subject.sh sets tool=fastsurfer + fsaparc=true.
recon.lesion_mask: FastSurfer native --lesion_mask (FS ≥ 2.6); skips standalone
Step 1.1 fill and runs neurolit inside recon on the raw BIDS T1w.
"""

RECON_TOOL = str(RECON_CFG.get("tool", "freesurfer"))
RECON_FSAPARC = bool(RECON_CFG.get("fsaparc", False))
RECON_FASTSURFER_DEVICE = str(RECON_CFG.get("fastsurfer_device", "cpu"))

RECON_APARC_PATTERN = f"{RECON_OUT}/sub-{{subject}}/mri/aparc+aseg.mgz"


def recon_aparc(subject: str) -> str:
    return RECON_APARC_PATTERN.format(subject=subject)


def recon_t1w_input(subject: str) -> str:
    """T1w for Step 2: raw BIDS when native --lesion_mask; else standalone
    inpainted T1w when Step 1.1 ran; else raw BIDS T1w."""
    if RECON_LESION_MASK:
        return _bids_t1w_for(subject, resolve_session(subject))
    mitigated = mitigated_t1w_for(subject)
    if mitigated:
        return mitigated
    return _bids_t1w_for(subject, resolve_session(subject))


def _recon_inputs(wildcards):
    paths = [recon_t1w_input(wildcards.subject)]
    if RECON_LESION_MASK:
        if not subject_has_lesion_mask(wildcards.subject):
            raise WorkflowError(
                f"recon.lesion_mask=true requires a BIDS lesion mask for "
                f"sub-{wildcards.subject}"
            )
        paths.append(lesion_mask_paths(wildcards.subject)["mask"])
    return paths


rule recon:
    input:
        _recon_inputs,
    output:
        aparc=RECON_APARC_PATTERN,
    threads: NTHREADS
    resources:
        gpu=1,
    log:
        f"{RESULTS_ROOT}/logs/sub-{{subject}}_recon.log",
    params:
        sd_subj=lambda wc: f"{RECON_OUT}/sub-{wc.subject}",
        lesion_mask=lambda wc: (
            lesion_mask_paths(wc.subject)["mask"] if RECON_LESION_MASK else ""
        ),
        nv_flag="--nv" if RECON_FASTSURFER_DEVICE != "cpu" else "",
        fsaparc_flag="--fsaparc" if RECON_FSAPARC else "",
        use_lesion_mask="1" if RECON_LESION_MASK else "0",
    shell:
        r"""
        exec > {log} 2>&1
        set -euo pipefail
        source {COMMON_SH}
        SUBJECT="{wildcards.subject}"
        T1_HOST="{input[0]}"

        echo "=== Recon ({RECON_TOOL}): sub-${{SUBJECT}} -> {RECON_OUT} ==="
        if [[ "{params.use_lesion_mask}" == "1" ]]; then
          echo "Recon: native FastSurfer --lesion_mask (standalone Step 1.1 skipped)"
        fi
        mkdir -p "{RECON_OUT}"

        APARC="{output.aparc}"
        MRI_DIR="{params.sd_subj}/mri"
        if [[ ! -f "$APARC" ]]; then
          for src in "$MRI_DIR/aparc.DKTatlas+aseg.mapped.mgz" \
                     "$MRI_DIR/aparc.DKTatlas+aseg.mgz"; do
            if [[ -f "$src" ]]; then
              echo "Recon: linking aparc+aseg.mgz -> $(basename "$src")"
              ln -sf "$(basename "$src")" "$APARC"
              break
            fi
          done
        fi
        if [[ -f "$APARC" ]]; then
          echo "Recon: {RECON_TOOL} OK — $APARC (already present)"
          exit 0
        fi

        if [[ "{RECON_TOOL}" == "freesurfer" ]]; then
          if [[ "{params.use_lesion_mask}" == "1" ]]; then
            _pipeline_fail "recon" "recon.lesion_mask requires FastSurfer (not recon-all)"
          fi
          fs_home="$(apptainer exec --cleanenv "{CONTAINER_FREESURFER}" bash -lc '
            for p in "$FREESURFER_HOME" /opt/freesurfer /usr/local/freesurfer; do
              [[ -n "$p" && -x "$p/bin/recon-all" ]] && {{ echo "$p"; exit 0; }}
            done
            exit 1
          ' 2>/dev/null | tail -1)"
          [[ -n "$fs_home" ]] || _pipeline_fail "recon" "recon-all not found in CONTAINER_FREESURFER"
          echo "Recon: FREESURFER_HOME inside container = $fs_home"

          apptainer exec --cleanenv --containall \
            -B "$(dirname "$T1_HOST")":/t1w_input:ro \
            -B "{RECON_OUT}":/sd \
            -B "{FS_LICENSE}":/.fs_license.txt:ro \
            "{CONTAINER_FREESURFER}" \
            bash -lc "
              set -euo pipefail
              export FS_LICENSE=/.fs_license.txt
              export SUBJECTS_DIR=/sd
              sd_subj=\"/sd/sub-${{SUBJECT}}\"
              t1w=\"/t1w_input/$(basename "$T1_HOST")\"
              if [[ -d \"\$sd_subj\" ]]; then
                echo \"Recon: resuming existing subjects dir (omit -i)\"
                recon-all -all -s 'sub-${{SUBJECT}}' -openmp {NTHREADS}
              else
                echo \"Recon: new subject (with -i)\"
                recon-all -all -s 'sub-${{SUBJECT}}' -i \"\$t1w\" -openmp {NTHREADS}
              fi
            "
        elif [[ "{RECON_TOOL}" == "fastsurfer" ]]; then
          BIND_MASK=""
          LESION_ARGS=""
          if [[ "{params.use_lesion_mask}" == "1" ]]; then
            MASK_HOST="{params.lesion_mask}"
            BIND_MASK="-B $(dirname "$MASK_HOST"):/lesion_mask_input:ro"
            LESION_ARGS="--lesion_mask /lesion_mask_input/$(basename "$MASK_HOST")"
            echo "Recon: --lesion_mask $(basename "$MASK_HOST")"
          fi
          # shellcheck disable=SC2086
          apptainer exec {params.nv_flag} --cleanenv --containall \
            -B "$(dirname "$T1_HOST")":/t1w_input:ro \
            $BIND_MASK \
            -B "{RECON_OUT}":/sd \
            -B "{FS_LICENSE}":/fs_license/license.txt:ro \
            "{CONTAINER_FASTSURFER}" \
            /fastsurfer/run_fastsurfer.sh \
              --fs_license /fs_license/license.txt \
              --sid "sub-${{SUBJECT}}" \
              --sd /sd \
              --t1 "/t1w_input/$(basename "$T1_HOST")" \
              --parallel \
              --threads {NTHREADS} \
              --device {RECON_FASTSURFER_DEVICE} \
              {params.fsaparc_flag} \
              $LESION_ARGS
          if [[ ! -f "$APARC" ]]; then
            for src in "$MRI_DIR/aparc.DKTatlas+aseg.mapped.mgz" \
                       "$MRI_DIR/aparc.DKTatlas+aseg.mgz"; do
              if [[ -f "$src" ]]; then
                echo "Recon: linking aparc+aseg.mgz -> $(basename "$src")"
                ln -sf "$(basename "$src")" "$APARC"
                break
              fi
            done
          fi
        else
          _pipeline_fail "recon" "invalid recon.tool={RECON_TOOL} (use freesurfer or fastsurfer)"
        fi

        [[ -f "{output.aparc}" ]] || _pipeline_fail "recon" \
          "{RECON_TOOL} finished but {output.aparc} was not produced" \
          "Inspect {params.sd_subj}/scripts/ for tool logs."
        echo "Recon: {RECON_TOOL} OK — {output.aparc}"
        """
