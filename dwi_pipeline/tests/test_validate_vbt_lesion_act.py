from __future__ import annotations

import importlib.util
import subprocess
from pathlib import Path

import pytest

REPO = Path(__file__).resolve().parents[2]
DWI = REPO / "dwi_pipeline"
TEST_TBI = DWI / "dwi_test_TBI"

VBT_JSON = TEST_TBI / "phase3_vbt_validation/vbt/sub-TBI011011/ses-2WK/inpainting.json"
ACT_JSON = (
    TEST_TBI
    / "sub-TBI011011_fastsurfer_inpaint/lesion_aware_act/sub-TBI011011/lesion_aware_act.json"
)


def _load_validator():
    path = DWI / "scripts" / "validate_vbt_lesion_act.py"
    spec = importlib.util.spec_from_file_location("validate_vbt_lesion_act", path)
    module = importlib.util.module_from_spec(spec)
    assert spec.loader is not None
    spec.loader.exec_module(module)
    return module


@pytest.mark.skipif(not VBT_JSON.is_file(), reason="VBT validation fixture not present")
def test_vbt_tbi011011_artifacts_pass():
    validator = _load_validator()
    errors = validator.validate_vbt(VBT_JSON)
    assert errors == [], errors


@pytest.mark.skipif(not ACT_JSON.is_file(), reason="lesion-aware ACT fixture not present")
def test_lesion_aware_act_tbi011011_artifacts_pass():
    validator = _load_validator()
    errors = validator.validate_lesion_aware_act(ACT_JSON)
    assert errors == [], errors


@pytest.mark.skipif(
    not (VBT_JSON.is_file() and ACT_JSON.is_file()),
    reason="validation fixtures not present",
)
def test_validate_cli_exits_zero_on_fixtures():
    script = DWI / "scripts" / "validate_vbt_lesion_act.py"
    subprocess.run(
        [
            "python3",
            str(script),
            "--vbt-json",
            str(VBT_JSON),
            "--lesion-act-json",
            str(ACT_JSON),
        ],
        check=True,
    )
