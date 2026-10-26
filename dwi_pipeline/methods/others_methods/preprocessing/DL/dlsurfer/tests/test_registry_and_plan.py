from pathlib import Path

import pytest

from dlsurfer.adapters.plan import build_plan, runnable_steps
from dlsurfer.registry import engines, ensure_dl_profile, profiles, profiles_dl_only
from dlsurfer.tools import CLASSICAL_PROFILES, resolve_tool


def test_chosen_engines_have_why_and_cite():
    engs, pins, deferred = engines()
    assert pins.get("fastsurfer_image")
    for eid, e in engs.items():
        if not e.get("chosen"):
            continue
        assert e.get("why"), eid
        assert e.get("cite"), eid
        assert e.get("classical_replaces"), eid
        # future-reference alternatives documented (may be empty only if deferred covers it)
        assert "alternatives" in e, eid
        assert isinstance(e["alternatives"], list), eid
    assert deferred


def test_atlases_yaml_default_dkt():
    from pathlib import Path
    import yaml

    path = Path(__file__).resolve().parents[1] / "dlsurfer" / "atlases.yaml"
    data = yaml.safe_load(path.read_text())
    assert data["default"] == "dkt"
    assert "dk" in data["atlases"] and "destrieux" in data["atlases"]
    assert data["atlases"]["dk"].get("wired") is True


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
    assert any("LIT" in w or "neuroLIT" in w for w in plan.warnings) or plan.warnings == []
    run = runnable_steps(plan)
    assert any(s.argv and s.argv[0] == "lit-inpainting" and "-i" in s.argv for s in run)
    assert any(s.stage == "seg_only" for s in run)
    assert any(s.argv and s.argv[0] == "dlsurfer-v2c" for s in run)
    assert any(s.argv and s.argv[0] == "dlsurfer-install-surfaces" for s in run)
    assert not any(s.stage == "surf_only" for s in run)
    assert any("lit-postprocessing" in s.argv[0] for s in run)
    cited = [s for s in plan.steps if s.citations]
    assert len(cited) >= 5


def test_lit_dl_separable_only():
    """LIT public path is DL separable neuroLIT only (no --lesion_mask)."""
    from dlsurfer.adapters.plan import filter_steps_for_partition

    for name in ("core-lesion", "core-lesion-native"):
        plan = build_plan(
            name,
            t1=Path("/tmp/t1.nii.gz"),
            sd=Path("/tmp/subjects"),
            sid="sub-EG",
            lesion_mask=Path("/tmp/les.nii.gz"),
            device="cpu",
        )
        run = runnable_steps(plan)
        assert any(s.argv and s.argv[0] == "lit-inpainting" for s in run)
        assert any(s.stage == "seg_only" for s in run)
        assert any(s.argv and s.argv[0] == "dlsurfer-v2c" for s in run)
        assert not any("--lesion_mask" in " ".join(s.argv) for s in run)
        assert plan.extras.get("lit_mode") == "separable"
    with pytest.raises(ValueError, match="removed|separable|DL-only"):
        build_plan(
            "core-lesion-fs-native",
            t1=Path("/tmp/t1.nii.gz"),
            sd=Path("/tmp/subjects"),
            sid="sub-EG",
            lesion_mask=Path("/tmp/les.nii.gz"),
            device="cpu",
        )
    plan = build_plan(
        "core-lesion",
        t1=Path("/tmp/t1.nii.gz"),
        sd=Path("/tmp/subjects"),
        sid="sub-EG",
        lesion_mask=Path("/tmp/les.nii.gz"),
        device="cpu",
    )
    gpu = filter_steps_for_partition(plan, "gpu")
    cpu = filter_steps_for_partition(plan, "cpu")
    assert any(s.stage in {"fill", "seg_only", "csr"} for s in runnable_steps(gpu))
    assert any(s.argv and s.argv[0] == "dlsurfer-v2c" for s in runnable_steps(gpu))
    assert not any(s.argv and s.argv[0] == "dlsurfer-v2c" for s in runnable_steps(cpu))
    assert any(s.stage in {"install_surf", "post"} for s in runnable_steps(cpu))


def test_lesion_required():
    with pytest.raises(ValueError):
        build_plan(
            "core-lesion",
            t1=Path("/tmp/t1.nii.gz"),
            sd=Path("/tmp/subjects"),
            sid="sub-EG",
        )


