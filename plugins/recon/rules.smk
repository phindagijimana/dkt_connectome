"""
recon.smk — Step 2: BIDS T1w → FreeSurfer subjects directory.

Real output file = mri/aparc+aseg.mgz (unambiguous, idempotent), so we don't
need a sentinel here. Tool selection (recon-all vs FastSurfer) is config-driven
via config['recon']['tool']; we branch inside the shell block.

Mirrors subject.sh::run_recon / _run_recon_freesurfer / _run_recon_fastsurfer.

Notes:
  * recon-all refuses to overwrite an existing subject dir — if a previous
    attempt died half-way, we abort and tell the user to remove it.
  * `containers.freesurfer` should point at the dedicated full FreeSurfer
    SIF (pulled via dwi_pipeline/containers/pull_freesurfer_sif.sbatch).
    `fastsurfer_latest.sif` ships a *trimmed* FreeSurfer that is missing the
    skull-strip atlas RB_all_withskull_2020_01_02.gca — recon-all -all dies
    after ~30 min on that image (job 44563 in the bash run hit exactly this).
  * The FreeSurfer install lives at `/opt/freesurfer` in some images
    (NeuroDocker/FastSurfer) and `/usr/local/freesurfer` in the MGH-published
    `freesurfer/freesurfer` image — we detect it at runtime instead of guessing.
"""

def _recon_t1ws(subject: str) -> list[str]:
    t1ws = find_t1ws(subject)
    if not t1ws:
        raise WorkflowError(
            f"Recon: no T1w found under {BIDS_DIR}/sub-{subject}/.../anat/"
        )
    return t1ws


