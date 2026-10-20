"""Locked Wave-3 ANTs helpers (FORMULA.md §2). Not Simpson / VoxelMorph."""

from __future__ import annotations

import os
import subprocess
from pathlib import Path

SIF_DEFAULT = (
    "/mnt/nfs/home/urmc-sh.rochester.edu/pndagiji/Documents/others/"
    "containers/dkt_connectome.sif"
)

_BOUND_DOCS = "/mnt/nfs/home/urmc-sh.rochester.edu/pndagiji/Documents"
_REAL_DOCS = "/mnt/nfs/home/URMC-SH/pndagiji/Documents"


def path_for_ants(p: Path | str) -> str:
    s = str(Path(p).resolve())
    if s.startswith(_REAL_DOCS):
        return _BOUND_DOCS + s[len(_REAL_DOCS) :]
    return s


def existing_ants_file(p: Path) -> Path | None:
    if p.is_file():
        return p
    s = str(p)
    for a, b in ((_REAL_DOCS, _BOUND_DOCS), (_BOUND_DOCS, _REAL_DOCS)):
        alt = Path(s.replace(a, b))
        if alt.is_file():
            return alt
    return None


def default_binds() -> list[str]:
    binds = []
    for p in (_BOUND_DOCS, _REAL_DOCS):
        if Path(p).is_dir() and p not in binds:
            binds.append(p)
    gugger = "/mnt/nfs/Gugger_Lab/NIR/dwi_test_TBI_experiment/validation_v030"
    if Path(gugger).is_dir():
        binds.append(gugger)
    return binds


def ants_prefix(sif: str, *args: str, bind: list[str] | None = None) -> list[str]:
    cmd = ["apptainer", "exec"]
    for b in bind or []:
        cmd.extend(["-B", b])
    cmd.append(sif)
    cmd.extend(args)
    return cmd


def locate_ants_outputs(out_prefix: Path) -> dict[str, str | None]:
    affine = existing_ants_file(Path(f"{out_prefix}_0GenericAffine.mat"))
    warp = existing_ants_file(Path(f"{out_prefix}_1Warp.nii.gz"))
    if warp is None:
        warp = existing_ants_file(Path(f"{out_prefix}_0Warp.nii.gz"))
    return {
        "affine": str(affine) if affine else None,
        "warp": str(warp) if warp else None,
    }


def apply_labels(
    *,
    labels: Path,
    reference: Path,
    transforms: list[Path],
    out_labels: Path,
    sif: str = SIF_DEFAULT,
    bind: list[str] | None = None,
) -> Path:
    """Warp integer labels with GenericLabel (FORMULA.md §2). Not linear."""
    out_labels.parent.mkdir(parents=True, exist_ok=True)
    bind = bind if bind is not None else default_binds()
    if not transforms:
        raise ValueError("apply_labels: empty transform list")
    t_args: list[str] = []
    for t in transforms:
        found = existing_ants_file(Path(t))
        if found is None:
            raise FileNotFoundError(t)
        t_args.extend(["-t", path_for_ants(found)])
    cmd = ants_prefix(
        sif,
        "antsApplyTransforms",
        "-d",
        "3",
        "-i",
        path_for_ants(labels),
        "-r",
        path_for_ants(reference),
        "-o",
        path_for_ants(out_labels),
        "-n",
        "GenericLabel",
        *t_args,
        bind=bind,
    )
    env = os.environ.copy()
    env["ITK_GLOBAL_DEFAULT_NUMBER_OF_THREADS"] = env.get("OMP_NUM_THREADS", "4")
    subprocess.run(cmd, check=True, env=env)
    found = existing_ants_file(out_labels)
    if found is None:
        raise FileNotFoundError(out_labels)
    return found


def mrconvert(
    src: Path,
    dest: Path,
    *,
    sif: str = SIF_DEFAULT,
    bind: list[str] | None = None,
) -> Path:
    dest.parent.mkdir(parents=True, exist_ok=True)
    bind = bind if bind is not None else default_binds()
    cmd = ants_prefix(sif, "mrconvert", path_for_ants(src), path_for_ants(dest), "-force", bind=bind)
    subprocess.run(cmd, check=True)
    found = existing_ants_file(dest)
    if found is None:
        raise FileNotFoundError(dest)
    return found