def test_atlas_dk_adds_fsaparc():
    plan = build_plan(
        "core",
        t1=Path("/tmp/t1.nii.gz"),
        sd=Path("/tmp/subjects"),
        sid="sub-EG",
        atlas="dk",
        device="cpu",
    )
    run = runnable_steps(plan)
    assert any("--fsaparc" in s.argv for s in run)
    assert plan.atlas == "dk"


def test_module_toggles_and_vox_and_srun():
    plan = build_plan(
        "core",
        t1=Path("/tmp/t1.nii.gz"),
        sd=Path("/tmp/subjects"),
        sid="sub-EG",
        no_hypothal=True,
        vox_size=0.8,
        hpc="srun",
        device="cpu",
    )
    run = runnable_steps(plan)
    joined = " ".join(" ".join(s.argv) for s in run)
    assert "srun_fastsurfer.sh" in joined
    assert "--no_hypothal" in joined
    assert "--vox_size" in joined and "0.8" in joined
    assert "hypvinn" not in {s.engine_id for s in plan.steps if s.stage == "cited_module"}


def test_gap_fill_profiles():
    for name, needle in [
        ("fs-long", "recon-all"),
        ("subfields-ha", "segmentHA_T1.sh"),
        ("nuclei-bs-thal", "segmentBS.sh"),
        ("atlas-destrieux", "-a2009s"),
        ("fs-clinical", "recon-all-clinical.sh"),
    ]:
        plan = build_plan(
            name,
            t1=Path("/tmp/t1.nii.gz"),
            sd=Path("/tmp/subjects"),
            sid="sub-EG",
            device="cpu",
        )
        run = runnable_steps(plan)
        assert run, name
        assert any(needle in " ".join(s.argv) for s in run), (name, needle)


def test_gaps_without_alternatives_doc_exists():
    path = Path(__file__).resolve().parents[1] / "docs" / "reference" / "GAPS_WITHOUT_ALTERNATIVES.md"
    text = path.read_text()
    assert "Manual edit" in text
    assert "TRACULA" in text
    assert "meta-container" in text.lower() or "meta-image" in text.lower() or "SIF" in text


def test_structure_modules():
    for name, needle in [
        ("preprocess-synthsr", "mri_synthsr"),
        ("structure-claustrum", "mri_claustrum_seg"),
        ("structure-piriform-synthseg", "predict_ideas_one.py"),
        ("structure-hippunfold", "dlsurfer-hippunfold"),
        ("structure-brainstem-mars", "dlsurfer-mars-brainstem"),
        ("structure-sclimbic", "dlsurfer-sclimbic"),
        ("seg-wmh-synthseg", "dlsurfer-wmh-synthseg"),
        ("nuclei-thalamic-dti-cnn", "dlsurfer-thalamic-dti-cnn"),
        ("infant-ibeat", "dlsurfer-ibeat"),
        ("surf-dl-v2c-long", "dlsurfer-v2c-long"),
        ("clinical-claustrum", "mri_synthsr"),
        ("seg-wmh-mars", "dlsurfer-mars-wmh"),
        ("structure-hippodeep", "dlsurfer-hippodeep"),
        ("strip-hdbet", "dlsurfer-hdbet"),
        ("nuclei-thalamic-deep-thomas", "dlsurfer-deep-thomas"),
        ("sphere-s3reg", "dlsurfer-s3reg"),
        ("lesion-vbg", "dlsurfer-vbg"),
        ("lesion-enantiomorphic", "dlsurfer-enantiomorphic"),
        ("structure-ventricles-mars", "dlsurfer-mars-ventricles"),
        ("structure-claustrum-albishri", "dlsurfer-albishri-claustrum"),
        ("structure-piriform-nnunet", "dlsurfer-nnunet-piriform"),
        ("structure-amygdala-go", "dlsurfer-amygdala-go"),
        ("infant-dhcp", "dlsurfer-dhcp-neonatal"),
        ("surf-dl-cortexode", "dlsurfer-cortexode"),
        ("surf-dl-pialnn", "dlsurfer-pialnn"),
        ("thickness-dl-direct", "dlsurfer-dl-direct"),
    ]:
        kw = {}
        if name.startswith("lesion-"):
            kw["lesion_mask"] = Path("/tmp/lesion.nii.gz")
        plan = build_plan(
            name,
            t1=Path("/tmp/t1.nii.gz"),
            sd=Path("/tmp/subjects"),
            sid="sub-EG",
            device="cpu",
            **kw,
        )
        if name in {"structure-piriform-synthseg", "surf-dl-v2c-long"}:
            assert any("EXPERIMENTAL" in w or "experimental" in w.lower() for w in plan.warnings) or plan.steps
        run = runnable_steps(plan)
        assert run, name
        assert any(needle in " ".join(s.argv) for s in run), (name, needle)
    # clinical chain: synthsr then claustrum on synthsr T1
    plan = build_plan(
        "clinical-claustrum",
        t1=Path("/tmp/t1.nii.gz"),
        sd=Path("/tmp/subjects"),
        sid="sub-EG",
        device="cpu",
    )
    run = runnable_steps(plan)
    assert len(run) >= 2
    assert "T1.synthsr.nii.gz" in " ".join(run[1].argv)
    assert "mri_claustrum_seg" in run[1].argv[0]


