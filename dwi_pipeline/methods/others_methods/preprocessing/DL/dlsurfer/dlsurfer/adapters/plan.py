"""Build executable step plans from profiles (dry-run friendly)."""

from __future__ import annotations

from dataclasses import dataclass, field
from pathlib import Path

from dlsurfer.device import resolve_device, stage_device
from dlsurfer.registry import engine as get_engine
from dlsurfer.registry import profile as get_profile


@dataclass
class Step:
    engine_id: str
    engine_name: str
    stage: str
    device: str
    argv: list[str]
    why: str
    citations: list[str]
    notes: list[str] = field(default_factory=list)
    informational: bool = False


@dataclass
class Plan:
    profile: str
    description: str
    steps: list[Step]
    warnings: list[str] = field(default_factory=list)
    citations_note: str = ""


_FS_MODULES = {"fastsurfer_vinn", "fastsurfer_cc", "cerebnet", "hypvinn", "recon_surf"}


def build_plan(
    profile_name: str,
    *,
    t1: Path,
    sd: Path,
    sid: str,
    lesion_mask: Path | None = None,
    fs_license: Path | None = None,
    device: str = "auto",
    post_lit: bool = True,
    threads: int = 4,
) -> Plan:
    prof = get_profile(profile_name)
    if prof.get("requires_lesion_mask") and lesion_mask is None:
        raise ValueError(f"Profile '{profile_name}' requires --lesion-mask")

    warnings: list[str] = []
    if prof.get("warn"):
        warnings.append(str(prof["warn"]))
    if prof.get("experimental"):
        warnings.append(
            f"EXPERIMENTAL '{profile_name}': {prof.get('gate', 'validate before production')}"
        )
    if profile_name == "core-lesion-native":
        warnings.append(
            "Native --lesion_mask cannot use FastSurfer --seg_only/--surf_only "
            "(no optimal GPU/CPU SLURM split). Prefer profile 'core-lesion' on clusters."
        )

    global_dev = resolve_device(device)
    t1 = Path(t1).resolve()
    sd = Path(sd).resolve()
    lic = str(fs_license.resolve()) if fs_license else "${FS_LICENSE}"
    inpainted = sd / sid / "mri" / "inpainted.lit.nii.gz"
    steps_out: list[Step] = []

    raw_steps = list(prof.get("steps", []))
    i = 0
    working_t1 = t1
    native_lesion = False

    while i < len(raw_steps):
        raw = raw_steps[i]
        if raw.get("optional_flag") == "post_lit" and not post_lit:
            i += 1
            continue

        eid = raw["engine"]
        mode = raw.get("mode", "")
        stage = raw.get("stage", "")

        # --- neuroLIT standalone fill ---
        if eid == "neurolit" and mode == "standalone_inpaint":
            assert lesion_mask is not None
            meta = get_engine(eid)
            steps_out.append(
                Step(
                    engine_id=eid,
                    engine_name=meta["name"],
                    stage="fill",
                    device=stage_device(raw.get("device", "gpu"), global_dev),
                    argv=[
                        "lit-inpainting",
                        "--input_image",
                        str(t1),
                        "--lesion_mask",
                        str(Path(lesion_mask).resolve()),
                        "--output_directory",
                        str(sd / sid),
                        "--device",
                        "cuda" if global_dev.startswith("cuda") else "cpu",
                        "--dilate",
                        "2",
                    ],
                    why=meta["why"].strip(),
                    citations=list(meta.get("cite", [])),
                    notes=["Standalone fill preserves later GPU seg / CPU surf split."],
                )
            )
            working_t1 = inpainted
            i += 1
            continue

        if eid == "neurolit" and mode == "lesion_mask_flag":
            native_lesion = True
            meta = get_engine(eid)
            steps_out.append(
                Step(
                    engine_id=eid,
                    engine_name=meta["name"],
                    stage="native_flag",
                    device=global_dev,
                    argv=[],
                    why=meta["why"].strip(),
                    citations=list(meta.get("cite", [])),
                    notes=["Will pass --lesion_mask into run_fastsurfer.sh"],
                    informational=True,
                )
            )
            i += 1
            continue

        if eid == "neurolit" and mode == "lit_post":
            meta = get_engine(eid)
            steps_out.append(
                Step(
                    engine_id=eid,
                    engine_name="neuroLIT postprocessing",
                    stage="post",
                    device="cpu",
                    argv=[
                        "lit-postprocessing",
                        "--subject-id",
                        sid,
                        "--subjects-dir",
                        str(sd),
                    ],
                    why=meta["why"].strip(),
                    citations=list(meta.get("cite", [])),
                    notes=["Adds *.lit* products / lesion reports into FS tree."],
                )
            )
            i += 1
            continue

        # --- Collapse contiguous FastSurfer modules into seg (+ surf) ---
        if eid in _FS_MODULES:
            block = []
            while i < len(raw_steps) and raw_steps[i]["engine"] in _FS_MODULES:
                block.append(raw_steps[i])
                i += 1
            steps_out.extend(
                _fastsurfer_block(
                    block,
                    t1=working_t1,
                    sd=sd,
                    sid=sid,
                    lic=lic,
                    device=global_dev,
                    threads=threads,
                    lesion_mask=Path(lesion_mask).resolve() if native_lesion and lesion_mask else None,
                )
            )
            continue

        # --- other single engines ---
        meta = get_engine(eid)
        use_t1 = inpainted if raw.get("t1") == "inpainted" else working_t1
        argv, notes, informational = _single_argv(
            eid,
            stage=stage,
            t1=use_t1,
            sd=sd,
            sid=sid,
            device=stage_device(raw.get("device", "auto"), global_dev),
        )
        steps_out.append(
            Step(
                engine_id=eid,
                engine_name=meta["name"],
                stage=stage or eid,
                device=stage_device(raw.get("device", "auto"), global_dev),
                argv=argv,
                why=meta["why"].strip(),
                citations=list(meta.get("cite", [])),
                notes=notes,
                informational=informational,
            )
        )
        i += 1

    return Plan(
        profile=profile_name,
        description=str(prof.get("description", "")).strip(),
        steps=steps_out,
        warnings=warnings,
        citations_note=str(prof.get("citations_note", "")),
    )


