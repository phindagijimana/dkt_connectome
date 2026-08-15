#!/usr/bin/env python3
"""Build cohort-level index of per-subject QC dashboards."""

from __future__ import annotations

import argparse
import html
import json
import sys
from datetime import datetime, timezone
from pathlib import Path

SCRIPT_DIR = Path(__file__).resolve().parent
if str(SCRIPT_DIR) not in sys.path:
    sys.path.insert(0, str(SCRIPT_DIR))

from collect_subject_qc import collect_subject_qc
from render_subject_qc import render_html


def discover_subjects(results_root: Path) -> list[str]:
    qc_root = results_root / "qc"
    subjects: set[str] = set()
    if qc_root.is_dir():
        for d in qc_root.glob("sub-*"):
            if (d / "subject_qc.json").is_file():
                subjects.add(d.name)
    # Also infer from connectomes / qsiprep when qc not yet built
    for d in (results_root / "connectomes").glob("sub-*"):
        subjects.add(d.name)
    for html_file in (results_root / "qsiprep_single_run_output").glob("sub-*.html"):
        subjects.add(html_file.stem)
    return sorted(subjects)


def render_cohort_html(results_root: Path, rows: list[dict]) -> str:
    generated = datetime.now(timezone.utc).strftime("%Y-%m-%d %H:%M UTC")
    body = []
    for row in rows:
        cls = row.get("overall_status", "NA").lower()
        link = row.get("qc_html")
        link_cell = f"<a href='{html.escape(link)}'>subject_qc.html</a>" if link else "—"
        body.append(
            f"<tr class='{html.escape(cls)}'>"
            f"<td>{html.escape(row['subject'])}</td>"
            f"<td>{html.escape(row.get('overall_status', 'NA'))}</td>"
            f"<td>{html.escape(str(row.get('qsiprep', 'NA')))}</td>"
            f"<td>{html.escape(str(row.get('inpaint', 'SKIP')))}</td>"
            f"<td>{html.escape(str(row.get('connectome', 'NA')))}</td>"
            f"<td>{html.escape(str(row.get('disconnectome', 'SKIP')))}</td>"
            f"<td>{html.escape(str(row.get('nodestrength', 'SKIP')))}</td>"
            f"<td>{link_cell}</td>"
            f"</tr>"
        )
    return f"""<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <title>Cohort QC index</title>
  <style>
    body {{ font-family: system-ui, sans-serif; margin: 2rem; }}
    table {{ border-collapse: collapse; width: 100%; }}
    th, td {{ border: 1px solid #ddd; padding: 0.45rem 0.65rem; text-align: left; font-size: 0.92rem; }}
    th {{ background: #f5f5f5; }}
  </style>
</head>
<body>
  <h1>Cohort QC index</h1>
  <p>{html.escape(str(results_root))} · {len(rows)} subject(s) · generated {generated}</p>
  <table>
    <thead>
      <tr>
        <th>Subject</th><th>Overall</th><th>QSIPrep</th><th>Inpaint</th>
        <th>Connectome</th><th>Disconnectome</th><th>Node strength</th><th>Dashboard</th>
      </tr>
    </thead>
    <tbody>{''.join(body) or '<tr><td colspan="8">No subjects found</td></tr>'}</tbody>
  </table>
</body>
</html>
"""


def _step_status(report: dict, step_id: str) -> str:
    for step in report.get("steps", []):
        if step["id"] == step_id:
            return step["status"]
    return "NA"


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--results-root", type=Path, required=True)
    ap.add_argument("--html-out", type=Path, help="Default: RESULTS_ROOT/cohort_qc.html")
    ap.add_argument("--write-subject-reports", action="store_true", help="Regenerate per-subject dashboards")
    args = ap.parse_args()

    results_root = args.results_root.resolve()
    rows: list[dict] = []

    for subject_id in discover_subjects(results_root):
        sub_short = subject_id.removeprefix("sub-")
        qc_json = results_root / "qc" / subject_id / "subject_qc.json"
        if args.write_subject_reports or not qc_json.is_file():
            report = collect_subject_qc(results_root, sub_short)
            out_dir = results_root / "qc" / subject_id
            out_dir.mkdir(parents=True, exist_ok=True)
            (out_dir / "subject_qc.html").write_text(render_html(report) + "\n")
            qc_json.write_text(json.dumps(report, indent=2) + "\n")
        else:
            report = json.loads(qc_json.read_text())

        rel = None
        qc_html = results_root / "qc" / subject_id / "subject_qc.html"
        if qc_html.is_file():
            rel = str(qc_html.relative_to(results_root))

        rows.append(
            {
                "subject": subject_id,
                "overall_status": report.get("overall_status", "NA"),
                "qsiprep": _step_status(report, "qsiprep"),
                "inpaint": _step_status(report, "inpaint"),
                "connectome": _step_status(report, "connectome"),
                "disconnectome": _step_status(report, "disconnectome"),
                "nodestrength": _step_status(report, "nodestrength"),
                "qc_html": rel,
            }
        )

    html_out = args.html_out or (results_root / "cohort_qc.html")
    json_out = results_root / "cohort_qc.json"
    html_out.write_text(render_cohort_html(results_root, rows) + "\n")
    json_out.write_text(json.dumps({"results_root": str(results_root), "subjects": rows}, indent=2) + "\n")
    print(f"Wrote {html_out} ({len(rows)} subjects)")
    print(f"Wrote {json_out}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