def test_structure_docs_and_engines():
    engs, _, deferred = engines()
    for eid in (
        "mauri_claustrum",
        "synthseg_pc",
        "synthsr",
        "hippunfold",
        "mars_brainstem",
        "sclimbic",
        "wmh_synthseg",
        "thalamic_dti_cnn",
        "infant_ibeat",
        "v2c_long",
        "mars_wmh",
        "deep_thomas",
        "s3reg",
        "hippodeep",
        "hdbet",
        "vbg",
        "mars_ventricles",
        "cortexode",
        "dl_direct",
        "tractseg",
        "pet_dl_quant",
        "deepprep",
        "brainqcnet",
    ):
        assert eid in engs and engs[eid].get("chosen"), eid
        assert engs[eid].get("is_deep_learning") is True, eid
        assert engs[eid].get("alternatives") is not None
    assert engs["enantiomorphic"].get("chosen") and engs["enantiomorphic"].get("is_deep_learning") is False
    for eid in ("segment_ha", "segment_bs", "segment_thalamic", "freesurfer_long", "recon_surf"):
        assert engs[eid].get("is_deep_learning") is False or engs[eid].get("readiness") == "classical"
    assert any(d["id"] == "mauri_weights_as_pc" for d in deferred)
    doc = Path(__file__).resolve().parents[1] / "docs" / "reference" / "STRUCTURE_MODULES.md"
    text = doc.read_text()
    assert "Mauri" in text and "SynthSeg-PC" in text and "MARS" in text and "ScLimbic" in text
    assert "MARS-WMH" in text or "mars_wmh" in text
    assert "Deep-THOMAS" in text or "deep_thomas" in text
    assert "TractSeg" in text or "tractseg" in text
    assert "DeepPrep" in text or "deepprep" in text


def test_multimodal_fs_suite_profiles():
    from dlsurfer.credibility import PROFILE_TIER
    from dlsurfer.tools import resolve_tool

    assert PROFILE_TIER["dwi-tractseg"] == "B"
    assert PROFILE_TIER["pet-dl-quant"] == "B"
    assert PROFILE_TIER["fmri-deepprep"] == "B"
    assert PROFILE_TIER["qc-brainqcnet"] == "B"
    assert resolve_tool("tractseg") == "dwi-tractseg"
    assert resolve_tool("pet-dl") == "pet-dl-quant"
    for name, needle in [
        ("dwi-tractseg", "dlsurfer-tractseg"),
        ("pet-dl-quant", "dlsurfer-pet-dl"),
        ("fmri-deepprep", "dlsurfer-deepprep"),
        ("qc-brainqcnet", "dlsurfer-brainqcnet"),
    ]:
        plan = build_plan(
            name,
            t1=Path("/tmp/t1.nii.gz"),
            sd=Path("/tmp/subjects"),
            sid="sub-EG",
            device="cpu",
        )
        run = runnable_steps(plan)
        assert any(needle in " ".join(s.argv) for s in run), (name, needle)