def _fastsurfer_block(
    block: list[dict],
    *,
    t1: Path,
    sd: Path,
    sid: str,
    lic: str,
    device: str,
    threads: int,
    lesion_mask: Path | None,
) -> list[Step]:
    ids = {b["engine"] for b in block}
    stages = {b.get("stage") for b in block}
    cites: list[str] = []
    whys: list[str] = []
    for eid in sorted(ids):
        meta = get_engine(eid)
        cites.extend(meta.get("cite", []))
        whys.append(f"{meta['name']}: {meta['why'].strip()}")

    # informational per-module citation steps
    info_steps = [
        Step(
            engine_id=eid,
            engine_name=get_engine(eid)["name"],
            stage="cited_module",
            device=device,
            argv=[],
            why=get_engine(eid)["why"].strip(),
            citations=list(get_engine(eid).get("cite", [])),
            informational=True,
        )
        for eid in sorted(ids)
    ]

    want_seg_only = stages <= {"seg", "seg_only"} or stages == {"seg_only"}
    want_surf_only = stages == {"surf"} or (stages <= {"surf"} and "fastsurfer_vinn" not in ids)
    want_split = "seg" in stages and "surf" in stages and not lesion_mask
    want_all = "all" in stages or lesion_mask is not None

    out: list[Step] = list(info_steps)
    base = [
        "${FASTSURFER_HOME}/run_fastsurfer.sh",
        "--t1",
        str(t1),
        "--sid",
        sid,
        "--sd",
        str(sd),
        "--fs_license",
        lic,
        "--device",
        "cpu" if device == "cpu" else "cuda",
        "--threads",
        str(threads),
        "--3T",
    ]
    if lesion_mask is not None:
        base.extend(["--lesion_mask", str(lesion_mask)])

    if want_all and not want_split:
        out.append(
            Step(
                engine_id="fastsurfer_pipeline",
                engine_name="FastSurfer (full / native)",
                stage="all",
                device=device,
                argv=list(base),
                why=" ; ".join(whys),
                citations=cites,
                notes=["Single job — required when --lesion_mask is set."],
            )
        )
        return out

    if want_seg_only and "recon_surf" not in ids:
        out.append(
            Step(
                engine_id="fastsurfer_pipeline",
                engine_name="FastSurfer segmentation",
                stage="seg_only",
                device=device if device != "cpu" else "cpu",
                argv=list(base) + ["--seg_only"],
                why=" ; ".join(whys),
                citations=cites,
                notes=["GPU partition recommended."],
            )
        )
        return out

    # default core: seg then surf (HPC-friendly)
    if "recon_surf" in ids or want_split:
        seg_argv = list(base) + ["--seg_only"]
        surf_argv = list(base) + ["--surf_only"]
        # surf_only should not re-request GPU necessarily
        out.append(
            Step(
                engine_id="fastsurfer_pipeline",
                engine_name="FastSurfer segmentation",
                stage="seg_only",
                device="cuda" if device != "cpu" else "cpu",
                argv=seg_argv,
                why="GPU-heavy VINN (+ modules).",
                citations=cites,
                notes=["Schedule on GPU partition (see hpc/slurm_core_lesion.sh)."],
            )
        )
        out.append(
            Step(
                engine_id="recon_surf",
                engine_name="FastSurfer recon-surf",
                stage="surf_only",
                device="cpu",
                argv=surf_argv,
                why=get_engine("recon_surf")["why"].strip(),
                citations=list(get_engine("recon_surf").get("cite", [])),
                notes=["CPU partition; do not hold a GPU idle for surfaces."],
            )
        )
        return out

    out.append(
        Step(
            engine_id="fastsurfer_pipeline",
            engine_name="FastSurfer",
            stage="run",
            device=device,
            argv=list(base),
            why=" ; ".join(whys),
            citations=cites,
        )
    )
    return out


