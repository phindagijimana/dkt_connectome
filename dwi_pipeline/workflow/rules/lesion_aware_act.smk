"""Step 3.5: rebuild matched iFOD2/SIFT2 tractography with lesion-aware ACT."""

ACT_MODE = str(ACT_CFG.get("mode", "standard")).lower()
if ACT_MODE not in ("standard", "lesion-aware"):
    raise WorkflowError(f"invalid act.mode={ACT_MODE} (use standard or lesion-aware)")

if ACT_MODE == "lesion-aware" and ACT_FIVE_TT_SOURCE == "deep-atropos-native":
    # Validated at rule runtime via find_deep_atropos_segmentation when deep_atropos_5tt runs.
    pass

ACT_STREAMLINES = int(ACT_CFG.get("streamlines", 10_000_000))
ACT_RANDOM_SEED = int(ACT_CFG.get("random_seed", 0))
ACT_CUTOFF = float(ACT_CFG.get("cutoff", 0.05))
ACT_MIN_LENGTH = float(ACT_CFG.get("min_length_mm", 30))
ACT_MAX_LENGTH = float(ACT_CFG.get("max_length_mm", 250))
EXPERIMENT_ARM = str(EXPERIMENT_CFG.get("arm") or "")

LESION_ACT_5TT_PATTERN = f"{LESION_AWARE_ACT_OUT}/sub-{{subject}}/lesion_aware_5tt.mif"
LESION_ACT_MASK_PATTERN = f"{LESION_AWARE_ACT_OUT}/sub-{{subject}}/lesion_mask_in_dwi.nii.gz"
LESION_ACT_TRACKS_PATTERN = f"{LESION_AWARE_ACT_OUT}/sub-{{subject}}/model-ifod2_streamlines.tck"
LESION_ACT_WEIGHTS_PATTERN = f"{LESION_AWARE_ACT_OUT}/sub-{{subject}}/model-sift2_streamlineweights.csv"
LESION_ACT_JSON_PATTERN = f"{LESION_AWARE_ACT_OUT}/sub-{{subject}}/lesion_aware_act.json"


def lesion_act_tracks(subject: str) -> str:
    return LESION_ACT_TRACKS_PATTERN.format(subject=subject)


def lesion_act_weights(subject: str) -> str:
    return LESION_ACT_WEIGHTS_PATTERN.format(subject=subject)


def lesion_act_products(subject: str) -> list[str]:
    if ACT_MODE != "lesion-aware":
        return []
    return [
        pattern.format(subject=subject)
        for pattern in (
            LESION_ACT_5TT_PATTERN,
            LESION_ACT_MASK_PATTERN,
            LESION_ACT_TRACKS_PATTERN,
            LESION_ACT_WEIGHTS_PATTERN,
            LESION_ACT_JSON_PATTERN,
        )
    ]


def lesion_act_mask(subject: str) -> str:
    session = resolve_session(subject)
    mask = find_lesion_mask(subject, session)
    if not mask:
        raise WorkflowError(
            f"act.mode=lesion-aware requires a lesion mask for "
            f"sub-{subject} ses-{session}"
        )
    return mask


def _lesion_act_base_5tt_dep(wildcards) -> str:
    """Ensure QSIRecon (HSVS) or Deep Atropos 5TT completes before Step 3.5."""
    if ACT_FIVE_TT_SOURCE == "deep-atropos-native":
        return deep_atropos_base_5tt(wildcards.subject)
    return qsirecon_marker(wildcards.subject)


