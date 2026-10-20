#!/usr/bin/env python3
"""BIDS-ify Kirby21 + Boekel A/B same-day pairs. Not leftover y. Not gold.

Kirby: ses-1 / ses-2 from subject_id_to_visit_id.csv.
Boekel: ses-1 = session A, ses-2 = session B. run01-04 stay runs. No C/week.
"""

from __future__ import annotations

import csv
import json
import shutil
import tarfile
from pathlib import Path

import numpy as np

from boekel_trace_repair import repair_run

ROOT = Path(__file__).resolve().parents[4] / "sample_data"
KRAW = ROOT / "kirby21/raw"
KCSV = ROOT / "kirby21/subject_id_to_visit_id.csv"
KBIDS = ROOT / "kirby21/bids"
BRAW = ROOT / "boekel_dwi_retest/raw"
BBIDS = ROOT / "boekel_dwi_retest/bids"
OUTJ = Path(__file__).resolve().parent / "retest_bids.json"

# Landman 2010 PAR: Preparation direction Anterior-Posterior. BIDS j- is the usual AP EPI.
KIRBY_PE = "j-"
# WFS=12.160 px, EPI factor=41, 3T: ees = WFS / (3.4e-6*42.576e6*3) / (EPI+1)
KIRBY_TRT = 0.02664
# Boekel 2017: bandwidth 32.1 Hz/Px, FOV 224 mm, 2 mm → PE 112. TRT=(112-1)/(32.1*112).
BOEKEL_BW_PE = 32.1
BOEKEL_RECON_PE = 112
BOEKEL_EES = 1.0 / (BOEKEL_BW_PE * BOEKEL_RECON_PE)
BOEKEL_TRT = BOEKEL_EES * (BOEKEL_RECON_PE - 1)


def write_json(path: Path, rec: dict) -> None:
    path.write_text(json.dumps(rec, indent=2) + "\n")


def save_nii(src: Path, dest: Path) -> None:
    dest.parent.mkdir(parents=True, exist_ok=True)
    if src.suffixes[-2:] == [".nii", ".gz"] or src.name.endswith(".nii.gz"):
        shutil.copy2(src, dest)
        return
    import nibabel as nib

    img = nib.load(str(src))
    nib.save(img, str(dest))


def write_bval_bvec(b: np.ndarray, g: np.ndarray, nvol: int, dest_stub: Path) -> None:
    b = np.asarray(b, dtype=np.float64).ravel()
    g = np.asarray(g, dtype=np.float64)
    if g.ndim == 1:
        g = g.reshape(-1, 3)
    if g.shape[0] == 3 and g.shape[1] != 3:
        g = g.T
    if b.size == nvol - 1:
        b = np.concatenate([[0.0], b])
        g = np.vstack([[0.0, 0.0, 0.0], g])
    if b.size != nvol or g.shape[0] != nvol:
        raise SystemExit(f"{dest_stub}: b={b.size} g={g.shape} nvol={nvol}")
    dest_stub.with_suffix(".bval").write_text(" ".join(f"{x:.6g}" for x in b) + "\n")
    dest_stub.with_suffix(".bvec").write_text(
        "\n".join(" ".join(f"{x:.8f}" for x in g[:, i]) for i in range(3)) + "\n"
    )


def nvol_nii(path: Path) -> int:
    import nibabel as nib

    img = nib.load(str(path))
    shape = img.shape
    return int(shape[3]) if len(shape) > 3 else 1


ONLY: set[str] = set()


