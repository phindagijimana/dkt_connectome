"""
connectome.smk — Step 4 plugin: build the structural connectome from the
QSIRecon tractogram + a FreeSurfer parcellation (DKT-78 or DK-84).

Scope note: only the single-container path (CONTAINER_CONNECTOME) is ported
in this first pass; the legacy dual-container (freesurfer.sif + qsirecon.sif)
path stays subject.sh-only for now.

Tractogram / dwiref / T1w discovery happens inside the shell block at run
time via find (exactly like subject.sh) rather than in Python at DAG-build
time, because their BIDS-entity-laden filenames aren't predictable until
Steps 1-3 have actually produced them. Snakemake still gets correct ordering
and skip-if-exists from the input/output files declared below.
"""

import os
import tempfile

wildcard_constraints:
    parc=r"dk|dkt|lausanne60"

CONNECTOME_MATRIX_PATTERN = f"{CONNECTOME_OUT}/sub-{{subject}}/{{parc}}_connectome.csv"
CONNECTOME_COUNT_PATTERN = f"{CONNECTOME_OUT}/sub-{{subject}}/{{parc}}_connectome_count.csv"
CONNECTOME_SIFT2_PATTERN = f"{CONNECTOME_OUT}/sub-{{subject}}/{{parc}}_connectome_sift2.csv"
CONNECTOME_MEANLENGTH_PATTERN = f"{CONNECTOME_OUT}/sub-{{subject}}/{{parc}}_connectome_meanlength.csv"
CONNECTOME_MEANFA_PATTERN = f"{CONNECTOME_OUT}/sub-{{subject}}/{{parc}}_connectome_meanfa.csv"
CONNECTOME_MEANMD_PATTERN = f"{CONNECTOME_OUT}/sub-{{subject}}/{{parc}}_connectome_meanmd.csv"
CONNECTOME_FA_MAP_PATTERN = f"{CONNECTOME_OUT}/sub-{{subject}}/{{parc}}_desc-FA_dwi.nii.gz"
CONNECTOME_MD_MAP_PATTERN = f"{CONNECTOME_OUT}/sub-{{subject}}/{{parc}}_desc-MD_dwi.nii.gz"
CONNECTOME_NODES_PATTERN = f"{CONNECTOME_OUT}/sub-{{subject}}/{{parc}}_nodes.mif"
CONNECTOME_PARCJSON_PATTERN = f"{CONNECTOME_OUT}/sub-{{subject}}/parcellation.json"

CONNECTOME_PARCELLATION_CFG = str(CONNECTOME_CFG.get("parcellation", "dkt"))
CONNECTOME_DETERMINISTIC = bool(CONNECTOME_CFG.get("deterministic", True))
CONNECTOME_FAIL_ON_EMPTY_NODES = bool(CONNECTOME_CFG.get("fail_on_empty_nodes", False))
CONNECTOME_RESAMPLE_TO_DWI = bool(CONNECTOME_CFG.get("resample_to_dwi", True))
CONNECTOME_WEIGHTING = str(CONNECTOME_CFG.get("weighting", "count")).lower()
CONNECTOME_PRIMARY_MEASURE = str(
    CONNECTOME_CFG.get("primary_measure") or "count"
).lower()
EXPERIMENT_ARM = str(EXPERIMENT_CFG.get("arm") or "")
if CONNECTOME_PRIMARY_MEASURE not in ("count", "sift2"):
    raise WorkflowError(
        "invalid connectome.primary_measure="
        f"{CONNECTOME_PRIMARY_MEASURE} (use count or sift2)"
    )
if CONNECTOME_PRIMARY_MEASURE == "sift2" and not CONNECTOME_SIFT2_ENABLED:
    raise WorkflowError(
        "connectome.primary_measure=sift2 requires connectome.sift2=true "
        "(enable with --connectome-sift2 or CONNECTOME_SIFT2=1)"
    )
CONNECTOME_RUN_PRIMARY = (
    "count" if CONNECTOME_SIFT2_ENABLED else CONNECTOME_PRIMARY_MEASURE
)


