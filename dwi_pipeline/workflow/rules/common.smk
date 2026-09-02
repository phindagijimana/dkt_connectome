"""
common.smk — Shared config, paths, and Python helpers for every plugin rule.

Mirrors the "Paths" / "defaults" / preflight sections of subject.sh, but as
Snakemake config lookups instead of bash env-var defaults. See
dwi_pipeline/workflow/README.md for the full env-var <-> config key mapping.
"""

import functools
import json
import os
import shutil
import subprocess
from pathlib import Path

from snakemake.exceptions import WorkflowError

# --- Repo layout -------------------------------------------------------------
WORKFLOW_DIR = Path(workflow.basedir)          # dwi_pipeline/workflow
DWI_PIPELINE_DIR = WORKFLOW_DIR.parent          # dwi_pipeline
REPO_ROOT = DWI_PIPELINE_DIR.parent         # repo root

LIB_DIR = WORKFLOW_DIR / "lib"
COMMON_SH = LIB_DIR / "common.sh"
RESOLVE_SESSION_PY = LIB_DIR / "resolve_session.py"
PREPARE_LESION_MASK = DWI_PIPELINE_DIR / "scripts" / "prepare_lesion_mask.py"
CHECK_INPAINTING = DWI_PIPELINE_DIR / "scripts" / "check_inpainting.py"
RUN_VBT = DWI_PIPELINE_DIR / "scripts" / "run_vbt.py"
BUILD_LAUSANNE_PARC = DWI_PIPELINE_DIR / "scripts" / "build_lausanne_parcellation.py"
BUILD_BIDS_FILTER = DWI_PIPELINE_DIR / "scripts" / "build_bids_filter.py"
MAKE_DWI_SELECT_CONFIG = DWI_PIPELINE_DIR / "scripts" / "make_dwi_select_config.py"

def _resolve_pipeline_python() -> str:
    """Host Python for numpy/nibabel scripts on compute nodes.

    Must match slurm_env.sh PIPELINE_PYTHON (3.12 user site-packages), not
    /usr/bin/python3 (3.9) which breaks when PYTHONPATH points at cp312 wheels.
    """
    if os.environ.get("PIPELINE_PYTHON"):
        return os.environ["PIPELINE_PYTHON"]
    if config.get("pipeline_python"):
        return str(config["pipeline_python"])
    for candidate in ("python3.12", "python3"):
        if shutil.which(candidate):
            return candidate
    return "python3.12"


PIPELINE_PYTHON = _resolve_pipeline_python()

wildcard_constraints:
    subject=r"[^/]+"

# --- Config with subject.sh-equivalent defaults ------------------------------
RESULTS_ROOT = config["results_root"]
BIDS_DIR = config["bids_dir"]
NTHREADS = int(config.get("nthreads", 8))
OMP_NTHREADS = int(config.get("omp_nthreads", 8))
OUTPUT_RES = config.get("output_res", 2)

_containers = config.get("containers", {})
CONTAINER_QSIPREP = _containers["qsiprep"]
CONTAINER_QSIRECON = _containers["qsirecon"]
CONTAINER_FASTSURFER = _containers["fastsurfer"]
CONTAINER_FREESURFER = _containers["freesurfer"]
CONTAINER_CONNECTOME = _containers["connectome"]
CONTAINER_LIT = _containers["lit"]
CONTAINER_NODESTRENGTH = _containers["nodestrength"]
CONTAINER_VBT = _containers.get("vbt") or _containers["qsiprep"]

FS_LICENSE = config["fs_license"]
FS_LUT = config.get("fs_lut") or str(Path(FS_LICENSE).parent / "FreeSurferColorLUT.txt")
TEMPLATEFLOW_HOME = config.get("templateflow_home") or str(DWI_PIPELINE_DIR / "templateflow")

