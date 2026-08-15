#!/usr/bin/env python3
"""Render unified per-subject HTML QC dashboard (Steps 1–5)."""

from __future__ import annotations

import argparse
import html
import json
import sys
from pathlib import Path

SCRIPT_DIR = Path(__file__).resolve().parent
if str(SCRIPT_DIR) not in sys.path:
    sys.path.insert(0, str(SCRIPT_DIR))

from collect_subject_qc import collect_subject_qc


def _status_class(status: str) -> str:
    return {"PASS": "pass", "WARN": "warn", "FAIL": "fail", "SKIP": "skip", "NA": "na"}.get(status, "na")


def _fmt(value: object) -> str:
    if isinstance(value, float):
        return f"{value:.4f}"
    if isinstance(value, bool):
        return "yes" if value else "no"
    return html.escape(str(value))


def _render_summary_table(summary: dict) -> str:
    if not summary:
        return "<p class='muted'>No summary metrics.</p>"
    rows = "".join(
        f"<tr><th>{html.escape(str(k))}</th><td>{_fmt(v)}</td></tr>" for k, v in summary.items()
    )
    return f"<table class='kv'><tbody>{rows}</tbody></table>"


def _render_links(links: list[dict]) -> str:
    if not links:
        return ""
    items = "".join(
        f"<li><a href='{html.escape(l['href'])}'>{html.escape(l['label'])}</a></li>" for l in links if l.get("href")
    )
    return f"<ul class='links'>{items}</ul>"


def _render_figures(figures: list[dict]) -> str:
    if not figures:
        return ""
    blocks = []
    for fig in figures:
        href = fig.get("href", "")
        label = html.escape(fig.get("label", "figure"))
        kind = fig.get("kind", "")
        if kind in {"png", "svg", "jpg", "jpeg"}:
            blocks.append(
                f"<figure><img src='{html.escape(href)}' alt='{label}' loading='lazy'>"
                f"<figcaption>{label}</figcaption></figure>"
            )
        elif kind == "html":
            blocks.append(
                f"<figure><a class='fig-link' href='{html.escape(href)}'>{label} (HTML reportlet)</a></figure>"
            )
    return f"<div class='fig-grid'>{''.join(blocks)}</div>"


