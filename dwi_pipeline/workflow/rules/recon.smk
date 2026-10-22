"""
recon.smk — Step 2 plugin: anatomical surface reconstruction.

recon.tool: freesurfer (recon-all -all) | fastsurfer (run_fastsurfer.sh).
recon.fsaparc: FastSurfer --fsaparc (adds classic DK-68 aparc/ribbon); the
--fast-fs CLI flag on run_subject.sh sets tool=fastsurfer + fsaparc=true.

When inpaint.mode=integrated and a lesion mask exists, FastSurfer is used with
--lesion_mask on the raw T1w (requires CONTAINER_FASTSURFER ≥2.5).
"""

_RECON_TOOL_CFG = str(RECON_CFG.get("tool", "freesurfer"))
RECON_FSAPARC = bool(RECON_CFG.get("fsaparc", False))
RECON_FASTSURFER_DEVICE = str(RECON_CFG.get("fastsurfer_device", "cpu"))

RECON_APARC_PATTERN = f"{RECON_OUT}/sub-{{subject}}/mri/aparc+aseg.mgz"


def recon_aparc(subject: str) -> str:
    return RECON_APARC_PATTERN.format(subject=subject)


def recon_t1w_input(subject: str) -> str:
    """T1w for Step 2: standalone inpainted T1 when present, else raw BIDS T1w."""
    mitigated = mitigated_t1w_for(subject)
    if mitigated:
        return mitigated
    return _bids_t1w_for(subject, resolve_session(subject))


def recon_tool_for(subject: str) -> str:
    """Force fastsurfer when integrated LIT + lesion mask."""
    if prepared_lesion_mask_for(subject):
        return "fastsurfer"
    return _RECON_TOOL_CFG


def _recon_inputs(wildcards):
    d = {"t1w": recon_t1w_input(wildcards.subject)}
    path = prepared_lesion_mask_for(wildcards.subject)
    if path:
        d["lesion_mask"] = path
    return d


rule recon:
    input:
        unpack(_recon_inputs),
    output:
        aparc=RECON_APARC_PATTERN,
    threads: NTHREADS
    resources:
        gpu=1,
    log:
        f"{RESULTS_ROOT}/logs/sub-{{subject}}_recon.log",
    params:
        sd_subj=lambda wc: f"{RECON_OUT}/sub-{wc.subject}",
        recon_tool=lambda wc: recon_tool_for(wc.subject),
        nv_flag="--nv" if RECON_FASTSURFER_DEVICE != "cpu" else "",
        fsaparc_flag="--fsaparc" if RECON_FSAPARC else "",
        has_lesion_mask=lambda wc: "1" if prepared_lesion_mask_for(wc.subject) else "0",
    shell:
        r"""
        exec > {log} 2>&1
        set -euo pipefail
        source {COMMON_SH}
        SUBJECT="{wildcards.subject}"
        RECON_TOOL="{params.recon_tool}"

        echo "=== Recon (${{RECON_TOOL}}): sub-${{SUBJECT}} -> {RECON_OUT} ==="
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
          echo "Recon: ${{RECON_TOOL}} OK — $APARC (already present)"
          exit 0
        fi

        if [[ "${{RECON_TOOL}}" == "freesurfer" ]]; then
          fs_home="$(apptainer exec --cleanenv "{CONTAINER_FREESURFER}" bash -lc '
            for p in "$FREESURFER_HOME" /opt/freesurfer /usr/local/freesurfer; do
              [[ -n "$p" && -x "$p/bin/recon-all" ]] && {{ echo "$p"; exit 0; }}
            done
            exit 1
          ' 2>/dev/null | tail -1)"
          [[ -n "$fs_home" ]] || _pipeline_fail "recon" "recon-all not found in CONTAINER_FREESURFER"
          echo "Recon: FREESURFER_HOME inside container = $fs_home"

          apptainer exec --cleanenv --containall \
            -B "$(dirname "{input.t1w}")":/t1w_input:ro \
            -B "{RECON_OUT}":/sd \
            -B "{FS_LICENSE}":/.fs_license.txt:ro \
            "{CONTAINER_FREESURFER}" \
            bash -lc "
              set -euo pipefail
              export FS_LICENSE=/.fs_license.txt
              export SUBJECTS_DIR=/sd
              sd_subj=\"/sd/sub-${{SUBJECT}}\"
              t1w=\"/t1w_input/$(basename "{input.t1w}")\"
              if [[ -d \"\$sd_subj\" ]]; then
                echo \"Recon: resuming existing subjects dir (omit -i)\"
                recon-all -all -s 'sub-${{SUBJECT}}' -openmp {NTHREADS}
              else
                echo \"Recon: new subject (with -i)\"
                recon-all -all -s 'sub-${{SUBJECT}}' -i \"\$t1w\" -openmp {NTHREADS}
              fi
            "
        elif [[ "${{RECON_TOOL}}" == "fastsurfer" ]]; then
          LESION_ARGS=()
          LESION_BINDS=()
          if [[ "{params.has_lesion_mask}" == "1" ]]; then
            if ! apptainer exec --cleanenv "{CONTAINER_FASTSURFER}" \
                 bash -lc 'grep -q lesion_mask /fastsurfer/run_fastsurfer.sh'; then
              _pipeline_fail "recon" \
                "inpaint.mode=integrated needs FastSurfer ≥2.5 with --lesion_mask in {CONTAINER_FASTSURFER}" \
                "Pull deepmi/fastsurfer:cu126-v2.6.0+ or set inpaint.mode=standalone"
            fi
            LESION_BINDS+=( -B "$(dirname "{input.lesion_mask}")":/lesion_mask_input:ro )
            LESION_ARGS+=( --lesion_mask "/lesion_mask_input/$(basename "{input.lesion_mask}")" )
            echo "Recon: FastSurfer-LIT integrated (--lesion_mask)"
          fi
          apptainer exec {params.nv_flag} --cleanenv --containall \
            -B "$(dirname "{input.t1w}")":/t1w_input:ro \
            "${{LESION_BINDS[@]}}" \
            -B "{RECON_OUT}":/sd \
            -B "{FS_LICENSE}":/fs_license/license.txt:ro \
            "{CONTAINER_FASTSURFER}" \
            /fastsurfer/run_fastsurfer.sh \
              --fs_license /fs_license/license.txt \
              --sid "sub-${{SUBJECT}}" \
              --sd /sd \
              --t1 "/t1w_input/$(basename "{input.t1w}")" \
              "${{LESION_ARGS[@]}}" \
              --parallel \
              --threads {NTHREADS} \
              --device {RECON_FASTSURFER_DEVICE} \
              {params.fsaparc_flag}
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
          _pipeline_fail "recon" "invalid recon.tool=${{RECON_TOOL}} (use freesurfer or fastsurfer)"
        fi

        [[ -f "{output.aparc}" ]] || _pipeline_fail "recon" \
          "${{RECON_TOOL}} finished but {output.aparc} was not produced" \
          "Inspect {params.sd_subj}/scripts/ for tool logs."
        echo "Recon: ${{RECON_TOOL}} OK — {output.aparc}"
        """
