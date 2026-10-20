#!/usr/bin/env python3
"""HCP-YA Test-Retest diffusion pairs from s3://hcp-openaccess. Not leftover y. Not gold.

Test = HCP_1200/<sub>, retest = HCP_Retest/<sub>. Needs HCP-issued keys in AWS profile `hcp`
(ConnectomeDB/BALSA, after accepting the HCP Open Access Data Use Terms). HCP data must not be
redistributed: keep it out of git, the edgeuq repo and any container.

  fetch_hcp_retest.py list              inventory + size per package, writes hcp_retest_inventory.json
  fetch_hcp_retest.py get preproc [SUB…]  minimally preprocessed DWI + T1 (T1w/ space)
  fetch_hcp_retest.py get unproc  [SUB…]  raw DWI (dir95/96/97 RL+LR) + T1w_MPR1
"""

from __future__ import annotations

import json
import sys
from pathlib import Path

import boto3

BUCKET = "hcp-openaccess"
SITES = {"ses-1": "HCP_1200", "ses-2": "HCP_Retest"}
OUT = Path(__file__).resolve().parents[1] / "hcp_retest/raw"
INV = Path(__file__).resolve().parent / "hcp_retest_inventory.json"

PACKAGES = {
    "preproc": [
        "T1w/Diffusion/data.nii.gz",
        "T1w/Diffusion/bvals",
        "T1w/Diffusion/bvecs",
        "T1w/Diffusion/nodif_brain_mask.nii.gz",
        # grad_dev.nii.gz omitted (~4 GB): unused by adapter / shift / jitter / rescan
        "T1w/T1w_acpc_dc_restore.nii.gz",
        "T1w/T1w_acpc_dc_restore_brain.nii.gz",
    ],
    "unproc": ["unprocessed/3T/Diffusion/", "unprocessed/3T/T1w_MPR1/"],
}


def client():
    return boto3.Session(profile_name="hcp").client("s3")


def objects(s3, prefix: str):
    for page in s3.get_paginator("list_objects_v2").paginate(Bucket=BUCKET, Prefix=prefix):
        yield from page.get("Contents", [])


def subjects(s3) -> list[str]:
    subs = []
    for page in s3.get_paginator("list_objects_v2").paginate(
        Bucket=BUCKET, Prefix=SITES["ses-2"] + "/", Delimiter="/"
    ):
        subs += [p["Prefix"].split("/")[1] for p in page.get("CommonPrefixes", [])]
    return sorted(s for s in subs if s.isdigit())


def keys(s3, sub: str, ses: str, pkg: str) -> list[dict]:
    root = f"{SITES[ses]}/{sub}/"
    out = []
    for item in PACKAGES[pkg]:
        if item.endswith("/"):
            out += [o for o in objects(s3, root + item) if not o["Key"].endswith("/")]
        else:
            out += [o for o in objects(s3, root + item) if o["Key"] == root + item]
    return out


def cmd_list() -> int:
    s3 = client()
    rows = []
    for sub in subjects(s3):
        row = {"sub": sub}
        for pkg in PACKAGES:
            for ses in SITES:
                ks = keys(s3, sub, ses, pkg)
                row[f"{pkg}_{ses}_n"] = len(ks)
                row[f"{pkg}_{ses}_gb"] = round(sum(k["Size"] for k in ks) / 1e9, 2)
        row["preproc_pair"] = all(row[f"preproc_{s}_n"] == len(PACKAGES["preproc"]) for s in SITES)
        row["unproc_pair"] = all(row[f"unproc_{s}_n"] > 0 for s in SITES)
        rows.append(row)
        print(json.dumps(row), flush=True)
    rec = {
        "n_retest_subjects": len(rows),
        "n_preproc_pairs": sum(r["preproc_pair"] for r in rows),
        "n_unproc_pairs": sum(r["unproc_pair"] for r in rows),
        "preproc_total_gb": round(sum(r[f"preproc_{s}_gb"] for r in rows for s in SITES), 1),
        "unproc_total_gb": round(sum(r[f"unproc_{s}_gb"] for r in rows for s in SITES), 1),
        "not_gold": True,
        "not_leftover_y": True,
        "rows": rows,
    }
    INV.write_text(json.dumps(rec, indent=2) + "\n")
    print({k: v for k, v in rec.items() if k != "rows"})
    return 0


def cmd_get(pkg: str, subs: list[str]) -> int:
    s3 = client()
    subs = subs or subjects(s3)
    for sub in subs:
        for ses in SITES:
            for obj in keys(s3, sub, ses, pkg):
                rel = obj["Key"].split(f"/{sub}/", 1)[1]
                dest = OUT / pkg / sub / ses / rel
                if dest.is_file() and dest.stat().st_size == obj["Size"]:
                    continue
                dest.parent.mkdir(parents=True, exist_ok=True)
                s3.download_file(BUCKET, obj["Key"], str(dest))
                print(sub, ses, rel, flush=True)
    return 0


if __name__ == "__main__":
    a = sys.argv[1:]
    if a[:1] == ["list"]:
        sys.exit(cmd_list())
    if a[:1] == ["get"] and len(a) >= 2 and a[1] in PACKAGES:
        sys.exit(cmd_get(a[1], a[2:]))
    sys.exit(__doc__)
