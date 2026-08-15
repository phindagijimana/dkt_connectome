#!/usr/bin/env python3
"""BIDS App smoke tests (dry-run on minimal fixture, no containers)."""

from __future__ import annotations

import os
import subprocess
from pathlib import Path

import pytest

REPO = Path(__file__).resolve().parents[2]
DWI = REPO / "dwi_pipeline"
FIXTURE = DWI / "tests" / "fixtures" / "bids_minimal"
RUN = DWI / "run"
RUN_SUBJECT = DWI / "workflow" / "run_subject.sh"


@pytest.fixture
def ci_env(tmp_path, monkeypatch):
    monkeypatch.setenv("BIDS_APP_CI", "1")
    monkeypatch.setenv("BIDS_DIR", str(FIXTURE))
    monkeypatch.setenv("RESULTS_ROOT", str(tmp_path / "out"))
    lic = tmp_path / "license.txt"
    lic.write_text("stub\n")
    monkeypatch.setenv("FS_LICENSE", str(lic))
    for name in (
        "CONTAINER_QSIPREP",
        "CONTAINER_QSIRECON",
        "CONTAINER_FREESURFER",
        "CONTAINER_CONNECTOME",
        "CONTAINER_LIT",
        "CONTAINER_NODESTRENGTH",
    ):
        stub = tmp_path / f"{name.lower()}.sif"
        stub.write_text("")
        monkeypatch.setenv(name, str(stub))
    return tmp_path


def test_run_version():
    out = subprocess.check_output([str(RUN), "--version"], text=True).strip()
    assert out == "0.2.0"


def test_run_help_has_bids_app_flags():
    help_text = subprocess.check_output([str(RUN), "--help"], text=True)
    for flag in ("--random-seed", "--stop-on-first-crash", "--participant-label"):
        assert flag in help_text


def test_smoke_preflight_quick(ci_env):
    proc = subprocess.run(
        ["bash", "workflow/preflight.sh", "--mode", "qsiprep", "--subject", "EXAMPLE", "--quick"],
        cwd=DWI,
        capture_output=True,
        text=True,
        timeout=30,
    )
    assert proc.returncode == 0, proc.stderr or proc.stdout
    assert "quick checks OK" in proc.stdout


def test_smoke_run_subject_dry_run(ci_env):
    proc = subprocess.run(
        [
            "bash",
            str(RUN_SUBJECT),
            "qsiprep",
            "EXAMPLE",
            "--session-filter",
            "ses-1",
            "--dry-run",
            "--no-sdc",
            "--no-dwi-filter",
        ],
        cwd=DWI,
        stdout=subprocess.DEVNULL,
        stderr=subprocess.PIPE,
        text=True,
        timeout=90,
    )
    assert proc.returncode == 0, proc.stderr


def test_run_script_skips_postprocess_on_dry_run():
    text = RUN.read_text()
    assert 'if [[ "${DRY_RUN}" -eq 1 ]]; then' in text
    assert "exit \"${exit_code}\"" in text
