"""Unit tests for dwi_pipeline scripts (Phase A CI)."""

from __future__ import annotations

import importlib.util
import json
import sys
from pathlib import Path

import numpy as np
import pytest

REPO = Path(__file__).resolve().parents[2]
DWI = REPO / "dwi_pipeline"
sys.path.insert(0, str(DWI / "scripts"))


def _load_module(name: str, path: Path):
    spec = importlib.util.spec_from_file_location(name, path)
    mod = importlib.util.module_from_spec(spec)
    assert spec.loader is not None
    sys.modules[name] = mod
    spec.loader.exec_module(mod)
    return mod


def test_edge_stats_count_weighting_sane():
    mod = _load_module("evaluate_disconnectome_integrity", DWI / "scripts" / "evaluate_disconnectome_integrity.py")
    primary = np.array([[0.0, 10.0], [10.0, 0.0]])
    spared = np.array([[0.0, 9.0], [9.0, 0.0]])
    stats = mod.edge_stats(primary, spared)
    assert stats["edges_spared_gt_primary"] == 0
    assert stats["mean_disconnection_clipped"] == pytest.approx(0.1)


def test_write_disconnection_matrix_clips():
    mod = _load_module("run_disconnectome", DWI / "scripts" / "run_disconnectome.py")
    tmp = Path(__file__).parent / "_tmp_disc"
    tmp.mkdir(exist_ok=True)
    primary = tmp / "p.csv"
    spared = tmp / "s.csv"
    out = tmp / "d.csv"
    np.savetxt(primary, np.array([[0.0, 10.0], [10.0, 0.0]]), delimiter=",")
    np.savetxt(spared, np.array([[0.0, 12.0], [8.0, 0.0]]), delimiter=",")
    summary = mod.write_disconnection_matrix(primary, spared, out)
    d = np.loadtxt(out, delimiter=",")
    assert d[0, 1] == pytest.approx(0.0)  # spared > primary clipped
    assert summary["n_edges_spared_gt_primary"] == 1
    assert out.read_text().count("\n") >= 1


def test_normalize_weighting():
    mod = _load_module("run_disconnectome", DWI / "scripts" / "run_disconnectome.py")
    assert mod.normalize_weighting("count") == "count"
    assert mod.normalize_weighting("sift2") == "sift2"
    with pytest.raises(SystemExit):
        mod.normalize_weighting("sift1")


def test_write_derivatives_description(tmp_path):
    _load_module(
        "write_derivatives_description",
        DWI / "scripts" / "write_derivatives_description.py",
    )
    from write_derivatives_description import main as wmain  # type: ignore

    bids = tmp_path / "bids"
    bids.mkdir()
    out = tmp_path / "derivatives"
    import sys

    sys.argv = ["prog", "--results-root", str(out), "--bids-dir", str(bids)]
    wmain()
    data = json.loads((out / "dataset_description.json").read_text())
    assert data["DatasetType"] == "derivative"
    assert data["GeneratedBy"][0]["Version"] == "0.2.0"


def test_render_disconnectome_qc_html(tmp_path):
    disc = _load_module(
        "evaluate_disconnectome_integrity",
        DWI / "scripts" / "evaluate_disconnectome_integrity.py",
    )
    render = _load_module("render_disconnectome_qc", DWI / "scripts" / "render_disconnectome_qc.py")

    ddir = tmp_path / "disconnectome"
    ddir.mkdir()
    primary = np.array([[0.0, 10.0, 0.0], [10.0, 0.0, 5.0], [0.0, 5.0, 0.0]])
    spared_c = np.array([[0.0, 9.0, 0.0], [9.0, 0.0, 4.0], [0.0, 4.0, 0.0]])
    np.savetxt(ddir / "dkt_connectome_C_both.csv", spared_c, delimiter=",")
    np.savetxt(ddir / "disconnection_matrix.csv", np.clip(1 - spared_c / primary, 0, 1), delimiter=",")
    np.savetxt(ddir / "disconnection_matrix_C.csv", np.clip(1 - spared_c / primary, 0, 1), delimiter=",")
    (ddir / "lesion_roi_metrics.csv").write_text("node,flagged\n1,0\n")
    primary_path = tmp_path / "dkt_connectome.csv"
    np.savetxt(primary_path, primary, delimiter=",")
    prov = {
        "subject": "sub-test",
        "session": "ses-1",
        "connectome_weighting": "count",
        "disconnection_spared": "C",
        "primary_connectome": str(primary_path),
        "disconnection_summary": {
            "mean_disconnection_on_primary_edges": 0.1,
            "edges_with_disconnection_gt_0": 2,
        },
        "disconnection_by_option": {
            "C": {
                "mean_disconnection_on_primary_edges": 0.1,
                "edges_with_disconnection_gt_0": 2,
                "max_disconnection": 0.2,
            }
        },
        "lesion_selection": {"lesion_erode_voxels": 0, "core_only": False},
    }
    (ddir / "disconnectome.json").write_text(json.dumps(prov))

    report = disc.collect_integrity_report(ddir)
    html = render.render_html(report)
    assert "Disconnectome QC" in html
    assert "sub-test" in html
    assert report["overall_status"] in ("PASS", "WARN", "FAIL")


def test_collect_subject_qc_tbi_fixture():
    collect = _load_module("collect_subject_qc", DWI / "scripts" / "collect_subject_qc.py")
    rr = DWI / "dwi_test_TBI" / "sub-TBI011011_fastsurfer_inpaint"
    if not rr.is_dir():
        pytest.skip("TBI fixture not present")
    report = collect.collect_subject_qc(rr, "TBI011011")
    assert report["subject"] == "sub-TBI011011"
    assert report["overall_status"] in ("PASS", "WARN", "FAIL")
    step_ids = {s["id"] for s in report["steps"]}
    assert "qsiprep" in step_ids
    assert "disconnectome" in step_ids
    disc = next(s for s in report["steps"] if s["id"] == "disconnectome")
    assert disc["status"] in ("PASS", "WARN")


def test_export_bids_derivatives_symlinks(tmp_path):
    export_mod = _load_module("export_bids_derivatives", DWI / "scripts" / "export_bids_derivatives.py")

    rr = tmp_path / "results"
    (rr / "qsiprep_single_run_output" / "sub-test" / "ses-1" / "dwi").mkdir(parents=True)
    (rr / "qsiprep_single_run_output" / "sub-test" / "ses-1" / "dwi" / "dummy.txt").write_text("x")
    (rr / "connectomes" / "sub-test").mkdir(parents=True)
    (rr / "connectomes" / "sub-test" / "dkt_connectome.csv").write_text("0,1\n1,0\n")

    payload = export_mod.export_bids_derivatives(rr, copy=False)
    export_root = Path(payload["export_root"])
    assert (export_root / "dataset_description.json").is_file()
    assert (export_root / "export_manifest.json").is_file()
    assert (export_root / "qsiprep" / "sub-test").is_symlink()
    assert (export_root / "tracktbi-connectome" / "sub-test" / "dkt_connectome.csv").exists()
    assert payload["mode"] == "symlink"
