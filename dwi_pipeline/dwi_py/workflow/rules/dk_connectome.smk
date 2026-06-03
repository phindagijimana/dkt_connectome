"""
dk_connectome.smk — Step 4: aparc+aseg + QSIRecon .tck → DK connectome CSV.

Re-uses the qsirecon.sif container (has FreeSurfer + MRtrix). Locates the
tractogram, the QSIPrep DWI reference, and the from-orig→T1w LTA at runtime
inside the shell block (paths vary by session/acq/run) — that matches the
bash version and keeps the DAG free of brittle wildcards.

Space alignment:
  resample_to_dwi=true (default) — aparc+aseg is warped onto the DWI grid
  via mri_vol2vol --nearest before labelconvert. If the LTA / dwiref can't
  be found, the rule falls back to FS conformed space and emits a warning.
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
        qsiprep_out    = str(QSIPREP_OUT),
        qsirecon_out   = str(QSIRECON_OUT),
        fs_dir         = str(RECON_OUT),
        dk_out         = str(DK_OUT),
        fs_license     = str(FS_LICENSE),
        container      = str(CONTAINERS["qsirecon"]),
        resample       = "1" if config["dk"].get("resample_to_dwi", True) else "0",
        tck2c_extra    = " ".join(config["dk"].get("tck2connectome_extra", []) or []),
    shell:
        r"""
        set -euo pipefail
        sid="sub-{wildcards.sid}"
        fs_subj="{params.fs_dir}/$sid"
        outdir="{params.dk_out}/$sid"
        mkdir -p "$outdir"

        # ---- Discover inputs (paths vary by session/run) ----
        tracks="$(find {params.qsirecon_out} -type f -path "*${{sid}}*" -name '*.tck' 2>/dev/null | head -1)"
        if [[ -z "$tracks" ]]; then
            echo "DK: missing QSIRecon .tck for $sid under {params.qsirecon_out}" | tee -a {log} >&2
            exit 1
        fi
        tracks_rel="${{tracks#{params.qsirecon_out}/}}"
        tracks_c="/qsirecon/$tracks_rel"

        dwiref=""
        lta=""
        nodes_input_c="/out/aparc+aseg.nii.gz"
        space_note="WARNING: aparc+aseg used in FS conformed space (no resample)"

        if [[ "{params.resample}" == "1" ]]; then
            dwiref="$(find {params.qsiprep_out} -type f -path "*${{sid}}*" \
                      -name '*space-T1w_dwiref.nii.gz' 2>/dev/null | head -1)"
            [[ -z "$dwiref" ]] && dwiref="$(find {params.qsiprep_out} -type f -path "*${{sid}}*" \
                      -name '*space-T1w*desc-preproc_dwi.nii.gz' 2>/dev/null | head -1)"
            lta="$(find {params.qsiprep_out} -type f -path "*${{sid}}*" \
                    \( -name '*from-orig_to-T1w_mode-image_xfm.txt' \
                    -o -name '*from-orig_to-T1w_mode-image_xfm.lta' \
                    -o -name '*from-fsnative_to-T1w_mode-image_xfm.txt' \
                    -o -name '*from-fsnative_to-T1w_mode-image_xfm.lta' \) 2>/dev/null | head -1)"
            if [[ -n "$dwiref" && -n "$lta" ]]; then
                dwiref_c="/qsiprep/${{dwiref#{params.qsiprep_out}/}}"
                lta_c="/qsiprep/${{lta#{params.qsiprep_out}/}}"
                nodes_input_c="/out/aparc+aseg_in_dwi.nii.gz"
                space_note="resampled aparc+aseg onto DWI grid (LTA: $(basename "$lta"))"
            else
                echo "DK warning: dwiref/LTA not found; falling back to FS conformed space" \
                    | tee -a {log} >&2
            fi
        fi

        echo "=== DK connectome: $sid ===" | tee -a {log} >&2
        echo "  tracks   : $tracks"                       | tee -a {log} >&2
        echo "  aparc    : {input.aparc}"                 | tee -a {log} >&2
        [[ -n "$dwiref" ]] && echo "  dwiref  : $dwiref" | tee -a {log} >&2
        [[ -n "$lta"    ]] && echo "  LTA     : $lta"    | tee -a {log} >&2
        echo "  space    : $space_note"                   | tee -a {log} >&2

        # ---- Container binds ----
        binds=(
            -B "$fs_subj":/fs_subject:ro
            -B "{params.qsirecon_out}":/qsirecon:ro
            -B "$outdir":/out
            -B "{params.fs_license}":/opt/freesurfer/license.txt:ro
        )
        [[ -n "$lta" ]] && binds+=( -B "{params.qsiprep_out}":/qsiprep:ro )

        apptainer run --cleanenv --containall \
            "${{binds[@]}}" \
            "{params.container}" \
            bash -lc "
                set -euo pipefail
                export FS_LICENSE=/opt/freesurfer/license.txt

                mri_convert /fs_subject/mri/aparc+aseg.mgz /out/aparc+aseg.nii.gz

                if [[ -n '${{lta_c:-}}' && -n '${{dwiref_c:-}}' ]]; then
                    echo '[dk] Resampling aparc+aseg onto DWI grid'
                    mri_vol2vol \
                        --mov  /fs_subject/mri/aparc+aseg.mgz \
                        --targ '${{dwiref_c}}' \
                        --lta  '${{lta_c}}' \
                        --nearest \
                        --o    /out/aparc+aseg_in_dwi.nii.gz
                fi

                fs_lut=\${{FREESURFER_HOME:-/opt/freesurfer}}/FreeSurferColorLUT.txt
                [[ -f \"\$fs_lut\" ]] || fs_lut=/opt/freesurfer/FreeSurferColorLUT.txt
                mrtrix_lut=\${{MRTRIX_HOME:-/opt/mrtrix3}}/share/mrtrix3/labelconvert/fs_default.txt
                [[ -f \"\$mrtrix_lut\" ]] || mrtrix_lut=/usr/local/mrtrix3/share/mrtrix3/labelconvert/fs_default.txt

                labelconvert $nodes_input_c \"\$fs_lut\" \"\$mrtrix_lut\" /out/dk_nodes.mif

                echo '[dk] === space diagnostic ==='
                mrinfo /out/dk_nodes.mif       | tee /out/dk_nodes.mrinfo.txt   | sed -n '1,20p'
                tckinfo '$tracks_c'            | tee /out/tracks.tckinfo.txt    | sed -n '1,30p'

                tck2connectome \
                    '$tracks_c' \
                    /out/dk_nodes.mif \
                    /out/dk_connectome.csv \
                    -symmetric \
                    -zero_diagonal \
                    -out_assignments /out/dk_assignments.csv \
                    {params.tck2c_extra}
            " &>> {log}

        echo "DK done: {output.csv}" | tee -a {log} >&2
        """
