#!/usr/bin/env python3
"""Convert pipeline markdown documentation to .docx (basic formatting)."""

from __future__ import annotations

import re
import sys
from pathlib import Path

from docx import Document
from docx.shared import Pt
from docx.enum.text import WD_BREAK


def add_code_block(doc: Document, lines: list[str]) -> None:
    p = doc.add_paragraph()
    run = p.add_run("\n".join(lines))
    run.font.name = "Courier New"
    run.font.size = Pt(9)


def parse_table(lines: list[str]) -> tuple[list[str], list[list[str]]]:
    rows = []
    for line in lines:
        if not line.strip().startswith("|"):
            break
        cells = [c.strip() for c in line.strip().strip("|").split("|")]
        rows.append(cells)
    if len(rows) < 2:
        return [], []
    header = rows[0]
    body = [r for r in rows[2:] if any(c.strip() for c in r)]  # skip separator
    return header, body


def md_to_docx(md_path: Path, docx_path: Path) -> None:
    text = md_path.read_text(encoding="utf-8")
    lines = text.splitlines()
    doc = Document()
    style = doc.styles["Normal"]
    style.font.name = "Calibri"
    style.font.size = Pt(11)

    i = 0
    in_code = False
    code_buf: list[str] = []

    while i < len(lines):
        line = lines[i]

        if line.strip().startswith("```"):
            if in_code:
                add_code_block(doc, code_buf)
                code_buf = []
                in_code = False
            else:
                in_code = True
            i += 1
            continue

        if in_code:
            code_buf.append(line)
            i += 1
            continue

        if line.strip() == "---":
            doc.add_paragraph("")
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

        if line.strip().startswith("|"):
            table_lines = []
            while i < len(lines) and lines[i].strip().startswith("|"):
                table_lines.append(lines[i])
                i += 1
            header, body = parse_table(table_lines)
            if header:
                tbl = doc.add_table(rows=1 + len(body), cols=len(header))
                tbl.style = "Table Grid"
                for j, h in enumerate(header):
                    tbl.rows[0].cells[j].text = h
                for ri, row in enumerate(body):
                    for j, cell in enumerate(row):
                        if j < len(tbl.rows[ri + 1].cells):
                            tbl.rows[ri + 1].cells[j].text = cell
                doc.add_paragraph("")
            continue

        if line.strip().startswith("- "):
            doc.add_paragraph(line.strip()[2:], style="List Bullet")
            i += 1
            continue

        if re.match(r"^\d+\.\s", line.strip()):
            doc.add_paragraph(re.sub(r"^\d+\.\s", "", line.strip()), style="List Number")
            i += 1
            continue

        if not line.strip():
            i += 1
            continue

        # inline code/backticks stripped simply
        plain = re.sub(r"`([^`]+)`", r"\1", line)
        plain = re.sub(r"\[([^\]]+)\]\([^)]+\)", r"\1", plain)
        doc.add_paragraph(plain)
        i += 1

    docx_path.parent.mkdir(parents=True, exist_ok=True)
    doc.save(str(docx_path))
    print(f"Wrote {docx_path}")


def main() -> None:
    if len(sys.argv) != 3:
        print(f"Usage: {sys.argv[0]} input.md output.docx", file=sys.stderr)
        sys.exit(1)
    md_to_docx(Path(sys.argv[1]), Path(sys.argv[2]))


if __name__ == "__main__":
    main()
