"""
common.smk — Shared config, paths, and Python helpers for every plugin rule.

Mirrors the "Paths" / "defaults" / preflight sections of subject.sh, but as
Snakemake config lookups instead of bash env-var defaults. See
dwi_pipeline/workflow/README.md for the full env-var <-> config key mapping.
"""

import functools
import json
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
BUILD_BIDS_FILTER = DWI_PIPELINE_DIR / "scripts" / "build_bids_filter.py"
MAKE_DWI_SELECT_CONFIG = DWI_PIPELINE_DIR / "scripts" / "make_dwi_select_config.py"

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

FS_LICENSE = config["fs_license"]
FS_LUT = config.get("fs_lut") or str(Path(FS_LICENSE).parent / "FreeSurferColorLUT.txt")
TEMPLATEFLOW_HOME = config.get("templateflow_home") or str(DWI_PIPELINE_DIR / "templateflow")

# --- Output layout (identical to subject.sh) ---------------------------------
QSIPREP_OUT = f"{RESULTS_ROOT}/qsiprep_single_run_output"
QSIRECON_OUT = f"{RESULTS_ROOT}/qsirecon_single_run_output"
RECON_OUT = config.get("recon_out") or f"{RESULTS_ROOT}/freesurfer"
FS_SUBJECTS_DIR = config.get("fs_subjects_dir") or RECON_OUT
INPAINT_OUT = f"{RESULTS_ROOT}/inpainted"
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
CONNECTOME_CFG = config.get("connectome", {})
NODESTRENGTH_CFG = config.get("nodestrength", {})

CONNECTOME_LUT_DKT = CONNECTOME_CFG.get("lut_dkt") or str(
    DWI_PIPELINE_DIR / "containers" / "connectome" / "mrtrix_lut" / "fs_dkt.txt"
)


@functools.lru_cache(maxsize=None)
def resolve_session(subject: str) -> str:
    """Target BIDS session for a subject (mirrors subject.sh's
    _resolve_target_session). Cached: called repeatedly while building the
    DAG (once per rule that needs a session for this subject)."""
    filter_cache = f"{INTER_QSP}/bids_filter_sub-{subject}.json"
    Path(INTER_QSP).mkdir(parents=True, exist_ok=True)
    cmd = [
        "python3", str(RESOLVE_SESSION_PY),
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
    subjects: no lesion mask, Step 1.5 is a no-op for them."""
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
    if not INPAINT_CFG.get("enabled", True):
        return False
    session = resolve_session(subject)
    return find_lesion_mask(subject, session) is not None