@functools.lru_cache(maxsize=None)
def _fs_aparc_has_dk_only_labels_py(fs_dir: str) -> bool | None:
    """Python-side copy of common.sh's _fs_aparc_has_dk_only_labels, used only
    to pick an output filename ahead of time when parcellation=auto. The shell
    block re-derives the same fact at run time for the segmentation-file
    substitution, so this and common.sh must be kept in sync."""
    if not Path(CONTAINER_CONNECTOME).is_file():
        return None
    with tempfile.TemporaryDirectory() as scratch:
        cmd = [
            "apptainer", "exec", "--cleanenv", "--containall",
            "--env", "LD_LIBRARY_PATH=/opt/ants/lib:/opt/mrtrix3-latest/lib",
            "-B", f"{fs_dir}/mri:/probe:ro",
            "-B", f"{scratch}:/scratch",
            CONTAINER_CONNECTOME, "bash", "-c",
            'set -e; a=/probe/aparc+aseg.mgz; '
            'mrcalc -quiet -force "$a" 1001 -eq "$a" 1032 -eq -add "$a" 1033 -eq -add '
            '"$a" 2001 -eq -add "$a" 2032 -eq -add "$a" 2033 -eq -add /scratch/dk_only.mif; '
            'mrstats /scratch/dk_only.mif -output max',
        ]
        try:
            out = subprocess.run(cmd, capture_output=True, text=True, timeout=120)
        except Exception:
            return None
        val = out.stdout.strip()
        if val == "0":
            return False
        if val == "1":
            return True
        return None


@functools.lru_cache(maxsize=None)
def fs_tree_is_dkt(subject: str) -> bool:
    fs_dir = f"{FS_SUBJECTS_DIR}/sub-{subject}"
    probe = _fs_aparc_has_dk_only_labels_py(fs_dir)
    if probe is not None:
        return not probe
    aparc = Path(fs_dir) / "mri" / "aparc+aseg.mgz"
    if aparc.is_symlink() and "DKTatlas" in os.readlink(aparc):
        return True
    return (Path(fs_dir) / "mri" / "aparc.DKTatlas+aseg.deep.mgz").is_file()


def resolved_parcellation(subject: str) -> str:
    parc = CONNECTOME_PARCELLATION_CFG
    if parc == "auto":
        return "dkt" if fs_tree_is_dkt(subject) else "dk"
    if parc not in ("dk", "dkt"):
        raise WorkflowError(f"invalid connectome.parcellation={parc} (use auto, dk, or dkt)")
    return parc


def connectome_atlases_for(subject: str) -> list[str]:
    out: list[str] = []
    for atlas in CONNECTOME_ATLASES:
        if atlas == "auto":
            resolved = resolved_parcellation(subject)
        elif atlas in ("dkt", "dk", "lausanne60"):
            resolved = atlas
        else:
            raise WorkflowError(f"unsupported connectome atlas: {atlas}")
        if resolved not in out:
            out.append(resolved)
    return out


def connectome_matrix(subject: str) -> str:
    return CONNECTOME_MATRIX_PATTERN.format(
        subject=subject, parc=resolved_parcellation(subject)
    )


def connectome_sift2_products(subject: str) -> list[str]:
    if not CONNECTOME_SIFT2_ENABLED:
        return []
    return [
        CONNECTOME_SIFT2_PATTERN.format(subject=subject, parc=parc)
        for parc in connectome_atlases_for(subject)
    ]


def connectome_products(subject: str) -> list[str]:
    products: list[str] = []
    for parc in connectome_atlases_for(subject):
        products.extend(
            pattern.format(subject=subject, parc=parc)
            for pattern in (
                CONNECTOME_MATRIX_PATTERN,
                CONNECTOME_COUNT_PATTERN,
                CONNECTOME_MEANLENGTH_PATTERN,
                CONNECTOME_MEANFA_PATTERN,
                CONNECTOME_MEANMD_PATTERN,
                CONNECTOME_FA_MAP_PATTERN,
                CONNECTOME_MD_MAP_PATTERN,
                CONNECTOME_NODES_PATTERN,
            )
        )
    products.extend(connectome_sift2_products(subject))
    return products