def test_atlas_dl_profiles_chain_sugar():
    for name, needle in [
        ("atlas-destrieux-dl", "-a2009s"),
        ("atlas-schaefer-dl", "mri_surf2surf"),
    ]:
        plan = build_plan(
            name,
            t1=Path("/tmp/t1.nii.gz"),
            sd=Path("/tmp/subjects"),
            sid="sub-EG",
            device="cpu",
        )
        run = runnable_steps(plan)
        assert any("dlsurfer-sugar" in " ".join(s.argv) for s in run), name
        assert any(needle in " ".join(s.argv) for s in run), (name, needle)


def test_schaefer_annot_paths():
    plan = build_plan(
        "atlas-schaefer",
        t1=Path("/tmp/t1.nii.gz"),
        sd=Path("/tmp/subjects"),
        sid="sub-EG",
        schaefer_annot_lh=Path("/tmp/lh.Schaefer.annot"),
        schaefer_annot_rh=Path("/tmp/rh.Schaefer.annot"),
        device="cpu",
    )
    run = runnable_steps(plan)
    assert len(run) == 2
    assert "/tmp/lh.Schaefer.annot" in run[0].argv
    assert "/tmp/rh.Schaefer.annot" in run[1].argv


def test_fs_long_two_steps():
    plan = build_plan(
        "fs-long",
        t1=Path("/tmp/t1.nii.gz"),
        sd=Path("/tmp/subjects"),
        sid="sub-EG",
        device="cpu",
    )
    run = runnable_steps(plan)
    assert len(run) == 2
    assert "-base" in run[0].argv and "-long" in run[1].argv


def test_gates_block_experimental_execute():
    from dlsurfer.gates import gates_blocking_profile
    from dlsurfer.runner import execute_plan

    blockers = gates_blocking_profile("structure-piriform-synthseg")
    assert any(b["id"] == "synthseg_pc_vs_jlf" for b in blockers)
    # TopoFit ±LIT machine gate passed → execute not blocked by gates
    assert gates_blocking_profile("surf-dl-topofit") == []
    assert gates_blocking_profile("surf-dl-topofit-only") == []
    # V2C still open (literature-best CSR gate)
    assert any(b["id"] == "tbi_lit_surfaces" for b in gates_blocking_profile("surf-dl-v2c"))
    assert any(b["id"] == "tbi_lit_surfaces" for b in gates_blocking_profile("core-dl-surf"))
    assert any(b["id"] == "tbi_lit_sphere_sugar" for b in gates_blocking_profile("sphere-sugar"))
    assert any(b["id"] == "tbi_lit_v2c_long" for b in gates_blocking_profile("surf-dl-v2c-long"))
    # thickness-fast gate is passed → no blocker
    assert gates_blocking_profile("thickness-fast") == []
    plan = build_plan(
        "surf-dl-v2c",
        t1=Path("/tmp/t1.nii.gz"),
        sd=Path("/tmp/subjects"),
        sid="sub-EG",
        device="cpu",
    )
    rc = execute_plan(plan, dry_run=False, allow_experimental=False)
    assert rc == 3


def test_live_runs_doc():
    path = Path(__file__).resolve().parents[1] / "docs" / "lab" / "LIVE_RUNS.md"
    assert path.is_file() and "EG smoke" in path.read_text()
    assert (Path(__file__).resolve().parents[1] / "docs" / "index.md").is_file()
    assert (Path(__file__).resolve().parents[1] / "dlsurfer" / "gates.yaml").is_file()


def test_topofit_multi_hemi_plan():
    plan = build_plan(
        "surf-dl-topofit-only",
        t1=Path("/tmp/t1.nii.gz"),
        sd=Path("/tmp/subjects"),
        sid="sub-EG",
        device="cuda",
    )
    run = runnable_steps(plan)
    assert len(run) == 3  # lh + rh TopoFit + FS surf contract
    assert Path(run[0].argv[0]).name == "mris_estimate_wm"
    assert run[0].argv[1:5] == ["-s", "sub-EG", "--hemi", "lh"]
    assert "--gpu" in run[0].argv and "--gpu" in run[1].argv
    assert run[1].argv[4] == "rh"
    assert run[2].argv[0] == "dlsurfer-install-surfaces"
    assert "--backend" in run[2].argv and run[2].argv[run[2].argv.index("--backend") + 1] == "topofit"


