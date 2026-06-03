#!/usr/bin/env python3
"""
Write results_fmaps/qsiprep_qsirecon_fmap_status.csv:
  per BIDS subject: DWI/fmap presence, qsiprep/qsirecon outputs, latest qsiprep.toml SDC hints.
"""
from __future__ import annotations

import csv
import re
import sys
from pathlib import Path


def parse_workflow_block(text: str) -> tuple[object | None, list[str] | None]:
    """Return (use_syn_sdc, ignore_list) from [workflow] section; best-effort parse."""
    lines = text.splitlines()
    in_wf = False
    use_syn: object | None = None
    ignore: list[str] | None = None
    for line in lines:
        s = line.strip()
        if s == "[workflow]":
            in_wf = True
            continue
        if s.startswith("[") and s.endswith("]") and s != "[workflow]":
            in_wf = False
            continue
        if not in_wf:
            continue
        if s.startswith("use_syn_sdc"):
            _, _, rest = s.partition("=")
            rest = rest.strip()
            if rest.lower() == "false":
                use_syn = False
            elif rest.lower() == "true":
                use_syn = True
            elif rest.startswith('"') and rest.endswith('"'):
                use_syn = rest[1:-1]
            else:
                use_syn = rest
        if s.startswith("ignore") and "=" in s and not s.startswith("ignore_"):
            _, _, rest = s.partition("=")
            rest = rest.strip()
            if rest == "[]":
                ignore = []
            else:
                ignore = re.findall(r'"([^"]*)"', rest)
    return use_syn, ignore


def latest_qsiprep_toml(sub_dir: Path) -> Path | None:
    logd = sub_dir / "log"
    if not logd.is_dir():
        return None
    toms = list(logd.glob("*/qsiprep.toml"))
    if not toms:
        return None
    toms.sort(key=lambda p: p.parent.name, reverse=True)
    return toms[0]


def has_dwi_nifti(sub_bids: Path) -> bool:
    for pat in ("*.nii", "*.nii.gz"):
        if list((sub_bids / "dwi").glob(pat)) if (sub_bids / "dwi").is_dir() else []:
            return True
        for p in sub_bids.rglob(pat):
            if "/dwi/" in str(p).replace("\\", "/"):
                return True
    return False


def count_fmap_nifti(sub_bids: Path) -> int:
    n = 0
    for p in sub_bids.rglob("*.nii*"):
        sp = str(p).replace("\\", "/")
        if "/fmap/" not in sp:
            continue
        if p.name.endswith(".nii.gz") or p.name.endswith(".nii"):
            n += 1
    return n


def has_qsiprep_artifact(q_dir: Path) -> bool:
    if not q_dir.is_dir():
        return False
    for pat in ("*desc-preproc*dwi*.nii.gz", "*desc-preproc*dwi*.nii"):
        if list(q_dir.rglob(pat)):
            return True
    return False


def has_qsirecon_artifact(res: Path, sub: str) -> bool:
    s = f"sub-{sub}"
    d1 = res / "qsirecon_single_run_output" / "derivatives" / "qsirecon-DSIStudio" / s
    d2 = res / "qsirecon_single_run_output" / s
    for d in (d1, d2):
        if d.is_dir() and any(d.iterdir()):
            return True
    return False


def sdc_category(
    bids_fmap_count: int,
    use_syn: object | None,
    ignore: list[str] | None,
) -> str:
    ign = ignore or []
    if "fieldmaps" in ign:
        return "ignored_fieldmaps_then_syn_or_custom"
    if use_syn is True or use_syn in ("warn", "error"):
        return f"syn_sdc_{use_syn}" if use_syn in ("warn", "error") else "syn_sdc_true"
    if use_syn is False:
        if bids_fmap_count > 0:
            return "measured_fmaps_topup"
        return "no_syn_sdc_no_bids_fmap"
    return "unknown"


def main() -> int:
    root = Path(__file__).resolve().parent.parent
    bids = Path(
        sys.argv[1]
        if len(sys.argv) > 1
        else "/mnt/nfs/home/urmc-sh.rochester.edu/pndagiji/Documents/CIDUR_BIDS/data_bids"
    )
    res = Path(
        sys.argv[2]
        if len(sys.argv) > 2
        else "/mnt/nfs/home/urmc-sh.rochester.edu/pndagiji/Documents/CIDUR_BIDS/results_fmaps"
    )
    out_csv = res / "qsiprep_qsirecon_fmap_status.csv"

    subs = sorted(p.name[4:] for p in bids.glob("sub-*") if p.is_dir() and p.name.startswith("sub-"))

    rows = []
    for sub in subs:
        sub_bids = bids / f"sub-{sub}"
        qsub = res / "qsiprep_single_run_output" / f"sub-{sub}"
        dwi = has_dwi_nifti(sub_bids)
        nf = count_fmap_nifti(sub_bids)
        has_qsp = has_qsiprep_artifact(qsub)
        has_qsr = has_qsirecon_artifact(res, sub)
        toml = latest_qsiprep_toml(qsub)
        use_syn, ignore = (None, None)
        toml_m = ""
        if toml and toml.is_file():
            toml_m = toml.parent.name
            use_syn, ignore = parse_workflow_block(toml.read_text(encoding="utf-8", errors="replace"))
        ign_s = json_list(ignore)
        if toml:
            cat = sdc_category(nf, use_syn, ignore)
        elif has_qsp:
            cat = "qsiprep_output_missing_toml"
        else:
            cat = "no_qsiprep_output"

        if cat == "measured_fmaps_topup":
            measured = "yes"
        elif cat == "no_syn_sdc_no_bids_fmap":
            measured = "no"
        elif cat.startswith("syn_sdc"):
            measured = "n/a_syn"
        elif cat == "ignored_fieldmaps_then_syn_or_custom":
            measured = "n/a_ignored_fmaps"
        else:
            measured = "n/a"

        rows.append(
            {
                "subject": sub,
                "bids_has_dwi": "yes" if dwi else "no",
                "bids_fmap_nifti_count": str(nf),
                "bids_fmap_present": "yes" if nf > 0 else "no",
                "has_qsiprep_output": "yes" if has_qsp else "no",
                "has_qsirecon_output": "yes" if has_qsr else "no",
                "latest_qsiprep_toml_run": toml_m,
                "use_syn_sdc": "" if use_syn is None else ("false" if use_syn is False else str(use_syn)),
                "ignore": ign_s,
                "sdc_category": cat,
                "qsiprep_measured_fmap_sdc": measured,
            }
        )

    fieldnames = [
        "subject",
        "bids_has_dwi",
        "bids_fmap_nifti_count",
        "bids_fmap_present",
        "has_qsiprep_output",
        "has_qsirecon_output",
        "latest_qsiprep_toml_run",
        "use_syn_sdc",
        "ignore",
        "sdc_category",
        "qsiprep_measured_fmap_sdc",
    ]
    out_csv.parent.mkdir(parents=True, exist_ok=True)
    with out_csv.open("w", newline="", encoding="utf-8") as f:
        w = csv.DictWriter(f, fieldnames=fieldnames)
        w.writeheader()
        w.writerows(rows)
    print(f"Wrote {len(rows)} rows -> {out_csv}", file=sys.stderr)
    return 0


def json_list(ignore: list[str] | None) -> str:
    if ignore is None:
        return ""
    if not ignore:
        return "[]"
    return "[" + ", ".join(ignore) + "]"


if __name__ == "__main__":
    raise SystemExit(main())
