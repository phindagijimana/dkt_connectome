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
    import json

    expected = json.loads((DWI / "app.json").read_text())["PipelineVersion"]
    out = subprocess.check_output([str(RUN), "--version"], text=True).strip()
    assert out == expected


def test_run_help_has_bids_app_flags():
    help_text = subprocess.check_output([str(RUN), "--help"], text=True)
    for flag in (
        "--random-seed",
        "--stop-on-first-crash",
        "--participant-label",
        "--session-id",
        "--nprocs",
        "--bids-filter-file",
        "--omp-nthreads",
        "--act-5tt-source",
        "--deep-atropos-seg",
        "--deep-atropos-seg-mode",
        "--connectome-atlases",
        "--force-syn",
        "--experiment-arm",
        "--fastsurfer-device",
    ):
        assert flag in help_text


def test_run_accepts_lesion_and_syn_flags(ci_env):
    """Flags that used to be HPC-only must parse on ./run (exit 2 was Unknown option)."""
    if not (FIXTURE / "dataset_description.json").is_file():
        subprocess.run(
            ["python3", str(DWI / "tests" / "fixtures" / "generate_bids_fixture.py")],
            cwd=DWI,
            check=False,
        )
    proc = subprocess.run(
        [
            str(RUN),
            str(FIXTURE),
            str(ci_env / "out"),
            "participant",
            "--participant-label",
            "EXAMPLE",
            "--act-5tt-source",
            "hsvs",
            "--deep-atropos-seg-mode",
            "auto",
            "--deep-atropos-seg",
            str(ci_env / "seg.nii.gz"),
            "--connectome-atlases",
            "dkt",
            "--force-syn",
            "--experiment-arm",
            "orig-std",
            "--fastsurfer-device",
            "cpu",
            "--dry-run",
            "--no-sdc",
            "--no-dwi-filter",
        ],
        cwd=DWI,
        capture_output=True,
        text=True,
        timeout=90,
    )
    combined = proc.stdout + proc.stderr
    assert "Unknown option" not in combined, combined
    assert proc.returncode != 2, combined


def test_run_rejects_invalid_fastsurfer_device(ci_env):
    proc = subprocess.run(
        [
            str(RUN),
            str(FIXTURE),
            str(ci_env / "out"),
            "participant",
            "--participant-label",
            "EXAMPLE",
            "--fastsurfer-device",
            "tpu",
            "--dry-run",
            "--no-sdc",
            "--no-dwi-filter",
        ],
        cwd=DWI,
        capture_output=True,
        text=True,
        timeout=30,
    )
    combined = proc.stdout + proc.stderr
    assert proc.returncode != 0
    assert "Unknown option" not in combined
    assert "fastsurfer-device" in combined


def test_run_still_rejects_unknown_option(tmp_path):
    proc = subprocess.run(
        [str(RUN), str(tmp_path), str(tmp_path), "participant", "--not-a-real-flag"],
        cwd=DWI,
        capture_output=True,
        text=True,
        timeout=15,
    )
    assert proc.returncode == 2
    assert "Unknown option" in proc.stderr


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
            "baseline",
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


def test_run_doctor_ci(ci_env, monkeypatch):
    monkeypatch.setenv("BIDS_APP_CI", "1")
    proc = subprocess.run(
        [str(RUN), "doctor"],
        cwd=DWI,
        capture_output=True,
        text=True,
        timeout=120,
    )
    assert proc.returncode == 0, proc.stderr or proc.stdout
    assert "doctor: OK" in proc.stdout


def test_container_install_list(tmp_path):
    proc = subprocess.run(
        [
            "python3",
            str(DWI / "scripts" / "container_install.py"),
            "list",
            "--cache",
            str(tmp_path / "cache"),
        ],
        cwd=DWI,
        capture_output=True,
        text=True,
        timeout=30,
    )
    assert proc.returncode == 0, proc.stderr
    assert "qsiprep" in proc.stdout
    assert "missing" in proc.stdout


def test_run_script_skips_postprocess_on_dry_run():
    text = RUN.read_text()
    assert 'if [[ "${DRY_RUN}" -eq 1 ]]; then' in text
    assert "exit \"${exit_code}\"" in text
    assert "PROCESSED" in text
    assert 'for sub in "${PROCESSED[@]}"' in text
