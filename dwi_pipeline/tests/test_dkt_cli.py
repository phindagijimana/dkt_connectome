#!/usr/bin/env python3
"""Tests for dkt_cli helpers (init / status / profiles / boutiques)."""

from __future__ import annotations

import json
import os
import subprocess
import sys
from pathlib import Path

import pytest

DWI = Path(__file__).resolve().parents[1]
DKT_PY = DWI / "scripts" / "dkt_cli.py"
DKT = DWI / "dkt"


def _run_py(*args: str, env: dict | None = None) -> subprocess.CompletedProcess[str]:
    return subprocess.run(
        [sys.executable, str(DKT_PY), *args],
        cwd=DWI,
        capture_output=True,
        text=True,
        timeout=60,
        env={**os.environ, **(env or {})},
    )


def test_profiles_list():
    proc = _run_py("profiles")
    assert proc.returncode == 0, proc.stderr
    assert "ideas" in proc.stdout
    assert "glioma" in proc.stdout
    assert "minimal" in proc.stdout


def test_expand_profile_ideas():
    proc = _run_py("expand-profile", "ideas")
    assert proc.returncode == 0, proc.stderr
    assert "--fastsurfer" in proc.stdout
    assert "--syn" in proc.stdout


def test_expand_profile_unknown():
    proc = _run_py("expand-profile", "nope")
    assert proc.returncode != 0


def test_bids_exec_spec_json():
    proc = _run_py("bids-exec-spec")
    assert proc.returncode == 0, proc.stderr
    data = json.loads(proc.stdout)
    assert data["name"] == "DKT Connectome"
    assert data["schema-version"] == "0.5"
    assert "BIDSAppSpecVersion" in data["custom"]
    ids = {i["id"] for i in data["inputs"]}
    assert "InputDataset" in ids
    assert "OutputLocation" in ids
    assert "AnalysisLevel" in ids


def test_run_bids_exec_spec_flag():
    proc = subprocess.run(
        [str(DWI / "run"), "--bids-exec-spec"],
        cwd=DWI,
        capture_output=True,
        text=True,
        timeout=60,
    )
    assert proc.returncode == 0, proc.stderr
    data = json.loads(proc.stdout)
    assert data["tool-version"]


def test_init_writes_config(tmp_path, monkeypatch):
    lic = tmp_path / "license.txt"
    lic.write_text("license\n")
    bids = tmp_path / "bids"
    bids.mkdir()
    (bids / "dataset_description.json").write_text('{"Name":"t"}\n')
    out = tmp_path / "out"
    # Point LOCAL_CONFIG via running from a copy is hard; call API directly.
    sys.path.insert(0, str(DWI / "scripts"))
    import dkt_cli as cli  # noqa: WPS433

    monkeypatch.setattr(cli, "LOCAL_CONFIG", tmp_path / "config.local.yaml")
    rc = cli.main(
        [
            "init",
            "--license",
            str(lic),
            "--bids",
            str(bids),
            "--out",
            str(out),
            "--cache",
            str(tmp_path / "cache"),
            "--yes",
        ]
    )
    assert rc == 0
    text = (tmp_path / "config.local.yaml").read_text()
    assert "fs_license:" in text
    assert "bids_dir:" in text
    assert "results_root:" in text


def test_status_table(tmp_path):
    root = tmp_path / "results"
    markers = root / ".snakemake_markers" / "sub-001"
    markers.mkdir(parents=True)
    (markers / "qsiprep.done").write_text("")
    (markers / "qsirecon.done").write_text("")
    fs = root / "freesurfer" / "sub-001" / "mri"
    fs.mkdir(parents=True)
    (fs / "aparc+aseg.mgz").write_bytes(b"x")
    conn = root / "connectomes" / "sub-001"
    conn.mkdir(parents=True)
    (conn / "dkt_connectome.csv").write_text("a,b\n")
    qc = root / "qc" / "sub-001"
    qc.mkdir(parents=True)
    (qc / "subject_qc.html").write_text("<html></html>")

    proc = _run_py("status", "--results-root", str(root), "--write")
    assert proc.returncode == 0, proc.stderr
    assert "sub-001" in proc.stdout
    assert "OK" in proc.stdout
    summary = json.loads((root / "status" / "summary.json").read_text())
    assert summary["subjects"]["001"]["qsiprep"] == "done"
    assert summary["summary"]["done"] == 1


def test_dkt_status_via_wrapper(tmp_path):
    root = tmp_path / "results"
    root.mkdir()
    proc = subprocess.run(
        [str(DKT), "status", "--results-root", str(root)],
        cwd=DWI,
        capture_output=True,
        text=True,
        timeout=60,
    )
    assert proc.returncode == 0, proc.stderr
    assert "no subjects" in proc.stdout.lower() or "Next:" in proc.stdout


def test_provenance_runs():
    proc = _run_py("provenance")
    assert proc.returncode == 0, proc.stderr
    assert "pipeline" in proc.stdout.lower() or "provenance" in proc.stdout.lower()
