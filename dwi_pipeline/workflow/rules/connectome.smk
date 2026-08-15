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
    parc=r"dk|dkt"

CONNECTOME_MATRIX_PATTERN = f"{CONNECTOME_OUT}/sub-{{subject}}/{{parc}}_connectome.csv"
CONNECTOME_PARCJSON_PATTERN = f"{CONNECTOME_OUT}/sub-{{subject}}/parcellation.json"

CONNECTOME_PARCELLATION_CFG = str(CONNECTOME_CFG.get("parcellation", "dkt"))
CONNECTOME_DETERMINISTIC = bool(CONNECTOME_CFG.get("deterministic", True))
CONNECTOME_FAIL_ON_EMPTY_NODES = bool(CONNECTOME_CFG.get("fail_on_empty_nodes", False))
CONNECTOME_RESAMPLE_TO_DWI = bool(CONNECTOME_CFG.get("resample_to_dwi", True))
CONNECTOME_WEIGHTING = str(CONNECTOME_CFG.get("weighting", "count")).lower()


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


def connectome_matrix(subject: str) -> str:
    return CONNECTOME_MATRIX_PATTERN.format(subject=subject, parc=resolved_parcellation(subject))


def connectome_parcellation_json(subject: str) -> str:
    return CONNECTOME_PARCJSON_PATTERN.format(subject=subject)


def connectome_registration_t1w_input(subject: str):
    """If Step 1.5 ran for this subject, connectome must wait for it and use
    its result as the affine-registration source (see subject.sh's
    _resolve_registration_t1w); otherwise no such dependency exists."""
    return inpainted_t1w_for(subject) or []


