"""Unit tests for check_inpainting decide_qc_status (no NIfTI required)."""

from __future__ import annotations

import importlib.util
import math
import sys
from pathlib import Path

REPO = Path(__file__).resolve().parents[2]
DWI = REPO / "dwi_pipeline"
sys.path.insert(0, str(DWI / "scripts"))


def _load():
    path = DWI / "scripts" / "check_inpainting.py"
    spec = importlib.util.spec_from_file_location("check_inpainting", path)
    mod = importlib.util.module_from_spec(spec)
    assert spec.loader is not None
    spec.loader.exec_module(mod)
    return mod


def test_pat20_like_numbers_are_ok_without_opt_in():
    mod = _load()
    d = mod.decide_qc_status(
        geometry_matches_original=True,
        outside_lesion_correlation=0.986897,
        correlation_drop_vs_control=0.009728,
        lesion_voxels=12451,
        fail_on_thresholds=False,
    )
    assert d["ok"] is True
    assert d["hard_failures"] == []
    assert d["threshold_notes"]
    assert "not a published cutoff" in d["threshold_notes"][0]


def test_opt_in_thresholds_set_ok_false():
    mod = _load()
    d = mod.decide_qc_status(
        geometry_matches_original=True,
        outside_lesion_correlation=0.986897,
        correlation_drop_vs_control=0.009728,
        lesion_voxels=12451,
        fail_on_thresholds=True,
    )
    assert d["ok"] is False
    assert d["fail_on_thresholds"] is True
    assert d["failures"] == d["threshold_notes"]


def test_hard_failures_only():
    mod = _load()
    geom = mod.decide_qc_status(
        geometry_matches_original=False,
        outside_lesion_correlation=0.999,
        correlation_drop_vs_control=0.0,
        lesion_voxels=100,
    )
    assert geom["ok"] is False
    assert any("geometry" in f for f in geom["hard_failures"])

    nan = mod.decide_qc_status(
        geometry_matches_original=True,
        outside_lesion_correlation=float("nan"),
        correlation_drop_vs_control=0.0,
        lesion_voxels=100,
    )
    assert nan["ok"] is False
    assert any("NaN" in f for f in nan["hard_failures"])

    empty = mod.decide_qc_status(
        geometry_matches_original=True,
        outside_lesion_correlation=0.999,
        correlation_drop_vs_control=0.0,
        lesion_voxels=0,
    )
    assert empty["ok"] is False
    assert any("empty" in f for f in empty["hard_failures"])


def test_drop_above_optional_default_is_note_only():
    mod = _load()
    d = mod.decide_qc_status(
        geometry_matches_original=True,
        outside_lesion_correlation=0.999,
        correlation_drop_vs_control=0.02,
        lesion_voxels=100,
        fail_on_thresholds=False,
    )
    assert d["ok"] is True
    assert any("0.02" in n for n in d["threshold_notes"])
    assert math.isfinite(0.02)
