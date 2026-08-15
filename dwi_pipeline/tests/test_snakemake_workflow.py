#!/usr/bin/env python3
"""Snakemake full-workflow dry-run (all plugin targets)."""

from __future__ import annotations

import subprocess
from pathlib import Path

import pytest

REPO = Path(__file__).resolve().parents[2]
DWI = REPO / "dwi_pipeline"
DRYRUN = DWI / "scripts" / "snakemake_dryrun_ci.sh"


@pytest.mark.slow
def test_snakemake_full_workflow_dryrun():
    """Exercise every target_* rule and `all` via snakemake -n (no containers)."""
    subprocess.run([str(DRYRUN)], check=True, cwd=DWI)
