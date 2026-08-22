"""
inpaint.smk — Step 1.5 plugin: selectable anatomical lesion mitigation before
Step 2 (neuroLIT or LeAPP-inspired virtual brain transplant).

Only ever included in the DAG for a subject when subject_has_lesion_mask()
is true for them (see inpainted_t1w_for(), used by recon.smk / connectome.smk
to decide their T1w input). Most subjects have no lesion mask and never touch
this rule at all -- exactly as in subject.sh's run_inpaint() no-op path.
"""

wildcard_constraints:
    session=r"[^/]+"

INPAINT_RESULT_PATTERN = f"{ANATOMY_MITIGATION_OUT}/sub-{{subject}}/ses-{{session}}/inpainting_volumes/inpainting_result.nii.gz"
INPAINT_JSON_PATTERN = f"{ANATOMY_MITIGATION_OUT}/sub-{{subject}}/ses-{{session}}/inpainting.json"
INPAINT_MASK_PREPARED_PATTERN = f"{ANATOMY_MITIGATION_OUT}/sub-{{subject}}/ses-{{session}}/lesion_mask_prepared.nii.gz"
INPAINT_MASK_JSON_PATTERN = f"{ANATOMY_MITIGATION_OUT}/sub-{{subject}}/ses-{{session}}/lesion_mask_prepared.json"
LESION_MASK_PREPARED_PATTERN = f"{LESION_MASK_OUT}/sub-{{subject}}/ses-{{session}}/lesion_mask_prepared.nii.gz"
LESION_MASK_JSON_PATTERN = f"{LESION_MASK_OUT}/sub-{{subject}}/ses-{{session}}/lesion_mask_prepared.json"

INPAINT_BINARIZE = bool(INPAINT_CFG.get("binarize", False))
INPAINT_LABELS = str(INPAINT_CFG.get("labels", "all"))
INPAINT_DILATE = int(INPAINT_CFG.get("dilate", 2))
INPAINT_DEVICE = str(INPAINT_CFG.get("device", "auto"))
INPAINT_BATCH_SIZE = int(INPAINT_CFG.get("batch_size", 8))
INPAINT_MIN_OUTSIDE_CORR = float(INPAINT_CFG.get("min_outside_corr", 0.995))
INPAINT_MAX_CORR_DROP = float(INPAINT_CFG.get("max_corr_drop", 0.01))
INPAINT_FAIL_ON_QC = bool(INPAINT_CFG.get("fail_on_qc", False))
VBT_CFG = INPAINT_CFG.get("vbt", {})
VBT_SMOOTHING_FACTOR = float(VBT_CFG.get("smoothing_factor", 2.0))


def inpaint_paths(subject: str) -> dict:
    session = resolve_session(subject)
    outdir = f"{ANATOMY_MITIGATION_OUT}/sub-{subject}/ses-{session}"
    return {
        "session": session,
        "outdir": outdir,
        "result": INPAINT_RESULT_PATTERN.format(subject=subject, session=session),
        "final_json": INPAINT_JSON_PATTERN.format(subject=subject, session=session),
        "mask_prepared": INPAINT_MASK_PREPARED_PATTERN.format(subject=subject, session=session),
        "mask_json": INPAINT_MASK_JSON_PATTERN.format(subject=subject, session=session),
        "qc_json": f"{outdir}/inpainting_qc.json",
    }


def inpainted_t1w_for(subject: str) -> str | None:
    """Path to the Step 1.5 result for `subject`, or None when no lesion mask
    exists (the common case -- Step 2/4 then use the raw BIDS T1w)."""
    if not mitigation_enabled_for(subject):
        return None
    return inpaint_paths(subject)["result"]


def mitigated_t1w_for(subject: str) -> str | None:
    """Backend-neutral name used by new workflow code."""
    return inpainted_t1w_for(subject)


def lesion_mask_paths(subject: str) -> dict:
    session = resolve_session(subject)
    return {
        "mask": LESION_MASK_PREPARED_PATTERN.format(subject=subject, session=session),
        "json": LESION_MASK_JSON_PATTERN.format(subject=subject, session=session),
    }


