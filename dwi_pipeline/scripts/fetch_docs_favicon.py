#!/usr/bin/env python3
"""Install sphinx-rtd-theme / MkDocs RTD favicon into docs/img (QSIPrep-style tab icon)."""
from __future__ import annotations

import shutil
from importlib.resources import files
from pathlib import Path

OUT = Path(__file__).resolve().parents[1] / "docs" / "img" / "favicon.ico"


def main() -> None:
    src = files("mkdocs.themes.readthedocs") / "img" / "favicon.ico"
    OUT.parent.mkdir(parents=True, exist_ok=True)
    with src.open("rb") as fh:
        data = fh.read()
    OUT.write_bytes(data)
    print(f"Wrote {OUT} ({len(data)} bytes)")


if __name__ == "__main__":
    main()
