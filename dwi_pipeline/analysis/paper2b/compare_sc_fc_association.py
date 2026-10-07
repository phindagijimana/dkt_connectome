#!/usr/bin/env python3
"""Paper 2B RQ3: SC disconnection vs Arm B FC disconnection (patient-specific ± LQT)."""

from __future__ import annotations

import argparse
import csv
import json
import sys
from pathlib import Path

from matrix_utils import load_square_matrix_csv, safe_pearson, upper_triangle_vector


def patient_sdc(connectomes: Path, subject: str) -> Path:
    return connectomes / f"sub-{subject}" / "disconnectome" / "disconnection_matrix.csv"


def lqt_sdc(lqt_dir: Path, subject: str) -> Path:
    return lqt_dir / f"sub-{subject}" / "lqt_disconnection_matrix.csv"


def fc_arm_b(out_root: Path, stream: str, subject: str, session: str) -> Path:
    return (
        out_root
        / stream
        / f"sub-{subject}"
        / f"ses-{session}"
        / "func"
        / "characterization"
        / stream
        / "arm-B_empirical_fc_disconnection"
        / "desc-empirical_fc_disconnection.csv"
    )


def assoc_sc_fc(sc: Path, fc: Path) -> dict:
    if not sc.is_file() or not fc.is_file():
        return {"status": "missing", "sc": str(sc), "fc": str(fc)}
    a = upper_triangle_vector(load_square_matrix_csv(sc))
    b = upper_triangle_vector(load_square_matrix_csv(fc))
    if a.size != b.size or a.size < 3:
        return {"status": "edge_error", "n_edges": int(min(a.size, b.size))}
    return {
        "status": "ok",
        "n_edges": int(a.size),
        "pearson_r": safe_pearson(a, b),
    }


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--dwi-connectomes", type=Path, required=True)
    ap.add_argument("--out-root", type=Path, required=True, help="fMRI OUT_ROOT")
    ap.add_argument("--lqt-dir", type=Path, default=None)
    ap.add_argument("--fc-stream", default="xcp_d", choices=("xcp_d", "fmristroke"))
    ap.add_argument("--session", default="2WK")
    ap.add_argument("--subject", action="append", dest="subjects", required=True)
    ap.add_argument("--output-dir", type=Path, required=True)
    args = ap.parse_args()

    args.output_dir.mkdir(parents=True, exist_ok=True)
    rows: list[dict] = []

    for sub in args.subjects:
        fc_p = fc_arm_b(args.out_root, args.fc_stream, sub, args.session)
        ps_p = patient_sdc(args.dwi_connectomes, sub)
        r_ps = assoc_sc_fc(ps_p, fc_p)
        row = {
            "subject": sub,
            "session": args.session,
            "fc_stream": args.fc_stream,
            "patient_sc_fc": r_ps,
        }
        if args.lqt_dir is not None:
            lqt_p = lqt_sdc(args.lqt_dir, sub)
            row["lqt_sc_fc"] = assoc_sc_fc(lqt_p, fc_p)
        rows.append(row)

    flat: list[dict] = []
    for row in rows:
        sub = row["subject"]
        for label in ("patient_sc_fc", "lqt_sc_fc"):
            if label not in row:
                continue
            st = row[label]
            flat.append(
                {
                    "subject": sub,
                    "sc_source": "patient" if label == "patient_sc_fc" else "lqt",
                    "status": st.get("status"),
                    "pearson_r": st.get("pearson_r"),
                    "n_edges": st.get("n_edges"),
                }
            )

    tsv = args.output_dir / f"sc_fc_association_{args.fc_stream}.tsv"
    if flat:
        with tsv.open("w", newline="") as f:
            w = csv.DictWriter(f, fieldnames=list(flat[0].keys()), delimiter="\t")
            w.writeheader()
            w.writerows(flat)

    summary = {"step": "compare_sc_fc_association", "per_subject": rows}
    ok_ps = [
        r["patient_sc_fc"]["pearson_r"]
        for r in rows
        if r.get("patient_sc_fc", {}).get("status") == "ok"
    ]
    if ok_ps:
        import numpy as np

        summary["cohort_patient_sc_fc"] = {"mean_pearson_r": float(np.nanmean(ok_ps))}

    out_json = args.output_dir / f"sc_fc_association_{args.fc_stream}.json"
    out_json.write_text(json.dumps(summary, indent=2) + "\n")
    print(f"Wrote {tsv}")
    print(f"Wrote {out_json}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
