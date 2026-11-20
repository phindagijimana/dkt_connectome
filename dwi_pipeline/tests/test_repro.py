"""Stranger-path checks: messages, session label, orchestrator identity, IDEAS shells."""

from __future__ import annotations

import os
import subprocess
from pathlib import Path

DWI = Path(__file__).resolve().parents[1]
REPO = DWI.parent


def _exec_env() -> dict[str, str]:
    env = os.environ.copy()
    env.pop("PYTHONPATH", None)
    tmp = Path.home() / ".cache" / "dkt-connectome" / "repro_test_tmp"
    tmp.mkdir(parents=True, exist_ok=True)
    for key in ("TMPDIR", "APPTAINER_TMPDIR", "PROOT_TMP_DIR", "SINGULARITY_TMPDIR"):
        env[key] = str(tmp)
    return env


def test_check_repro_ok():
    proc = subprocess.run(
        ["bash", str(DWI / "scripts" / "check_repro.sh")],
        cwd=DWI,
        capture_output=True,
        text=True,
        env=_exec_env(),
        timeout=60,
    )
    combined = proc.stdout + proc.stderr
    assert proc.returncode == 0, combined
    assert "RECON_SESSION=ses-1 -> 1" in proc.stdout
    assert "does not mount host apptainer" in proc.stdout
    assert "Step 4 image rejected" in proc.stdout
    assert "./dkt install" in proc.stdout
    assert "fastsurfer tested build 2.4.2+7e53343" in proc.stdout
    assert proc.stdout.strip().endswith("repro: OK")


def test_first_run_demo_help():
    proc = subprocess.run(
        ["bash", str(DWI / "scripts" / "first_run_demo.sh"), "--help"],
        cwd=DWI,
        capture_output=True,
        text=True,
        timeout=30,
    )
    assert proc.returncode == 0, proc.stderr
    assert "--dwi-select" not in proc.stdout or "IDEAS" in proc.stdout
    assert "--check-shells-only" in proc.stdout


def test_first_run_demo_rejects_b1000(tmp_path):
    dwi = tmp_path / "sub-1" / "ses-1" / "dwi"
    dwi.mkdir(parents=True)
    (dwi / "sub-1_ses-1_dwi.bval").write_text("0 1000\n")
    (dwi / "sub-1_ses-1_dwi.nii.gz").write_bytes(b"\x1f\x8b")
    proc = subprocess.run(
        [
            "bash",
            str(DWI / "scripts" / "first_run_demo.sh"),
            "--bids",
            str(tmp_path),
            "--subject",
            "1",
            "--check-shells-only",
        ],
        cwd=DWI,
        capture_output=True,
        text=True,
        env=_exec_env(),
        timeout=30,
    )
    combined = proc.stdout + proc.stderr
    assert proc.returncode != 0, combined
    assert "nonzero b=[1000]" in combined
    assert "dwi_select_ideas_b2500.json" in combined
    assert "dkt run" not in combined


def test_first_run_demo_prints_ideas_command(tmp_path):
    dwi = tmp_path / "sub-1" / "ses-1" / "dwi"
    dwi.mkdir(parents=True)
    (dwi / "sub-1_ses-1_dwi.bval").write_text("0 300 700 2500\n")
    (dwi / "sub-1_ses-1_dwi.nii.gz").write_bytes(b"\x1f\x8b")
    results = tmp_path / "results"
    proc = subprocess.run(
        [
            "bash",
            str(DWI / "scripts" / "first_run_demo.sh"),
            "--bids",
            str(tmp_path),
            "--results",
            str(results),
            "--subject",
            "1",
            "--session",
            "ses-1",
            "--engine",
            "bids_app",
        ],
        cwd=DWI,
        capture_output=True,
        text=True,
        env=_exec_env(),
        timeout=30,
    )
    combined = proc.stdout + proc.stderr
    assert proc.returncode == 0, combined
    assert "Step 4 connectome image" in combined
    assert "unset SBATCH_GRES" in combined
    assert "--fastsurfer" in combined
    assert "dwi_select_ideas_b2500.json" in combined
    assert "--dry-run" in combined
    assert not results.exists()
