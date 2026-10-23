"""Environment checks for DLSurfer."""

from __future__ import annotations

import os
import shutil
from dataclasses import dataclass

from dlsurfer.device import resolve_device
from dlsurfer.registry import engines as load_engines


@dataclass
class Check:
    name: str
    ok: bool
    detail: str


def run_doctor() -> list[Check]:
    checks: list[Check] = []
    _, pins, _ = load_engines()

    checks.append(
        Check(
            "claim",
            True,
            "DLSurfer orchestrates validated tools; does not replace FreeSurfer/FastSurfer science.",
        )
    )
    checks.append(
        Check(
            "pins",
            True,
            f"fastsurfer_image={pins.get('fastsurfer_image')} freesurfer_min={pins.get('freesurfer_min')}",
        )
    )

    dev = resolve_device("auto")
    checks.append(Check("device_auto", True, f"resolved device={dev}"))

    for label, path_env, which in [
        ("FASTSURFER_HOME", "FASTSURFER_HOME", None),
        ("FREESURFER_HOME", "FREESURFER_HOME", None),
        ("fs_license_env", "FS_LICENSE", None),
    ]:
        val = os.environ.get(path_env, "")
        checks.append(
            Check(
                label,
                bool(val),
                val if val else f"${path_env} not set (required for live runs)",
            )
        )

    for exe, name in [
        ("mri_synthstrip", "synthstrip"),
        ("mri_synthseg", "synthseg"),
        ("mri_easyreg", "easyreg"),
        ("lit-inpainting", "neurolit"),
        ("recon-all", "freesurfer"),
        ("nvidia-smi", "gpu_smi"),
    ]:
        found = shutil.which(exe)
        checks.append(Check(name, found is not None, found or f"{exe} not on PATH"))

    fs_home = os.environ.get("FASTSURFER_HOME", "")
    if fs_home:
        rfs = os.path.join(fs_home, "run_fastsurfer.sh")
        checks.append(Check("run_fastsurfer", os.path.isfile(rfs), rfs))
    else:
        checks.append(Check("run_fastsurfer", False, "set FASTSURFER_HOME"))

    return checks