"""Build executable step plans from profiles (dry-run friendly)."""

from __future__ import annotations

from dataclasses import dataclass, field
from pathlib import Path
from typing import Any

import yaml

from dlsurfer.device import resolve_device, stage_device
from dlsurfer.registry import engine as get_engine
from dlsurfer.registry import profile as get_profile

_PKG = Path(__file__).resolve().parent.parent


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
    atlas: str = "dkt"
    extras: dict[str, Any] = field(default_factory=dict)


_FS_MODULES = {"fastsurfer_vinn", "fastsurfer_cc", "cerebnet", "hypvinn", "recon_surf"}

_WIRED_ATLASES = {"dkt", "dk", "destrieux", "schaefer", "aseg"}


def load_atlases() -> dict[str, Any]:
    with (_PKG / "atlases.yaml").open() as f:
        return yaml.safe_load(f)


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
    atlas: str | None = None,
    no_cc: bool = False,
    no_cereb: bool = False,
    no_hypothal: bool = False,
    vox_size: float | None = None,
    hpc: str = "none",
) -> Plan:
    prof = get_profile(profile_name)
    if prof.get("requires_lesion_mask") and lesion_mask is None:
        raise ValueError(f"Profile '{profile_name}' requires --lesion-mask")

    atlas_data = load_atlases()
    atlas = (atlas or prof.get("atlas") or atlas_data.get("default") or "dkt").lower()
    known = set(atlas_data.get("atlases", {})) | {"aseg"}
    if atlas not in known:
        raise ValueError(f"Unknown atlas '{atlas}'. Known: {', '.join(sorted(known))}")
    if atlas not in _WIRED_ATLASES:
        raise ValueError(f"Atlas '{atlas}' is registered but not wired yet.")

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
    if atlas == "dk":
        warnings.append("Atlas dk → FastSurfer --fsaparc (classical DK on FastSurfer surfaces).")
    if atlas in {"destrieux", "schaefer"} and profile_name in {"core", "core-lesion", "core-dk"}:
        warnings.append(
            f"Atlas {atlas} is not applied inside FastSurfer VINN; "
            f"run profile atlas-{atlas} after surfaces exist."
        )
    if hpc not in {"none", "srun", "brun"}:
        raise ValueError("--hpc must be none|srun|brun")
    if vox_size is not None and vox_size <= 0:
        raise ValueError("--vox-size must be positive")

    global_dev = resolve_device(device)
    t1 = Path(t1).resolve()
    sd = Path(sd).resolve()
    lic = str(fs_license.resolve()) if fs_license else "${FS_LICENSE}"
    inpainted = sd / sid / "mri" / "inpainted.lit.nii.gz"
    synthsr_t1 = sd / sid / "mri" / "T1.synthsr.nii.gz"
    steps_out: list[Step] = []

    raw_steps = list(prof.get("steps", []))
    # Drop disabled FastSurfer modules before collapsing
    skip_engines: set[str] = set()
    if no_cc:
        skip_engines.add("fastsurfer_cc")
    if no_cereb:
        skip_engines.add("cerebnet")
    if no_hypothal:
        skip_engines.add("hypvinn")
    raw_steps = [s for s in raw_steps if s["engine"] not in skip_engines]

    i = 0
    working_t1 = t1
    native_lesion = False
    fs_flags: list[str] = []
    if no_cc:
        fs_flags.append("--no_cc")
    if no_cereb:
        fs_flags.append("--no_cereb")
    if no_hypothal:
        fs_flags.append("--no_hypothal")
    if atlas == "dk":
        fs_flags.append("--fsaparc")
    if vox_size is not None:
        fs_flags.extend(["--vox_size", str(vox_size)])

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
                    extra_flags=fs_flags,
                    hpc=hpc,
                )
            )
            continue

        # --- other single engines ---
        meta = get_engine(eid)
        if raw.get("t1") == "inpainted":
            use_t1 = inpainted
        elif raw.get("t1") == "synthsr":
            use_t1 = synthsr_t1
        else:
            use_t1 = working_t1
        argv, notes, informational = _single_argv(
            eid,
            stage=stage,
            t1=use_t1,
            sd=sd,
            sid=sid,
            device=stage_device(raw.get("device", "auto"), global_dev),
            atlas=atlas,
            threads=threads,
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
        if eid == "synthsr":
            working_t1 = synthsr_t1
        i += 1

    extras = {
        "atlas": atlas,
        "no_cc": no_cc,
        "no_cereb": no_cereb,
        "no_hypothal": no_hypothal,
        "vox_size": vox_size,
        "hpc": hpc,
        "fs_flags": fs_flags,
    }
    return Plan(
        profile=profile_name,
        description=str(prof.get("description", "")).strip(),
        steps=steps_out,
        warnings=warnings,
        citations_note=str(prof.get("citations_note", "")),
        atlas=atlas,
        extras=extras,
    )


def _fs_launcher(hpc: str) -> str:
    if hpc == "srun":
        return "${FASTSURFER_HOME}/srun_fastsurfer.sh"
    if hpc == "brun":
        return "${FASTSURFER_HOME}/brun_fastsurfer.sh"
    return "${FASTSURFER_HOME}/run_fastsurfer.sh"


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
    extra_flags: list[str] | None = None,
    hpc: str = "none",
) -> list[Step]:
    ids = {b["engine"] for b in block}
    stages = {b.get("stage") for b in block}
    cites: list[str] = []
    whys: list[str] = []
    for eid in sorted(ids):
        meta = get_engine(eid)
        cites.extend(meta.get("cite", []))
        whys.append(f"{meta['name']}: {meta['why'].strip()}")

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
    want_split = "seg" in stages and "surf" in stages and not lesion_mask
    want_all = "all" in stages or lesion_mask is not None
    extra_flags = list(extra_flags or [])

    out: list[Step] = list(info_steps)
    launcher = _fs_launcher(hpc)
    base = [
        launcher,
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
        *extra_flags,
    ]
    hpc_notes: list[str] = []
    if hpc in {"srun", "brun"}:
        hpc_notes.append(f"HPC launcher={launcher} (gap-fill: srun_fastsurfer).")
    if "--fsaparc" in extra_flags:
        hpc_notes.append("DK atlas via --fsaparc.")
    if any(f == "--vox_size" for f in extra_flags):
        hpc_notes.append("High-res VINN via --vox_size.")

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
                notes=["Single job — required when --lesion_mask is set.", *hpc_notes],
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
                notes=["GPU partition recommended.", *hpc_notes],
            )
        )
        return out

    if "recon_surf" in ids or want_split:
        seg_argv = list(base) + ["--seg_only"]
        surf_argv = list(base) + ["--surf_only"]
        out.append(
            Step(
                engine_id="fastsurfer_pipeline",
                engine_name="FastSurfer segmentation",
                stage="seg_only",
                device="cuda" if device != "cpu" else "cpu",
                argv=seg_argv,
                why="GPU-heavy VINN (+ modules).",
                citations=cites,
                notes=["Schedule on GPU partition (see hpc/slurm_core_lesion.sh).", *hpc_notes],
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
                notes=["CPU partition; do not hold a GPU idle for surfaces.", *hpc_notes],
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
            notes=hpc_notes,
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
    atlas: str = "dkt",
    threads: int = 4,
) -> tuple[list[str], list[str], bool]:
    if eid == "synthsr":
        out = sd / sid / "mri" / "T1.synthsr.nii.gz"
        return (
            ["mri_synthsr", "--i", str(t1), "--o", str(out)],
            [
                "Optional T1 preprocess only — not a PC/claustrum segmenter.",
                "Cite Billot SynthSR; mirrors piriform/synthseg_pc/maybe_synthsr.sh.",
            ],
            False,
        )
    if eid == "mauri_claustrum":
        out = sd / sid / "mri" / "claustrum"
        return (
            [
                "mri_claustrum_seg",
                "--i",
                str(t1),
                "--o",
                str(out),
                "--threads",
                str(threads),
                "--topo-correct",
            ],
            [
                "Mauri 2025; lab Documents/clau_seg. FS LUT 138/139 typical.",
                "Do not use these weights for piriform (Steinbart 125/126).",
            ],
            False,
        )
    if eid == "synthseg_pc":
        out = sd / sid / "mri" / "piriform_synthseg_pc"
        return (
            [
                "python",
                "${SYNTHSEG_PC_ROOT}/predict_ideas_one.py",
                "--images",
                str(t1),
                "--out",
                str(out),
                "--model",
                "${SYNTHSEG_PC_MODEL}",
                "--seg-labels",
                "${SYNTHSEG_PC_LABELS}",
                "--synthseg-root",
                "${SYNTHSEG_ROOT:-${CLAU_SEG_ROOT}/tools/SynthSeg}",
            ],
            [
                "EXPERIMENTAL: set SYNTHSEG_PC_* env vars (Documents/piriform/synthseg_pc).",
                "NOT mri_synthseg; NOT Mauri claustrum. IDEAS production PC = JLF until gate.",
            ],
            False,
        )
    if eid == "hippunfold":
        return (
            [
                "hippunfold",
                "<bids_or_input>",
                str(sd / sid / "hippunfold"),
                "participant",
                "--participant_label",
                sid,
                f"# t1={t1}",
            ],
            [
                "Ready DL HA alternative; default HA remains segmentHA (subfields-ha).",
                "Cite DeKraker eLife 2022; lab Documents/HippUnfold.",
            ],
            False,
        )
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
        argv = ["recon-all", "-s", sid, "-sd", str(sd), "-i", str(t1), "-all"]
        notes = ["FS8 embeds Synth*; cite FS8 release notes + Fischl 2012."]
        if atlas == "destrieux":
            argv.append("-a2009s")
            notes.append("Also requests Destrieux (-a2009s).")
        return argv, notes, False
    if eid == "freesurfer_long":
        return (
            [
                "recon-all",
                "-base",
                f"{sid}_base",
                "-tp",
                f"{sid}_tp1",
                "-tp",
                f"{sid}_tp2",
                "-all",
                ";",
                "recon-all",
                "-long",
                f"{sid}_tp1",
                f"{sid}_base",
                "-all",
            ],
            [
                "Placeholders: create cross-sectional runs first, then -base / -long.",
                "Best Production alt for longitudinal gap (Reuter 2012).",
            ],
            False,
        )
    if eid == "segment_ha":
        return (
            ["segmentHA_T1.sh", sid, str(sd)],
            ["Requires finished SUBJECTS_DIR; best Production alt for HA gap."],
            False,
        )
    if eid == "segment_bs":
        return (
            ["segmentBS.sh", sid, str(sd)],
            ["Best Production alt for brainstem nuclei gap."],
            False,
        )
    if eid == "segment_thalamic":
        return (
            ["segmentThalamicNuclei.sh", sid, str(sd)],
            ["Best Production alt for thalamic nuclei gap."],
            False,
        )
    if eid == "recon_all_clinical":
        return (
            [
                "recon-all-clinical.sh",
                "-s",
                sid,
                "-sd",
                str(sd),
                "-i",
                str(t1),
            ],
            [
                "Best Production alt for clinical/odd-contrast gap.",
                "True neonates: use Infant FreeSurfer (documented alternative).",
            ],
            False,
        )
    if eid == "atlas_destrieux":
        return (
            ["recon-all", "-s", sid, "-sd", str(sd), "-a2009s"],
            [
                "Needs white/pial + sphere.reg already present.",
                "Best Production alt for Destrieux gap.",
            ],
            False,
        )
    if eid == "atlas_schaefer":
        lh = "${SCHAEFER_ANNOT_LH}"
        rh = "${SCHAEFER_ANNOT_RH}"
        return (
            [
                "mri_surf2surf",
                "--srcsubject",
                "fsaverage",
                "--trgsubject",
                sid,
                "--hemi",
                "lh",
                "--sval-annot",
                lh,
                "--tval",
                str(sd / sid / "label" / "lh.schaefer.annot"),
                ";",
                "mri_surf2surf",
                "--srcsubject",
                "fsaverage",
                "--trgsubject",
                sid,
                "--hemi",
                "rh",
                "--sval-annot",
                rh,
                "--tval",
                str(sd / sid / "label" / "rh.schaefer.annot"),
            ],
            [
                "Set SCHAEFER_ANNOT_{LH,RH} to fsaverage annot paths.",
                "Best Ready alt for Schaefer gap; same pattern for HCP-MMP.",
            ],
            False,
        )
    if eid == "srun_fastsurfer":
        return (
            [f"# enable via: dlsurfer run --hpc srun …  (launcher swap)"],
            ["Informational; use --hpc srun|brun on FastSurfer profiles."],
            True,
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
