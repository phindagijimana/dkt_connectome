"""Optional deterministic SD_STREAM tractography and matched connectomes."""

TRACTOGRAPHY_MODEL = str(TRACTOGRAPHY_CFG.get("model", "both")).lower()
if TRACTOGRAPHY_MODEL not in ("ifod2", "sd_stream", "both"):
    raise WorkflowError(
        f"invalid tractography.model={TRACTOGRAPHY_MODEL} "
        "(use ifod2, sd_stream, or both)"
    )


def sdstream_enabled() -> bool:
    return TRACTOGRAPHY_MODEL in ("sd_stream", "both")


SDSTREAM_TRACKS_PATTERN = f"{TRACTOGRAPHY_OUT}/sub-{{subject}}/model-SDSTREAM_streamlines.tck"
SDSTREAM_WEIGHTS_PATTERN = f"{TRACTOGRAPHY_OUT}/sub-{{subject}}/model-SDSTREAM_sift2weights.csv"
SDSTREAM_5TT_PATTERN = f"{TRACTOGRAPHY_OUT}/sub-{{subject}}/model-SDSTREAM_5tt.mif"
SDSTREAM_JSON_PATTERN = f"{TRACTOGRAPHY_OUT}/sub-{{subject}}/model-SDSTREAM.json"


def sdstream_tracks(subject: str) -> str:
    return SDSTREAM_TRACKS_PATTERN.format(subject=subject)


def sdstream_weights(subject: str) -> str:
    return SDSTREAM_WEIGHTS_PATTERN.format(subject=subject)


def sdstream_products(subject: str) -> list[str]:
    if not sdstream_enabled():
        return []
    return [
        pattern.format(subject=subject)
        for pattern in (
            SDSTREAM_TRACKS_PATTERN,
            SDSTREAM_WEIGHTS_PATTERN,
            SDSTREAM_5TT_PATTERN,
            SDSTREAM_JSON_PATTERN,
        )
    ]


