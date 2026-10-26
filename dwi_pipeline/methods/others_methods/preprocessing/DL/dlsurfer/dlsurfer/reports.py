"""Terminal-friendly summaries of long reference docs + doctor output."""

from __future__ import annotations

import re
from pathlib import Path

from dlsurfer.doctor import Check, doctor_summary_ok


def _pkg_docs() -> Path:
    return Path(__file__).resolve().parent.parent / "docs" / "reference"


def _parse_md_tables(text: str) -> list[tuple[str, list[str], list[list[str]]]]:
    """Return list of (heading_before, headers, rows) for GitHub-style tables."""
    lines = text.splitlines()
    tables: list[tuple[str, list[str], list[list[str]]]] = []
    i = 0
    last_heading = ""
    while i < len(lines):
        line = lines[i]
        if line.startswith("#"):
            last_heading = line.lstrip("#").strip()
        if line.startswith("|") and i + 1 < len(lines) and re.search(r"-{3,}", lines[i + 1]):
            headers = [c.strip() for c in line.strip().strip("|").split("|")]
            rows: list[list[str]] = []
            j = i + 2
            while j < len(lines) and lines[j].startswith("|"):
                rows.append([c.strip() for c in lines[j].strip().strip("|").split("|")])
                j += 1
            tables.append((last_heading, headers, rows))
            i = j
            continue
        i += 1
    return tables


def format_gaps_remaining(*, full: bool = False) -> str:
    path = _pkg_docs() / "GAPS_WITHOUT_ALTERNATIVES.md"
    if not path.is_file():
        return "Missing docs/reference/GAPS_WITHOUT_ALTERNATIVES.md"
    text = path.read_text()
    if full:
        return text.rstrip() + "\n"

    tables = _parse_md_tables(text)
    lines = [
        "Gaps without a credible DLSurfer alternative",
        "(full markdown: dlsurfer gaps-remaining --full)",
        "",
    ]
    if tables:
        _heading, _headers, rows = tables[0]
        for row in rows:
            if len(row) < 3:
                continue
            gap = re.sub(r"\*+", "", row[0]).strip()
            instead = row[2].strip()
            lines.append(f"• {gap}")
            lines.append(f"    → {instead}")
        lines.append("")
    if len(tables) > 1:
        lines.append(f"Wired former gaps: {len(tables[1][2])} (see --full or ALTERNATIVES.md)")
    lines.append(f"Source: {path}")
    return "\n".join(lines) + "\n"


def format_compare(*, full: bool = False) -> str:
    path = _pkg_docs() / "COMPARE_FS_FASTSURFER.md"
    if not path.is_file():
        return "Missing docs/reference/COMPARE_FS_FASTSURFER.md"
    text = path.read_text()
    if full:
        return text.rstrip() + "\n"

    tables = _parse_md_tables(text)
    lines = [
        "DLSurfer vs FreeSurfer vs FastSurfer (summary)",
        "(full matrix: dlsurfer compare --full)",
        "",
    ]

    status_counts: dict[str, int] = {}
    no_alt: list[str] = []
    wired: list[str] = []
    for _heading, headers, rows in tables:
        dls_idx = next((i for i, h in enumerate(headers) if "dlsurfer" in h.lower()), None)
        if dls_idx is None:
            continue
        for row in rows:
            if len(row) <= dls_idx:
                continue
            cap = re.sub(r"\*+", "", row[0]).strip()
            cell = row[dls_idx]
            for m in re.finditer(r"\*\*([YPNECW])\*\*|\b([YPNECW])\b", cell):
                letter = m.group(1) or m.group(2)
                status_counts[letter] = status_counts.get(letter, 0) + 1
            note = row[-1] if row else ""
            if "No alt" in note or "Non-claim" in note:
                no_alt.append(cap)
            if "**W**" in cell:
                wired.append(cap)

    if status_counts:
        order = ["Y", "W", "P", "E", "C", "N"]
        bits = [f"{k}={status_counts[k]}" for k in order if k in status_counts]
        lines.append("DLSurfer cell marks: " + ", ".join(bits))
        lines.append(
            "  Y=first-class  W=wired alt  P=partial  E=experimental  C=classical  N=missing"
        )
        lines.append("")

    bottom = None
    for t in reversed(tables):
        if t[1] and "question" in t[1][0].lower():
            bottom = t
            break
    if bottom:
        lines.append("Bottom line:")
        for row in bottom[2]:
            if len(row) >= 2:
                q = re.sub(r"\*+", "", row[0]).strip()
                a = re.sub(r"\*+", "", row[1]).strip()
                lines.append(f"  {q}: {a}")
        lines.append("")

    if wired:
        lines.append(f"Wired alts (sample): {', '.join(wired[:8])}{'…' if len(wired) > 8 else ''}")
    if no_alt:
        lines.append(f"No-alt callouts: {', '.join(dict.fromkeys(no_alt))}")
        lines.append("Detail: dlsurfer gaps-remaining")
    lines.append(f"Source: {path}")
    return "\n".join(lines) + "\n"


