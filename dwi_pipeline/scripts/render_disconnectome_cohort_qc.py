#!/usr/bin/env python3
"""Build a cohort-level HTML index of disconnectome QC under RESULTS_ROOT."""

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

from evaluate_disconnectome_integrity import collect_integrity_report
from render_disconnectome_qc import render_html


def discover_disconnectome_dirs(results_root: Path) -> list[Path]:
    connectomes = results_root / "connectomes"
    if not connectomes.is_dir():
        return []
    dirs: list[Path] = []
    for subject_dir in sorted(connectomes.glob("sub-*")):
        ddir = subject_dir / "disconnectome"
        if (ddir / "disconnectome.json").is_file():
            dirs.append(ddir)
    return dirs


def render_cohort_html(results_root: Path, rows: list[dict]) -> str:
    generated = datetime.now(timezone.utc).strftime("%Y-%m-%d %H:%M UTC")
    body_rows = []
    for row in rows:
        status = row["overall_status"]
        cls = {"PASS": "pass", "WARN": "warn", "FAIL": "fail"}.get(status, "neutral")
        qc_link = row.get("qc_html")
        link_cell = (
            f"<a href='{html.escape(qc_link)}'>disconnectome_qc.html</a>"
            if qc_link
            else "—"
        )
        body_rows.append(
            f"<tr class='{cls}'>"
            f"<td>{html.escape(row['subject'])}</td>"
            f"<td>{html.escape(row['session'])}</td>"
            f"<td>{html.escape(status)}</td>"
            f"<td>{row.get('mean_d', '—')}</td>"
            f"<td>{row.get('edges_d_gt_0', '—')}</td>"
            f"<td>{html.escape(str(row.get('disconnection_spared', '')))}</td>"
            f"<td>{link_cell}</td>"
            f"</tr>"
        )

    return f"""<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <title>Disconnectome cohort QC</title>
  <style>
    body {{ font-family: system-ui, sans-serif; margin: 2rem; }}
    table {{ border-collapse: collapse; width: 100%; }}
    th, td {{ border: 1px solid #ddd; padding: 0.5rem 0.75rem; text-align: left; }}
    th {{ background: #f5f5f5; }}
    tr.pass td:nth-child(3) {{ color: #0a7a2f; font-weight: 600; }}
    tr.warn td:nth-child(3) {{ color: #9a6700; font-weight: 600; }}
    tr.fail td:nth-child(3) {{ color: #b42318; font-weight: 600; }}
  </style>
</head>
<body>
  <h1>Disconnectome cohort QC</h1>
  <p>{html.escape(str(results_root))} · {len(rows)} subject(s) · generated {generated}</p>
  <table>
    <thead>
      <tr>
        <th>Subject</th><th>Session</th><th>Overall</th><th>Mean D</th>
        <th>Edges D&gt;0</th><th>Spared option</th><th>Report</th>
      </tr>
    </thead>
    <tbody>{''.join(body_rows) or '<tr><td colspan="7">No disconnectome outputs found</td></tr>'}</tbody>
  </table>
</body>
</html>
"""


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--results-root", type=Path, required=True)
    ap.add_argument("--html-out", type=Path, help="Default: RESULTS_ROOT/disconnectome_cohort_qc.html")
    ap.add_argument("--write-subject-reports", action="store_true", help="Regenerate per-subject HTML/JSON")
    args = ap.parse_args()

    results_root = args.results_root.resolve()
    rows: list[dict] = []

    for ddir in discover_disconnectome_dirs(results_root):
        if args.write_subject_reports:
            report = collect_integrity_report(ddir)
            (ddir / "disconnectome_qc.html").write_text(render_html(report) + "\n")
            (ddir / "disconnectome_qc.json").write_text(json.dumps(report, indent=2) + "\n")
        else:
            report = collect_integrity_report(ddir)
        summary = report.get("disconnection_summary") or {}
        rel_qc = None
        qc_path = ddir / "disconnectome_qc.html"
        if qc_path.is_file():
            rel_qc = str(qc_path.relative_to(results_root))
        rows.append(
            {
                "subject": report.get("subject", ddir.parent.name),
                "session": report.get("session", ""),
                "overall_status": report["overall_status"],
                "mean_d": summary.get("mean_disconnection_on_primary_edges"),
                "edges_d_gt_0": summary.get("edges_with_disconnection_gt_0"),
                "disconnection_spared": report.get("disconnection_spared"),
                "qc_html": rel_qc,
            }
        )

    html_out = args.html_out or (results_root / "disconnectome_cohort_qc.html")
    json_out = results_root / "disconnectome_cohort_qc.json"
    html_out.write_text(render_cohort_html(results_root, rows) + "\n")
    json_out.write_text(json.dumps({"results_root": str(results_root), "subjects": rows}, indent=2) + "\n")
    print(f"Wrote {html_out} ({len(rows)} subjects)")
    print(f"Wrote {json_out}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
