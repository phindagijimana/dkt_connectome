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


def test_resolve_keys_all_and_single():
    sys.path.insert(0, str(DWI / "scripts"))
    import container_install as ci  # noqa: WPS433

    assert ci.resolve_keys(None, "all") == ci.DEFAULT_KEYS
    assert ci.resolve_keys(None, "qsirecon") == ("qsirecon",)
    assert ci.resolve_keys(None, "qsiprep,qsirecon") == ("qsiprep", "qsirecon")
    assert ci.resolve_keys(None, "qsiprep qsirecon") == ("qsiprep", "qsirecon")
    # --mode qsirecon is a pipeline mode (qsirecon + freesurfer), not single-image
    assert ci.resolve_keys("qsirecon", None) == ("qsirecon", "freesurfer")


def test_resolve_keys_unknown_exits():
    sys.path.insert(0, str(DWI / "scripts"))
    import container_install as ci  # noqa: WPS433

    with pytest.raises(SystemExit) as exc:
        ci.resolve_keys(None, "not_a_real_container")
    assert "unknown container key" in str(exc.value).lower() or "unknown" in str(exc.value).lower()


def _run_install_sh(*args: str, env: dict | None = None) -> subprocess.CompletedProcess[str]:
    return subprocess.run(
        ["bash", str(DWI / "scripts" / "install.sh"), *args],
        cwd=DWI,
        capture_output=True,
        text=True,
        timeout=60,
        env={**os.environ, **(env or {})},
    )


def test_install_sh_dry_run_single_container(tmp_path):
    cache = tmp_path / "containers"
    proc = _run_install_sh("--dry-run", "qsirecon", "--cache", str(cache), "--no-doctor")
    assert proc.returncode == 0, proc.stderr or proc.stdout
    assert "qsirecon" in proc.stdout
    assert "qsiprep" not in proc.stdout
    assert "dry-run" in proc.stdout


def test_install_sh_dry_run_all(tmp_path):
    cache = tmp_path / "containers"
    proc = _run_install_sh("--dry-run", "all", "--cache", str(cache), "--no-doctor")
    assert proc.returncode == 0, proc.stderr or proc.stdout
    for key in ("qsiprep", "qsirecon", "freesurfer", "fastsurfer"):
        assert key in proc.stdout


def test_install_sh_rejects_unknown_key(tmp_path):
    cache = tmp_path / "containers"
    proc = _run_install_sh("--dry-run", "nope", "--cache", str(cache), "--no-doctor")
    assert proc.returncode != 0
    assert "unknown" in (proc.stderr + proc.stdout).lower()


def test_dkt_install_dry_run_positional(tmp_path):
    cache = tmp_path / "containers"
    proc = subprocess.run(
        [str(DWI / "dkt"), "install", "qsirecon", "--dry-run", "--cache", str(cache)],
        cwd=DWI,
        capture_output=True,
        text=True,
        timeout=60,
    )
    assert proc.returncode == 0, proc.stderr or proc.stdout
    assert "qsirecon" in proc.stdout
    assert "qsiprep" not in proc.stdout


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


def test_find_container_any_path(tmp_path, monkeypatch):
    """Container is found via cache even when config path is a missing placeholder."""
    sys.path.insert(0, str(DWI / "scripts"))
    import container_install as ci  # noqa: WPS433

    monkeypatch.delenv("CONTAINER_QSIRECON", raising=False)

    cache = tmp_path / "containers"
    cache.mkdir()
    pin = "pennlinc/qsirecon:1.2.0"
    sif = cache / ci.sif_name("qsirecon", pin)
    sif.write_bytes(b"fake-sif")

    cfg = {
        "container_pins": {"qsirecon": pin},
        "containers": {"qsirecon": "/path/to/others/containers/qsirecon.sif"},
    }
    found, candidates = ci.find_container(cfg, cache, "qsirecon", pin)
    assert found == sif
    assert str(sif) in [str(c) for c in candidates]

    # env override wins
    env_sif = tmp_path / "from_env.sif"
    env_sif.write_bytes(b"env-sif")
    monkeypatch.setenv("CONTAINER_QSIRECON", str(env_sif))
    found_env, _ = ci.find_container(cfg, cache, "qsirecon", pin)
    assert found_env == env_sif


def _stub_doctor_host_tools(monkeypatch):
    """Avoid requiring apptainer/snakemake on the test host."""
    import shutil

    real_which = shutil.which

    def fake_which(cmd: str, *args, **kwargs):
        if cmd in ("apptainer", "snakemake", "python3"):
            return f"/usr/bin/{cmd}"
        return real_which(cmd, *args, **kwargs)

    monkeypatch.setattr(shutil, "which", fake_which)


def test_doctor_accepts_cache_when_config_missing(tmp_path, monkeypatch):
    sys.path.insert(0, str(DWI / "scripts"))
    import container_install as ci  # noqa: WPS433
    import yaml

    _stub_doctor_host_tools(monkeypatch)

    cache = tmp_path / "containers"
    cache.mkdir()
    monkeypatch.setenv("DKT_LOCAL_CONFIG", str(tmp_path / "empty.local.yaml"))
    (tmp_path / "empty.local.yaml").write_text("{}\n")
    merged = ci._load_merged_config()
    pins = merged.get("container_pins") or {}
    for key in ci.DEFAULT_KEYS:
        pin = pins.get(key) or f"example/{key}:0"
        (cache / ci.sif_name(key, pin)).write_bytes(b"x")

    monkeypatch.setenv("FS_LICENSE", str(tmp_path / "license.txt"))
    (tmp_path / "license.txt").write_text("license\n")
    monkeypatch.delenv("BIDS_APP_CI", raising=False)

    # Point config containers at missing placeholders — any_path should still pass
    local = tmp_path / "config.local.yaml"
    local.write_text(
        yaml.safe_dump(
            {
                "containers": {
                    k: f"/path/to/missing/{k}.sif" for k in ci.DEFAULT_KEYS
                }
            }
        )
    )
    monkeypatch.setenv("DKT_LOCAL_CONFIG", str(local))
    monkeypatch.setenv("DKT_CONTAINER_CACHE", str(cache))

    rc = ci.doctor(cache, mode="all", any_path=True, cache_only=False)
    assert rc == 0


def test_doctor_cache_only_ignores_env(tmp_path, monkeypatch):
    sys.path.insert(0, str(DWI / "scripts"))
    import container_install as ci  # noqa: WPS433

    _stub_doctor_host_tools(monkeypatch)

    cache = tmp_path / "containers"
    cache.mkdir()
    env_sif = tmp_path / "qsirecon.sif"
    env_sif.write_bytes(b"env")
    monkeypatch.setenv("CONTAINER_QSIRECON", str(env_sif))
    monkeypatch.setenv("FS_LICENSE", str(tmp_path / "license.txt"))
    (tmp_path / "license.txt").write_text("license\n")
    monkeypatch.delenv("BIDS_APP_CI", raising=False)

    rc = ci.doctor(cache, mode="qsirecon", any_path=True, cache_only=True)
    assert rc == 1  # cache empty; env ignored


@pytest.mark.skipif(
    os.environ.get("DKT_VERIFY_NETWORK") != "1",
    reason="Set DKT_VERIFY_NETWORK=1 to HTTP-check registries in CI",
)
def test_verify_pins_network():
    proc = _run_install_py("verify")
    assert proc.returncode == 0, proc.stdout + proc.stderr
