"""
common.smk — paths, subject discovery, and helpers shared by every rule.

This is included once at the top of the Snakefile. Every other rule file
relies on the constants and functions defined here.
"""

from pathlib import Path


# ---------------------------------------------------------------------------
# Path roots (resolved from config)
# ---------------------------------------------------------------------------
BIDS_DIR          = Path(config["bids_dir"]).resolve()
RESULTS_ROOT      = Path(config["results_root"]).resolve()
TEMPLATEFLOW_HOME = Path(config["templateflow_home"]).resolve()
FS_LICENSE        = Path(config["fs_license"]).resolve()
# Optional override; default sits next to the FS license (host-side FS install).
FS_LUT            = Path(config.get("fs_lut") or (FS_LICENSE.parent / "FreeSurferColorLUT.txt")).resolve()

CONTAINERS = {k: Path(v).resolve() for k, v in config["containers"].items()}

QSIPREP_OUT  = RESULTS_ROOT / "qsiprep_single_run_output"
QSIRECON_OUT = RESULTS_ROOT / "qsirecon_single_run_output"
RECON_OUT    = RESULTS_ROOT / "freesurfer"
DK_OUT       = RESULTS_ROOT / "dk_connectomes"
LOGS_DIR     = RESULTS_ROOT / "logs"
WORK_QSIPREP_DIR  = RESULTS_ROOT / "intermediate_results_qsiprep_single"
WORK_QSIRECON_DIR = RESULTS_ROOT / "intermediate_results_qsirecon_single"
FLAGS_DIR    = RESULTS_ROOT / ".flags"      # sentinel files for stages with dir-tree outputs

for d in (RESULTS_ROOT, TEMPLATEFLOW_HOME, QSIPREP_OUT, QSIRECON_OUT, RECON_OUT,
          DK_OUT, LOGS_DIR, WORK_QSIPREP_DIR, WORK_QSIRECON_DIR, FLAGS_DIR):
    d.mkdir(parents=True, exist_ok=True)


# ---------------------------------------------------------------------------
# Subject discovery (TSV wins over inline list)
# ---------------------------------------------------------------------------
def _load_subjects():
    tsv = config.get("subjects_tsv")
    if tsv:
        p = Path(tsv)
        if not p.is_absolute():
            # Resolve relative to dwi_py/ (workflow.basedir is the Snakefile's
            # directory; previously we wrongly went .parent which pointed at
            # dwi_pipeline/ and missed the TSV).
            p = (Path(workflow.basedir) / p).resolve()
        if p.exists():
            ids = []
            for line in p.read_text().splitlines():
                line = line.strip()
                if line and not line.startswith("#"):
                    ids.append(line.removeprefix("sub-"))
            if ids:
                return sorted(set(ids))
    inline = config.get("subjects", []) or []
    return sorted({s.removeprefix("sub-") for s in inline})


SUBJECTS = _load_subjects()
if not SUBJECTS:
    raise WorkflowError(
        "No subjects found. Populate config/subjects.tsv or set config['subjects']."
    )

# Restrict wildcard expansion so a stray directory name can't leak into the DAG.
wildcard_constraints:
    sid = r"|".join(SUBJECTS),


# ---------------------------------------------------------------------------
# Truthy coercion (CLI `--config flag=false` arrives as the STRING "false")
# ---------------------------------------------------------------------------
def cfg_bool(key: str, default: bool = False) -> bool:
    v = config.get(key, default)
    if isinstance(v, bool):
        return v
    if isinstance(v, (int, float)):
        return bool(v)
    if isinstance(v, str):
        return v.strip().lower() in ("1", "true", "yes", "on", "y", "t")
    return bool(v)


RUN_RECON          = cfg_bool("run_recon",         True)
RUN_QSIRECON       = cfg_bool("run_qsirecon",      True)
RUN_DK_CONNECTOME  = cfg_bool("run_dk_connectome", True)


# ---------------------------------------------------------------------------
# BIDS helpers (mirror subject.sh)
# ---------------------------------------------------------------------------
def has_fmap(subject: str) -> bool:
    """True iff sub-XXX has any NIfTI under a fmap/ folder."""
    root = BIDS_DIR / f"sub-{subject}"
    if not root.exists():
        return False
    for p in root.rglob("*.nii*"):
        if "/fmap/" in str(p):
            return True
    return False


def find_t1ws(subject: str) -> list[str]:
    """Sorted list of T1w NIfTIs under sub-XXX/.../anat/."""
    root = BIDS_DIR / f"sub-{subject}"
    return sorted(str(p) for p in root.rglob("*_T1w.nii*") if "/anat/" in str(p))


# ---------------------------------------------------------------------------
# Stage targets and aggregation
# ---------------------------------------------------------------------------
def qsiprep_flag(sid):    return str(FLAGS_DIR  / f"qsiprep.sub-{sid}.done")
def recon_target(sid):    return str(RECON_OUT  / f"sub-{sid}" / "mri" / "aparc+aseg.mgz")
def qsirecon_flag(sid):   return str(FLAGS_DIR  / f"qsirecon.sub-{sid}.done")
def dk_target(sid):       return str(DK_OUT     / f"sub-{sid}" / "dk_connectome.csv")


def all_targets():
    """Top-level target list — chooses the deepest enabled stage per subject."""
    if RUN_DK_CONNECTOME and RUN_RECON:
        return [dk_target(s) for s in SUBJECTS]
    if RUN_QSIRECON:
        return [qsirecon_flag(s) for s in SUBJECTS]
    return [qsiprep_flag(s) for s in SUBJECTS]


# ---------------------------------------------------------------------------
# Per-stage thread/resource lookups (config-driven, sensible fallbacks)
# ---------------------------------------------------------------------------
def stage_threads(stage: str) -> int:
    return int(config.get("threads", {}).get(stage, 4))


def stage_resources(stage: str) -> dict:
    base = {"mem_mb": 16000, "runtime": 120}
    base.update(config.get("resources", {}).get(stage, {}) or {})
    return base
