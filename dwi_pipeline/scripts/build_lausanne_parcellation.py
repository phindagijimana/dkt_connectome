#!/usr/bin/env python3
"""Build Lausanne-60 volume parcellation from a FreeSurfer subject tree.

Port of the scale60 path in easy_lausanne (EPFL/UNIL-CHUV, BSD license).
Generates a single integer-labeled NIfTI volume in native FreeSurfer space
(aligned to mri/orig.mgz). Downstream Step 4 warps it to DWI space.
"""

from __future__ import annotations

import argparse
import math
import shutil
import subprocess
import sys
import xml.etree.ElementTree as ET
from pathlib import Path

import nibabel as nib
import numpy as np


def run(
    cmd: list[str],
    *,
    fs_prefix: list[str] | None = None,
    check: bool = True,
) -> subprocess.CompletedProcess[str]:
    full = (fs_prefix or []) + cmd
    print("+", " ".join(full), flush=True)
    proc = subprocess.run(full, check=False, text=True, capture_output=True)
    if check and proc.returncode != 0:
        sys.stderr.write(proc.stdout or "")
        sys.stderr.write(proc.stderr or "")
        proc.check_returncode()
    return proc


def parse_graphml(graphml_path: Path) -> list[dict[str, str]]:
    root = ET.parse(graphml_path).getroot()
    key_ids: dict[str, str] = {}
    for key in root.iter():
        if key.tag.endswith("key"):
            key_ids[key.attrib.get("id", "")] = key.attrib.get("attr.name", "")

    nodes: list[dict[str, str]] = []
    for node in root.iter():
        if not node.tag.endswith("node"):
            continue
        data: dict[str, str] = {}
        for elem in node:
            if not elem.tag.endswith("data"):
                continue
            attr = key_ids.get(elem.attrib.get("key", ""), elem.attrib.get("key", ""))
            data[attr] = elem.text or ""
        nodes.append(
            {
                "region": data.get("dn_region", ""),
                "fsname": data.get("dn_fsname", ""),
                "hemisphere": data.get("dn_hemisphere", ""),
                "correspondence_id": data.get("dn_correspondence_id", ""),
                "name": data.get("dn_name", ""),
                "aseg_val": data.get("dn_fs_aseg_val", ""),
            }
        )
    return nodes


def require_path(path: Path, label: str, *, directory: bool = False) -> Path:
    ok = path.is_dir() if directory else path.is_file()
    if not ok:
        raise FileNotFoundError(f"missing {label}: {path}")
    return path


def build_surface_labels(
    fs_subject_fs: Path,
    fs_subject_host: Path,
    _work_dir_host: Path,
    _work_dir_fs: Path,
    atlas_dir_host: Path,
    atlas_dir_fs: Path,
    *,
    fs_prefix: list[str],
    subject_id: str,
) -> tuple[Path, Path]:
    label_dir_host = fs_subject_host / "label"
    label_dir_fs = fs_subject_fs / "label"
    label_dir_host.mkdir(parents=True, exist_ok=True)
    gcs_dir_host = require_path(atlas_dir_host / "gcs", "atlas gcs directory", directory=True)

    for hemi, gcs_name, annot_name, folder, aparc in (
        ("lh", "myatlas_60_lh.gcs", "lh.myaparc_60.annot", "regenerated_lh_60", "myaparc_60"),
        ("rh", "myatlas_60_rh.gcs", "rh.myaparc_60.annot", "regenerated_rh_60", "myaparc_60"),
    ):
        require_path(gcs_dir_host / gcs_name, gcs_name)
        sphere_fs = fs_subject_fs / "surf" / f"{hemi}.sphere.reg"
        require_path(fs_subject_host / "surf" / f"{hemi}.sphere.reg", f"{hemi}.sphere.reg")
        gcs_fs = atlas_dir_fs / "gcs" / gcs_name
        annot_fs = label_dir_fs / annot_name
        out_labels_host = label_dir_host / folder
        out_labels_fs = label_dir_fs / folder
        out_labels_host.mkdir(parents=True, exist_ok=True)
        run(
            [
                "mris_ca_label",
                subject_id,
                hemi,
                str(sphere_fs),
                str(gcs_fs),
                str(annot_fs),
            ],
            fs_prefix=fs_prefix,
        )
        run(
            [
                "mri_annotation2label",
                "--subject",
                subject_id,
                "--hemi",
                hemi,
                "--outdir",
                str(out_labels_fs),
                "--annotation",
                aparc,
            ],
            fs_prefix=fs_prefix,
        )
    return label_dir_host / "regenerated_lh_60", label_dir_host / "regenerated_rh_60"


