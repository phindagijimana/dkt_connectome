from __future__ import annotations

import importlib.util
import os
import subprocess
from pathlib import Path

import pytest

REPO = Path(__file__).resolve().parents[2]
DWI = REPO / "dwi_pipeline"
TEST_TBI = DWI / "dwi_test_TBI"

SUBJECT = os.environ.get("VBT_VALIDATION_SUBJECT", "EXAMPLE")
SESSION = os.environ.get("VBT_VALIDATION_SESSION", "baseline")
RESULTS_SUFFIX = os.environ.get("VBT_VALIDATION_RESULTS_SUFFIX", "fastsurfer_inpaint")

VBT_JSON = TEST_TBI / f"phase3_vbt_validation/vbt/sub-{SUBJECT}/ses-{SESSION}/inpainting.json"
ACT_JSON = (
    TEST_TBI
    / f"sub-{SUBJECT}_{RESULTS_SUFFIX}/lesion_aware_act/sub-{SUBJECT}/lesion_aware_act.json"
)


def _load_validator():
    path = DWI / "scripts" / "validate_vbt_lesion_act.py"
    spec = importlib.util.spec_from_file_location("validate_vbt_lesion_act", path)
    module = importlib.util.module_from_spec(spec)
    assert spec.loader is not None
    spec.loader.exec_module(module)
    return module


@pytest.mark.skipif(not VBT_JSON.is_file(), reason="VBT validation fixture not present")
def test_vbt_validation_artifacts_pass():
    validator = _load_validator()
    errors = validator.validate_vbt(VBT_JSON)
    assert errors == [], errors


@pytest.mark.skipif(not ACT_JSON.is_file(), reason="lesion-aware ACT fixture not present")
def test_lesion_aware_act_validation_artifacts_pass():
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