def format_doctor_report(
    checks: list[Check],
    *,
    brief: bool = False,
    version: str = "",
    claim: str = "",
    isolation: str = "",
) -> str:
    """Render doctor checks for the terminal."""
    optional_miss = [c for c in checks if not c.ok]
    ok_core = doctor_summary_ok(checks)
    required = {
        "FASTSURFER_HOME",
        "FREESURFER_HOME",
        "fs_license_env",
        "run_fastsurfer",
        "neurolit",
        "freesurfer",
    }
    by = {c.name: c for c in checks}
    out: list[str] = []

    if version:
        out.append(f"dlsurfer {version}")

    if not brief:
        if claim:
            out.append(claim)
        if isolation:
            out.append(isolation)
        out.append("")
        for c in checks:
            mark = "OK " if c.ok else "MISS"
            out.append(f"[{mark}] {c.name}: {c.detail}")
        out.append("[OK ] isolation: package path under others_methods/preprocessing/DL/dlsurfer/")
        out.append("[OK ] dkt_decouple: no import of DKT workflow; handoff is print-only")
        out.append("")
    else:
        out.append("")
        for name in (
            "FASTSURFER_HOME",
            "FREESURFER_HOME",
            "fs_license_env",
            "run_fastsurfer",
            "neurolit",
            "freesurfer",
        ):
            c = by.get(name)
            if c is None:
                continue
            mark = "OK " if c.ok else "MISS"
            detail = c.detail if not c.ok else ""
            out.append(f"[{mark}] {c.name}" + (f": {detail}" if detail else ""))
        c_dev = by.get("device_auto")
        if c_dev:
            out.append(f"[{'OK ' if c_dev.ok else 'MISS'}] {c_dev.name}: {c_dev.detail}")
        for c in checks:
            if c.name.startswith("gates:"):
                out.append(f"[{'OK ' if c.ok else 'MISS'}] {c.name}: {c.detail}")
        names = [c.name for c in optional_miss if c.name not in required]
        if names:
            out.append(
                f"[note] {len(names)} optional MISS: {', '.join(names[:8])}"
                f"{'…' if len(names) > 8 else ''}"
            )
        out.append("")

    if ok_core:
        out.append("[READY] core live-run deps present")
        if optional_miss and not brief:
            names = [c.name for c in optional_miss]
            out.append(
                f"[note] {len(names)} optional/specialty check(s) MISS "
                f"({', '.join(names[:6])}{'…' if len(names) > 6 else ''}) — "
                "OK for core/core-lesion; needed only for matching specialty profiles"
            )
            out.append("Tip: dlsurfer doctor --brief")
    else:
        out.append(
            "[NOT READY] set FASTSURFER_HOME, FREESURFER_HOME, FS_LICENSE, neurolit, recon-all"
        )
    return "\n".join(out) + "\n"
