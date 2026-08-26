from __future__ import annotations

import importlib.util
from pathlib import Path

import nibabel as nib
import numpy as np


REPO = Path(__file__).resolve().parents[2]
DWI = REPO / "dwi_pipeline"


def _load_vbt():
    path = DWI / "scripts" / "run_vbt.py"
    spec = importlib.util.spec_from_file_location("run_vbt_test", path)
    module = importlib.util.module_from_spec(spec)
    assert spec.loader is not None
    spec.loader.exec_module(module)
    return module


def _save(data: np.ndarray, path: Path) -> None:
    nib.save(nib.Nifti1Image(data.astype(np.float32), np.eye(4)), path)


def test_create_transplant_uses_mirrored_signal_inside_lesion(tmp_path: Path):
    vbt = _load_vbt()
    original = np.full((9, 9, 9), 10.0)
    mirror = np.full((9, 9, 9), 100.0)
    mask = np.zeros((9, 9, 9))
    mask[4, 4, 4] = 1
    _save(original, tmp_path / "OrigMidline.nii.gz")
    _save(mirror, tmp_path / "MirrorMidline.nii.gz")
    _save(mask, tmp_path / "MaskMidline.nii.gz")

    vbt.create_transplant(tmp_path, smoothing_factor=1.0)

    transplant = nib.load(tmp_path / "Transplant.nii.gz").get_fdata()
    inverse = nib.load(tmp_path / "VBTMaskInverse.nii.gz").get_fdata()
    assert transplant[4, 4, 4] == 100.0
    assert inverse[4, 4, 4] == 0.0
    assert transplant[0, 0, 0] == 0.0
    assert inverse[0, 0, 0] == 1.0


def test_anatomy_backend_defaults_to_neurolit():
    config = (DWI / "workflow" / "config" / "config.yaml").read_text()
    assert "backend: neurolit" in config
    assert "smoothing_factor: 2.0" in config
    assert "model: both" in config
    assert "sift2: false" in config


def test_lesion_aware_act_contract():
    rule = (
        DWI / "workflow" / "rules" / "lesion_aware_act.smk"
    ).read_text()
    inpaint = (DWI / "workflow" / "rules" / "inpaint.smk").read_text()
    assert "CONTAINER_LESION_ACT" in rule
    assert "run_lesion_aware_act" in (
        DWI / "containers" / "lesion_act" / "run_lesion_aware_act.sh"
    ).read_text()
    assert "CONTAINER_QSIPREP" in inpaint
    assert "run_vbt.py" in inpaint
    assert "apptainer exec" in inpaint


def test_experiment_arms_are_isolated():
    wrapper = (DWI / "workflow" / "run_subject.sh").read_text()
    for arm in (
        "orig-std",
        "orig-lesion",
        "neurolit-std",
        "neurolit-lesion",
        "vbt-std",
        "vbt-lesion",
    ):
        assert arm in wrapper
    assert 'RESULTS_ROOT="${RESULTS_ROOT}/arms/${EXPERIMENT_ARM_EFFECTIVE}"' in wrapper


def test_sdstream_contract_is_model_specific():
    rule = (DWI / "workflow" / "rules" / "sdstream.smk").read_text()
    connectome = (DWI / "workflow" / "rules" / "connectome.smk").read_text()
    assert "-algorithm SD_Stream" in rule
    assert "-backtrack" not in rule
    assert "model-SDSTREAM_connectome_count.csv" in rule
    assert "model-SDSTREAM_connectome_meanlength.csv" in rule
    assert "model-SDSTREAM_connectome_meanfa.csv" in rule
    assert "model-SDSTREAM_connectome_meanmd.csv" in rule
    assert "rule sdstream_connectome_sift2:" in rule
    assert "rule connectome_sift2:" in connectome
    assert "CONNECTOME_SIFT2_ENABLED" in connectome
