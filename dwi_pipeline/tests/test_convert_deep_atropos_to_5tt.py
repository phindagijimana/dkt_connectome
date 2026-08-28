#!/usr/bin/env python3
"""Unit tests for Deep Atropos → 5TT conversion."""

from __future__ import annotations

import importlib.util
import sys
from pathlib import Path

import numpy as np
import nibabel as nib
import pytest

REPO = Path(__file__).resolve().parents[2]
SCRIPT = REPO / "dwi_pipeline" / "scripts" / "convert_deep_atropos_to_5tt.py"


def _load_module():
    spec = importlib.util.spec_from_file_location("convert_deep_atropos_to_5tt", SCRIPT)
    mod = importlib.util.module_from_spec(spec)
    assert spec.loader is not None
    spec.loader.exec_module(mod)
    return mod


@pytest.fixture(scope="module")
def convert_mod():
    return _load_module()


def test_label_mapping_one_hot(tmp_path, convert_mod):
    affine = np.eye(4)
    seg = np.zeros((4, 4, 4), dtype=np.int16)
    seg[1, 1, 1] = 1  # CSF
    seg[2, 2, 2] = 2  # GM
    seg[3, 3, 3] = 3  # WM
    seg[0, 0, 0] = 4  # SCGM
    t1w = tmp_path / "t1w.nii.gz"
    seg_path = tmp_path / "seg.nii.gz"
    nib.save(nib.Nifti1Image(seg.astype(np.float32), affine), str(seg_path))
    nib.save(nib.Nifti1Image(np.zeros(seg.shape, dtype=np.float32), affine), str(t1w))

    out_nii = tmp_path / "five_tt.nii.gz"
    convert_mod.convert(
        t1w=t1w,
        segmentation=seg_path,
        output_nii=out_nii,
    )
    data = nib.load(str(out_nii)).get_fdata()
    assert data.shape == (4, 4, 4, 5)
    assert data[1, 1, 1, 3] == 1.0
    assert data[2, 2, 2, 0] == 1.0
    assert data[3, 3, 3, 2] == 1.0
    assert data[0, 0, 0, 1] == 1.0


def test_unknown_label_raises(convert_mod):
    seg = np.array([[[7]]], dtype=np.int16)
    with pytest.raises(ValueError, match="unexpected Deep Atropos labels"):
        convert_mod.deep_atropos_seg_to_5tt(seg)