rule recon:
    """Anatomical surface reconstruction → aparc+aseg.mgz."""
    input:
        bids_subject = lambda wc: str(BIDS_DIR / f"sub-{wc.sid}"),
    output:
        aparc = str(RECON_OUT / "sub-{sid}" / "mri" / "aparc+aseg.mgz"),
    log:
        str(LOGS_DIR / "recon.sub-{sid}.log"),
    benchmark:
        stage_benchmark("recon")
    threads: stage_threads("recon")
    resources: **stage_resources("recon")
    retries: stage_retries("recon")
    params:
        tool          = config["recon"]["tool"],
        bids_dir      = str(BIDS_DIR),
        recon_out     = str(RECON_OUT),
        fs_license    = str(FS_LICENSE),
        c_freesurfer  = str(CONTAINERS["freesurfer"]),
        c_fastsurfer  = str(CONTAINERS["fastsurfer"]),
        fs_device     = config["recon"].get("fastsurfer_device", "cpu"),
        t1ws_rel      = lambda wc: " ".join(
                            f"-i /bids/{Path(t).relative_to(BIDS_DIR)}"
                            for t in _recon_t1ws(wc.sid)
                        ),
        first_t1_rel  = lambda wc: str(Path(_recon_t1ws(wc.sid)[0]).relative_to(BIDS_DIR)),
    shell:
        r"""
        set -euo pipefail
        sid="sub-{wildcards.sid}"
        sd_subj="{params.recon_out}/$sid"

        # Snakemake auto-creates the output's parent dir ($sd_subj/mri/) before
        # the rule runs. If that empty mri/ is all that's there, it's noise
        # from Snakemake (not a real recon-all in progress) — wipe it so
        # recon-all starts clean. Only refuse to overwrite when there's real
        # content (scripts/, surf/, anything in mri/, etc.).
        if [[ -d "$sd_subj" ]]; then
            snake_only=1
            for entry in "$sd_subj"/*; do
                [[ -e "$entry" ]] || continue                # nothing inside
                if [[ "$(basename "$entry")" != "mri" ]]; then
                    snake_only=0
                    break
                fi
                # mri/ exists; OK iff empty
                if [[ -n "$(ls -A "$entry" 2>/dev/null)" ]]; then
                    snake_only=0
                    break
                fi
            done
            if [[ "$snake_only" == "1" ]]; then
                echo "Recon: removing Snakemake-only empty subject dir $sd_subj" | tee -a {log} >&2
                rm -rf "$sd_subj"
            elif [[ ! -f "$sd_subj/mri/aparc+aseg.mgz" ]]; then
                echo "Recon: partial subjects dir at $sd_subj with real content — remove it first." | tee -a {log} >&2
                exit 1
            fi
        fi
        mkdir -p "{params.recon_out}"

        if [[ "{params.tool}" == "freesurfer" ]]; then
            echo "=== Recon (recon-all): $sid ===" | tee -a {log} >&2

            # Layout-agnostic FREESURFER_HOME probe — see module docstring.
            fs_home=$(apptainer exec --cleanenv "{params.c_freesurfer}" bash -lc '
                for p in "$FREESURFER_HOME" /opt/freesurfer /usr/local/freesurfer; do
                    [[ -n "$p" && -x "$p/bin/recon-all" ]] && {{ echo "$p"; exit 0; }}
                done
                ra=$(command -v recon-all || true)
                [[ -n "$ra" ]] && {{ dirname "$(dirname "$ra")"; exit 0; }}
                exit 1
            ' 2>/dev/null | tail -1)
            if [[ -z "$fs_home" ]]; then
                echo "Recon: recon-all not found in {params.c_freesurfer}" | tee -a {log} >&2
                exit 1
            fi
            # The skull-strip atlas is what catches the trimmed-FreeSurfer-in-FastSurfer
            # image. Fail fast instead of dying 30 min into recon-all.
            apptainer exec --cleanenv "{params.c_freesurfer}" \
                test -f "$fs_home/average/RB_all_withskull_2020_01_02.gca" \
                || {{ echo "Recon: $fs_home/average/RB_all_withskull_2020_01_02.gca missing" \
                       "in {params.c_freesurfer}; switch containers.freesurfer to the dedicated" \
                       "freesurfer_7.4.1.sif (sbatch ../containers/pull_freesurfer_sif.sbatch)" \
                       | tee -a {log} >&2; exit 1; }}
            echo "Recon: FREESURFER_HOME inside container = $fs_home" | tee -a {log} >&2

            # License is bound at a neutral path and picked up via FS_LICENSE env
            # (works regardless of $FREESURFER_HOME inside the image).
            apptainer exec --cleanenv --containall \
                -B "{params.bids_dir}":/bids:ro \
                -B "{params.recon_out}":/sd \
                -B "{params.fs_license}":/.fs_license.txt:ro \
                "{params.c_freesurfer}" \
                bash -lc "
                    set -euo pipefail
                    export FS_LICENSE=/.fs_license.txt
                    export SUBJECTS_DIR=/sd
                    recon-all -all -s '$sid' {params.t1ws_rel} -openmp {threads}
                " &>> {log}

        elif [[ "{params.tool}" == "fastsurfer" ]]; then
            echo "=== Recon (FastSurfer): $sid ===" | tee -a {log} >&2
            apptainer exec --cleanenv "{params.c_fastsurfer}" \
                bash -lc 'test -x /fastsurfer/run_fastsurfer.sh' \
                || {{ echo "run_fastsurfer.sh missing in {params.c_fastsurfer}" | tee -a {log} >&2; exit 1; }}

            apptainer exec --cleanenv --containall \
                -B "{params.bids_dir}":/bids:ro \
                -B "{params.recon_out}":/sd \
                -B "{params.fs_license}":/fs_license/license.txt:ro \
                "{params.c_fastsurfer}" \
                /fastsurfer/run_fastsurfer.sh \
                    --fs_license /fs_license/license.txt \
                    --sid "$sid" \
                    --sd /sd \
                    --t1 "/bids/{params.first_t1_rel}" \
                    --parallel \
                    --threads {threads} \
                    --device {params.fs_device} \
                    &>> {log}
        else
            echo "Invalid recon tool: {params.tool}" | tee -a {log} >&2
            exit 1
        fi

        [[ -f "{output.aparc}" ]] || {{
            echo "Recon: {params.tool} ran but {output.aparc} missing." | tee -a {log} >&2
            exit 1
        }}
        echo "Recon OK: $(du -h {output.aparc} | cut -f1)" | tee -a {log} >&2
        """