def connectome_parcellation_json(subject: str, parc: str | None = None) -> str:
    parc = parc or resolved_parcellation(subject)
    if parc == resolved_parcellation(subject):
        return CONNECTOME_PARCJSON_PATTERN.format(subject=subject)
    return f"{CONNECTOME_OUT}/sub-{subject}/{parc}_parcellation.json"


def connectome_registration_t1w_input(subject: str):
    """If Step 1.1 ran for this subject, connectome must wait for it and use
    its result as the affine-registration source (see subject.sh's
    _resolve_registration_t1w); otherwise no such dependency exists."""
    return mitigated_t1w_for(subject) or []


rule connectome:
    input:
        aparc=lambda wc: recon_aparc(wc.subject),
        lausanne_parc=lambda wc: (
            lausanne60_parcellation(wc.subject) if wc.parc == "lausanne60" else []
        ),
        qsirecon_marker=lambda wc: qsirecon_marker(wc.subject),
        lesion_act=lambda wc: lesion_act_products(wc.subject),
        registration_t1w=lambda wc: connectome_registration_t1w_input(wc.subject),
    output:
        # parcellation.json is not declared here (Snakemake requires every
        # output of a rule to share the same wildcard set, and this file's
        # name -- unlike the matrix -- doesn't vary with {parc}); it's still
        # written by the shell block below, just not skip/rerun-tracked.
        matrix=CONNECTOME_MATRIX_PATTERN,
        count_matrix=CONNECTOME_COUNT_PATTERN,
        meanlength_matrix=CONNECTOME_MEANLENGTH_PATTERN,
        meanfa_matrix=CONNECTOME_MEANFA_PATTERN,
        meanmd_matrix=CONNECTOME_MEANMD_PATTERN,
        fa_map=CONNECTOME_FA_MAP_PATTERN,
        md_map=CONNECTOME_MD_MAP_PATTERN,
        nodes=CONNECTOME_NODES_PATTERN,
    threads: 4
    log:
        f"{RESULTS_ROOT}/logs/sub-{{subject}}_connectome_{{parc}}.log",
    params:
        parc=lambda wc: wc.parc,
        fs_dir=lambda wc: f"{FS_SUBJECTS_DIR}/sub-{wc.subject}",
        outdir=lambda wc: f"{CONNECTOME_OUT}/sub-{wc.subject}",
        parcellation_json=lambda wc: connectome_parcellation_json(wc.subject, wc.parc),
        lut_dkt=CONNECTOME_LUT_DKT,
        lut_lausanne_fs=LAUSANNE60_LUT_FS,
        lut_lausanne_mrtrix=LAUSANNE60_LUT_MRTRIX,
        deterministic="1" if CONNECTOME_DETERMINISTIC else "0",
        fail_on_empty="1" if CONNECTOME_FAIL_ON_EMPTY_NODES else "0",
        weighting=CONNECTOME_WEIGHTING,
        primary_measure=CONNECTOME_RUN_PRIMARY,
        session=lambda wc: resolve_session(wc.subject),
    shell:
        r"""
        exec > {log} 2>&1
        set -euo pipefail
        source {COMMON_SH}
        export CONTAINER_CONNECTOME="{CONTAINER_CONNECTOME}"
        SUBJECT="{wildcards.subject}"

        [[ "{CONNECTOME_RESAMPLE_TO_DWI}" == "True" ]] || \
          _pipeline_fail "connectome" "connectome.resample_to_dwi must be true (strict pipeline)"

        # Multi-atlas safe: remove only this atlas's prior outputs.
        mkdir -p "{params.outdir}"
        rm -f "{params.outdir}/{params.parc}_connectome"*.csv \
              "{params.outdir}/{params.parc}_desc-FA_dwi.nii.gz" \
              "{params.outdir}/{params.parc}_desc-MD_dwi.nii.gz" \
              "{params.outdir}/{params.parc}_nodes.mif"
        aparc="{input.aparc}"
        seg_container_path=""
        lausanne_binds=()

        if [[ "{params.parc}" == "lausanne60" ]]; then
          aparc="{input.lausanne_parc}"
          [[ -f "${{aparc}}" ]] || _pipeline_fail "connectome" \
            "missing Lausanne-60 parcellation: ${{aparc}}"
          lausanne_binds=(-B "$(dirname "${{aparc}}")":/lausanne_parc:ro)
          seg_container_path="/lausanne_parc/$(basename "${{aparc}}")"
          echo "Using Lausanne-60 parcellation: ${{aparc}}"
        else
          _CONNECTOME_DETECT_METHOD=""
          tree_is_dkt=0
          if _fs_tree_is_dkt "{params.fs_dir}" "{params.outdir}"; then tree_is_dkt=1; fi
          echo "Parcellation requested: {params.parc} (tree_is_dkt=${{tree_is_dkt}}, detected via ${{_CONNECTOME_DETECT_METHOD}})"

          if [[ "{params.parc}" == "dkt" && "${{tree_is_dkt}}" != "1" ]]; then
            aparc="{params.fs_dir}/mri/aparc.DKTatlas+aseg.mgz"
            [[ -f "${{aparc}}" ]] || _pipeline_fail "connectome" "DKT requested but no DKT segmentation at ${{aparc}}"
            echo "Using the recon-all DKT segmentation: ${{aparc}}"
          fi
          if [[ "{params.parc}" == "dk" && "${{tree_is_dkt}}" == "1" ]]; then
            echo "WARNING: parcellation=dk on a FastSurfer tree -- expect 6 empty nodes."
          fi
          seg_container_path="$(basename "${{aparc}}")"
        fi

        ses="{params.session}"
        tractography_binds=()
        if [[ "{ACT_MODE}" == "lesion-aware" ]]; then
          tracks="{LESION_AWARE_ACT_OUT}/sub-${{SUBJECT}}/model-ifod2_streamlines.tck"
          [[ -f "${{tracks}}" ]] || _pipeline_fail "connectome/tractogram" \
            "missing lesion-aware tractogram: ${{tracks}}"
          tracks_in_container="/lesion_act/sub-${{SUBJECT}}/model-ifod2_streamlines.tck"
        else
          tracks="$(_find_ifod2_tractogram "{QSIRECON_OUT}" "{TRACTOGRAPHY_OUT}" "" "${{SUBJECT}}")"
          if [[ "{ANATOMY_MITIGATION_BACKEND}" != "none" \
             && "${{tracks}}" != "{TRACTOGRAPHY_OUT}/sub-${{SUBJECT}}/model-ifod2_streamlines.tck" ]]; then
            staged="{TRACTOGRAPHY_OUT}/sub-${{SUBJECT}}/model-ifod2_streamlines.tck"
            mkdir -p "{TRACTOGRAPHY_OUT}/sub-${{SUBJECT}}"
            if [[ "${{tracks}}" == *.tck.gz ]]; then
              gunzip -c "${{tracks}}" > "${{staged}}"
            else
              cp -f "${{tracks}}" "${{staged}}"
            fi
            sift2_src="$(_find_sift2_weights "{QSIRECON_OUT}" "" "${{SUBJECT}}")"
            cp -f "${{sift2_src}}" "{TRACTOGRAPHY_OUT}/sub-${{SUBJECT}}/model-ifod2_sift2weights.csv"
            tracks="${{staged}}"
            echo "Staged iFOD2 tractogram for {ANATOMY_MITIGATION_BACKEND} path: ${{tracks}}"
          fi
          if [[ "${{tracks}}" == "{TRACTOGRAPHY_OUT}/sub-${{SUBJECT}}/model-ifod2_streamlines.tck" ]]; then
            tracks_in_container="/tractography/sub-${{SUBJECT}}/model-ifod2_streamlines.tck"
            tractography_binds=(-B "{TRACTOGRAPHY_OUT}":/tractography:ro)
          else
            tracks_rel="${{tracks#{QSIRECON_OUT}/}}"
            tracks_in_container="/qsirecon/${{tracks_rel}}"
          fi
        fi

        dwiref="$(find_qsiprep_dwiref "connectome/dwiref" "{QSIPREP_OUT}" "${{SUBJECT}}" "${{ses}}")"
        preproc_dwi="$(find_qsiprep_preproc_dwi "connectome/preproc_dwi" "{QSIPREP_OUT}" "${{SUBJECT}}" "${{ses}}")"
        bval="${{preproc_dwi%.nii.gz}}.bval"
        bvec="${{preproc_dwi%.nii.gz}}.bvec"
        [[ -f "${{bval}}" ]] || _pipeline_fail "connectome/tensor" "missing b-values: ${{bval}}"
        [[ -f "${{bvec}}" ]] || _pipeline_fail "connectome/tensor" "missing b-vectors: ${{bvec}}"
        brain_mask="$(find_qsiprep_brain_mask "connectome/brain_mask" "{QSIPREP_OUT}" "${{SUBJECT}}" "${{ses}}")"
        preproc_t1w="$(find_qsiprep_preproc_t1w "{QSIPREP_OUT}" "${{SUBJECT}}" "${{ses}}")"

        if [[ -n "{input.registration_t1w}" ]]; then
          bids_t1w="{input.registration_t1w}"
          echo "Connectome: using Step 1.1 inpainted T1w for registration: ${{bids_t1w}}"
        else
          bids_t1w="$(find_bids_t1w "${{SUBJECT}}" "${{ses}}")"
        fi

        dwiref_rel="${{dwiref#{QSIPREP_OUT}/}}"
        preproc_t1w_rel="${{preproc_t1w#{QSIPREP_OUT}/}}"
        preproc_dwi_rel="${{preproc_dwi#{QSIPREP_OUT}/}}"
        bval_rel="${{bval#{QSIPREP_OUT}/}}"
        bvec_rel="${{bvec#{QSIPREP_OUT}/}}"
        brain_mask_rel="${{brain_mask#{QSIPREP_OUT}/}}"
        dwiref_in_container="/qsiprep/${{dwiref_rel}}"
        preproc_t1w_in_container="/qsiprep/${{preproc_t1w_rel}}"
        preproc_dwi_in_container="/qsiprep/${{preproc_dwi_rel}}"
        bval_in_container="/qsiprep/${{bval_rel}}"
        bvec_in_container="/qsiprep/${{bvec_rel}}"
        brain_mask_in_container="/qsiprep/${{brain_mask_rel}}"

        t1w_override_binds=()
        if [[ "${{bids_t1w}}" == "{BIDS_DIR}"/* ]]; then
          bids_t1w_rel="${{bids_t1w#{BIDS_DIR}/}}"
          bids_t1w_in_container="/bids/${{bids_t1w_rel}}"
        else
          t1w_override_binds=( -B "$(dirname "${{bids_t1w}}")":/bids_t1w_override:ro )
          bids_t1w_in_container="/bids_t1w_override/$(basename "${{bids_t1w}}")"
        fi

        echo "Using tractogram: ${{tracks}}"
        echo "Using aparc+aseg: ${{aparc}}"
        echo "Using DWI reference: ${{dwiref}}"
        echo "Using preprocessed DWI: ${{preproc_dwi}}"
        echo "Using DWI brain mask: ${{brain_mask}}"
        echo "Using BIDS T1w (affine reg source): ${{bids_t1w}}"
        echo "Connectome weighting: {params.weighting}"

        binds=()
        act_binds=()
        if [[ "{ACT_MODE}" == "lesion-aware" ]]; then
          act_binds=(-B "{LESION_AWARE_ACT_OUT}":/lesion_act:ro)
        fi
        lut_args=()
        if [[ "{params.parc}" == "dkt" ]]; then
          if [[ "{CONNECTOME_BIND_DEV}" == "True" ]]; then
            [[ -f "{params.lut_dkt}" ]] || _pipeline_fail "connectome" "missing DKT LUT: {params.lut_dkt}"
            binds+=(-B "{params.lut_dkt}":/lut/fs_dkt.txt:ro)
            lut_args+=(--mrtrix-lut /lut/fs_dkt.txt)
          else
            lut_args+=(--mrtrix-lut {CONNECTOME_LUT_BAKED})
          fi
        elif [[ "{params.parc}" == "lausanne60" ]]; then
          [[ -f "{params.lut_lausanne_fs}" ]] || _pipeline_fail "connectome" "missing Lausanne FS LUT"
          [[ -f "{params.lut_lausanne_mrtrix}" ]] || _pipeline_fail "connectome" "missing Lausanne MRtrix LUT"
          binds+=(-B "{params.lut_lausanne_fs}":/lut/lausanne60_fs_lut.txt:ro)
          binds+=(-B "{params.lut_lausanne_mrtrix}":/lut/lausanne60_mrtrix_lut.txt:ro)
          lut_args+=(--fs-lut /lut/lausanne60_fs_lut.txt --mrtrix-lut /lut/lausanne60_mrtrix_lut.txt)
        fi

        env_args=()
        if [[ "{params.deterministic}" == "1" ]]; then
          env_args+=(--env "ITK_GLOBAL_DEFAULT_NUMBER_OF_THREADS=1" --env "ANTS_RANDOM_SEED=1")
        fi

        connectome_entrypoint_binds=()
        if [[ "{CONNECTOME_BIND_DEV}" == "True" ]]; then
          connectome_entrypoint_binds=( -B "{DWI_PIPELINE_DIR}/containers/connectome/run_connectome.sh":/usr/local/bin/run_connectome:ro )
        fi

        apptainer run --cleanenv --containall \
          --home /tmp \
          --env "LD_LIBRARY_PATH=/opt/ants/lib:/opt/mrtrix3-latest/lib" \
          "${{env_args[@]}}" \
          "${{binds[@]}}" \
          "${{lausanne_binds[@]}}" \
          "${{t1w_override_binds[@]}}" \
          "${{act_binds[@]}}" \
          "${{tractography_binds[@]}}" \
          "${{connectome_entrypoint_binds[@]}}" \
          -B "{FS_SUBJECTS_DIR}":/subjects:ro \
          -B "{QSIRECON_OUT}":/qsirecon:ro \
          -B "{QSIPREP_OUT}":/qsiprep:ro \
          -B "{BIDS_DIR}":/bids:ro \
          -B "{params.outdir}":/out \
          -B "{FS_LICENSE}":/opt/freesurfer/license.txt:ro \
          "{CONTAINER_CONNECTOME}" \
          --freesurfer-subject "/subjects/sub-${{SUBJECT}}" \
          --segmentation "${{seg_container_path}}" \
          --tractogram "${{tracks_in_container}}" \
          --dwiref "${{dwiref_in_container}}" \
          --preproc-t1w "${{preproc_t1w_in_container}}" \
          --bids-t1w "${{bids_t1w_in_container}}" \
          --preproc-dwi "${{preproc_dwi_in_container}}" \
          --bval "${{bval_in_container}}" \
          --bvec "${{bvec_in_container}}" \
          --brain-mask "${{brain_mask_in_container}}" \
          --output-dir /out \
          --fs-license /opt/freesurfer/license.txt \
          --primary-measure "{params.primary_measure}" \
          "${{lut_args[@]}}" \
          --subject-id "sub-${{SUBJECT}}"

        lut_used="fs_default.txt"; atlas="Desikan-Killiany"; node_count=84
        if [[ "{params.parc}" == "dkt" ]]; then
          lut_used="fs_dkt.txt"; atlas="Desikan-Killiany-Tourville"; node_count=78
        elif [[ "{params.parc}" == "lausanne60" ]]; then
          lut_used="lausanne60_mrtrix_lut.txt"; atlas="Lausanne-60"; node_count={LAUSANNE60_NODE_COUNT}
        fi

        mv -f "{params.outdir}/connectome.csv" "{output.matrix}"
        mv -f "{params.outdir}/connectome_count.csv" "{output.count_matrix}"
        mv -f "{params.outdir}/connectome_meanlength.csv" "{output.meanlength_matrix}"
        mv -f "{params.outdir}/connectome_meanfa.csv" "{output.meanfa_matrix}"
        mv -f "{params.outdir}/connectome_meanmd.csv" "{output.meanmd_matrix}"
        mv -f "{params.outdir}/desc-FA_dwi.nii.gz" "{output.fa_map}"
        mv -f "{params.outdir}/desc-MD_dwi.nii.gz" "{output.md_map}"
        cp -f "{params.outdir}/nodes.mif" "{output.nodes}"
        for other in dk dkt lausanne60; do
          if [[ "${{other}}" != "{params.parc}" ]]; then
            rm -f "{params.outdir}/${{other}}_connectome"*.csv
            rm -f "{params.outdir}/${{other}}_desc-FA_dwi.nii.gz" \
                  "{params.outdir}/${{other}}_desc-MD_dwi.nii.gz"
          fi
        done

        empty_nodes="$(_count_empty_nodes "{output.count_matrix}")"
        if [[ "${{empty_nodes}}" -gt 0 ]]; then
          echo "WARNING: ${{empty_nodes}} of ${{node_count}} ${{atlas}} nodes received no streamlines."
          if [[ "{params.fail_on_empty}" == "1" ]]; then
            _pipeline_fail "connectome" "${{empty_nodes}} empty nodes (fail_on_empty_nodes=true)"
          fi
        fi

        cat > "{params.parcellation_json}" <<EOF
{{
  "parcellation": "{params.parc}",
  "atlas": "${{atlas}}",
  "nodes": ${{node_count}},
  "labelconvert_lut": "${{lut_used}}",
  "primary_measure": "{params.primary_measure}",
  "act_mode": "{ACT_MODE}",
  "experiment_arm": "{EXPERIMENT_ARM}",
  "connectome_csv": "$(basename "{output.matrix}")",
  "matrices": {{
    "count": "$(basename "{output.count_matrix}")",
    "sift2": null,
    "meanlength": "$(basename "{output.meanlength_matrix}")",
    "meanfa": "$(basename "{output.meanfa_matrix}")",
    "meanmd": "$(basename "{output.meanmd_matrix}")"
  }},
  "tensor_maps": {{
    "fa": "$(basename "{output.fa_map}")",
    "md": "$(basename "{output.md_map}")"
  }},
  "nodes_image": "$(basename "{output.nodes}")",
  "empty_nodes": ${{empty_nodes}},
  "deterministic": {params.deterministic},
  "freesurfer_subject_dir": "{params.fs_dir}",
  "aparc_aseg": "${{aparc}}"
}}
EOF
        echo "Primary connectome: {output.matrix} ({params.primary_measure})"
        echo "Count: {output.count_matrix}"
        echo "MeanLength: {output.meanlength_matrix}"
        echo "MeanFA: {output.meanfa_matrix}"
        echo "MeanMD: {output.meanmd_matrix}"
        echo "FA map: {output.fa_map}"
        echo "MD map: {output.md_map}"
        echo "Atlas: ${{atlas}} (${{node_count}} nodes)"
        """