def test_v2c_plan_uses_wrapper():
    plan = build_plan(
        "surf-dl-v2c",
        t1=Path("/tmp/t1.nii.gz"),
        sd=Path("/tmp/subjects"),
        sid="sub-EG",
        device="cuda",
    )
    run = runnable_steps(plan)
    assert run and run[0].argv[0] == "dlsurfer-v2c"
    assert any(s.argv[0] == "dlsurfer-install-surfaces" for s in run)


def test_core_dl_surf_plan_and_fs_contract(tmp_path: Path):
    from dlsurfer.adapters.surfaces_fs import check_surf_contract, install_surfaces
    from dlsurfer.tools import resolve_tool

    assert resolve_tool("recon-surf-dl") == "core-dl-surf"
    assert resolve_tool("surfaces-dl") == "core-dl-surf"
    plan = build_plan(
        "core-dl-surf",
        t1=Path("/tmp/t1.nii.gz"),
        sd=Path("/tmp/subjects"),
        sid="sub-EG",
        device="cuda",
        fs_license=Path("/tmp/license.txt"),
    )
    run = runnable_steps(plan)
    assert any(s.stage == "seg_only" for s in run)
    assert any(s.argv and s.argv[0] == "dlsurfer-v2c" for s in run)
    install = [s for s in run if s.argv and s.argv[0] == "dlsurfer-install-surfaces"]
    assert install and install[0].argv[install[0].argv.index("--backend") + 1] == "v2c"

    sid = "sub-X"
    surf = tmp_path / sid / "surf"
    surf.mkdir(parents=True)
    for name in ("lh.white", "rh.white", "lh.pial", "rh.pial"):
        (surf / f"{name}.src").write_bytes(b"mesh")
    man = install_surfaces(
        tmp_path,
        sid,
        backend="generic",
        meshes={
            "lh.white": surf / "lh.white.src",
            "rh.white": surf / "rh.white.src",
            "lh.pial": surf / "lh.pial.src",
            "rh.pial": surf / "rh.pial.src",
        },
        mode="full",
    )
    assert man["actions"]
    assert check_surf_contract(tmp_path, sid, mode="full") == []
    assert (tmp_path / sid / "scripts" / "dlsurfer_surf_dl.done").is_file()


def test_schaefer_default_annots_resolve():
    root = Path(__file__).resolve().parents[1]
    lh = root / "resources/schaefer2018/fsaverage/label/lh.Schaefer2018_400Parcels_17Networks_order.annot"
    if not lh.is_file():
        return
    plan = build_plan(
        "atlas-schaefer",
        t1=Path("/tmp/t1.nii.gz"),
        sd=Path("/tmp/subjects"),
        sid="sub-EG",
        device="cpu",
    )
    run = runnable_steps(plan)
    assert "Schaefer2018" in run[0].argv[run[0].argv.index("--sval-annot") + 1]


def test_freeview_argv_builds(tmp_path: Path):
    from dlsurfer.freeview import build_freeview_argv, launch_freeview

    root = tmp_path / "sub-X"
    (root / "mri").mkdir(parents=True)
    (root / "surf").mkdir()
    (root / "mri" / "orig.mgz").write_bytes(b"x")
    (root / "surf" / "lh.white").write_bytes(b"x")
    (root / "surf" / "rh.white").write_bytes(b"x")
    argv = build_freeview_argv(root, aseg=False, pial=False)
    assert argv[0] == "-v"
    assert "orig.mgz" in argv[1]
    assert any("lh.white" in a for a in argv)
    rc = launch_freeview(tmp_path, "sub-X", dry_run=True)
    assert rc == 0


def test_quiet_plan_hides_info_noise():
    from dlsurfer.runner import format_plan

    plan = build_plan(
        "core",
        t1=Path("/tmp/t1.nii.gz"),
        sd=Path("/tmp/subjects"),
        sid="sub-EG",
        device="cpu",
    )
    quiet = format_plan(plan, verbose=False)
    assert "Why:" not in quiet
    assert "cite:" not in quiet
    assert "$ " in quiet
    assert "[run]" in quiet
    # Module info rows without argv should be omitted
    assert "(cerebnet)" not in quiet


