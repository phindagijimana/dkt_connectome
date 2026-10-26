#!/usr/bin/env python3
"""Run Vox2Cortex vox2organ/main.py with torch.load(weights_only=False) for PT 2.6."""
from __future__ import annotations

import os
import runpy
import sys
from pathlib import Path

import torch

v2c_root = Path(os.environ.get("V2C_ROOT", Path.home() / "Documents/others/Vox2Cortex"))
vox2organ = v2c_root / "vox2organ"
if not (vox2organ / "main.py").is_file():
    raise SystemExit(f"missing {vox2organ / 'main.py'} — set V2C_ROOT")

_orig = torch.load


def _load(*args, **kwargs):
    kwargs.setdefault("weights_only", False)
    return _orig(*args, **kwargs)


torch.load = _load  # type: ignore[assignment]

os.chdir(vox2organ)
sys.path.insert(0, str(vox2organ))
sys.argv = ["main.py"] + sys.argv[1:]
runpy.run_path(str(vox2organ / "main.py"), run_name="__main__")