if CONNECTOME_SIFT2_ENABLED:
    rule connectome_sift2:
        input:
            nodes=CONNECTOME_NODES_PATTERN,
            count_matrix=CONNECTOME_COUNT_PATTERN,
            qsirecon_marker=lambda wc: qsirecon_marker(wc.subject),
            lesion_act=lambda wc: lesion_act_products(wc.subject),
        output:
            sift2_matrix=CONNECTOME_SIFT2_PATTERN,
        threads: 2
        log:
            f"{RESULTS_ROOT}/logs/sub-{{subject}}_connectome_sift2_{{parc}}.log",
        params:
            outdir=lambda wc: f"{CONNECTOME_OUT}/sub-{wc.subject}",
            parcellation_json=lambda wc: connectome_parcellation_json(wc.subject, wc.parc),
            primary_matrix=lambda wc: CONNECTOME_MATRIX_PATTERN.format(
                subject=wc.subject, parc=wc.parc
            ),
            primary_measure=CONNECTOME_PRIMARY_MEASURE,
            session=lambda wc: resolve_session(wc.subject),
        shell:
            r"""
            exec > {log} 2>&1
            set -euo pipefail
            source {COMMON_SH}
            SUBJECT="{wildcards.subject}"

            if [[ "{ACT_MODE}" == "lesion-aware" ]]; then
              tracks="{LESION_AWARE_ACT_OUT}/sub-${{SUBJECT}}/model-ifod2_streamlines.tck"
              [[ -f "${{tracks}}" ]] || _pipeline_fail "connectome_sift2/tractogram" \
                "missing lesion-aware tractogram: ${{tracks}}"
              tracks_in_container="/lesion_act/sub-${{SUBJECT}}/model-ifod2_streamlines.tck"
              sift2_weights="$(_find_sift2_weights "{QSIRECON_OUT}" "{LESION_AWARE_ACT_OUT}" "${{SUBJECT}}")"
              weights_in_container="/lesion_act/sub-${{SUBJECT}}/model-sift2_streamlineweights.csv"
              act_binds=(-B "{LESION_AWARE_ACT_OUT}":/lesion_act:ro)
              tractography_binds=()
            else
              tracks="$(_find_ifod2_tractogram "{QSIRECON_OUT}" "{TRACTOGRAPHY_OUT}" "" "${{SUBJECT}}")"
              tractography_binds=()
              if [[ "${{tracks}}" == "{TRACTOGRAPHY_OUT}/sub-${{SUBJECT}}/model-ifod2_streamlines.tck" ]]; then
                tracks_in_container="/tractography/sub-${{SUBJECT}}/model-ifod2_streamlines.tck"
                tractography_binds=(-B "{TRACTOGRAPHY_OUT}":/tractography:ro)
                sift2_weights="{TRACTOGRAPHY_OUT}/sub-${{SUBJECT}}/model-ifod2_sift2weights.csv"
                weights_in_container="/tractography/sub-${{SUBJECT}}/model-ifod2_sift2weights.csv"
              else
                tracks_rel="${{tracks#{QSIRECON_OUT}/}}"
                tracks_in_container="/qsirecon/${{tracks_rel}}"
                sift2_weights="$(_find_sift2_weights "{QSIRECON_OUT}" "" "${{SUBJECT}}")"
                w_rel="${{sift2_weights#{QSIRECON_OUT}/}}"
                weights_in_container="/qsirecon/${{w_rel}}"
              fi
              act_binds=()
            fi

            mkdir -p "{params.outdir}"
            if [[ "${{tracks}}" == *.tck.gz ]]; then
              tck_staged="{params.outdir}/streamlines_sift2.tck"
              echo "Decompressing ${{tracks}} -> ${{tck_staged}}"
              gunzip -c "${{tracks}}" > "${{tck_staged}}"
              tracks_in_container="/connectomes/sub-${{SUBJECT}}/streamlines_sift2.tck"
            fi

            echo "SIFT2 connectome: tractogram=${{tracks}}"
            echo "SIFT2 connectome: weights=${{sift2_weights}}"

            apptainer exec --cleanenv --containall \
              --env "LD_LIBRARY_PATH=/opt/ants/lib:/opt/mrtrix3-latest/lib" \
              "${{act_binds[@]}}" \
              "${{tractography_binds[@]}}" \
              -B "{QSIRECON_OUT}":/qsirecon:ro \
              -B "{CONNECTOME_OUT}":/connectomes \
              "{CONTAINER_CONNECTOME}" \
              bash -lc "
                set -euo pipefail
                tck2connectome -force \
                  ${{tracks_in_container}} \
                  /connectomes/sub-${{SUBJECT}}/{wildcards.parc}_nodes.mif \
                  /connectomes/sub-${{SUBJECT}}/{wildcards.parc}_connectome_sift2.csv \
                  -symmetric -zero_diagonal \
                  -tck_weights_in ${{weights_in_container}}
              "

            if [[ "{params.primary_measure}" == "sift2" ]]; then
              cp -f "{output.sift2_matrix}" "{params.primary_matrix}"
              echo "Primary connectome alias updated from SIFT2: {params.primary_matrix}"
            fi

            {PIPELINE_PYTHON} - "{params.parcellation_json}" "{output.sift2_matrix}" \
              "{params.primary_measure}" <<'PY'
import json, sys
from pathlib import Path
json_path, sift2_path, primary = sys.argv[1:4]
payload = {{}}
path = Path(json_path)
if path.is_file():
    payload = json.loads(path.read_text())
matrices = payload.setdefault("matrices", {{}})
matrices["sift2"] = Path(sift2_path).name
if primary == "sift2":
    payload["primary_measure"] = "sift2"
    payload["connectome_csv"] = Path(sift2_path).name
path.write_text(json.dumps(payload, indent=2) + "\n")
PY

            echo "SIFT2 connectome: {output.sift2_matrix}"
            """