def render_html(report: dict) -> str:
    subject = report.get("subject", "unknown")
    generated = report.get("generated_at", "")

    step_sections = []
    for step in report.get("steps", []):
        notes = f"<p class='muted'>{html.escape(step['notes'])}</p>" if step.get("notes") else ""
        step_sections.append(
            f"""
<section id="{html.escape(step['id'])}" class="step {_status_class(step['status'])}">
  <header>
    <h2>{html.escape(step['name'])}</h2>
    <span class="badge {_status_class(step['status'])}">{html.escape(step['status'])}</span>
  </header>
  {notes}
  {_render_summary_table(step.get('summary') or {})}
  {_render_links(step.get('links') or [])}
  {_render_figures(step.get('figures') or [])}
</section>
"""
        )

    # Step nav
    nav_items = []
    for step in report.get("steps", []):
        if step["status"] in ("SKIP", "NA"):
            continue
        nav_items.append(
            f"<a href='#{html.escape(step['id'])}' class='{_status_class(step['status'])}'>"
            f"{html.escape(step['name'].split('—', 1)[-1].strip())}</a>"
        )

    overview_rows = "".join(
        f"<tr class='{_status_class(step['status'])}'>"
        f"<td>{html.escape(step['name'])}</td>"
        f"<td>{html.escape(step['status'])}</td>"
        f"</tr>"
        for step in report.get("steps", [])
    )

    return f"""<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>Subject QC — {html.escape(subject)}</title>
  <style>
    :root {{
      --pass: #166534; --warn: #92400e; --fail: #991b1b; --skip: #6b7280; --na: #9ca3af;
      --pass-bg: #dcfce7; --warn-bg: #fef3c7; --fail-bg: #fee2e2;
    }}
    body {{ font-family: system-ui, sans-serif; margin: 0; color: #111827; background: #f8fafc; }}
    .hero {{ background: #0f172a; color: #f8fafc; padding: 1.5rem 2rem; }}
    .hero h1 {{ margin: 0 0 0.25rem; font-size: 1.6rem; }}
    .hero .meta {{ color: #cbd5e1; font-size: 0.95rem; }}
    .container {{ max-width: 1100px; margin: 0 auto; padding: 1.5rem 2rem 3rem; }}
    .badge {{ display: inline-block; padding: 0.15rem 0.55rem; border-radius: 999px; font-size: 0.85rem; font-weight: 700; }}
    .badge.pass {{ background: var(--pass-bg); color: var(--pass); }}
    .badge.warn {{ background: var(--warn-bg); color: var(--warn); }}
    .badge.fail {{ background: var(--fail-bg); color: var(--fail); }}
    .badge.skip, .badge.na {{ background: #e5e7eb; color: #374151; }}
    nav.step-nav {{ display: flex; flex-wrap: wrap; gap: 0.5rem; margin: 1rem 0 1.5rem; }}
    nav.step-nav a {{ text-decoration: none; padding: 0.35rem 0.7rem; border-radius: 6px; background: white; border: 1px solid #e5e7eb; color: #111827; font-size: 0.9rem; }}
    nav.step-nav a.pass {{ border-color: #86efac; }}
    nav.step-nav a.warn {{ border-color: #fcd34d; }}
    nav.step-nav a.fail {{ border-color: #fca5a5; }}
    table {{ border-collapse: collapse; width: 100%; background: white; }}
    th, td {{ border: 1px solid #e5e7eb; padding: 0.45rem 0.65rem; text-align: left; }}
    th {{ background: #f9fafb; width: 40%; }}
    table.kv th {{ font-weight: 600; }}
    section.step {{ background: white; border: 1px solid #e5e7eb; border-radius: 10px; padding: 1rem 1.25rem; margin: 1rem 0; }}
    section.step header {{ display: flex; align-items: center; justify-content: space-between; gap: 1rem; }}
    section.step h2 {{ margin: 0; font-size: 1.15rem; }}
    .muted {{ color: #6b7280; }}
    ul.links {{ margin: 0.5rem 0; padding-left: 1.2rem; }}
    .fig-grid {{ display: grid; grid-template-columns: repeat(auto-fit, minmax(220px, 1fr)); gap: 1rem; margin-top: 0.75rem; }}
    figure {{ margin: 0; }}
    figure img {{ width: 100%; height: auto; border: 1px solid #e5e7eb; border-radius: 6px; background: #fff; }}
    figcaption {{ font-size: 0.85rem; color: #4b5563; margin-top: 0.25rem; }}
    a.fig-link {{ display: inline-block; padding: 0.5rem; background: #f3f4f6; border-radius: 6px; }}
    tr.pass td:nth-child(2) {{ color: var(--pass); font-weight: 600; }}
    tr.warn td:nth-child(2) {{ color: var(--warn); font-weight: 600; }}
    tr.fail td:nth-child(2) {{ color: var(--fail); font-weight: 600; }}
  </style>
</head>
<body>
  <div class="hero">
    <h1>Subject QC dashboard</h1>
    <p class="meta">{html.escape(subject)} · {html.escape(report.get('results_root', ''))}<br>Generated {html.escape(generated)}</p>
    <p><span class="badge {_status_class(report.get('overall_status', 'NA'))}">Overall: {html.escape(report.get('overall_status', 'NA'))}</span></p>
  </div>
  <div class="container">
    <h2>Overview</h2>
    <table><thead><tr><th>Step</th><th>Status</th></tr></thead><tbody>{overview_rows}</tbody></table>
    <nav class="step-nav">{''.join(nav_items)}</nav>
    {''.join(step_sections)}
  </div>
</body>
</html>
"""


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--results-root", type=Path, required=True)
    ap.add_argument("--subject", required=True, help="Subject ID with or without sub- prefix")
    ap.add_argument("--html-out", type=Path, help="Default: RESULTS_ROOT/qc/sub-<ID>/subject_qc.html")
    ap.add_argument("--json-out", type=Path, help="Default: RESULTS_ROOT/qc/sub-<ID>/subject_qc.json")
    args = ap.parse_args()

    report = collect_subject_qc(args.results_root, args.subject)
    subject_id = report["subject"]
    out_dir = args.results_root / "qc" / subject_id
    out_dir.mkdir(parents=True, exist_ok=True)

    html_out = args.html_out or (out_dir / "subject_qc.html")
    json_out = args.json_out or (out_dir / "subject_qc.json")

    html_out.write_text(render_html(report) + "\n")
    json_out.write_text(json.dumps(report, indent=2) + "\n")
    print(f"Wrote {html_out}")
    print(f"Wrote {json_out} (overall={report['overall_status']})")
    return 0


if __name__ == "__main__":
    sys.exit(main())