def _bids_t1w_for(subject: str, session: str) -> str:
    matches = sorted(
        list(Path(f"{BIDS_DIR}/sub-{subject}/ses-{session}/anat").glob("*_T1w.nii.gz"))
        + list(Path(f"{BIDS_DIR}/sub-{subject}/ses-{session}/anat").glob("*_T1w.nii"))
    )
    if len(matches) != 1:
        raise WorkflowError(
            f"inpaint/T1w: expected exactly 1 T1w for sub-{subject} ses-{session}, found {len(matches)}"
        )
    return str(matches[0])


rule prepare_lesion_mask:
    input:
        t1w=lambda wc: _bids_t1w_for(wc.subject, wc.session),
        mask=lambda wc: find_lesion_mask(wc.subject, wc.session),
    output:
        mask=LESION_MASK_PREPARED_PATTERN,
        json=LESION_MASK_JSON_PATTERN,
    log:
        f"{RESULTS_ROOT}/logs/sub-{{subject}}_ses-{{session}}_lesion_mask.log",
    params:
        binarize_flag="--binarize" if INPAINT_BINARIZE else "",
    shell:
        r"""
        exec > {log} 2>&1
        set -euo pipefail
        mkdir -p "$(dirname "{output.mask}")"
        python3 "{PREPARE_LESION_MASK}" \
          --t1w "{input.t1w}" --mask "{input.mask}" \
          --out "{output.mask}" --json "{output.json}" \
          --labels "{INPAINT_LABELS}" \
          {params.binarize_flag}
        """