# --- Output layout (identical to subject.sh) ---------------------------------
QSIPREP_OUT = f"{RESULTS_ROOT}/qsiprep_single_run_output"
QSIRECON_OUT = f"{RESULTS_ROOT}/qsirecon_single_run_output"
RECON_OUT = config.get("recon_out") or f"{RESULTS_ROOT}/freesurfer"
FS_SUBJECTS_DIR = config.get("fs_subjects_dir") or RECON_OUT
INPAINT_OUT = f"{RESULTS_ROOT}/inpainted"
LESION_MASK_OUT = f"{RESULTS_ROOT}/lesion_masks"
LESION_AWARE_ACT_OUT = f"{RESULTS_ROOT}/lesion_aware_act"
DEEP_ATROPOS_OUT = f"{RESULTS_ROOT}/deep_atropos"
DEEP_ATROPOS_SEG_OUT = f"{RESULTS_ROOT}/deep_atropos_seg"
TRACTOGRAPHY_OUT = f"{RESULTS_ROOT}/tractography"
CONNECTOME_OUT = f"{RESULTS_ROOT}/connectomes"
NODESTRENGTH_OUT = config.get("nodestrength_out") or f"{RESULTS_ROOT}/node_strength"
INTER_QSP = f"{RESULTS_ROOT}/intermediate_results_qsiprep_single"
INTER_QSI = f"{RESULTS_ROOT}/intermediate_results_qsirecon_single"
MARKERS_DIR = f"{RESULTS_ROOT}/.snakemake_markers"

# --- Step 1: QSIPrep -----------------------------------------------------------
_qsiprep_cfg = config.get("qsiprep", {})
QSIPREP_USE_SYN_SDC = bool(_qsiprep_cfg.get("use_syn_sdc", False))
QSIPREP_FMAP_RETRY = bool(_qsiprep_cfg.get("fmap_retry", False))
QSIPREP_NO_SDC = bool(_qsiprep_cfg.get("no_sdc", False))
QSIPREP_BIDS_FILTER = _qsiprep_cfg.get("bids_filter") or ""

# --- dwi-select ---------------------------------------------------------------
_dwi_select = config.get("dwi_select", {})
DWI_SELECT_ENABLED = bool(_dwi_select.get("enabled", True)) and not QSIPREP_BIDS_FILTER
DWI_SHELL_B = _dwi_select.get("shell_b", 1000)
DWI_SELECT_JSON = _dwi_select.get("json") or str(
    DWI_PIPELINE_DIR / "config" / f"dwi_select_b{DWI_SHELL_B}.json"
)

# --- Step config blocks --------------------------------------------------------
INPAINT_CFG = config.get("inpaint", {})
RECON_CFG = config.get("recon", {})
QSIRECON_CFG = config.get("qsirecon", {})
ACT_CFG = config.get("act", {})
ACT_FIVE_TT_SOURCE = str(ACT_CFG.get("five_tt_source", "hsvs")).lower()
if ACT_FIVE_TT_SOURCE not in ("hsvs", "deep-atropos-native"):
    raise WorkflowError(
        f"invalid act.five_tt_source={ACT_FIVE_TT_SOURCE} "
        "(use hsvs or deep-atropos-native)"
    )
DEEP_ATROPOS_CFG = ACT_CFG.get("deep_atropos") or {}
ACT_DEEP_ATROPOS_SEG_MODE = str(DEEP_ATROPOS_CFG.get("segmentation_mode", "auto")).lower()
if ACT_DEEP_ATROPOS_SEG_MODE not in ("auto", "import", "generate"):
    raise WorkflowError(
        f"invalid act.deep_atropos.segmentation_mode={ACT_DEEP_ATROPOS_SEG_MODE} "
        "(use auto, import, or generate)"
    )

ACT_MODE = str(ACT_CFG.get("mode", "standard")).lower()
if ACT_MODE not in ("standard", "lesion-aware"):
    raise WorkflowError(f"invalid act.mode={ACT_MODE} (use standard or lesion-aware)")

# Dev-only: bind-mount repo scripts over in-container copies (pilot iteration).
ACT_BIND_MOUNT_DEV = os.environ.get("ACT_BIND_MOUNT_DEV", "0") == "1"
CONNECTOME_BIND_DEV = os.environ.get(
    "CONNECTOME_BIND_DEV", os.environ.get("CONNECTOME_BIND_ENTRYPOINT", "0")
) == "1"
VBT_BIND_DEV = os.environ.get("VBT_BIND_DEV", "0") == "1"
DISCONNECTOME_BIND_DEV = os.environ.get("DISCONNECTOME_BIND_DEV", "0") == "1"

CONNECTOME_LUT_BAKED = "/opt/dkt/lut/fs_dkt.txt"


def _require_act_container(key: str, label: str) -> str:
    path = _containers.get(key)
    if not path:
        raise WorkflowError(
            f"act.mode=lesion-aware requires containers.{key} ({label}); "
            "do not rely on qsirecon fallback"
        )
    return str(path)


