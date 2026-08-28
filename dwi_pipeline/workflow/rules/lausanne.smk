"""
lausanne.smk — Build Lausanne-60 native-space parcellation from FreeSurfer surfaces.

Requires recon-all / FastSurfer surfaces (lh/rh.sphere.reg). Output is warped to
DWI space by Step 4 (run_connectome.sh) using the same chain as DKT.
"""

LAUSANNE_ATLAS_DIR = str(DWI_PIPELINE_DIR / "atlas" / "lausanne60")
LAUSANNE_OUT = f"{RESULTS_ROOT}/lausanne"
LAUSANNE60_LUT_FS = f"{LAUSANNE_ATLAS_DIR}/mrtrix_lut/lausanne60_fs_lut.txt"
LAUSANNE60_LUT_MRTRIX = f"{LAUSANNE_ATLAS_DIR}/mrtrix_lut/lausanne60_mrtrix_lut.txt"
LAUSANNE60_NODE_COUNT = 129

LAUSANNE60_PARC_PATTERN = f"{LAUSANNE_OUT}/sub-{{subject}}/lausanne60_parcellation.nii.gz"


def lausanne60_enabled() -> bool:
    return "lausanne60" in CONNECTOME_ATLASES


def lausanne60_parcellation(subject: str) -> str:
    return LAUSANNE60_PARC_PATTERN.format(subject=subject)


rule lausanne60_parcellation:
    input:
        aparc=lambda wc: recon_aparc(wc.subject),
    output:
        parcellation=LAUSANNE60_PARC_PATTERN,
    log:
        f"{RESULTS_ROOT}/logs/sub-{{subject}}_lausanne60_parcellation.log",
    params:
        fs_dir=lambda wc: f"{FS_SUBJECTS_DIR}/sub-{wc.subject}",
        subject_id=lambda wc: f"sub-{wc.subject}",
    shell:
        r"""
        exec > {log} 2>&1
        set -euo pipefail
        source {COMMON_SH}

        outdir="$(dirname "{output.parcellation}")"
        rm -rf "${{outdir}}"
        mkdir -p "${{outdir}}"

        export SUBJECTS_DIR="{FS_SUBJECTS_DIR}"
        FS_PREFIX=(apptainer exec --cleanenv --containall --home /tmp \
          -B "{FS_SUBJECTS_DIR}":/subjects \
          -B "{LAUSANNE_ATLAS_DIR}":/atlas:ro \
          -B "${{outdir}}":/out \
          -B "{FS_LICENSE}":/opt/freesurfer/license.txt:ro \
          --env SUBJECTS_DIR=/subjects \
          --env FS_LICENSE=/opt/freesurfer/license.txt \
          "{CONTAINER_FREESURFER}")

        {PIPELINE_PYTHON} {BUILD_LAUSANNE_PARC} \
          --freesurfer-subject "{params.fs_dir}" \
          --subjects-dir "{FS_SUBJECTS_DIR}" \
          --atlas-dir "{LAUSANNE_ATLAS_DIR}" \
          --output "{output.parcellation}" \
          --fs-subject "/subjects/{params.subject_id}" \
          --fs-atlas-dir "/atlas" \
          --fs-output-dir "/out" \
          --fs-exec-prefix "${{FS_PREFIX[*]}}"

        [[ -f "{output.parcellation}" ]] || \
          _pipeline_fail "lausanne60" "missing output parcellation"
        """