def test_compare_and_gaps_summaries():
    from dlsurfer.reports import format_compare, format_gaps_remaining

    summary = format_compare(full=False)
    assert "summary" in summary.lower() or "Bottom line" in summary
    assert "--full" in summary
    assert "Replace FreeSurfer" in summary or "Bottom line" in summary
    full = format_compare(full=True)
    assert "| Capability |" in full or "Whole-brain aseg" in full
    assert len(full) > len(summary)

    gaps = format_gaps_remaining(full=False)
    assert "•" in gaps
    assert "meta-container" in gaps.lower() or "Meta-container" in gaps or "meta-container" in gaps
    assert "--full" in gaps
    gaps_full = format_gaps_remaining(full=True)
    assert "| Gap |" in gaps_full
    assert len(gaps_full) > len(gaps)


def test_doctor_brief_shorter_than_full():
    from dlsurfer.doctor import Check
    from dlsurfer.reports import format_doctor_report

    checks = [
        Check("FASTSURFER_HOME", True, "/fs"),
        Check("FREESURFER_HOME", True, "/fs"),
        Check("fs_license_env", True, "/lic"),
        Check("run_fastsurfer", True, "ok"),
        Check("neurolit", True, "ok"),
        Check("freesurfer", True, "ok"),
        Check("optional_toy", False, "missing"),
        Check("device_auto", True, "resolved device=cpu"),
    ]
    brief = format_doctor_report(checks, brief=True, version="0.0")
    full = format_doctor_report(checks, brief=False, version="0.0", claim="c", isolation="i")
    assert "[READY]" in brief and "[READY]" in full
    assert "optional_toy" in brief  # listed in optional note
    assert len(brief) < len(full)
    assert "[OK ] optional_toy" not in brief  # not a full wall line


def test_dl_only_public_surface():
    """Classical FS profiles stay registered but are not the public DLSurfer surface."""
    all_p = profiles()
    dl_p = profiles_dl_only()
    for name in CLASSICAL_PROFILES:
        assert name in all_p
        assert name not in dl_p
        assert all_p[name].get("is_deep_learning") is False
    assert "core" in dl_p and "structure-hippunfold" in dl_p
    with pytest.raises(ValueError, match="classical"):
        ensure_dl_profile("fs8")
    ensure_dl_profile("fs8", allow_classical=True)
    assert resolve_tool("recon-all") == "core"
    assert resolve_tool("hippunfold") == "structure-hippunfold"
    assert resolve_tool("synthseg") == "seg-quick-synthseg"


def test_credibility_identity_specialty_allowed():
    from dlsurfer.credibility import PROFILE_TIER, tier_for_profile
    from dlsurfer.tools import tools_table

    # Every registered profile resolves to A/B/C/D
    for name, meta in profiles().items():
        t = tier_for_profile(name, meta)
        assert t in {"A", "B", "C", "D"}, name
    assert PROFILE_TIER["core"] == "A"
    assert PROFILE_TIER["structure-hippunfold"] == "B"
    assert PROFILE_TIER["lesion-vbg"] == "C"
    assert PROFILE_TIER["fs8"] == "D"
    # Specialty aliases present across A/B/C
    aliases = {a: t for a, _p, t in tools_table()}
    assert aliases["sclimbic"] == "A"
    assert aliases["hippunfold"] == "B"
    assert aliases["vbg"] == "C"
    assert "recon-all" in aliases and aliases["recon-all"] == "A"
    # CLI policy command
    from dlsurfer.cli import main

    assert main(["credibility"]) == 0
    assert main(["tools", "--tier", "A"]) == 0


def test_cli_recon_all_and_tool_dry_run():
    from dlsurfer.cli import main

    assert (
        main(
            [
                "recon-all",
                "-i",
                "/tmp/t1.nii.gz",
                "-sd",
                "/tmp/sd",
                "-s",
                "sub-EG",
                "-q",
            ]
        )
        == 0
    )
    assert (
        main(
            [
                "tool",
                "synthstrip",
                "--t1",
                "/tmp/t1.nii.gz",
                "--sd",
                "/tmp/sd",
                "--sid",
                "sub-EG",
                "-q",
            ]
        )
        == 0
    )
    assert (
        main(
            [
                "run",
                "--profile",
                "subfields-ha",
                "--t1",
                "/tmp/t1.nii.gz",
                "--sd",
                "/tmp/sd",
                "--sid",
                "sub-EG",
                "-q",
            ]
        )
        == 2
    )


