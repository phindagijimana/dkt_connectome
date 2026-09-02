"""Tests for release_manifest.json and manifest pin overlay."""

from __future__ import annotations

import json
from pathlib import Path

import pytest

REPO = Path(__file__).resolve().parents[1]
SCRIPTS = REPO / "scripts"
MANIFEST = REPO / "release_manifest.json"


@pytest.fixture(scope="module")
def container_install():
    import importlib.util

    spec = importlib.util.spec_from_file_location(
        "container_install", SCRIPTS / "container_install.py"
    )
    mod = importlib.util.module_from_spec(spec)
    assert spec.loader is not None
    spec.loader.exec_module(mod)
    return mod


def test_release_manifest_matches_app_version():
    data = json.loads(MANIFEST.read_text(encoding="utf-8"))
    app = json.loads((REPO / "app.json").read_text(encoding="utf-8"))
    assert data["pipeline_version"] == app["PipelineVersion"]


def test_apply_manifest_pins_overrides_connectome(container_install):
    cfg = {
        "container_pins": {
            "connectome": "ghcr.io/phindagijimana/dk-connectome:0.1.0",
            "qsiprep": "pennlinc/qsiprep:1.0.0",
        }
    }
    merged = container_install.apply_manifest_pins(cfg)
    assert merged["container_pins"]["connectome"] == "ghcr.io/phindagijimana/dk-connectome:0.3.0"
    assert merged["container_pins"]["qsiprep"] == "pennlinc/qsiprep:1.0.0"


def test_verify_release_manifest_skips_null_digests(container_install, tmp_path, monkeypatch):
    fake = tmp_path / "dkt_connectome.sif"
    fake.write_bytes(b"test")
    monkeypatch.setattr(
        container_install,
        "load_release_manifest",
        lambda: {
            "pipeline_version": "0.3.0",
            "steps": {
                "connectome": {
                    "uri": "ghcr.io/phindagijimana/dk-connectome:0.3.0",
                    "sha256": None,
                }
            },
        },
    )
    cfg_path = REPO / "workflow" / "config" / "config.local.yaml"
    had_local = cfg_path.is_file()
    old = cfg_path.read_text(encoding="utf-8") if had_local else None
    try:
        cfg_path.write_text(
            f"containers:\n  connectome: {fake}\n",
            encoding="utf-8",
        )
        rc = container_install.verify_release_manifest(
            tmp_path, strict=False, keys=("connectome",)
        )
        assert rc == 0
    finally:
        if had_local and old is not None:
            cfg_path.write_text(old, encoding="utf-8")
        elif cfg_path.is_file():
            cfg_path.unlink()