rule connectome:
    input:
        aparc=lambda wc: recon_aparc(wc.subject),
        qsirecon_marker=lambda wc: qsirecon_marker(wc.subject),
        registration_t1w=lambda wc: connectome_registration_t1w_input(wc.subject),
    output:
        # parcellation.json is not declared here (Snakemake requires every
        # output of a rule to share the same wildcard set, and this file's
        # name -- unlike the matrix -- doesn't vary with {parc}); it's still
        # written by the shell block below, just not skip/rerun-tracked.
        matrix=CONNECTOME_MATRIX_PATTERN,
    threads: 4
    log:
        f"{RESULTS_ROOT}/logs/sub-{{subject}}_connectome_{{parc}}.log",
    params:
        parc=lambda wc: wc.parc,
        fs_dir=lambda wc: f"{FS_SUBJECTS_DIR}/sub-{wc.subject}",
        outdir=lambda wc: f"{CONNECTOME_OUT}/sub-{wc.subject}",
        parcellation_json=lambda wc: connectome_parcellation_json(wc.subject),
        lut_dkt=CONNECTOME_LUT_DKT,
        deterministic="1" if CONNECTOME_DETERMINISTIC else "0",
        fail_on_empty="1" if CONNECTOME_FAIL_ON_EMPTY_NODES else "0",
        weighting=CONNECTOME_WEIGHTING,
    shell:
        r"""
        exec > {log} 2>&1
        set -euo pipefail
        source {COMMON_SH}
        SUBJECT="{wildcards.subject}"

        [[ "{CONNECTOME_RESAMPLE_TO_DWI}" == "True" ]] || \
          _pipeline_fail "connectome" "connectome.resample_to_dwi must be true (strict pipeline)"

        # Replace any prior connectome dir for this subject (resume-safe)
        rm -rf "{params.outdir}"
        mkdir -p "{params.outdir}"
        aparc="{input.aparc}"

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

        tracks="$(_strict_find_one "connectome/tractogram" \
          find "{QSIRECON_OUT}" -type f -path "*sub-${{SUBJECT}}*" \
            \( -name '*.tck' -o -name '*.tck.gz' \))"
        tracks_rel="${{tracks#{QSIRECON_OUT}/}}"
        tracks_in_container="/qsirecon/${{tracks_rel}}"

        ses="$(_bids_ses_from_path "${{tracks}}")"
        [[ -n "${{ses}}" ]] || _pipeline_fail "connectome/session" "tractogram path has no ses-* entity: ${{tracks}}"

        dwiref="$(_strict_find_one "connectome/dwiref" \
          find "{QSIPREP_OUT}" -type f -path "*sub-${{SUBJECT}}*/ses-${{ses}}/*" \
            -name '*space-T1w_dwiref.nii.gz')"
        preproc_t1w="$(find_qsiprep_preproc_t1w "{QSIPREP_OUT}" "${{SUBJECT}}" "${{ses}}")"

        if [[ -n "{input.registration_t1w}" ]]; then
          bids_t1w="{input.registration_t1w}"
          echo "Connectome: using Step 1.5 inpainted T1w for registration: ${{bids_t1w}}"
        else
          bids_t1w="$(find_bids_t1w "${{SUBJECT}}" "${{ses}}")"
        fi

        dwiref_rel="${{dwiref#{QSIPREP_OUT}/}}"
        preproc_t1w_rel="${{preproc_t1w#{QSIPREP_OUT}/}}"
        dwiref_in_container="/qsiprep/${{dwiref_rel}}"
        preproc_t1w_in_container="/qsiprep/${{preproc_t1w_rel}}"

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
        echo "Using BIDS T1w (affine reg source): ${{bids_t1w}}"
        echo "Connectome weighting: {params.weighting}"

        sift2_weights=""
        if [[ "{params.weighting}" == "sift2" ]]; then
          sift2_weights="$(_strict_find_one "connectome/sift2_weights" \
            find "{QSIRECON_OUT}" -type f -path "*sub-${{SUBJECT}}*" \
              -name '*model-sift2_streamlineweights.csv')"
          echo "Using SIFT2 weights: ${{sift2_weights}}"
        fi

        binds=()
        lut_args=()
        if [[ "{params.parc}" == "dkt" ]]; then
          [[ -f "{params.lut_dkt}" ]] || _pipeline_fail "connectome" "missing DKT LUT: {params.lut_dkt}"
          binds+=(-B "{params.lut_dkt}":/lut/fs_dkt.txt:ro)
          lut_args+=(--mrtrix-lut /lut/fs_dkt.txt)
        fi

        env_args=()
        if [[ "{params.deterministic}" == "1" ]]; then
          env_args+=(--env "ITK_GLOBAL_DEFAULT_NUMBER_OF_THREADS=1" --env "ANTS_RANDOM_SEED=1")
        fi

        sift2_args=()
        if [[ -n "${{sift2_weights}}" ]]; then
          w_rel="${{sift2_weights#{QSIRECON_OUT}/}}"
          sift2_args=(--sift2-weights "/qsirecon/${{w_rel}}")
        fi

        apptainer run --cleanenv --containall \
          --home /tmp \
          --env "LD_LIBRARY_PATH=/opt/ants/lib:/opt/mrtrix3-latest/lib" \
          "${{env_args[@]}}" \
          "${{binds[@]}}" \
          "${{t1w_override_binds[@]}}" \
          -B "{FS_SUBJECTS_DIR}":/subjects:ro \
          -B "{QSIRECON_OUT}":/qsirecon:ro \
          -B "{QSIPREP_OUT}":/qsiprep:ro \
          -B "{BIDS_DIR}":/bids:ro \
          -B "{params.outdir}":/out \
          -B "{FS_LICENSE}":/opt/freesurfer/license.txt:ro \
          "{CONTAINER_CONNECTOME}" \
          --freesurfer-subject "/subjects/sub-${{SUBJECT}}" \
          --segmentation "$(basename "${{aparc}}")" \
          --tractogram "${{tracks_in_container}}" \
          --dwiref "${{dwiref_in_container}}" \
          --preproc-t1w "${{preproc_t1w_in_container}}" \
          --bids-t1w "${{bids_t1w_in_container}}" \
          --output-dir /out \
          --fs-license /opt/freesurfer/license.txt \
          "${{sift2_args[@]}}" \
          "${{lut_args[@]}}" \
          --subject-id "sub-${{SUBJECT}}"

        lut_used="fs_default.txt"; atlas="Desikan-Killiany"; node_count=84
        if [[ "{params.parc}" == "dkt" ]]; then
          lut_used="fs_dkt.txt"; atlas="Desikan-Killiany-Tourville"; node_count=78
        fi

        mv -f "{params.outdir}/connectome.csv" "{output.matrix}"
        for other in dk dkt; do
          [[ "${{other}}" == "{params.parc}" ]] || rm -f "{params.outdir}/${{other}}_connectome.csv"
        done

        empty_nodes="$(_count_empty_nodes "{output.matrix}")"
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
  "connectome_csv": "$(basename "{output.matrix}")",
  "empty_nodes": ${{empty_nodes}},
  "deterministic": {params.deterministic},
  "freesurfer_subject_dir": "{params.fs_dir}",
  "aparc_aseg": "${{aparc}}"
}}
EOF
        echo "Connectome: {output.matrix} (${{atlas}}, ${{node_count}} nodes)"
        """
