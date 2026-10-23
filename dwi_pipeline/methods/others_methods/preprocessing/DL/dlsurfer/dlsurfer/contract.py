"""FreeSurfer-shaped output contract checks."""

from __future__ import annotations

from pathlib import Path

# Minimum files for a core / core-lesion morphometry tree
CORE_REQUIRED = [
    "mri",
    "surf",
    "scripts",
]

CORE_PREFERRED = [
    "mri/aparc.DKTatlas+aseg.deep.mgz",
    "mri/aseg.auto_noCCseg.mgz",
    "surf/lh.white",
    "surf/rh.white",
    "surf/lh.pial",
    "surf/rh.pial",
    "stats",
]


def subject_dir(sd: Path, sid: str) -> Path:
    return Path(sd) / sid


def check_contract(sd: Path, sid: str, *, seg_only: bool = False) -> list[str]:
    """Return list of problems (empty = ok)."""
    root = subject_dir(sd, sid)
    problems: list[str] = []
    if not root.is_dir():
        return [f"missing subject dir: {root}"]
    for d in ("mri", "scripts") if seg_only else CORE_REQUIRED:
        if not (root / d).exists():
            problems.append(f"missing {d}/")
    if not seg_only:
        for rel in CORE_PREFERRED:
            if not (root / rel).exists() and not any(root.joinpath(rel).parent.glob(Path(rel).name + "*")):
                problems.append(f"missing preferred: {rel}")
    return problems