def test_gates_yaml_eg_passed_synthseg_open():
    import yaml

    path = Path(__file__).resolve().parents[1] / "dlsurfer" / "gates.yaml"
    gates = yaml.safe_load(path.read_text())["gates"]
    assert gates["core_lesion_eg_smoke"]["status"] == "passed"
    assert "JLF" in gates["synthseg_pc_vs_jlf"]["note"]
    assert gates["tbi_lit_topofit"]["status"] == "passed"
    assert gates["tbi_lit_surfaces"]["status"] == "passed"
    assert gates["tbi_lit_surfaces"]["blocks_profiles"] == ["surf-dl-v2c", "core-dl-surf"]
    assert "atlas-destrieux-dl" in gates["tbi_lit_sphere_sugar"]["blocks_profiles"]
    assert "surf-dl-v2c-long" in gates["tbi_lit_v2c_long"]["blocks_profiles"]
    assert "TBI_LIT_SURFACES_REPORT" in gates["tbi_lit_surfaces"]["evidence"]
    assert "docs/lab/" in gates["tbi_lit_surfaces"]["evidence"]

def test_fs_dl_gap_tools():
    from dlsurfer.credibility import PROFILE_TIER
    from dlsurfer.tools import resolve_tool

    assert resolve_tool("super-synth") == "seg-super-synth"
    assert resolve_tool("synthseg-robust") == "seg-synthseg-robust"
    assert resolve_tool("easyatlas") == "atlas-easyatlas"
    assert resolve_tool("histo-atlas") == "structure-histo-atlas"
    assert resolve_tool("hypvinn-t2") == "structure-hypvinn-t2"
    assert resolve_tool("fs8-dl") == "fs8-dl-modules"
    assert PROFILE_TIER["seg-super-synth"] == "B"
    assert PROFILE_TIER["seg-synthseg-robust"] == "A"
    assert PROFILE_TIER["structure-hypvinn-t2"] == "A"
    engs, _, _ = engines()
    for eid in ("super_synth", "easyatlas", "histo_atlas", "synthseg_robust", "hypvinn_t2", "fs8_dl_helpers"):
        assert eid in engs and engs[eid].get("is_deep_learning") is True
    plan = build_plan(
        "seg-synthseg-robust",
        t1=Path("/tmp/t1.nii.gz"),
        sd=Path("/tmp/sd"),
        sid="sub-X",
        device="cpu",
    )
    run = runnable_steps(plan)
    assert any("--robust" in s.argv and "--qc" in s.argv for s in run)
    plan2 = build_plan(
        "structure-hypvinn-t2",
        t1=Path("/tmp/t1.nii.gz"),
        sd=Path("/tmp/sd"),
        sid="sub-X",
        t2=Path("/tmp/t2.nii.gz"),
        device="cpu",
    )
    run2 = runnable_steps(plan2)
    assert any("--t2" in s.argv for s in run2)


def test_outputs_registry_covers_all_profiles():
    from dlsurfer.contract import (
        TOOL_CONTRACTS,
        check_profile_contract,
        ensure_fs_tree,
        format_layout_tree,
        registry_profile_names,
    )

    names = registry_profile_names()
    assert "core" in names and "dwi-tractseg" in names and "core-dl-surf" in names
    missing = set(profiles()) - names
    assert not missing, f"profiles missing from outputs_registry.yaml: {sorted(missing)}"
    assert "structure-hippunfold" in TOOL_CONTRACTS
    assert "hippunfold" in TOOL_CONTRACTS["structure-hippunfold"]
    tree = format_layout_tree()
    assert "mri/" in tree and "dwi/" in tree and "Multimodal" in tree


def test_ensure_fs_tree_and_specialty_contract(tmp_path: Path):
    from dlsurfer.contract import check_profile_contract, ensure_fs_tree

    sid = "sub-FS"
    root = ensure_fs_tree(tmp_path, sid)
    for d in ("mri", "surf", "label", "stats", "scripts", "tmp", "touch"):
        assert (root / d).is_dir()
    # hippunfold contract
    assert check_profile_contract(tmp_path, sid, "structure-hippunfold")
    (root / "hippunfold").mkdir()
    assert check_profile_contract(tmp_path, sid, "structure-hippunfold") == []
    # tractseg
    (root / "dwi" / "tractseg").mkdir(parents=True)
    assert check_profile_contract(tmp_path, sid, "dwi-tractseg") == []
