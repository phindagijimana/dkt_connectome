"""Step 3.5: rebuild matched iFOD2/SIFT2 tractography with lesion-aware ACT."""

ACT_MODE = str(ACT_CFG.get("mode", "standard")).lower()
if ACT_MODE not in ("standard", "lesion-aware"):
    raise WorkflowError(f"invalid act.mode={ACT_MODE} (use standard or lesion-aware)")

ACT_STREAMLINES = int(ACT_CFG.get("streamlines", 10_000_000))
ACT_RANDOM_SEED = int(ACT_CFG.get("random_seed", 0))
ACT_CUTOFF = float(ACT_CFG.get("cutoff", 0.05))
ACT_MIN_LENGTH = float(ACT_CFG.get("min_length_mm", 30))
ACT_MAX_LENGTH = float(ACT_CFG.get("max_length_mm", 250))

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


rule lesion_aware_act:
    input:
        qsirecon_marker=lambda wc: qsirecon_marker(wc.subject),
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

        five_tt="$(_strict_find_one "lesion-aware-act/5tt" \
          find "{QSIRECON_OUT}" -type f -path "*sub-${{SUBJECT}}/anat/*" \
            -name '*space-ACPC_seg-hsvs_probseg.nii.gz')"
        wm_fod="$(_strict_find_one "lesion-aware-act/wm-fod" \
          find "{QSIRECON_OUT}" -type f -path "*sub-${{SUBJECT}}/ses-${{SESSION}}/dwi/*" \
            -name '*model-ss3t_param-fod_label-WM_dwimap.mif.gz')"
        dwiref="$(_strict_find_one "lesion-aware-act/dwiref" \
          find "{QSIPREP_OUT}" -type f -path "*sub-${{SUBJECT}}/ses-${{SESSION}}/dwi/*" \
            -name '*space-T1w_dwiref.nii.gz')"
        orig_to_t1w="$(_strict_find_one "lesion-aware-act/orig-to-T1w" \
          find "{QSIPREP_OUT}" -type f -path "*sub-${{SUBJECT}}/ses-${{SESSION}}/anat/*" \
            \( -name '*from-orig_to-T1w_mode-image_xfm.txt' \
               -o -name '*from-orig_to-T1w_mode-image_xfm.mat' \))"

        python3 "{PREPARE_LESION_MASK}" \
          --t1w "{input.t1w}" --mask "{input.lesion}" \
          --out "{params.outdir}/lesion_mask_t1w.nii.gz" \
          --json "{params.outdir}/lesion_mask_t1w.json" \
          --labels "{INPAINT_LABELS}" --binarize

        five_tt_rel="${{five_tt#{QSIRECON_OUT}/}}"
        wm_fod_rel="${{wm_fod#{QSIRECON_OUT}/}}"
        dwiref_rel="${{dwiref#{QSIPREP_OUT}/}}"
        xfm_rel="${{orig_to_t1w#{QSIPREP_OUT}/}}"

        apptainer exec --cleanenv --containall \
          --env "LD_LIBRARY_PATH=/opt/ants/lib:/opt/mrtrix3-latest/lib" \
          -B "{QSIRECON_OUT}":/qsirecon:ro \
          -B "{QSIPREP_OUT}":/qsiprep:ro \
          -B "{params.outdir}":/out \
          "{CONTAINER_QSIRECON}" \
          bash -lc "
            set -euo pipefail
            export MRTRIX_RNG_SEED={ACT_RANDOM_SEED}
            antsApplyTransforms -d 3 \
              -i /out/lesion_mask_t1w.nii.gz \
              -r /qsiprep/${{dwiref_rel}} \
              -t /qsiprep/${{xfm_rel}} \
              -n GenericLabel \
              -o /out/lesion_mask_in_dwi.nii.gz
            [[ \"\$(mrstats /out/lesion_mask_in_dwi.nii.gz -output max)\" != \"0\" ]] || {{
              echo 'ERROR: transformed lesion mask is empty' >&2
              exit 1
            }}
            mrtransform -force \
              /qsirecon/${{five_tt_rel}} \
              -template /qsiprep/${{dwiref_rel}} \
              -interp linear \
              /out/base_5tt_resampled.mif
            mrcalc -force /out/base_5tt_resampled.mif 0 -max 1 -min \
              /out/base_5tt_clipped.mif
            mrmath -force /out/base_5tt_clipped.mif sum /out/base_5tt_sum.mif \
              -axis 3
            mrcalc -force /out/base_5tt_sum.mif 0.000001 -max \
              /out/base_5tt_denominator.mif
            mrcalc -force /out/base_5tt_clipped.mif \
              /out/base_5tt_denominator.mif -div /out/base_5tt.mif
            5ttedit -force /out/base_5tt.mif /out/lesion_aware_5tt.mif \
              -path /out/lesion_mask_in_dwi.nii.gz
            5ttcheck /out/lesion_aware_5tt.mif
            mrconvert -force -quiet /out/lesion_aware_5tt.mif \
              -coord 3 4 /out/pathology_channel.mif
            mrcalc -force -quiet /out/pathology_channel.mif \
              /out/lesion_mask_in_dwi.nii.gz -sub -abs \
              /out/lesion_mask_in_dwi.nii.gz -mult /out/pathology_lesion_diff.mif
            [[ \"\$(mrstats /out/pathology_lesion_diff.mif -output max)\" == \"0\" ]] || {{
              echo 'ERROR: lesion voxels were not fully assigned to 5TT pathology' >&2
              exit 1
            }}
            5tt2gmwmi -force /out/lesion_aware_5tt.mif /out/gmwmi.mif
            tckgen -force \
              /qsirecon/${{wm_fod_rel}} \
              /out/model-ifod2_streamlines.tck \
              -algorithm iFOD2 \
              -act /out/lesion_aware_5tt.mif \
              -seed_dynamic /qsirecon/${{wm_fod_rel}} \
              -backtrack -crop_at_gmwmi \
              -cutoff {ACT_CUTOFF} \
              -minlength {ACT_MIN_LENGTH} \
              -maxlength {ACT_MAX_LENGTH} \
              -select {ACT_STREAMLINES} \
              -nthreads {threads}
            tcksift2 -force \
              /out/model-ifod2_streamlines.tck \
              /qsirecon/${{wm_fod_rel}} \
              /out/model-sift2_streamlineweights.csv \
              -act /out/lesion_aware_5tt.mif \
              -nthreads {threads}
          "

        python3 - "{output.provenance}" "{input.lesion}" "${{five_tt}}" "${{wm_fod}}" \
          "${{dwiref}}" "${{orig_to_t1w}}" <<'PY'
import json, sys
out, lesion, five_tt, wm_fod, dwiref, xfm = sys.argv[1:]
payload = {{
    "subject": "sub-{wildcards.subject}",
    "session": "ses-{params.session}",
    "act_mode": "lesion-aware",
    "lesion_mask_source": lesion,
    "lesion_mask_in_dwi": "{output.lesion_dwi}",
    "base_5tt": five_tt,
    "lesion_aware_5tt": "{output.five_tt}",
    "wm_fod": wm_fod,
    "dwiref": dwiref,
    "orig_to_t1w_transform": xfm,
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
