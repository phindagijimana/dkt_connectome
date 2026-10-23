from pathlib import Path

import pytest

from dlsurfer.adapters.plan import build_plan, runnable_steps
from dlsurfer.registry import engines, profiles


def test_chosen_engines_have_why_and_cite():
    engs, pins, deferred = engines()
    assert pins.get("fastsurfer_image")
    for eid, e in engs.items():
        if not e.get("chosen"):
            continue
        assert e.get("why"), eid
        assert e.get("cite"), eid
        assert e.get("classical_replaces"), eid
    assert deferred


def test_profiles_reference_known_engines():
    engs, _, _ = engines()
    for name, prof in profiles().items():
        for step in prof.get("steps", []):
            assert step["engine"] in engs, f"{name} -> {step['engine']}"


def test_core_lesion_plan_split():
    plan = build_plan(
        "core-lesion",
        t1=Path("/tmp/t1.nii.gz"),
        sd=Path("/tmp/subjects"),
        sid="sub-EG",
        lesion_mask=Path("/tmp/les.nii.gz"),
        fs_license=Path("/tmp/license.txt"),
        device="cpu",
    )
    assert plan.warnings == []
    run = runnable_steps(plan)
    assert any("lit-inpainting" in s.argv[0] for s in run)
    assert any(s.stage == "seg_only" for s in run)
    assert any(s.stage == "surf_only" for s in run)
    assert any("lit-postprocessing" in s.argv[0] for s in run)
    # every runnable/info step that is an engine cites something when not pipeline wrapper
    cited = [s for s in plan.steps if s.citations]
    assert len(cited) >= 5


def test_native_warns():
    plan = build_plan(
        "core-lesion-native",
        t1=Path("/tmp/t1.nii.gz"),
        sd=Path("/tmp/subjects"),
        sid="sub-EG",
        lesion_mask=Path("/tmp/les.nii.gz"),
        device="cpu",
    )
    assert any("seg_only" in w or "surf_only" in w or "split" in w.lower() for w in plan.warnings)


def test_lesion_required():
    with pytest.raises(ValueError):
        build_plan(
            "core-lesion",
            t1=Path("/tmp/t1.nii.gz"),
            sd=Path("/tmp/subjects"),
            sid="sub-EG",
        )