def convert_kirby() -> list[dict]:
    rows = []
    with KCSV.open() as f:
        pairs: dict[str, dict[int, str]] = {}
        for r in csv.DictReader(f):
            sid = f"{int(r['Subject_ID']):03d}"
            pairs.setdefault(sid, {})[int(r["Subj_Visit"])] = r["kki_id"]
    if ONLY:
        pairs = {k: v for k, v in pairs.items() if f"KKI{k}" in ONLY or f"sub-KKI{k}" in ONLY}
    KBIDS.mkdir(parents=True, exist_ok=True)
    write_json(
        KBIDS / "dataset_description.json",
        {
            "Name": "Kirby21 same-day scan-rescan",
            "BIDSVersion": "1.8.0",
            "DatasetType": "raw",
            "Authors": ["Landman BA", "Huang AJ", "van Zijl PCM"],
            "not_gold": True,
        },
    )
    work = ROOT / "kirby21/.extract"
    work.mkdir(parents=True, exist_ok=True)
    for sid, visits in sorted(pairs.items()):
        sub = f"sub-KKI{sid}"
        for vis, kki in visits.items():
            ses = f"ses-{vis}"
            archive = KRAW / f"{kki}.tar.bz2"
            if not archive.is_file() or archive.stat().st_size < 1_000_000:
                rows.append({"sub": sub, "ses": ses, "ok": False, "reason": "missing archive"})
                continue
            dest_root = work / kki
            if not (dest_root / f"{kki}-DTI.nii").exists() and not (dest_root / f"{kki}-DTI.nii.gz").exists():
                with tarfile.open(archive, "r:bz2") as t:
                    for m in t.getmembers():
                        name = Path(m.name).name
                        if name in {f"{kki}-DTI.nii", f"{kki}-DTI.b", f"{kki}-DTI.grad", f"{kki}-MPRAGE.nii"}:
                            t.extract(m, dest_root)
            dti = dest_root / f"{kki}-DTI.nii"
            t1 = dest_root / f"{kki}-MPRAGE.nii"
            if not dti.exists() or not t1.exists():
                # some tars nest one extra folder
                found = list(dest_root.rglob(f"{kki}-DTI.nii"))
                t1s = list(dest_root.rglob(f"{kki}-MPRAGE.nii"))
                if not found or not t1s:
                    rows.append({"sub": sub, "ses": ses, "ok": False, "reason": "extract miss"})
                    continue
                dti, t1 = found[0], t1s[0]
            anat = KBIDS / sub / ses / "anat" / f"{sub}_{ses}_T1w.nii.gz"
            dwi = KBIDS / sub / ses / "dwi" / f"{sub}_{ses}_dwi.nii.gz"
            save_nii(t1, anat)
            save_nii(dti, dwi)
            b = np.loadtxt(dti.with_suffix(".b"))
            g = np.loadtxt(dti.with_name(dti.stem + ".grad"))
            write_bval_bvec(b, g, nvol_nii(dwi), dwi.with_suffix("").with_suffix(""))
            write_json(
                anat.with_suffix("").with_suffix(".json"),
                {"Modality": "MR", "Manufacturer": "Philips", "PulseSequenceType": "MPRAGE"},
            )
            write_json(
                dwi.with_suffix("").with_suffix(".json"),
                {
                    "Modality": "MR",
                    "Manufacturer": "Philips",
                    "PhaseEncodingDirection": KIRBY_PE,
                    "TotalReadoutTime": KIRBY_TRT,
                    "PhaseEncodingDirectionNote": "Landman 2010 PAR Preparation direction Anterior-Posterior",
                    "TotalReadoutTimeNote": "From PAR WFS=12.160 and EPI factor=41 at 3T",
                },
            )
            rows.append({"sub": sub, "ses": ses, "kki": kki, "ok": True, "nvol": nvol_nii(dwi)})
    return rows


