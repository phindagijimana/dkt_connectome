#!/usr/bin/env python3
"""Adapt HCP-YA Test-Retest preprocessed T1w/Diffusion into a QSIPrep-like layout.

Not leftover y. Not gold. No redistribution of HCP data.

ses-1 T1 is the subject template (FastSurfer + both DWIs in that space).
ses-2 T1→ses-1 rigid, then DWI + bvecs transformed. Skips QSIPrep (user choice).
"""

from __future__ import annotations

import argparse
import json
import os
import shutil
import subprocess
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
SD = HERE.parents[3] / "sample_data"
RAW = SD / "hcp_retest" / "raw" / "preproc"
DS = SD / "hcp_retest"
CONN = Path.home() / "Documents/others/containers/dkt_connectome.sif"
TMP = Path.home() / ".cache/dkt-connectome/apptainer_tmp"

QSIPREP_DESC = {
    "Name": "qsiprep output",
    "BIDSVersion": "1.1.1",
    "PipelineDescription": {
        "Name": "qsiprep",
        "Version": "hcp-adapter-0",
        "CodeURL": "local:hcp_to_qsiprep.py",
    },
    "GeneratedBy": [
        {
            "Name": "hcp_to_qsiprep",
            "Version": "0",
            "Description": "HCP minimally-preprocessed Diffusion+T1 adapted to QSIPrep layout; ses-2 rigid to ses-1 T1",
        }
    ],
}


def run(cmd: list[str], **kw) -> None:
    print("+", " ".join(cmd), flush=True)
    subprocess.run(cmd, check=True, **kw)


def link_or_copy(src: Path, dst: Path) -> None:
    dst.parent.mkdir(parents=True, exist_ok=True)
    if dst.is_symlink() or dst.is_file():
        if dst.is_symlink() and dst.resolve() == src.resolve():
            return
        if dst.is_file() and not dst.is_symlink() and dst.stat().st_size == src.stat().st_size:
            return
        dst.unlink()
    try:
        os.link(src, dst)
    except OSError:
        try:
            dst.symlink_to(src)
        except OSError:
            shutil.copy2(src, dst)


def apptainer_bash(script: str, binds: list[tuple[str, str]]) -> None:
    TMP.mkdir(parents=True, exist_ok=True)
    env = os.environ.copy()
    env["APPTAINER_TMPDIR"] = str(TMP)
    env["SINGULARITY_TMPDIR"] = str(TMP)
    cmd = [
        "apptainer",
        "exec",
        "--cleanenv",
        "--containall",
        "--env",
        "LD_LIBRARY_PATH=/opt/ants/lib:/opt/mrtrix3-latest/lib",
        "--env",
        "PATH=/opt/mrtrix3-latest/bin:/opt/ants/bin:/usr/local/bin:/usr/bin:/bin",
        "-B",
        f"{TMP}:/tmp",
    ]
    for host, guest in binds:
        cmd += ["-B", f"{host}:{guest}"]
    cmd += [str(CONN), "bash", "-lc", script]
    run(cmd, env=env)


def write_json(path: Path, rec: dict) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(rec, indent=2) + "\n")