def extract_neighborhood(
    volume: np.ndarray,
    shape: tuple[int, int, int],
    position: tuple[int, int, int],
) -> np.ndarray:
    half = np.array(shape) // 2
    out = np.zeros(shape, dtype=volume.dtype)
    for x in range(shape[0]):
        for y in range(shape[1]):
            for z in range(shape[2]):
                src = np.array(position) - half + np.array([x, y, z])
                if np.all(src >= 0) and np.all(src < volume.shape):
                    out[x, y, z] = volume[tuple(src)]
    return out


def build_roi_volume(
    lh_labels_host: Path,
    rh_labels_host: Path,
    graphml: Path,
    out_path: Path,
    *,
    fs_prefix: list[str],
    fs_subject_fs: Path,
    fs_label_root: Path,
    fs_output_dir: Path | None = None,
) -> int:
    aseg_mgz = fs_subject_fs / "mri" / "aseg.mgz"
    orig_mgz = fs_subject_fs / "mri" / "orig.mgz"
    tmp_aseg = out_path.parent / "aseg.nii.gz"
    tmp_aseg_fs = (fs_output_dir / "aseg.nii.gz") if fs_output_dir else tmp_aseg
    run(["mri_convert", "-i", str(aseg_mgz), "-o", str(tmp_aseg_fs)], fs_prefix=fs_prefix)
    if not tmp_aseg.is_file():
        raise FileNotFoundError(f"missing converted aseg: {tmp_aseg}")
    aseg_img = nib.load(tmp_aseg)
    aseg_data = np.asanyarray(aseg_img.dataobj, dtype=np.int16)
    rois = np.zeros_like(aseg_data, dtype=np.int16)

    nodes = parse_graphml(graphml)
    for node in nodes:
        corr = int(node["correspondence_id"])
        if node["region"] == "subcortical":
            if not node["aseg_val"]:
                continue
            idx = np.where(aseg_data == int(node["aseg_val"]))
            rois[idx] = corr
            continue

        hemi = "lh" if node["hemisphere"] == "left" else "rh"
        label_dir_host = lh_labels_host if hemi == "lh" else rh_labels_host
        label_dir_fs = fs_label_root / ("regenerated_lh_60" if hemi == "lh" else "regenerated_rh_60")
        label_file_host = label_dir_host / f"{hemi}.{node['fsname']}.label"
        if not label_file_host.is_file():
            raise FileNotFoundError(f"missing cortical label: {label_file_host}")
        tmp_vol_host = label_dir_host / "tmp.nii.gz"
        tmp_vol_fs = label_dir_fs / "tmp.nii.gz"
        run(
            [
                "mri_label2vol",
                "--label",
                str(label_dir_fs / f"{hemi}.{node['fsname']}.label"),
                "--temp",
                str(orig_mgz),
                "--o",
                str(tmp_vol_fs),
                "--identity",
            ],
            fs_prefix=fs_prefix,
        )
        tmp_data = np.asanyarray(nib.load(tmp_vol_host).dataobj)
        rois[tmp_data == 1] = corr

    # Dilate unlabeled cortical ribbon voxels to nearest parcel (easy_lausanne).
    shape = (25, 25, 25)
    center = np.array(shape) // 2
    dist = np.zeros(shape, dtype=np.float32)
    for x in range(shape[0]):
        for y in range(shape[1]):
            for z in range(shape[2]):
                offset = center - np.array([x, y, z])
                dist[x, y, z] = math.sqrt(float(np.sum(offset * offset)))

    idxr = np.where(aseg_data == 3)
    idxl = np.where(aseg_data == 42)
    xx = np.concatenate((idxr[0], idxl[0]))
    yy = np.concatenate((idxr[1], idxl[1]))
    zz = np.concatenate((idxr[2], idxl[2]))
    for j in range(xx.size):
        if rois[xx[j], yy[j], zz[j]] != 0:
            continue
        local = extract_neighborhood(rois, shape, (int(xx[j]), int(yy[j]), int(zz[j])))
        mask = (local > 0).astype(np.float32)
        if mask.sum() == 0:
            continue
        weighted = dist * mask
        weighted[weighted == 0] = np.max(weighted)
        winners = local[weighted == np.min(weighted)]
        values, counts = np.unique(winners.astype(np.int64), return_counts=True)
        rois[xx[j], yy[j], zz[j]] = int(values[np.argmax(counts)])

    hdr = aseg_img.header.copy()
    hdr.set_data_dtype(np.int16)
    out_path.parent.mkdir(parents=True, exist_ok=True)
    nib.save(nib.Nifti1Image(rois, aseg_img.affine, hdr), out_path)
    return int(np.max(rois))


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--freesurfer-subject", required=True, type=Path)
    parser.add_argument("--atlas-dir", type=Path, required=True)
    parser.add_argument("--output", required=True, type=Path, help="Native-space parcellation NIfTI")
    parser.add_argument(
        "--subjects-dir",
        type=Path,
        default=None,
        help="FreeSurfer SUBJECTS_DIR (default: parent of --freesurfer-subject)",
    )
    parser.add_argument(
        "--fs-exec-prefix",
        default="",
        help="Optional prefix to run FreeSurfer commands in a container, e.g. "
        "'apptainer exec --cleanenv fs.sif'",
    )
    parser.add_argument(
        "--fs-subject",
        type=Path,
        default=None,
        help="FreeSurfer subject path as seen by --fs-exec-prefix (e.g. /subjects/sub-001)",
    )
    parser.add_argument(
        "--fs-atlas-dir",
        type=Path,
        default=None,
        help="Atlas directory as seen by --fs-exec-prefix (e.g. /atlas)",
    )
    parser.add_argument(
        "--fs-output-dir",
        type=Path,
        default=None,
        help="Output directory as seen by --fs-exec-prefix (e.g. /out)",
    )
    args = parser.parse_args()

    fs_subject_host = args.freesurfer_subject.resolve()
    subjects_dir = args.subjects_dir or fs_subject_host.parent
    subject_id = fs_subject_host.name
    graphml = require_path(args.atlas_dir / "resolution150.graphml", "resolution150.graphml")
    fs_prefix = args.fs_exec_prefix.split() if args.fs_exec_prefix.strip() else []

    fs_subject = (args.fs_subject or fs_subject_host).resolve()
    atlas_dir_host = args.atlas_dir.resolve()
    atlas_dir_fs = (args.fs_atlas_dir or atlas_dir_host).resolve()
    fs_subject_fs = fs_subject
    fs_subject_check = fs_subject_host
    fs_output_dir = args.fs_output_dir.resolve() if args.fs_output_dir else None

    import os

    os.environ["SUBJECTS_DIR"] = str(subjects_dir)

    lh_labels, rh_labels = build_surface_labels(
        fs_subject_fs,
        fs_subject_check,
        Path(),
        Path(),
        atlas_dir_host,
        atlas_dir_fs,
        fs_prefix=fs_prefix,
        subject_id=subject_id,
    )
    label_root_host = fs_subject_host / "label"
    max_label = build_roi_volume(
        label_root_host / "regenerated_lh_60",
        label_root_host / "regenerated_rh_60",
        graphml,
        args.output,
        fs_prefix=fs_prefix,
        fs_subject_fs=fs_subject_fs,
        fs_label_root=fs_subject_fs / "label",
        fs_output_dir=fs_output_dir,
    )
    print(f"Wrote Lausanne-60 parcellation: {args.output} (max label={max_label})", flush=True)


if __name__ == "__main__":
    try:
        main()
    except subprocess.CalledProcessError as exc:
        sys.stderr.write(exc.stderr or "")
        sys.stderr.write(exc.stdout or "")
        raise
