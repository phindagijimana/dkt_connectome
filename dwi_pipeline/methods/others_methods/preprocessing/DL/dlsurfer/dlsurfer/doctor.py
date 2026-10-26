"""Environment checks for DLSurfer."""

from __future__ import annotations

import os
import shutil
from dataclasses import dataclass
from pathlib import Path

from dlsurfer.device import resolve_device
from dlsurfer.registry import engines as load_engines


@dataclass
class Check:
    name: str
    ok: bool
    detail: str


def run_doctor(*, profile: str | None = None) -> list[Check]:
    checks: list[Check] = []
    _, pins, _ = load_engines()

    checks.append(
        Check(
            "claim",
            True,
            "DLSurfer orchestrates validated tools; does not replace FreeSurfer/FastSurfer science.",
        )
    )
    checks.append(
        Check(
            "pins",
            True,
            f"fastsurfer_image={pins.get('fastsurfer_image')} freesurfer_min={pins.get('freesurfer_min')}",
        )
    )

    dev = resolve_device("auto")
    checks.append(Check("device_auto", True, f"resolved device={dev}"))

    for label, path_env in [
        ("FASTSURFER_HOME", "FASTSURFER_HOME"),
        ("FREESURFER_HOME", "FREESURFER_HOME"),
        ("fs_license_env", "FS_LICENSE"),
    ]:
        val = os.environ.get(path_env, "")
        checks.append(
            Check(
                label,
                bool(val),
                val if val else f"${path_env} not set (required for live runs)",
            )
        )

    for exe, name in [
        ("mri_synthstrip", "synthstrip"),
        ("mri_synthseg", "synthseg"),
        ("mri_synthsr", "synthsr"),
        ("mri_super_synth", "super_synth"),
        ("mri_easyreg", "easyreg"),
        ("mri_easyatlas", "easyatlas"),
        ("mri_histo_atlas_segment_fireants", "histo_atlas"),
        ("mri_claustrum_seg", "mauri_claustrum"),
        ("mri_sclimbic_seg", "sclimbic"),
        ("mri_WMHsynthseg", "wmh_synthseg"),
        ("mri_segment_thalamic_nuclei_dti_cnn", "thalamic_dti_cnn"),
        ("lit-inpainting", "neurolit"),
        ("lit-postprocessing", "neurolit_post"),
        ("recon-all", "freesurfer"),
        ("segmentHA_T1.sh", "segment_ha"),
        ("segmentBS.sh", "segment_bs"),
        ("segmentThalamicNuclei.sh", "segment_thalamic"),
        ("dlsurfer-hippunfold", "dlsurfer_hippunfold"),
        ("dlsurfer-mars-brainstem", "mars_brainstem"),
        ("dlsurfer-sclimbic", "dlsurfer_sclimbic"),
        ("dlsurfer-wmh-synthseg", "dlsurfer_wmh_synthseg"),
        ("dlsurfer-v2c-long", "dlsurfer_v2c_long"),
        ("dlsurfer-thalamic-dti-cnn", "dlsurfer_thalamic_dti_cnn"),
        ("dlsurfer-ibeat", "dlsurfer_ibeat"),
        ("nvidia-smi", "gpu_smi"),
        ("apptainer", "apptainer"),
    ]:
        found = shutil.which(exe)
        checks.append(Check(name, found is not None, found or f"{exe} not on PATH"))

    for env, label in [
        ("HIPPUNFOLD_SIF", "hippunfold_sif"),
        ("MARS_SIF", "mars_sif"),
        ("IBEAT_SIF", "ibeat_sif"),
        ("V2C_LONG_ROOT", "v2c_long_root"),
        ("THAL_FA", "thal_fa"),
        ("THAL_V1", "thal_v1"),
    ]:
        val = os.environ.get(env, "")
        ok = bool(val) and Path(val).is_file() if env.endswith("_SIF") or env.endswith("_ROOT") else bool(val)
        if env == "V2C_LONG_ROOT":
            ok = bool(val) and Path(val).is_dir()
        detail = val if ok else (
            f"${env} unset (needed for specialty DL profiles)"
            if not val
            else f"missing path: {val}"
        )
        checks.append(Check(label, ok, detail if val else detail))

    fs_home = os.environ.get("FASTSURFER_HOME", "")
    if fs_home:
        rfs = os.path.join(fs_home, "run_fastsurfer.sh")
        checks.append(Check("run_fastsurfer", os.path.isfile(rfs), rfs))
        for wrap in ("srun_fastsurfer.sh", "brun_fastsurfer.sh"):
            p = os.path.join(fs_home, wrap)
            checks.append(Check(wrap, os.path.isfile(p), p if os.path.isfile(p) else f"missing {wrap}"))
    else:
        checks.append(Check("run_fastsurfer", False, "set FASTSURFER_HOME"))

    # SynthSeg-PC lab env (optional until structure-piriform-synthseg execute)
    for env in ("SYNTHSEG_PC_ROOT", "SYNTHSEG_PC_MODEL", "SYNTHSEG_PC_LABELS"):
        val = os.environ.get(env, "")
        ok = bool(val) and (Path(val).exists() if val else False)
        checks.append(
            Check(
                env,
                ok if val else False,
                val if ok else (f"{env} unset (needed for structure-piriform-synthseg)" if not val else f"missing path: {val}"),
            )
        )

    sch_lh = os.environ.get("SCHAEFER_ANNOT_LH", "")
    sch_rh = os.environ.get("SCHAEFER_ANNOT_RH", "")
    if sch_lh or sch_rh:
        checks.append(
            Check(
                "schaefer_annot",
                bool(sch_lh and sch_rh and Path(sch_lh).is_file() and Path(sch_rh).is_file()),
                f"LH={sch_lh or 'unset'} RH={sch_rh or 'unset'}",
            )
        )
    else:
        checks.append(
            Check(
                "schaefer_annot",
                False,
                "SCHAEFER_ANNOT_{LH,RH} unset (needed for atlas-schaefer execute)",
            )
        )

    if profile:
        from dlsurfer.gates import gates_blocking_profile

        blockers = gates_blocking_profile(profile)
        checks.append(
            Check(
                f"gates:{profile}",
                len(blockers) == 0,
                "clear" if not blockers else "blocked by " + ", ".join(b["id"] for b in blockers),
            )
        )

    return checks


def doctor_summary_ok(checks: list[Check], *, required: set[str] | None = None) -> bool:
    """Core live-run readiness (subset). Specialty tools may still be MISS."""
    required = required or {
        "FASTSURFER_HOME",
        "FREESURFER_HOME",
        "fs_license_env",
        "run_fastsurfer",
        "neurolit",
        "freesurfer",
    }
    by = {c.name: c for c in checks}
    return all(by[n].ok for n in required if n in by)