rule sdstream_tractography:
    input:
        qsirecon_marker=lambda wc: qsirecon_marker(wc.subject),
        lesion_act=lambda wc: lesion_act_products(wc.subject),
    output:
        tracks=SDSTREAM_TRACKS_PATTERN,
        weights=SDSTREAM_WEIGHTS_PATTERN,
        five_tt=SDSTREAM_5TT_PATTERN,
        provenance=SDSTREAM_JSON_PATTERN,
    threads: 8
    log:
        f"{RESULTS_ROOT}/logs/sub-{{subject}}_sdstream.log",
    params:
        outdir=lambda wc: f"{TRACTOGRAPHY_OUT}/sub-{wc.subject}",
        session=lambda wc: resolve_session(wc.subject),
    shell:
        r"""
        exec > {log} 2>&1
        set -euo pipefail
        source {COMMON_SH}
        SUBJECT="{wildcards.subject}"
        SESSION="{params.session}"
        mkdir -p "{params.outdir}"

        wm_fod="$(_strict_find_one "sdstream/wm-fod" \
          find -L "{QSIRECON_OUT}" -type f -path "*sub-${{SUBJECT}}/ses-${{SESSION}}/dwi/*" \
            -name '*model-ss3t_param-fod_label-WM_dwimap.mif.gz')"
        dwiref="$(find_qsiprep_dwiref "sdstream/dwiref" "{QSIPREP_OUT}" "${{SUBJECT}}" "${{SESSION}}")"
        five_tt="$(_strict_find_one "sdstream/5tt" \
          find -L "{QSIRECON_OUT}" -type f -path "*sub-${{SUBJECT}}/anat/*" \
            -name '*space-ACPC_seg-hsvs_probseg.nii.gz')"
        wm_fod_rel="${{wm_fod#{QSIRECON_OUT}/}}"
        dwiref_rel="${{dwiref#{QSIPREP_OUT}/}}"
        five_tt_rel="${{five_tt#{QSIRECON_OUT}/}}"

        act_binds=()
        if [[ "{ACT_MODE}" == "lesion-aware" ]]; then
          act_binds=(-B "{LESION_AWARE_ACT_OUT}":/lesion_act:ro)
        fi

        apptainer exec --cleanenv --containall \
          -B "{QSIRECON_OUT}":/qsirecon:ro \
          -B "{QSIPREP_OUT}":/qsiprep:ro \
          -B "{params.outdir}":/out \
          "${{act_binds[@]}}" \
          "{CONTAINER_QSIRECON}" \
          bash -lc "
            set -euo pipefail
            export MRTRIX_RNG_SEED={ACT_RANDOM_SEED}
            if [[ '{ACT_MODE}' == 'lesion-aware' ]]; then
              mrconvert -force \
                /lesion_act/sub-${{SUBJECT}}/lesion_aware_5tt.mif \
                /out/model-SDSTREAM_5tt.mif
            else
              mrtransform -force \
                /qsirecon/${{five_tt_rel}} \
                -template /qsiprep/${{dwiref_rel}} \
                -interp linear /out/base_5tt_resampled.mif
              mrcalc -force /out/base_5tt_resampled.mif 0 -max 1 -min \
                /out/base_5tt_clipped.mif
              mrmath -force /out/base_5tt_clipped.mif sum /out/base_5tt_sum.mif \
                -axis 3
              mrcalc -force /out/base_5tt_sum.mif 0.000001 -max \
                /out/base_5tt_denominator.mif
              mrcalc -force /out/base_5tt_clipped.mif \
                /out/base_5tt_denominator.mif -div /out/model-SDSTREAM_5tt.mif
            fi
            5ttcheck /out/model-SDSTREAM_5tt.mif
            tckgen -force \
              /qsirecon/${{wm_fod_rel}} \
              /out/model-SDSTREAM_streamlines.tck \
              -algorithm SD_Stream \
              -act /out/model-SDSTREAM_5tt.mif \
              -seed_dynamic /qsirecon/${{wm_fod_rel}} \
              -crop_at_gmwmi \
              -cutoff {ACT_CUTOFF} \
              -minlength {ACT_MIN_LENGTH} \
              -maxlength {ACT_MAX_LENGTH} \
              -select {ACT_STREAMLINES} \
              -nthreads {threads}
            tcksift2 -force \
              /out/model-SDSTREAM_streamlines.tck \
              /qsirecon/${{wm_fod_rel}} \
              /out/model-SDSTREAM_sift2weights.csv \
              -act /out/model-SDSTREAM_5tt.mif \
              -nthreads {threads}
          "

        {PIPELINE_PYTHON} - "{output.provenance}" "${{wm_fod}}" "${{dwiref}}" "${{five_tt}}" <<'PY'
import json, sys
out, wm_fod, dwiref, five_tt = sys.argv[1:]
payload = {{
    "subject": "sub-{wildcards.subject}",
    "session": "ses-{params.session}",
    "model": "SD_STREAM",
    "act_mode": "{ACT_MODE}",
    "base_5tt": five_tt,
    "tracking_5tt": "{output.five_tt}",
    "wm_fod": wm_fod,
    "dwiref": dwiref,
    "tractogram": "{output.tracks}",
    "sift2_weights": "{output.weights}",
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


SD_COUNT_PATTERN = f"{CONNECTOME_OUT}/sub-{{subject}}/{{parc}}_model-SDSTREAM_connectome_count.csv"
SD_SIFT2_PATTERN = f"{CONNECTOME_OUT}/sub-{{subject}}/{{parc}}_model-SDSTREAM_connectome_sift2.csv"
SD_MEANLENGTH_PATTERN = f"{CONNECTOME_OUT}/sub-{{subject}}/{{parc}}_model-SDSTREAM_connectome_meanlength.csv"
SD_MEANFA_PATTERN = f"{CONNECTOME_OUT}/sub-{{subject}}/{{parc}}_model-SDSTREAM_connectome_meanfa.csv"
SD_MEANMD_PATTERN = f"{CONNECTOME_OUT}/sub-{{subject}}/{{parc}}_model-SDSTREAM_connectome_meanmd.csv"
SD_CONNECTOME_JSON_PATTERN = f"{CONNECTOME_OUT}/sub-{{subject}}/{{parc}}_model-SDSTREAM_connectome.json"


def sdstream_connectome_sift2_products(subject: str, parc: str | None = None) -> list[str]:
    if not sdstream_enabled() or not CONNECTOME_SIFT2_ENABLED:
        return []
    parc = (parc or CONNECTOME_PARCELLATION_CFG).lower()
    return [SD_SIFT2_PATTERN.format(subject=subject, parc=parc)]


def sdstream_connectome_products(subject: str, parc: str | None = None) -> list[str]:
    if not sdstream_enabled():
        return []
    parc = (parc or CONNECTOME_PARCELLATION_CFG).lower()
    products = [
        pattern.format(subject=subject, parc=parc)
        for pattern in (
            SD_COUNT_PATTERN,
            SD_MEANLENGTH_PATTERN,
            SD_MEANFA_PATTERN,
            SD_MEANMD_PATTERN,
            SD_CONNECTOME_JSON_PATTERN,
        )
    ]
    products.extend(sdstream_connectome_sift2_products(subject, parc))
    return products


rule sdstream_connectome:
    input:
        tracks=lambda wc: sdstream_tracks(wc.subject),
        weights=lambda wc: sdstream_weights(wc.subject),
        nodes=CONNECTOME_NODES_PATTERN,
        fa=CONNECTOME_FA_MAP_PATTERN,
        md=CONNECTOME_MD_MAP_PATTERN,
    output:
        count_matrix=SD_COUNT_PATTERN,
        meanlength_matrix=SD_MEANLENGTH_PATTERN,
        meanfa_matrix=SD_MEANFA_PATTERN,
        meanmd_matrix=SD_MEANMD_PATTERN,
        provenance=SD_CONNECTOME_JSON_PATTERN,
    threads: 4
    log:
        f"{RESULTS_ROOT}/logs/sub-{{subject}}_sdstream_connectome_{{parc}}.log",
    params:
        outdir=lambda wc: f"{CONNECTOME_OUT}/sub-{wc.subject}",
    shell:
        r"""
        exec > {log} 2>&1
        set -euo pipefail
        source {COMMON_SH}
        SUBJECT="{wildcards.subject}"
        PARC="{wildcards.parc}"
        mkdir -p "{params.outdir}"

        apptainer exec --cleanenv --containall \
          -B "{TRACTOGRAPHY_OUT}":/tractography:ro \
          -B "{CONNECTOME_OUT}":/connectomes \
          "{CONTAINER_CONNECTOME}" \
          bash -lc "
            set -euo pipefail
            tracks=/tractography/sub-${{SUBJECT}}/model-SDSTREAM_streamlines.tck
            weights=/tractography/sub-${{SUBJECT}}/model-SDSTREAM_sift2weights.csv
            nodes=/connectomes/sub-${{SUBJECT}}/${{PARC}}_nodes.mif
            fa=/connectomes/sub-${{SUBJECT}}/${{PARC}}_desc-FA_dwi.nii.gz
            md=/connectomes/sub-${{SUBJECT}}/${{PARC}}_desc-MD_dwi.nii.gz
            prefix=/connectomes/sub-${{SUBJECT}}/${{PARC}}_model-SDSTREAM
            tck2connectome -force \${{tracks}} \${{nodes}} \${{prefix}}_connectome_count.csv \
              -symmetric -zero_diagonal
            tck2connectome -force \${{tracks}} \${{nodes}} \${{prefix}}_connectome_meanlength.csv \
              -symmetric -zero_diagonal -scale_length -stat_edge mean
            tcksample -force \${{tracks}} \${{fa}} \${{prefix}}_streamline_meanfa.csv \
              -stat_tck mean
            tcksample -force \${{tracks}} \${{md}} \${{prefix}}_streamline_meanmd.csv \
              -stat_tck mean
            tck2connectome -force \${{tracks}} \${{nodes}} \${{prefix}}_connectome_meanfa.csv \
              -symmetric -zero_diagonal -scale_file \${{prefix}}_streamline_meanfa.csv \
              -stat_edge mean
            tck2connectome -force \${{tracks}} \${{nodes}} \${{prefix}}_connectome_meanmd.csv \
              -symmetric -zero_diagonal -scale_file \${{prefix}}_streamline_meanmd.csv \
              -stat_edge mean
          "

        empty_nodes="$(_count_empty_nodes "{output.count_matrix}")"
        {PIPELINE_PYTHON} - "{output.provenance}" "${{empty_nodes}}" <<'PY'
