#!/usr/bin/env python3
"""Unit tests for container install / doctor (no network pulls)."""

from __future__ import annotations

import os
import subprocess
import sys
from pathlib import Path

import pytest

DWI = Path(__file__).resolve().parents[1]
INSTALL_PY = DWI / "scripts" / "container_install.py"


def _run_install_py(*args: str) -> subprocess.CompletedProcess[str]:
    return subprocess.run(
        [sys.executable, str(INSTALL_PY), *args],
        cwd=DWI,
        capture_output=True,
        text=True,
        timeout=60,
    )


def test_pull_uris_for_key_dedupes_primary():
    sys.path.insert(0, str(DWI / "scripts"))
    import container_install as ci  # noqa: WPS433

    uris = ci.pull_uris_for_key(
        "connectome",
        "ghcr.io/phindagijimana/dk-connectome:0.1.0",
    )
    assert uris[0] == "oras://ghcr.io/phindagijimana/dk-connectome:0.1.0"
    assert "docker://ghcr.io/phindagijimana/dk-connectome:0.1.0" in uris
    assert "docker://phindagijimana321/dkt_connectome:latest" in uris
    assert len(uris) == len(set(uris))


def test_list_subcommand(tmp_path):
    proc = _run_install_py("list", "--cache", str(tmp_path / "cache"), "--only", "qsiprep")
    assert proc.returncode == 0, proc.stderr
    assert "qsiprep" in proc.stdout
    assert "missing" in proc.stdout


def test_resolved_local_config_env(tmp_path, monkeypatch):
    sys.path.insert(0, str(DWI / "scripts"))
    import container_install as ci  # noqa: WPS433

    alt = tmp_path / "alt_config.local.yaml"
    monkeypatch.setenv("DKT_LOCAL_CONFIG", str(alt))
    assert ci.resolved_local_config() == alt
    monkeypatch.delenv("DKT_LOCAL_CONFIG")
    assert ci.resolved_local_config() == ci.DEFAULT_LOCAL_CONFIG


def test_export_apptainer_tmpdir_sets_proot(tmp_path, monkeypatch):
    sys.path.insert(0, str(DWI / "scripts"))
    import container_install as ci  # noqa: WPS433

    monkeypatch.delenv("APPTAINER_TMPDIR", raising=False)
    monkeypatch.delenv("SINGULARITY_TMPDIR", raising=False)
    monkeypatch.delenv("PROOT_TMP_DIR", raising=False)
    cache = tmp_path / "containers"
    cache.mkdir()
    tmp = ci.export_apptainer_tmpdir(cache)
    assert tmp == tmp_path / "apptainer_tmp"
    assert tmp.is_dir()
    assert os.environ["APPTAINER_TMPDIR"] == str(tmp)
    assert os.environ["PROOT_TMP_DIR"] == str(tmp)
    assert os.environ["SINGULARITY_TMPDIR"] == str(tmp)


def test_explicit_cache_not_masked_by_config_local(tmp_path):
    """--cache DIR must report pin-named files in DIR, not site config.local.yaml paths."""
    proc = _run_install_py("list", "--cache", str(tmp_path / "empty"), "--only", "qsiprep")
    assert proc.returncode == 0, proc.stderr
    line = next(ln for ln in proc.stdout.splitlines() if ln.startswith("qsiprep"))
    cols = line.split("\t")
    assert cols[1] == "missing"
    assert str(tmp_path / "empty") in cols[3]


def test_doctor_ci_mode():
    proc = subprocess.run(
        [str(DWI / "run"), "doctor"],
        cwd=DWI,
        capture_output=True,
        text=True,
        env={**os.environ, "BIDS_APP_CI": "1"},
        timeout=60,
    )
    assert proc.returncode == 0, proc.stderr or proc.stdout
    assert "doctor: OK" in proc.stdout


def test_dkt_check_invokes_doctor():
    proc = subprocess.run(
        [str(DWI / "dkt"), "check"],
        cwd=DWI,
        capture_output=True,
        text=True,
        env={**os.environ, "BIDS_APP_CI": "1"},
        timeout=60,
    )
    assert proc.returncode == 0, proc.stderr or proc.stdout
    assert "doctor: OK" in proc.stdout
    assert "[dkt check] OK" in proc.stdout


@pytest.mark.skipif(
    os.environ.get("DKT_VERIFY_NETWORK") != "1",
    reason="Set DKT_VERIFY_NETWORK=1 to HTTP-check registries in CI",
)
def test_verify_pins_network():
    proc = _run_install_py("verify")
    assert proc.returncode == 0, proc.stdout + proc.stderr
