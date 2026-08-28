#!/usr/bin/env python3
"""Render a self-contained HTML QC report for Step 4.1 disconnectome outputs."""

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


def _fmt(value: object) -> str:
    if isinstance(value, float):
        return f"{value:.6f}"
    return html.escape(str(value))


def _status_class(status: str) -> str:
    return {"PASS": "pass", "WARN": "warn", "FAIL": "fail"}.get(status, "neutral")


def render_html(report: dict) -> str:
    subject = report.get("subject") or "unknown"
    session = report.get("session") or ""
    spared = report.get("disconnection_spared", "C")
    summary = report.get("disconnection_summary") or {}
    lesion = report.get("lesion_selection") or {}
    generated = datetime.now(timezone.utc).strftime("%Y-%m-%d %H:%M UTC")

    rows = []
    for check in report["checks"]:
        stats = check.get("stats") or {}
        detail = "<br>".join(f"{html.escape(k)}: {_fmt(v)}" for k, v in stats.items())
        rows.append(
            f"<tr class='{_status_class(check['status'])}'>"
            f"<td>{html.escape(check['status'])}</td>"
            f"<td>{html.escape(check['name'])}</td>"
            f"<td>{detail or '—'}</td>"
            f"</tr>"
        )

    option_rows = []
    for label, stats in sorted((report.get("disconnection_by_option") or {}).items()):
        option_rows.append(
            "<tr>"
            f"<td>Option {html.escape(label)}</td>"
            f"<td>{_fmt(stats.get('mean_disconnection_on_primary_edges', '—'))}</td>"
            f"<td>{_fmt(stats.get('edges_with_disconnection_gt_0', '—'))}</td>"
            f"<td>{_fmt(stats.get('max_disconnection', '—'))}</td>"
            "</tr>"
        )

    return f"""<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <title>Disconnectome QC — {html.escape(subject)}</title>
  <style>
    body {{ font-family: system-ui, sans-serif; margin: 2rem; color: #1a1a1a; }}
    h1, h2 {{ margin-bottom: 0.4rem; }}
    .meta {{ color: #555; margin-bottom: 1.5rem; }}
    table {{ border-collapse: collapse; width: 100%; margin: 1rem 0 2rem; }}
    th, td {{ border: 1px solid #ddd; padding: 0.5rem 0.75rem; text-align: left; vertical-align: top; }}
    th {{ background: #f5f5f5; }}
    tr.pass td:first-child {{ color: #0a7a2f; font-weight: 600; }}
    tr.warn td:first-child {{ color: #9a6700; font-weight: 600; }}
    tr.fail td:first-child {{ color: #b42318; font-weight: 600; }}
    .badge {{ display: inline-block; padding: 0.2rem 0.6rem; border-radius: 999px; font-weight: 600; }}
    .badge.pass {{ background: #dcfce7; color: #166534; }}
    .badge.warn {{ background: #fef3c7; color: #92400e; }}
    .badge.fail {{ background: #fee2e2; color: #991b1b; }}
    .grid {{ display: grid; grid-template-columns: repeat(auto-fit, minmax(220px, 1fr)); gap: 1rem; }}
    .card {{ border: 1px solid #e5e7eb; border-radius: 8px; padding: 1rem; background: #fafafa; }}
    .card strong {{ display: block; font-size: 1.4rem; margin-top: 0.25rem; }}
  </style>
</head>
<body>
  <h1>Disconnectome QC</h1>
  <p class="meta">{html.escape(subject)} {html.escape(session)} · generated {generated}</p>
  <p><span class="badge {_status_class(report['overall_status'])}">{html.escape(report['overall_status'])}</span>
     weighting={html.escape(str(report.get('weighting', '')))}
     · primary spared option={html.escape(str(spared))}</p>

  <div class="grid">
    <div class="card"><span>Mean D (option {html.escape(str(spared))})</span>
      <strong>{_fmt(summary.get('mean_disconnection_on_primary_edges', '—'))}</strong></div>
    <div class="card"><span>Edges with D &gt; 0</span>
      <strong>{_fmt(summary.get('edges_with_disconnection_gt_0', '—'))}</strong></div>
    <div class="card"><span>Lesion erode voxels</span>
      <strong>{_fmt(lesion.get('lesion_erode_voxels', 0))}</strong></div>
    <div class="card"><span>Core only</span>
      <strong>{html.escape(str(lesion.get('core_only', False)))}</strong></div>
  </div>

  <h2>Disconnection by option</h2>
  <table>
    <thead><tr><th>Option</th><th>Mean D</th><th>Edges D&gt;0</th><th>Max D</th></tr></thead>
    <tbody>{''.join(option_rows) or '<tr><td colspan="4">No option stats in provenance</td></tr>'}</tbody>
  </table>

  <h2>Integrity checks</h2>
  <table>
    <thead><tr><th>Status</th><th>Check</th><th>Details</th></tr></thead>
    <tbody>{''.join(rows)}</tbody>
  </table>
</body>
</html>
"""


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--disconnectome-dir", type=Path, required=True)
    ap.add_argument("--html-out", type=Path, help="Output HTML path (default: disconnectome_qc.html in dir)")
    ap.add_argument("--json-out", type=Path, help="Also write JSON integrity report")
    args = ap.parse_args()

    try:
        report = collect_integrity_report(args.disconnectome_dir)
    except FileNotFoundError as exc:
        print(f"ERROR: {exc}", file=sys.stderr)
        return 2

    html_out = args.html_out or (args.disconnectome_dir / "disconnectome_qc.html")
    json_out = args.json_out or (args.disconnectome_dir / "disconnectome_qc.json")

    html_out.write_text(render_html(report) + "\n")
    json_out.write_text(json.dumps(report, indent=2) + "\n")
    print(f"Wrote {html_out}")
    print(f"Wrote {json_out}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