import json, sys
out, empty_nodes = sys.argv[1:]
payload = {{
    "subject": "sub-{wildcards.subject}",
    "parcellation": "{wildcards.parc}",
    "model": "SD_STREAM",
    "act_mode": "{ACT_MODE}",
    "empty_nodes": int(empty_nodes),
    "matrices": {{
        "count": "{output.count_matrix}",
        "sift2": None,
        "meanlength": "{output.meanlength_matrix}",
        "meanfa": "{output.meanfa_matrix}",
        "meanmd": "{output.meanmd_matrix}",
    }},
}}
with open(out, "w") as stream:
    json.dump(payload, stream, indent=2)
    stream.write("\n")
PY
        """


if CONNECTOME_SIFT2_ENABLED:
    rule sdstream_connectome_sift2:
        input:
            tracks=lambda wc: sdstream_tracks(wc.subject),
            weights=lambda wc: sdstream_weights(wc.subject),
            nodes=CONNECTOME_NODES_PATTERN,
            count_matrix=SD_COUNT_PATTERN,
        output:
            sift2_matrix=SD_SIFT2_PATTERN,
        threads: 2
        log:
            f"{RESULTS_ROOT}/logs/sub-{{subject}}_sdstream_connectome_sift2_{{parc}}.log",
        params:
            provenance=lambda wc: SD_CONNECTOME_JSON_PATTERN.format(
                subject=wc.subject, parc=wc.parc
            ),
        shell:
            r"""
            exec > {log} 2>&1
            set -euo pipefail
            source {COMMON_SH}
            SUBJECT="{wildcards.subject}"
            PARC="{wildcards.parc}"

            apptainer exec --cleanenv --containall \
              -B "{TRACTOGRAPHY_OUT}":/tractography:ro \
              -B "{CONNECTOME_OUT}":/connectomes \
              "{CONTAINER_CONNECTOME}" \
              bash -lc "
                set -euo pipefail
                tracks=/tractography/sub-${{SUBJECT}}/model-SDSTREAM_streamlines.tck
                weights=/tractography/sub-${{SUBJECT}}/model-SDSTREAM_sift2weights.csv
                nodes=/connectomes/sub-${{SUBJECT}}/${{PARC}}_nodes.mif
                prefix=/connectomes/sub-${{SUBJECT}}/${{PARC}}_model-SDSTREAM
                tck2connectome -force \${{tracks}} \${{nodes}} \${{prefix}}_connectome_sift2.csv \
                  -symmetric -zero_diagonal -tck_weights_in \${{weights}}
              "

            {PIPELINE_PYTHON} - "{params.provenance}" "{output.sift2_matrix}" <<'PY'
import json, sys
from pathlib import Path
out, sift2_path = sys.argv[1:3]
path = Path(out)
payload = json.loads(path.read_text()) if path.is_file() else {{
    "subject": "sub-{wildcards.subject}",
    "parcellation": "{wildcards.parc}",
    "model": "SD_STREAM",
    "act_mode": "{ACT_MODE}",
}}
payload.setdefault("matrices", {{}})["sift2"] = Path(sift2_path).name
with open(out, "w") as stream:
    json.dump(payload, stream, indent=2)
    stream.write("\n")
PY
            echo "SD_STREAM SIFT2 connectome: {output.sift2_matrix}"
            """