rule lesion_aware_act:
    input:
        base_5tt_dep=lambda wc: _lesion_act_base_5tt_dep(wc),
        t1w=lambda wc: _bids_t1w_for(wc.subject, resolve_session(wc.subject)),
        lesion=lambda wc: lesion_act_mask(wc.subject),
    output:
        five_tt=LESION_ACT_5TT_PATTERN,
        lesion_dwi=LESION_ACT_MASK_PATTERN,
        tracks=LESION_ACT_TRACKS_PATTERN,
        weights=LESION_ACT_WEIGHTS_PATTERN,
        provenance=LESION_ACT_JSON_PATTERN,
    threads: 8
    log:
        f"{RESULTS_ROOT}/logs/sub-{{subject}}_lesion_aware_act.log",
    params:
        outdir=lambda wc: f"{LESION_AWARE_ACT_OUT}/sub-{wc.subject}",
        session=lambda wc: resolve_session(wc.subject),
        deep_atropos_5tt=lambda wc: (
            f"{DEEP_ATROPOS_OUT}/sub-{wc.subject}/base_5tt_native.mif"
            if ACT_FIVE_TT_SOURCE == "deep-atropos-native"
            else ""
        ),
        deep_atropos_seg=lambda wc: (
            find_deep_atropos_segmentation(wc.subject, resolve_session(wc.subject))
            if ACT_FIVE_TT_SOURCE == "deep-atropos-native"
            else ""
        ),
    shell:
        r"""
        exec > {log} 2>&1
        set -euo pipefail
        source {COMMON_SH}
        SUBJECT="{wildcards.subject}"
        SESSION="{params.session}"
        [[ "{ACT_MODE}" == "lesion-aware" ]] || \
          _pipeline_fail "lesion-aware-act" "rule invoked with act.mode={ACT_MODE}"
        mkdir -p "{params.outdir}"

        wm_fod="$(_strict_find_one "lesion-aware-act/wm-fod" \
          find -L "{QSIRECON_OUT}" -type f -path "*sub-${{SUBJECT}}/ses-${{SESSION}}/dwi/*" \
            -name '*model-ss3t_param-fod_label-WM_dwimap.mif.gz')"
        dwiref="$(_strict_find_one "lesion-aware-act/dwiref" \
          find -L "{QSIPREP_OUT}" -type f -path "*sub-${{SUBJECT}}/ses-${{SESSION}}/dwi/*" \
            -name '*space-T1w_dwiref.nii.gz')"
        preproc_t1w="$(find_qsiprep_preproc_t1w "{QSIPREP_OUT}" "${{SUBJECT}}" "${{SESSION}}")"
        native_to_acpc="$(find_qsiprep_native_to_acpc "{QSIPREP_OUT}" "${{SUBJECT}}" "${{SESSION}}" || true)"

        if [[ "{ACT_FIVE_TT_SOURCE}" == "deep-atropos-native" ]]; then
          five_tt="{params.deep_atropos_5tt}"
          [[ -f "${{five_tt}}" ]] || _pipeline_fail "lesion-aware-act/5tt" "missing Deep Atropos base 5TT: ${{five_tt}}"
          five_tt_container="/deep_atropos/base_5tt_native.mif"
          deep_atropos_bind=(-B "$(dirname "${{five_tt}}")":/deep_atropos:ro)
        else
          five_tt="$(_strict_find_one "lesion-aware-act/5tt" \
            find -L "{QSIRECON_OUT}" -type f -path "*sub-${{SUBJECT}}/anat/*" \
              -name '*space-ACPC_seg-hsvs_probseg.nii.gz')"
          five_tt_rel="${{five_tt#{QSIRECON_OUT}/}}"
          five_tt_container="/qsirecon/${{five_tt_rel}}"
          deep_atropos_bind=()
        fi

        {PIPELINE_PYTHON} "{PREPARE_LESION_MASK}" \
          --t1w "{input.t1w}" --mask "{input.lesion}" \
          --out "{params.outdir}/lesion_mask_t1w.nii.gz" \
          --json "{params.outdir}/lesion_mask_t1w.json" \
          --labels "{INPAINT_LABELS}" --binarize

        wm_fod_rel="${{wm_fod#{QSIRECON_OUT}/}}"
        dwiref_rel="${{dwiref#{QSIPREP_OUT}/}}"
        preproc_rel="${{preproc_t1w#{QSIPREP_OUT}/}}"
        native_rel=""
        if [[ -n "${{native_to_acpc}}" ]]; then
          native_rel="${{native_to_acpc#{QSIPREP_OUT}/}}"
        fi

        _lesion_act_args=(
          --five-tt "${{five_tt_container}}"
          --five-tt-source "{ACT_FIVE_TT_SOURCE}"
          --wm-fod "/qsirecon/${{wm_fod_rel}}"
          --dwiref "/qsiprep/${{dwiref_rel}}"
          --lesion-mask-t1w "/out/lesion_mask_t1w.nii.gz"
          --bids-t1w "/bids_t1w/$(basename "{input.t1w}")"
          --preproc-t1w "/qsiprep/${{preproc_rel}}"
          --outdir /out
          --streamlines {ACT_STREAMLINES}
          --random-seed {ACT_RANDOM_SEED}
          --cutoff {ACT_CUTOFF}
          --min-length-mm {ACT_MIN_LENGTH}
          --max-length-mm {ACT_MAX_LENGTH}
          --threads {threads}
        )
        if [[ -n "${{native_rel}}" ]]; then
          _lesion_act_args+=(--native-to-acpc "/qsiprep/${{native_rel}}")
        fi

        apptainer run --cleanenv --containall \
          --env "LD_LIBRARY_PATH=/opt/ants/lib:/opt/mrtrix3-latest/lib" \
          -B "{QSIRECON_OUT}":/qsirecon:ro \
          -B "{QSIPREP_OUT}":/qsiprep:ro \
          -B "$(dirname "{input.t1w}")":/bids_t1w:ro \
          -B "{params.outdir}":/out \
          "${{deep_atropos_bind[@]}}" \
          "{CONTAINER_LESION_ACT}" \
          "${{_lesion_act_args[@]}}"

        recon_t1w="{input.t1w}"
        if [[ "{ANATOMY_MITIGATION_BACKEND}" != "none" ]]; then
          _inpaint_t1w="$(find "{ANATOMY_MITIGATION_OUT}" -type f \
            -path "*sub-${{SUBJECT}}/ses-${{SESSION}}/*" \
            -name 'inpainting_result.nii.gz' 2>/dev/null | head -1 || true)"
          [[ -n "${{_inpaint_t1w}}" ]] && recon_t1w="${{_inpaint_t1w}}"
        fi

        lesion_warp_method="$(cat "{params.outdir}/lesion_warp_method.txt")"
        spatial_workflow="$(cat "{params.outdir}/spatial_workflow.txt")"

        {PIPELINE_PYTHON} - "{output.provenance}" "{input.lesion}" "${{five_tt}}" "${{wm_fod}}" \
          "${{dwiref}}" "${{preproc_t1w}}" "${{native_to_acpc}}" "${{recon_t1w}}" \
          "${{lesion_warp_method}}" "${{spatial_workflow}}" "{params.deep_atropos_seg}" <<'PY'
import json, sys
(out, lesion, five_tt, wm_fod, dwiref, preproc_t1w, native_xfm, recon_t1w,
 warp_method, spatial_workflow, deep_atropos_seg) = sys.argv[1:]
_anat_backend = "{ANATOMY_MITIGATION_BACKEND}"
_recon_from_inpaint = _anat_backend != "none"
_five_tt_source = "{ACT_FIVE_TT_SOURCE}"
outdir = "{params.outdir}"
payload = {{
    "subject": "sub-{wildcards.subject}",
    "session": "ses-{params.session}",
    "experiment_arm": "{EXPERIMENT_ARM}" or None,
    "act_mode": "lesion-aware",
    "five_tt_source": _five_tt_source,
    "factorial_design": "LeAPP-style anatomy x ACT orthogonal factors (Bey et al. 2024)",
    "anatomy_mitigation_backend": _anat_backend,
    "recon_anatomy_source": (
        "deep_atropos_on_original_bids_t1w"
        if _five_tt_source == "deep-atropos-native"
        else ("inpainted_t1w" if _recon_from_inpaint else "original_bids_t1w")
    ),
    "recon_t1w_used_for_hsvs_5tt": recon_t1w if _five_tt_source == "hsvs" else None,
    "deep_atropos_segmentation": deep_atropos_seg or None,
    "base_5tt_native": five_tt if _five_tt_source == "deep-atropos-native" else None,
    "act_lesion_mask_source": "original_bids_lesion_roi",
    "act_lesion_mask_reference_t1w": "{input.t1w}",
    "dwi_inpainted": False,
    "cross_source_factorial_intentional": _recon_from_inpaint or _five_tt_source == "deep-atropos-native",
    "cross_source_note": (
        "Deep Atropos 5TT on original BIDS T1w; ACT pathology from original BIDS lesion ROI."
        if _five_tt_source == "deep-atropos-native"
        else (
            "HSVS 5TT from inpainted recon; ACT pathology from original BIDS lesion ROI. "
            "Deliberate factorial contrast—not a registration error."
            if _recon_from_inpaint else
            "Recon and ACT both use original anatomy (orig-lesion arm)."
        )
    ),
    "spatial_workflow": spatial_workflow,
    "lesion_warp_method": warp_method,
    "lesion_mask_in_acpc_5tt": (
        f"{{outdir}}/lesion_in_acpc_5tt.nii.gz"
        if spatial_workflow == "acpc_5tt_edit_then_dwiref_resample" else None
    ),
    "lesion_mask_in_native_5tt": (
        f"{{outdir}}/lesion_in_native_5tt.nii.gz"
        if spatial_workflow == "native_5tt_edit_then_dwiref_resample" else None
    ),
    "lesion_aware_5tt_acpc": (
        f"{{outdir}}/lesion_aware_5tt_acpc.mif"
        if spatial_workflow == "acpc_5tt_edit_then_dwiref_resample" else None
    ),
    "lesion_aware_5tt_native": (
        f"{{outdir}}/lesion_aware_5tt_native.mif"
        if spatial_workflow == "native_5tt_edit_then_dwiref_resample" else None
    ),
    "five_tt_ref": f"{{outdir}}/five_tt_ref.nii.gz",
    "native_to_acpc_transform": native_xfm or None,
    "preproc_t1w": preproc_t1w,
    "lesion_mask_source": lesion,
    "lesion_mask_in_dwi": "{output.lesion_dwi}",
    "base_5tt": five_tt,
    "lesion_aware_5tt": "{output.five_tt}",
    "wm_fod": wm_fod,
    "dwiref": dwiref,
    "tractogram": "{output.tracks}",
    "sift2_weights": "{output.weights}",
    "algorithm": "iFOD2",
    "streamlines": {ACT_STREAMLINES},
    "random_seed": {ACT_RANDOM_SEED},
    "cutoff": {ACT_CUTOFF},
    "min_length_mm": {ACT_MIN_LENGTH},
    "max_length_mm": {ACT_MAX_LENGTH},
}}
with open(out, "w") as stream:
    json.dump(payload, stream, indent=2)
    stream.write("\n")
PY
        """