def convert_boekel() -> list[dict]:
    rows = []
    BBIDS.mkdir(parents=True, exist_ok=True)
    write_json(
        BBIDS / "dataset_description.json",
        {
            "Name": "Boekel Keuken same-day DWI test-retest V2",
            "BIDSVersion": "1.8.0",
            "DatasetType": "raw",
            "Authors": ["Boekel W", "Forstmann BU", "Keuken MC"],
            "not_gold": True,
        },
    )
    work = ROOT / "boekel_dwi_retest/.extract"
    work.mkdir(parents=True, exist_ok=True)
    for archive in sorted(BRAW.glob("pp*_v2.tar.gz")):
        pp = archive.name.split("_")[0]  # pp01
        if ONLY and pp not in ONLY and f"sub-{pp}" not in ONLY:
            continue
        dest_root = work / pp
        if not dest_root.exists():
            with tarfile.open(archive, "r:gz") as t:
                t.extractall(dest_root)
        # flatten pp01/pp01/...
        base = dest_root / pp if (dest_root / pp).is_dir() else dest_root
        sub = f"sub-{pp}"
        for letter, sesn in (("A", "1"), ("B", "2")):
            ses = f"ses-{sesn}"
            t1s = list(base.glob(f"{pp}_t1_{letter}/{pp}_t1_{letter}*.nii*"))
            dwis = sorted(base.glob(f"{pp}_dwi_run*_{letter}/{pp}_dwi_run*_{letter}.nii.gz"))
            if not dwis or (not t1s and letter == "A"):
                rows.append({"sub": sub, "ses": ses, "ok": False, "reason": "missing A/B"})
                continue
            if t1s:
                anat = BBIDS / sub / ses / "anat" / f"{sub}_{ses}_T1w.nii.gz"
                save_nii(t1s[0], anat)
                write_json(
                    anat.with_suffix("").with_suffix(".json"),
                    {"Modality": "MR", "Manufacturer": "Philips"},
                )
            for dwi_src in dwis:
                run = "run-1"
                for tok in dwi_src.name.split("_"):
                    if tok.startswith("run"):
                        digits = "".join(c for c in tok if c.isdigit())
                        if digits:
                            run = f"run-{int(digits)}"
                stub = BBIDS / sub / ses / "dwi" / f"{sub}_{ses}_{run}_dwi"
                dest_nii = stub.with_suffix(".nii.gz")
                save_nii(dwi_src, dest_nii)
                src_dir = dwi_src.parent
                write_bval_bvec(
                    np.loadtxt(src_dir / "bvals"),
                    np.loadtxt(src_dir / "bvecs"),
                    nvol_nii(dest_nii),
                    stub,
                )
                repair_run(dest_nii)
                write_json(
                    stub.with_suffix(".json"),
                    {
                        "Modality": "MR",
                        "Manufacturer": "Philips",
                        "PhaseEncodingDirection": "j-",
                        "PhaseEncodingDirectionNote": "Boekel 2017 SENSE factor (AP); not invented leftover",
                        "BandwidthPerPixelPhaseEncode": BOEKEL_BW_PE,
                        "ReconMatrixPE": BOEKEL_RECON_PE,
                        "EffectiveEchoSpacing": BOEKEL_EES,
                        "TotalReadoutTime": BOEKEL_TRT,
                        "TotalReadoutTimeNote": (
                            "Boekel 2017 bandwidth 32.1 Hz/Px, FOV 224 mm, 2 mm iso "
                            "(ReconMatrixPE=112). TRT=(112-1)/(32.1*112). Not invented 0.05."
                        ),
                    },
                )
            rows.append(
                {"sub": sub, "ses": ses, "ok": True, "n_dwi": len(dwis), "anat": "own" if t1s else "ses-1 T1 only"}
            )
    return rows


def main() -> int:
    import sys

    if len(sys.argv) > 1:
        ONLY.update(sys.argv[1:])
    kirby = convert_kirby()
    boekel = convert_boekel()
    if ONLY and OUTJ.is_file():
        old = json.loads(OUTJ.read_text())
        for key, new in (("kirby", kirby), ("boekel", boekel)):
            done = {(r["sub"], r["ses"]) for r in new}
            new[:0] = [r for r in old.get(key, []) if (r["sub"], r["ses"]) not in done]
    rec = {
        "not_gold": True,
        "not_leftover_y": True,
        "kirby_ok": sum(1 for r in kirby if r.get("ok")),
        "kirby_n": len(kirby),
        "boekel_ok": sum(1 for r in boekel if r.get("ok")),
        "boekel_n": len(boekel),
        "kirby": kirby,
        "boekel": boekel,
    }
    OUTJ.write_text(json.dumps(rec, indent=2) + "\n")
    print(json.dumps({k: rec[k] for k in rec if k not in {"kirby", "boekel"}}, indent=2))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
