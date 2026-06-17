"""
dk_connectome.smk — Step 4: aparc+aseg + QSIRecon .tck(.gz) → DK connectome CSV.

Space alignment is a two-hop warp:
  1. mri_label2vol (full FreeSurfer container) — FS conformed -> native rawavg
  2. antsApplyTransforms (qsirecon.sif) — native -> QSIPrep T1w/DWI grid

qsirecon.sif ships a trimmed FreeSurfer with mri_convert but NOT mri_label2vol,
so Step 4a uses containers.freesurfer and Step 4b+ use containers.qsirecon.
"""

def _dk_inputs(wc):
    return {
        "qsirecon_flag": qsirecon_flag(wc.sid),
        "aparc":         recon_target(wc.sid),
    }


rule dk_connectome:
    """Desikan-Killiany connectome from QSIRecon tractogram + FS parcellation."""
    input:
        unpack(_dk_inputs),
    output:
        csv = str(DK_OUT / "sub-{sid}" / "dk_connectome.csv"),
    log:
        str(LOGS_DIR / "dk.sub-{sid}.log"),
    threads: stage_threads("dk")
    resources: **stage_resources("dk")
    params:
        qsiprep_out  = str(QSIPREP_OUT),
        qsirecon_out = str(QSIRECON_OUT),
        fs_dir       = str(RECON_OUT),
        dk_out       = str(DK_OUT),
        fs_license   = str(FS_LICENSE),
        fs_lut       = str(FS_LUT),
        container    = str(CONTAINERS["qsirecon"]),
        c_freesurfer = str(CONTAINERS["freesurfer"]),
        resample     = "1" if config["dk"].get("resample_to_dwi", True) else "0",
        tck2c_extra  = " ".join(config["dk"].get("tck2connectome_extra", []) or []),
    shell:
        r"""
        set -euo pipefail
        sid="sub-{wildcards.sid}"
        fs_subj="{params.fs_dir}/$sid"
        outdir="{params.dk_out}/$sid"
        mkdir -p "$outdir"

        # ---- Discover tractogram (path varies by session/run) ----
        # QSIRecon's MRtrix specs save it gzipped (*.tck.gz). MRtrix3 reads it
        # transparently, but `-name '*.tck'` won't match, so search for both
        # and prefer uncompressed when present.
        tracks="$(find {params.qsirecon_out} -type f -path "*${{sid}}*" -name '*.tck' 2>/dev/null | head -1)"
        if [[ -z "$tracks" ]]; then
            tracks="$(find {params.qsirecon_out} -type f -path "*${{sid}}*" -name '*.tck.gz' 2>/dev/null | head -1)"
        fi
        if [[ -z "$tracks" ]]; then
            echo "DK: missing QSIRecon .tck/.tck.gz for $sid under {params.qsirecon_out}" | tee -a {log} >&2
            exit 1
        fi
        tracks_rel="${{tracks#{params.qsirecon_out}/}}"
        tracks_c="/qsirecon/$tracks_rel"

        # ---- Discover DWI ref + fsnative->T1w xfm for the resample step ----
        dwiref=""; lta=""
        dwiref_c=""; lta_c=""
        nodes_input_c="/out/aparc+aseg.nii.gz"
        space_note="WARNING: aparc+aseg used in FS conformed space (no resample)"

        dk_ses=""
        if [[ "$tracks" =~ /ses-([^/]+)/ ]]; then dk_ses="${{BASH_REMATCH[1]}}"; fi
        dwiref_glob="*${{sid}}*"
        [[ -n "$dk_ses" ]] && dwiref_glob="*${{sid}}*/ses-${{dk_ses}}/*"

        if [[ "{params.resample}" == "1" ]]; then
            dwiref="$(find {params.qsiprep_out} -type f -path "$dwiref_glob" \
                      -name '*space-T1w_dwiref.nii.gz' 2>/dev/null | head -1)"
            [[ -z "$dwiref" ]] && dwiref="$(find {params.qsiprep_out} -type f -path "$dwiref_glob" \
                      -name '*space-T1w*desc-preproc_dwi.nii.gz' 2>/dev/null | head -1)"
            [[ -z "$dwiref" && -n "$dk_ses" ]] && dwiref="$(find {params.qsiprep_out} -type f -path "*${{sid}}*" \
                      -name '*space-T1w_dwiref.nii.gz' 2>/dev/null | head -1)"
            lta="$(find {params.qsiprep_out} -type f -path "$dwiref_glob" \
                    \( -name '*from-orig_to-T1w_mode-image_xfm.txt' \
                    -o -name '*from-orig_to-T1w_mode-image_xfm.lta' \
                    -o -name '*from-orig_to-T1w_mode-image_xfm.mat' \
                    -o -name '*from-fsnative_to-T1w_mode-image_xfm.txt' \
                    -o -name '*from-fsnative_to-T1w_mode-image_xfm.lta' \
                    -o -name '*from-fsnative_to-T1w_mode-image_xfm.mat' \) 2>/dev/null | head -1)"
            [[ -z "$lta" && -n "$dk_ses" ]] && lta="$(find {params.qsiprep_out} -type f -path "*${{sid}}*" \
                    \( -name '*from-orig_to-T1w_mode-image_xfm.txt' \
                    -o -name '*from-orig_to-T1w_mode-image_xfm.lta' \
                    -o -name '*from-orig_to-T1w_mode-image_xfm.mat' \
                    -o -name '*from-fsnative_to-T1w_mode-image_xfm.txt' \
                    -o -name '*from-fsnative_to-T1w_mode-image_xfm.lta' \
                    -o -name '*from-fsnative_to-T1w_mode-image_xfm.mat' \) 2>/dev/null | head -1)"
            if [[ -n "$dwiref" && -n "$lta" ]]; then
                dwiref_c="/qsiprep/${{dwiref#{params.qsiprep_out}/}}"
                lta_c="/qsiprep/${{lta#{params.qsiprep_out}/}}"
                nodes_input_c="/out/aparc+aseg_in_dwi.nii.gz"
                space_note="FS conformed -> native (mri_label2vol/rawavg) -> QSIPrep T1w (antsApplyTransforms; xfm: $(basename "$lta"))"
            else
                echo "DK warning: dwiref/xfm not found in {params.qsiprep_out};" \
                     "falling back to FS conformed space (connectome may mis-align)" \
                    | tee -a {log} >&2
            fi
        fi

        echo "=== DK connectome: $sid ===" | tee -a {log} >&2
        echo "  tracks   : $tracks"                       | tee -a {log} >&2
        echo "  aparc    : {input.aparc}"                 | tee -a {log} >&2
        [[ -n "$dwiref" ]] && echo "  dwiref  : $dwiref" | tee -a {log} >&2
        [[ -n "$lta"    ]] && echo "  xfm     : $lta"    | tee -a {log} >&2
        echo "  space    : $space_note"                   | tee -a {log} >&2

        if [[ ! -f "$fs_subj/mri/rawavg.mgz" ]]; then
            echo "DK: missing rawavg.mgz under $fs_subj/mri/ (recon-all should write it)" | tee -a {log} >&2
            exit 1
        fi

        # ---- Step 4a: FS conformed -> native (full FreeSurfer container) ----
        if [[ -n "$lta" && -n "$dwiref" ]]; then
            apptainer exec --cleanenv "{params.c_freesurfer}" bash -lc "command -v mri_label2vol" >/dev/null 2>&1 || {{
                echo "DK: missing mri_label2vol in containers.freesurfer ({params.c_freesurfer})" | tee -a {log} >&2
                exit 1
            }}
            echo "[dk] Warping aparc+aseg FS conformed -> native (mri_label2vol / rawavg.mgz)" | tee -a {log} >&2
            apptainer exec --cleanenv --containall \
                -B "$fs_subj":/fs_subject:ro \
                -B "$outdir":/out \
                -B "{params.fs_license}":/.fs_license.txt:ro \
                "{params.c_freesurfer}" \
                bash -lc "
                    set -euo pipefail
                    export FS_LICENSE=/.fs_license.txt
                    mri_label2vol --seg /fs_subject/mri/aparc+aseg.mgz \
                      --temp /fs_subject/mri/rawavg.mgz \
                      --o /out/aparc+aseg_in_rawavg.mgz \
                      --regheader /fs_subject/mri/aparc+aseg.mgz
                " &>> {log}
        fi

        # ---- Preflight: MRtrix/ANTs tools live in qsirecon.sif ----
        for c in mri_convert antsApplyTransforms labelconvert tck2connectome tckinfo mrinfo; do
            apptainer exec --cleanenv "{params.container}" bash -lc "command -v $c" >/dev/null 2>&1 || {{
                echo "DK: missing $c in CONTAINER_QSIRECON ({params.container})" | tee -a {log} >&2
                exit 1
            }}
        done

        if [[ ! -f "{params.fs_lut}" ]]; then
            echo "DK: missing FreeSurferColorLUT.txt at {params.fs_lut}" | tee -a {log} >&2
            echo "  qsirecon.sif's trimmed FreeSurfer doesn't ship this file;" | tee -a {log} >&2
            echo "  set fs_lut in config.yaml to a host-side FS LUT path." | tee -a {log} >&2
            exit 1
        fi

        # ---- Single-container run ----
        binds=(
            -B "$fs_subj":/fs_subject:ro
            -B "{params.qsirecon_out}":/qsirecon:ro
            -B "$outdir":/out
            -B "{params.fs_license}":/opt/freesurfer/license.txt:ro
            -B "{params.fs_lut}":/opt/freesurfer/FreeSurferColorLUT.txt:ro
        )
        [[ -n "$lta" ]] && binds+=( -B "{params.qsiprep_out}":/qsiprep:ro )

        apptainer exec --cleanenv --containall \
            "${{binds[@]}}" \
            "{params.container}" \
            bash -lc "
                set -euo pipefail
                export FS_LICENSE=/opt/freesurfer/license.txt

                mri_convert /fs_subject/mri/aparc+aseg.mgz /out/aparc+aseg.nii.gz

                if [[ -n '${{lta_c}}' && -n '${{dwiref_c}}' ]]; then
                    mri_convert /out/aparc+aseg_in_rawavg.mgz /out/aparc+aseg_in_rawavg.nii.gz
                    echo '[dk] Resampling native aparc+aseg onto DWI grid via antsApplyTransforms (GenericLabel)'
                    # GenericLabel is the ANTs label-aware resampler: per-label
                    # nearest-neighbour vote, no float interpolation between
                    # distinct integer IDs.
                    antsApplyTransforms -d 3 \
                        -i /out/aparc+aseg_in_rawavg.nii.gz \
                        -r '${{dwiref_c}}' \
                        -t '${{lta_c}}' \
                        -n GenericLabel \
                        -o /out/aparc+aseg_in_dwi.nii.gz
                fi

                # FreeSurferColorLUT.txt is bind-mounted in; MRtrix's
                # fs_default.txt ships with mrtrix3-latest inside qsirecon.sif.
                fs_lut=/opt/freesurfer/FreeSurferColorLUT.txt
                mrtrix_lut=/opt/mrtrix3-latest/share/mrtrix3/labelconvert/fs_default.txt

                labelconvert -force $nodes_input_c \"\$fs_lut\" \"\$mrtrix_lut\" /out/dk_nodes.mif

                # MRtrix3 3.0.4 doesn't read *.tck.gz directly. If the input
                # is gzipped, stage an uncompressed copy under /out, then
                # clean it up (10-20 GB per subject — don't leave it).
                tck_in='$tracks_c'
                tck_use=\"\$tck_in\"
                tck_staged=\"\"
                if [[ \"\$tck_in\" == *.tck.gz ]]; then
                    tck_staged=/out/streamlines.tck
                    echo \"[dk] Decompressing \$tck_in -> \$tck_staged\"
                    gunzip -c \"\$tck_in\" > \"\$tck_staged\"
                    tck_use=\"\$tck_staged\"
                fi

                echo '[dk] === space diagnostic ==='
                mrinfo /out/dk_nodes.mif       | tee /out/dk_nodes.mrinfo.txt   | sed -n '1,20p'
                tckinfo \"\$tck_use\"          | tee /out/tracks.tckinfo.txt    | sed -n '1,30p'

                tck2connectome -force \
                    \"\$tck_use\" \
                    /out/dk_nodes.mif \
                    /out/dk_connectome.csv \
                    -symmetric \
                    -zero_diagonal \
                    -out_assignments /out/dk_assignments.csv \
                    {params.tck2c_extra}

                [[ -n \"\$tck_staged\" ]] && rm -f \"\$tck_staged\"
            " &>> {log}

        echo "DK done: {output.csv}" | tee -a {log} >&2
        """
