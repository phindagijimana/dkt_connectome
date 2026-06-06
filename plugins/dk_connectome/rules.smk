"""
dk_connectome.smk -- Step 4: aparc+aseg + QSIRecon .tck(.gz) -> DK connectome CSV.

This step runs inside the dedicated dk-connectome image (~900 MB), which
bundles only what's needed:
  mrconvert (MRtrix3)            -- reads aparc+aseg.mgz natively (no FreeSurfer
                                    binaries required).
  antsApplyTransforms (ANTs)     -- ITK-native resample of aparc+aseg onto the
                                    DWI/T1w grid using QSIPrep's xfm. QSIPrep
                                    ships transforms in ITK text format
                                    ('#Insight Transform File V1.0') -- the
                                    .lta/.txt BIDS suffix is misleading and
                                    confused earlier attempts to use
                                    FreeSurfer's mri_vol2vol (which reads true
                                    LTA, not ITK).
  labelconvert + tck2connectome  -- MRtrix3 connectome step.
  mrinfo + tckinfo               -- diagnostics for the space-alignment QC.

FreeSurferColorLUT.txt is baked into the image at
/opt/freesurfer/FreeSurferColorLUT.txt, so no FS license / host LUT is
required for this step. Users can still override the baked-in LUT by setting
`fs_lut:` in config.yaml -- if the file exists on the host it gets bind-mounted
in over the baked one.

Tractogram lookup: matches both *.tck and *.tck.gz (QSIRecon ships the latter).
Space alignment: if dwiref/xfm can't be found, falls back to FS conformed space
with a warning (connectome may be mis-aligned).
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
        fs_lut       = str(FS_LUT),
        container    = str(CONTAINERS["dk_connectome"]),
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
        # QSIRecon's MRtrix specs save it gzipped (*.tck.gz). MRtrix3 3.0.4
        # cannot read .tck.gz directly, so we decompress it inside the
        # container below; here we just have to find either form.
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
                space_note="resampled aparc+aseg onto DWI grid via antsApplyTransforms (xfm: $(basename "$lta"))"
            else
                echo "DK warning: dwiref/xfm not found in {params.qsiprep_out};" \
                     "falling back to FS conformed space (connectome may mis-align)" \
                    | tee -a {log} >&2
            fi
        fi

        echo "=== DK connectome: $sid ===" | tee -a {log} >&2
        echo "  image    : {params.container}"           | tee -a {log} >&2
        echo "  tracks   : $tracks"                       | tee -a {log} >&2
        echo "  aparc    : {input.aparc}"                 | tee -a {log} >&2
        [[ -n "$dwiref" ]] && echo "  dwiref  : $dwiref" | tee -a {log} >&2
        [[ -n "$lta"    ]] && echo "  xfm     : $lta"    | tee -a {log} >&2
        echo "  space    : $space_note"                   | tee -a {log} >&2

        # ---- Preflight: every tool the rule needs is in dk_connectome.sif ----
        for c in mrconvert antsApplyTransforms labelconvert tck2connectome tckinfo mrinfo; do
            apptainer exec --cleanenv "{params.container}" bash -lc "command -v $c" >/dev/null 2>&1 || {{
                echo "DK: missing $c in CONTAINER_DK_CONNECTOME ({params.container})" | tee -a {log} >&2
                exit 1
            }}
        done

        # ---- Bind mounts ------------------------------------------------------
        # The image bakes in /opt/freesurfer/FreeSurferColorLUT.txt. If the
        # user also supplies a host LUT via fs_lut: in config.yaml, mount it
        # over the baked one (useful for pinning to a specific FS release).
        binds=(
            -B "$fs_subj":/fs_subject:ro
            -B "{params.qsirecon_out}":/qsirecon:ro
            -B "$outdir":/out
        )
        if [[ -n "{params.fs_lut}" && -f "{params.fs_lut}" ]]; then
            binds+=( -B "{params.fs_lut}":/opt/freesurfer/FreeSurferColorLUT.txt:ro )
        fi
        [[ -n "$lta" ]] && binds+=( -B "{params.qsiprep_out}":/qsiprep:ro )

        apptainer exec --cleanenv --containall \
            "${{binds[@]}}" \
            "{params.container}" \
            bash -lc "
                set -euo pipefail

                # MRtrix3's mrconvert reads MGZ natively, so we don't need
                # FreeSurfer's mri_convert (and therefore don't need a
                # FreeSurfer license for this step).
                mrconvert -force /fs_subject/mri/aparc+aseg.mgz /out/aparc+aseg.nii.gz

                if [[ -n '${{lta_c}}' && -n '${{dwiref_c}}' ]]; then
                    echo '[dk] Resampling aparc+aseg onto DWI grid via antsApplyTransforms (GenericLabel)'
                    # GenericLabel is the ANTs label-aware resampler: per-label
                    # nearest-neighbour vote, no float interpolation between
                    # distinct integer IDs.
                    antsApplyTransforms -d 3 \
                        -i /out/aparc+aseg.nii.gz \
                        -r '${{dwiref_c}}' \
                        -t '${{lta_c}}' \
                        -n GenericLabel \
                        -o /out/aparc+aseg_in_dwi.nii.gz
                fi

                # MRtrix3 fs_default.txt path differs across base images.
                fs_lut=/opt/freesurfer/FreeSurferColorLUT.txt
                if [[ -f /opt/mrtrix3/share/mrtrix3/labelconvert/fs_default.txt ]]; then
                    mrtrix_lut=/opt/mrtrix3/share/mrtrix3/labelconvert/fs_default.txt
                else
                    mrtrix_lut=/opt/mrtrix3-latest/share/mrtrix3/labelconvert/fs_default.txt
                fi

                labelconvert -force $nodes_input_c \"\$fs_lut\" \"\$mrtrix_lut\" /out/dk_nodes.mif

                # MRtrix3 3.0.4 doesn't read *.tck.gz directly. If the input
                # is gzipped, stage an uncompressed copy under /out, then
                # clean it up (10-20 GB per subject -- don't leave it).
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