if ACT_MODE == "lesion-aware":
    CONTAINER_LESION_ACT = _require_act_container("lesion_act", "dkt_lesion_act.sif")
    if ACT_FIVE_TT_SOURCE == "deep-atropos-native":
        CONTAINER_DEEP_ATROPOS = _require_act_container("deep_atropos", "dkt_deep_atropos.sif")
        if ACT_DEEP_ATROPOS_SEG_MODE != "import":
            CONTAINER_DEEP_ATROPOS_SEG = _require_act_container(
                "deep_atropos_seg", "dkt_deep_atropos_seg.sif"
            )
        else:
            CONTAINER_DEEP_ATROPOS_SEG = (
                _containers.get("deep_atropos_seg")
                or _containers.get("deep_atropos")
                or CONTAINER_LESION_ACT
            )
    else:
        CONTAINER_DEEP_ATROPOS = _containers.get("deep_atropos") or CONTAINER_LESION_ACT
        CONTAINER_DEEP_ATROPOS_SEG = (
            _containers.get("deep_atropos_seg") or CONTAINER_DEEP_ATROPOS
        )
else:
    CONTAINER_LESION_ACT = _containers.get("lesion_act") or _containers["qsirecon"]
    CONTAINER_DEEP_ATROPOS = (
        _containers.get("deep_atropos") or _containers.get("lesion_act") or _containers["qsirecon"]
    )
    CONTAINER_DEEP_ATROPOS_SEG = (
        _containers.get("deep_atropos_seg")
        or _containers.get("deep_atropos")
        or _containers["qsirecon"]
    )

TRACTOGRAPHY_CFG = config.get("tractography", {})
EXPERIMENT_CFG = config.get("experiment", {})
CONNECTOME_CFG = config.get("connectome", {})
NODESTRENGTH_CFG = config.get("nodestrength", {})

ANATOMY_MITIGATION_BACKEND = str(
    INPAINT_CFG.get("backend", "neurolit") if INPAINT_CFG.get("enabled", True) else "none"
).lower()
if ANATOMY_MITIGATION_BACKEND not in ("none", "neurolit", "vbt"):
    raise WorkflowError(
        "invalid inpaint.backend="
        f"{ANATOMY_MITIGATION_BACKEND} (use none, neurolit, or vbt)"
    )
ANATOMY_MITIGATION_OUT = (
    f"{RESULTS_ROOT}/vbt"
    if ANATOMY_MITIGATION_BACKEND == "vbt"
    else INPAINT_OUT
)

CONNECTOME_SIFT2_ENABLED = bool(CONNECTOME_CFG.get("sift2", False))

CONNECTOME_LUT_DKT = CONNECTOME_CFG.get("lut_dkt") or str(
    DWI_PIPELINE_DIR / "containers" / "connectome" / "mrtrix_lut" / "fs_dkt.txt"
)

_raw_connectome_atlases = CONNECTOME_CFG.get("atlases")
if _raw_connectome_atlases is None:
    CONNECTOME_ATLASES = [str(CONNECTOME_CFG.get("parcellation", "dkt"))]
else:
    CONNECTOME_ATLASES = [str(a).lower() for a in _raw_connectome_atlases]
for _atlas in CONNECTOME_ATLASES:
    if _atlas not in ("dkt", "dk", "auto", "lausanne60"):
        raise WorkflowError(
            f"invalid connectome.atlases entry={_atlas} "
            "(use dkt, dk, auto, lausanne60)"
        )


@functools.lru_cache(maxsize=None)
def resolve_session(subject: str) -> str:
    """Target BIDS session for a subject (mirrors subject.sh's
    _resolve_target_session). Cached: called repeatedly while building the
    DAG (once per rule that needs a session for this subject)."""
    filter_cache = f"{INTER_QSP}/bids_filter_sub-{subject}.json"
    Path(INTER_QSP).mkdir(parents=True, exist_ok=True)
    cmd = [
        PIPELINE_PYTHON, str(RESOLVE_SESSION_PY),
        "--bids-dir", BIDS_DIR,
        "--subject", subject,
        "--filter-cache", filter_cache,
    ]
    recon_session = RECON_CFG.get("session")
    if recon_session:
        cmd += ["--recon-session", str(recon_session)]
    elif QSIPREP_BIDS_FILTER:
        cmd += ["--static-bids-filter", str(QSIPREP_BIDS_FILTER)]
    elif DWI_SELECT_ENABLED:
        cmd += ["--dwi-select-json", DWI_SELECT_JSON]
    else:
        raise WorkflowError(
            f"Cannot resolve session for sub-{subject}: dwi_select disabled and "
            "recon.session not set. Set config['recon']['session'] explicitly."
        )
    out = subprocess.run(cmd, capture_output=True, text=True, check=False)
    if out.returncode != 0:
        raise WorkflowError(
            f"resolve_session.py failed for sub-{subject}:\n{out.stderr}"
        )
    return out.stdout.strip()