def adapt(sid: str, force: bool = False) -> dict:
    if not CONN.is_file():
        raise SystemExit(f"missing container {CONN}")
    src1 = RAW / sid / "ses-1" / "T1w"
    src2 = RAW / sid / "ses-2" / "T1w"
    for p in (
        src1 / "T1w_acpc_dc_restore.nii.gz",
        src1 / "Diffusion" / "data.nii.gz",
        src2 / "T1w_acpc_dc_restore.nii.gz",
        src2 / "Diffusion" / "data.nii.gz",
    ):
        if not p.is_file():
            raise SystemExit(f"missing {p}")

    bids_t1 = DS / "bids" / f"sub-{sid}" / "ses-1" / "anat" / f"sub-{sid}_ses-1_T1w.nii.gz"
    qroot = DS / "results" / f"sub-{sid}"
    qsub = qroot / f"sub-{sid}"
    anat = qsub / "anat"
    work = qroot / ".adapt_work"
    work.mkdir(parents=True, exist_ok=True)
    marker = qroot / "adapter.json"
    if marker.is_file() and not force:
        dwirefs = [
            qsub / f"ses-{s}" / "dwi" / f"sub-{sid}_ses-{s}_space-T1w_dwiref.nii.gz" for s in (1, 2)
        ]
        if all(p.is_file() for p in dwirefs):
            print(f"[HCP-ADAPT] already done {sid}", flush=True)
            return json.loads(marker.read_text())

    link_or_copy(src1 / "T1w_acpc_dc_restore.nii.gz", bids_t1)
    write_json(
        bids_t1.with_suffix("").with_suffix(".json"),
        {
            "Modality": "MR",
            "MagneticFieldStrength": 3,
            "Manufacturer": "Siemens",
            "ManufacturersModelName": "Connectome Skyra",
            "InstitutionName": "HCP",
            "Adaptive": "HCP T1w_acpc_dc_restore as ses-1 T1",
        },
    )

    preproc_t1 = anat / f"sub-{sid}_desc-preproc_T1w.nii.gz"
    link_or_copy(src1 / "T1w_acpc_dc_restore.nii.gz", preproc_t1)
    write_json(preproc_t1.with_suffix("").with_suffix(".json"), {"keep_dtype": True, "source": "HCP T1w_acpc_dc_restore ses-1"})
    brain = anat / f"sub-{sid}_desc-brain_mask.nii.gz"
    if (src1 / "T1w_acpc_dc_restore_brain.nii.gz").is_file() and (not brain.is_file() or force):
        apptainer_bash(
            "mrcalc /in/T1w_acpc_dc_restore_brain.nii.gz 0 -gt /out/tmp_mask.nii.gz -force && "
            "mrconvert /out/tmp_mask.nii.gz /out/brain_mask.nii.gz -datatype uint8 -force && "
            "rm -f /out/tmp_mask.nii.gz",
            [(str(src1), "/in"), (str(anat), "/out")],
        )
        produced = anat / "brain_mask.nii.gz"
        if produced.is_file():
            produced.replace(brain)

    # ses-1 DWI: link into QSIPrep names; build dwiref from b≈0.
    dwi1 = qsub / "ses-1" / "dwi"
    dwi1.mkdir(parents=True, exist_ok=True)
    pre1 = dwi1 / f"sub-{sid}_ses-1_space-T1w_desc-preproc_dwi.nii.gz"
    link_or_copy(src1 / "Diffusion" / "data.nii.gz", pre1)
    link_or_copy(src1 / "Diffusion" / "bvals", pre1.with_suffix("").with_suffix(".bval"))
    link_or_copy(src1 / "Diffusion" / "bvecs", pre1.with_suffix("").with_suffix(".bvec"))
    mask1 = dwi1 / f"sub-{sid}_ses-1_space-T1w_desc-brain_mask.nii.gz"
    link_or_copy(src1 / "Diffusion" / "nodif_brain_mask.nii.gz", mask1)
    dwiref1 = dwi1 / f"sub-{sid}_ses-1_space-T1w_dwiref.nii.gz"
    if not dwiref1.is_file() or force:
        apptainer_bash(
            "dwiextract /dwi/data.nii.gz /work/b0.mif -bzero -fslgrad /dwi/bvecs /dwi/bvals -force && "
            "mrmath /work/b0.mif mean /work/dwiref.nii.gz -axis 3 -force && "
            "cp /work/dwiref.nii.gz /out/dwiref.nii.gz",
            [
                (str(src1 / "Diffusion"), "/dwi"),
                (str(work), "/work"),
                (str(dwi1), "/out"),
            ],
        )
        (dwi1 / "dwiref.nii.gz").replace(dwiref1)

    # ses-2 → ses-1 rigid on T1, apply to DWI (+ rotate bvecs via mrtransform).
    dwi2 = qsub / "ses-2" / "dwi"
    dwi2.mkdir(parents=True, exist_ok=True)
    pre2 = dwi2 / f"sub-{sid}_ses-2_space-T1w_desc-preproc_dwi.nii.gz"
    mask2 = dwi2 / f"sub-{sid}_ses-2_space-T1w_desc-brain_mask.nii.gz"
    dwiref2 = dwi2 / f"sub-{sid}_ses-2_space-T1w_dwiref.nii.gz"
    xfm = work / "ses2_to_ses1_rigid.mat"
    if not pre2.is_file() or force:
        t1_bind = work / "t1_bind"
        t1_bind.mkdir(parents=True, exist_ok=True)
        link_or_copy(src1 / "T1w_acpc_dc_restore.nii.gz", t1_bind / "ses1_T1.nii.gz")
        link_or_copy(src2 / "T1w_acpc_dc_restore.nii.gz", t1_bind / "ses2_T1.nii.gz")

        apptainer_bash(
            "set -euo pipefail; "
            # Moving=ses-2 T1, template=ses-1 T1 → rigid maps ses-2 → ses-1.
            "mrregister /t1/ses2_T1.nii.gz /t1/ses1_T1.nii.gz "
            "  -type rigid -rigid /work/ses2_to_ses1_rigid.txt -force; "
            "mrtransform /dwi2/data.nii.gz /out/preproc_dwi.nii.gz "
            "  -linear /work/ses2_to_ses1_rigid.txt "
            "  -template /dwi1/data.nii.gz "
            "  -fslgrad /dwi2/bvecs /dwi2/bvals "
            "  -export_grad_fsl /out/preproc_dwi.bvec /out/preproc_dwi.bval "
            "  -interp cubic -force; "
            "mrtransform /dwi2/nodif_brain_mask.nii.gz /out/mask.nii.gz "
            "  -linear /work/ses2_to_ses1_rigid.txt "
            "  -template /dwi1/nodif_brain_mask.nii.gz "
            "  -interp nearest -datatype uint8 -force; "
            "dwiextract /out/preproc_dwi.nii.gz /work/b0s.mif -bzero "
            "  -fslgrad /out/preproc_dwi.bvec /out/preproc_dwi.bval -force; "
            "mrmath /work/b0s.mif mean /out/dwiref.nii.gz -axis 3 -force",
            [
                (str(work), "/work"),
                (str(dwi2), "/out"),
                (str(src2 / "Diffusion"), "/dwi2"),
                (str(src1 / "Diffusion"), "/dwi1"),
                (str(t1_bind), "/t1"),
            ],
        )
        (dwi2 / "preproc_dwi.nii.gz").replace(pre2)
        (dwi2 / "preproc_dwi.bval").replace(pre2.with_suffix("").with_suffix(".bval"))
        (dwi2 / "preproc_dwi.bvec").replace(pre2.with_suffix("").with_suffix(".bvec"))
        (dwi2 / "mask.nii.gz").replace(mask2)
        (dwi2 / "dwiref.nii.gz").replace(dwiref2)
        if (work / "ses2_to_ses1_rigid.txt").is_file():
            shutil.copy2(work / "ses2_to_ses1_rigid.txt", xfm)

    write_json(qroot / "dataset_description.json", QSIPREP_DESC)
    write_json(
        qsub / "ses-1" / "dwi" / f"sub-{sid}_ses-1_space-T1w_desc-preproc_dwi.json",
        {"source": "HCP T1w/Diffusion ses-1", "SpatialReference": "ses-1 T1w_acpc_dc_restore"},
    )
    write_json(
        qsub / "ses-2" / "dwi" / f"sub-{sid}_ses-2_space-T1w_desc-preproc_dwi.json",
        {
            "source": "HCP T1w/Diffusion ses-2 rigid→ses-1 T1",
            "SpatialReference": "ses-1 T1w_acpc_dc_restore",
            "transform": str(xfm.name),
        },
    )

    rec = {
        "sub": sid,
        "dataset": "hcp_retest",
        "ses1_t1_template": True,
        "ses2_rigid_to_ses1": True,
        "skips_qsiprep": True,
        "raw": str(RAW / sid),
        "results": str(qroot),
        "bids_t1": str(bids_t1),
        "recon_spec": "mrtrix_multishell_msmt_ACT-hsvs",
        "not_gold": True,
        "not_leftover_y": True,
    }
    write_json(marker, rec)
    print(json.dumps(rec), flush=True)
    return rec


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("subject", help="HCP subject ID, e.g. 103818")
    ap.add_argument("--force", action="store_true")
    args = ap.parse_args()
    adapt(args.subject, force=args.force)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
