#!/usr/bin/env python3
"""Run SUGAR predict.py (torch 2.x + PyG 2.2 per SUGAR README)."""
from __future__ import annotations

import os
import sys
from pathlib import Path

import torch

sugar_root = os.environ.get("SUGAR_ROOT")
if not sugar_root:
    raise SystemExit("set SUGAR_ROOT")
shim = Path(__file__).resolve().parent / "shims"
featreg_utils = shim / "featreg" / "utils"
if not featreg_utils.exists():
    featreg_utils.symlink_to(Path(sugar_root) / "utils")
sys.path.insert(0, sugar_root)
sys.path.insert(0, str(shim))

import featreg.gatunet_model  # noqa: F401,E402
import featreg.utils  # noqa: F401,E402

_orig = torch.load


def _load(*args, **kwargs):
    kwargs.setdefault("weights_only", False)
    return _orig(*args, **kwargs)


torch.load = _load  # type: ignore[assignment]

if __name__ == "__main__":
    import runpy

    sys.argv = ["predict.py"] + sys.argv[1:]
    runpy.run_path(os.path.join(sugar_root, "predict.py"), run_name="__main__")