rule inpaint:
    input:
        t1w=lambda wc: _bids_t1w_for(wc.subject, wc.session),
        mask=lambda wc: find_lesion_mask(wc.subject, wc.session),
    output:
        result=INPAINT_RESULT_PATTERN,
        final_json=INPAINT_JSON_PATTERN,
        mask_prepared=INPAINT_MASK_PREPARED_PATTERN,
        mask_json=INPAINT_MASK_JSON_PATTERN,
    threads: 4
    resources:
        gpu=1 if ANATOMY_MITIGATION_BACKEND == "neurolit" else 0,
    log:
        f"{RESULTS_ROOT}/logs/sub-{{subject}}_ses-{{session}}_anat-{ANATOMY_MITIGATION_BACKEND}.log",
    params:
        outdir=lambda wc: f"{ANATOMY_MITIGATION_OUT}/sub-{wc.subject}/ses-{wc.session}",
        qc_json=lambda wc: f"{ANATOMY_MITIGATION_OUT}/sub-{wc.subject}/ses-{wc.session}/inpainting_qc.json",
        session=lambda wc: wc.session,
        backend_container=(
            CONTAINER_LIT
            if ANATOMY_MITIGATION_BACKEND == "neurolit"
            else CONTAINER_QSIPREP
        ),
        binarize_flag="--binarize" if INPAINT_BINARIZE else "",
        nv_flag="--nv" if INPAINT_DEVICE != "cpu" else "",
    shell:
        r"""
        exec > {log} 2>&1
        set -euo pipefail
        source {COMMON_SH}
        SUBJECT="{wildcards.subject}"

        echo "=== Anatomical mitigation ({ANATOMY_MITIGATION_BACKEND}): sub-${{SUBJECT}} ses-{params.session} ==="
        mkdir -p "{params.outdir}"

        python3 "{PREPARE_LESION_MASK}" \
          --t1w "{input.t1w}" --mask "{input.mask}" \
          --out "{output.mask_prepared}" --json "{output.mask_json}" \
          --labels "{INPAINT_LABELS}" \
          {params.binarize_flag}

        if [[ "{ANATOMY_MITIGATION_BACKEND}" == "neurolit" ]]; then
          apptainer exec {params.nv_flag} --cleanenv --containall \
            -B "$(dirname "{input.t1w}")":/t1w_input:ro \
            -B "{output.mask_prepared}":/mask/lesion_mask_prepared.nii.gz:ro \
            -B "{params.outdir}":/out \
            "{CONTAINER_LIT}" \
            lit-inpainting \
              -i "/t1w_input/$(basename "{input.t1w}")" \
              -m /mask/lesion_mask_prepared.nii.gz \
              -o /out \
              --dilate {INPAINT_DILATE} \
              --keepgeom \
              --device {INPAINT_DEVICE} \
              --batch_size {INPAINT_BATCH_SIZE}
        elif [[ "{ANATOMY_MITIGATION_BACKEND}" == "vbt" ]]; then
          mkdir -p "$(dirname "{output.result}")"
          apptainer exec --cleanenv --containall \
            -B "$(dirname "{input.t1w}")":/t1w_input:ro \
            -B "{output.mask_prepared}":/mask/lesion_mask_prepared.nii.gz:ro \
            -B "{params.outdir}":/out \
            -B "{RUN_VBT}":/run_vbt.py:ro \
            "{CONTAINER_QSIPREP}" \
            python3 /run_vbt.py \
              --t1w "/t1w_input/$(basename "{input.t1w}")" \
              --mask /mask/lesion_mask_prepared.nii.gz \
              --output /out/inpainting_volumes/inpainting_result.nii.gz \
              --smoothing-factor {VBT_SMOOTHING_FACTOR} \
              --work-dir /out/.vbt_work
          rm -rf "{params.outdir}/.vbt_work"
        else
          _pipeline_fail "inpaint" \
            "invalid anatomy mitigation backend: {ANATOMY_MITIGATION_BACKEND}"
        fi

        [[ -f "{output.result}" ]] || _pipeline_fail "inpaint" \
          "lit-inpainting finished but {output.result} was not produced"

        python3 "{CHECK_INPAINTING}" \
          --original "{input.t1w}" --inpainted "{output.result}" --mask "{output.mask_prepared}" \
          --json "{params.qc_json}" \
          --min-outside-corr {INPAINT_MIN_OUTSIDE_CORR} \
          --max-corr-drop {INPAINT_MAX_CORR_DROP}

        qc_ok="$(python3 -c "import json; print(json.load(open('{params.qc_json}'))['ok'])")"
        if [[ "${{qc_ok}}" != "True" ]]; then
          echo "WARNING: Inpaint QC failed for sub-${{SUBJECT}} ses-{params.session} — see {params.qc_json}"
          if [[ "{INPAINT_FAIL_ON_QC}" == "True" ]]; then
            _pipeline_fail "inpaint" "QC failed for sub-${{SUBJECT}} (fail_on_qc=true)"
          fi
        fi

        python3 - "{input.t1w}" "{input.mask}" "{output.mask_prepared}" "{output.result}" \
          "{output.mask_json}" "{params.qc_json}" "{output.final_json}" \
          "sub-${{SUBJECT}}" "ses-{params.session}" "{params.backend_container}" "{INPAINT_LABELS}" \
          {INPAINT_DILATE} {INPAINT_DEVICE} {INPAINT_BATCH_SIZE} \
          "{ANATOMY_MITIGATION_BACKEND}" {VBT_SMOOTHING_FACTOR} <<'PY'
import json, sys
(t1w, mask, mask_prepared, result, mask_json, qc_json, final_json,
 subject, session, container, labels, dilate, device, batch_size,
 backend, vbt_smoothing) = sys.argv[1:17]
out = {{
    "subject": subject,
    "session": session,
    "backend": backend,
    "tool": "neuroLIT (FastSurfer-LIT)" if backend == "neurolit" else "virtual brain transplant",
    "container": container,
    "input_t1w": t1w,
    "lesion_mask_source": mask,
    "lesion_mask_prepared": mask_prepared,
    "mask_labels": labels,
    "dilate": int(dilate),
    "device": device,
    "batch_size": int(batch_size),
    "vbt_smoothing_factor": float(vbt_smoothing) if backend == "vbt" else None,
    "vbt_smoothing_units": "voxel sigma (LeAPP code default)" if backend == "vbt" else None,
    "keepgeom": True,
    "inpainted_t1w": result,
    "mask_summary": json.load(open(mask_json)),
    "qc": json.load(open(qc_json)),
}}
with open(final_json, "w") as fh:
    json.dump(out, fh, indent=2)
    fh.write("\n")
PY

        echo "Inpaint: OK — inpainted T1w: {output.result}"
        """
