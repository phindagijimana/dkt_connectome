#!/usr/bin/env python3
"""Convert pipeline markdown reference to Word (.docx)."""
from __future__ import annotations

import re
import sys
from pathlib import Path

from docx import Document
from docx.shared import Pt


def convert(md_path: Path, docx_path: Path | None = None) -> Path:
    docx_path = docx_path or md_path.with_suffix(".docx")
    text = md_path.read_text()
    doc = Document()
    doc.styles["Normal"].font.name = "Calibri"
    doc.styles["Normal"].font.size = Pt(11)

    lines = text.splitlines()
    i = 0
    in_code = False
    code_buf: list[str] = []
    table_rows: list[str] = []

    def parse_table_row(row: str) -> list[str]:
        # Strip outer pipes only; do not keep empty split segments from them.
        return [c.strip() for c in row.strip().strip("|").split("|")]

    def flush_table() -> None:
        nonlocal table_rows
        if not table_rows:
            return
        headers = parse_table_row(table_rows[0])
        rows: list[list[str]] = []
        for row in table_rows[2:]:
            cells = parse_table_row(row)
            if len(cells) >= len(headers):
                rows.append(cells[: len(headers)])
        if headers:
            tbl = doc.add_table(rows=1, cols=len(headers))
            tbl.style = "Table Grid"
            for j, h in enumerate(headers):
                tbl.rows[0].cells[j].text = h
            for r in rows:
                cells = tbl.add_row().cells
                for j, val in enumerate(r):
                    cells[j].text = val
            doc.add_paragraph("")
        table_rows = []

    while i < len(lines):
        line = lines[i]
        if line.strip().startswith("```"):
            if in_code:
                para = doc.add_paragraph()
                run = para.add_run("\n".join(code_buf))
                run.font.name = "Consolas"
                run.font.size = Pt(9)
                code_buf = []
                in_code = False
            else:
                flush_table()
                in_code = True
            i += 1
            continue
        if in_code:
            code_buf.append(line)
            i += 1
            continue
        if line.startswith("|"):
            table_rows.append(line)
            i += 1
            continue
        flush_table()
        if line.strip() == "---":
            i += 1
            continue
        if line.startswith("# "):
            doc.add_heading(line[2:].strip(), level=1)
            i += 1
            continue
        if line.startswith("## "):
            doc.add_heading(line[3:].strip(), level=2)
            i += 1
            continue
        if line.startswith("### "):
            doc.add_heading(line[4:].strip(), level=3)
            i += 1
            continue
        if line.startswith("- "):
            doc.add_paragraph(line[2:].strip(), style="List Bullet")
            i += 1
            continue
        if re.match(r"^\d+\.\s", line.strip()):
            doc.add_paragraph(re.sub(r"^\d+\.\s*", "", line.strip()), style="List Number")
            i += 1
            continue
        if line.strip():
            t = re.sub(r"\*\*(.+?)\*\*", r"\1", line.strip())
            t = re.sub(r"`([^`]+)`", r"\1", t)
            doc.add_paragraph(t)
        i += 1

    flush_table()
    doc.save(str(docx_path))
    return docx_path


def main() -> None:
    md = Path(sys.argv[1]) if len(sys.argv) > 1 else Path(__file__).resolve().parents[1] / "DWI_Connectivity_Pipeline_Documentation.md"
    out = convert(md)
    print(out)


if __name__ == "__main__":
    main()