@functools.lru_cache(maxsize=None)
def find_lesion_mask(subject: str, session: str) -> str | None:
    """0 or 1 sibling *_T1w_label-lesion_roi.nii.gz next to the session's T1w.
    Mirrors subject.sh's find_lesion_mask(). None (not an error) means most
    subjects: no lesion mask, Step 1.1 is a no-op for them."""
    anat_dir = Path(BIDS_DIR) / f"sub-{subject}" / f"ses-{session}" / "anat"
    if not anat_dir.is_dir():
        return None
    matches = sorted(anat_dir.glob("*_T1w_label-lesion_roi.nii.gz"))
    if not matches:
        return None
    if len(matches) > 1:
        raise WorkflowError(
            f"expected 0 or 1 lesion mask for sub-{subject} ses-{session}, "
            f"found {len(matches)}: {matches}"
        )
    return str(matches[0])


def subject_has_lesion_mask(subject: str) -> bool:
    session = resolve_session(subject)
    return find_lesion_mask(subject, session) is not None


@functools.lru_cache(maxsize=None)
def _find_external_deep_atropos_segmentation(subject: str, session: str) -> str | None:
    """Return external Deep Atropos seg if configured on disk, else None."""
    explicit = DEEP_ATROPOS_CFG.get("segmentation")
    if explicit:
        raw = str(explicit)
        for candidate in (
            raw.format(subject=subject, session=session),
            raw.replace("{subject}", subject).replace("{session}", session),
            raw,
        ):
            path = Path(candidate)
            if path.is_file():
                return str(path)
        return None

    env_path = os.environ.get("DEEP_ATROPOS_SEG")
    if env_path and Path(env_path).is_file():
        return env_path

    search_roots = [
        Path(BIDS_DIR).parent / "derivatives" / "deep-atropos",
        Path(BIDS_DIR) / "derivatives" / "deep-atropos",
        DWI_PIPELINE_DIR / "derivatives" / "deep-atropos",
    ]
    patterns = (
        f"sub-{subject}/ses-{session}/anat/*deep_atropos*seg*.nii.gz",
        f"sub-{subject}/ses-{session}/anat/*deep_atropos*.nii.gz",
        f"sub-{subject}/anat/*deep_atropos*seg*.nii.gz",
    )
    matches: list[Path] = []
    for root in search_roots:
        if not root.is_dir():
            continue
        for pattern in patterns:
            matches.extend(sorted(root.glob(pattern)))
    matches = sorted({str(p): p for p in matches}.values(), key=str)
    if len(matches) == 1:
        return str(matches[0])
    if len(matches) > 1:
        raise WorkflowError(
            f"expected 0 or 1 external Deep Atropos segmentation for sub-{subject} "
            f"ses-{session}, found {len(matches)}: {matches}"
        )
    return None


def deep_atropos_seg_resolved(subject: str) -> str:
    """Canonical seg path under results_root (import symlink or generated)."""
    return f"{DEEP_ATROPOS_SEG_OUT}/sub-{subject}/desc-deepatropos_seg.nii.gz"


@functools.lru_cache(maxsize=None)
def find_deep_atropos_segmentation(subject: str, session: str) -> str:
    """Resolve Deep Atropos integer segmentation for Step 3.1."""
    if ACT_FIVE_TT_SOURCE != "deep-atropos-native":
        raise WorkflowError(
            "find_deep_atropos_segmentation called with act.five_tt_source="
            f"{ACT_FIVE_TT_SOURCE}"
        )
    external = _find_external_deep_atropos_segmentation(subject, session)
    if ACT_DEEP_ATROPOS_SEG_MODE == "generate":
        return deep_atropos_seg_resolved(subject)
    if ACT_DEEP_ATROPOS_SEG_MODE == "import" and not external:
        raise WorkflowError(
            f"act.deep_atropos.segmentation_mode=import requires an external "
            f"Deep Atropos segmentation for sub-{subject} ses-{session}. "
            f"Set act.deep_atropos.segmentation, DEEP_ATROPOS_SEG, or place seg "
            f"under derivatives/deep-atropos/."
        )
    return deep_atropos_seg_resolved(subject)


def mitigation_enabled_for(subject: str) -> bool:
    return (
        ANATOMY_MITIGATION_BACKEND != "none"
        and subject_has_lesion_mask(subject)
    )
