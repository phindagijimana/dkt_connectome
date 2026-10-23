"""Device policy helpers."""

from __future__ import annotations

import os
import shutil
import subprocess


def resolve_device(requested: str = "auto") -> str:
    requested = (requested or "auto").lower()
    if requested in {"cpu", "cuda", "cuda:0"}:
        return requested
    # auto
    if shutil.which("nvidia-smi"):
        try:
            r = subprocess.run(
                ["nvidia-smi", "-L"],
                capture_output=True,
                text=True,
                timeout=5,
                check=False,
            )
            if r.returncode == 0 and r.stdout.strip():
                return "cuda"
        except (OSError, subprocess.TimeoutExpired):
            pass
    if os.environ.get("CUDA_VISIBLE_DEVICES", "") not in {"", "-1"}:
        return "cuda"
    return "cpu"


def stage_device(stage_device: str, global_device: str) -> str:
    """Map profile step device hint to concrete device."""
    g = resolve_device(global_device)
    if stage_device == "cpu":
        return "cpu"
    if stage_device in {"gpu", "cuda", "auto", "mixed"}:
        return g if stage_device != "cpu" else "cpu"
    return g