def _single_argv(
    eid: str,
    *,
    stage: str,
    t1: Path,
    sd: Path,
    sid: str,
    device: str,
) -> tuple[list[str], list[str], bool]:
    if eid == "synthstrip":
        outm = sd / sid / "mri" / "brainmask_synthstrip.mgz"
        outb = sd / sid / "mri" / "brain_synthstrip.mgz"
        return (
            ["mri_synthstrip", "-i", str(t1), "-o", str(outb), "-m", str(outm)],
            ["Cite Hoopes SynthStrip 2022."],
            False,
        )
    if eid == "synthseg":
        cmd = ["mri_synthseg", "--i", str(t1), "--o", str(sd / sid / "mri" / "synthseg"), "--parc"]
        if device == "cpu":
            cmd.append("--cpu")
        return cmd, ["Cite Billot SynthSeg."], False
    if eid == "freesurfer8":
        return (
            ["recon-all", "-s", sid, "-sd", str(sd), "-i", str(t1), "-all"],
            ["FS8 embeds Synth*; cite FS8 release notes + Fischl 2012."],
            False,
        )
    if eid == "easyreg":
        return (
            [
                "mri_easyreg",
                "--ref",
                "<ref.nii.gz>",
                "--flo",
                str(t1),
                "--ref_seg",
                "<ref_seg.nii.gz>",
                "--flo_seg",
                "<flo_seg.nii.gz>",
                "--threads",
                "-1",
            ],
            ["Utility: fill placeholders; cite Iglesias EasyReg 2023."],
            False,
        )
    if eid == "synthmorph":
        return (
            [
                "mri_synthmorph",
                "register",
                "-m",
                str(t1),
                "-f",
                "<fixed.nii.gz>",
                "-o",
                str(sd / sid / "mri" / "synthmorph"),
            ],
            ["Utility placeholders; cite Hoffmann SynthMorph."],
            False,
        )
    if eid == "deepn4":
        return (
            [
                "dipy_bias_field_correction",
                str(t1),
                "--method",
                "n4",
                "--out_dir",
                str(sd / sid / "mri"),
            ],
            ["Or MASILab/DeepN4; cite Kanakaraj DeepN4 2024."],
            False,
        )
    if eid == "topofit":
        return (
            ["mris_estimate_wm", "-h"],
            ["EXPERIMENTAL Production WM fit in FS; cite Hoopes TopoFit 2022. Pass TBI±LIT gate."],
            False,
        )
    if eid == "v2c_flow":
        return (
            [
                "python",
                "main.py",
                "--test",
                "-n",
                "V2C-Flow-S-ADNI",
                f"# t1={t1}",
                f"# out={sd / sid}",
                "# see https://github.com/ai-med/Vox2Cortex",
            ],
            ["EXPERIMENTAL Ready CSR; cite Bongratz CVPR 2022 + V2C-Flow 2024."],
            False,
        )
    if eid == "sugar":
        return (
            [f"# SUGAR sphere.reg alternative — subjects_dir={sd} sid={sid}"],
            ["EXPERIMENTAL; cite Ren SUGAR 2023. https://github.com/pBFSLab/SUGAR"],
            True,
        )
    if eid == "dl_cte":
        return (
            [f"# DL-CTE thickness — t1={t1} — NOT for connectome handoff"],
            ["Cite Rebsamen DL+DiReCT; CortexMorph; Wu DL-CTE."],
            True,
        )
    return [f"# unset builder for {eid}"], [], True


def runnable_steps(plan: Plan) -> list[Step]:
    return [s for s in plan.steps if s.argv and not s.informational and not str(s.argv[0]).startswith("#")]