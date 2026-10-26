# DLSurfer documentation — Sphinx configuration (DKT Connectome / QSIPrep-style RTD theme).
# Build: cd docs && make html

from __future__ import annotations

import re
from pathlib import Path

DOCS_ROOT = Path(__file__).resolve().parent
PKG_ROOT = DOCS_ROOT.parent
PYPROJECT = PKG_ROOT / "pyproject.toml"

version = release = "0.1.1"
if PYPROJECT.is_file():
    text = PYPROJECT.read_text(encoding="utf-8")
    m = re.search(r'^version\s*=\s*["\']([^"\']+)["\']', text, re.M)
    if m:
        version = release = m.group(1)

project = "DLSurfer"
author = "Philbert Ndagijimana and contributors"
copyright = f"2026, {author}"

needs_sphinx = "4.2.0"

extensions = [
    "myst_parser",
    "sphinx.ext.mathjax",
    "sphinx.ext.intersphinx",
    "sphinx.ext.todo",
    "sphinx_reredirects",
]

templates_path = ["_templates"]
exclude_patterns = [
    "_build",
    "Thumbs.db",
    ".DS_Store",
    # MkDocs-only landing (replaced by home.md + index.rst)
    "index.md",
    # Superseded by what_it_does.md / methods/index.md
    "getting_started/what.md",
    "methods/overview.md",
]

source_suffix = {
    ".rst": "restructuredtext",
    ".md": "markdown",
}
master_doc = "index"
language = "en"
pygments_style = "default"
todo_include_todos = False

myst_enable_extensions = [
    "amsmath",
    "colon_fence",
    "deflist",
    "fieldlist",
    "substitution",
    "tasklist",
]
myst_heading_anchors = 0

# Match DKT Connectome: clean headings on RTD (no broken permalink glyphs).
html_permalinks = False

suppress_warnings = [
    "myst.xref_missing",
    "intersphinx",
    "misc.highlighting_failure",
]

# Optional short aliases → current nested pages (do not redirect pages that
# themselves are in the toctree — that would overwrite real HTML).
redirects = {
    "tutorial": "getting_started/tutorial.html",
    "sample_results": "getting_started/sample_results.html",
    "installation": "installation/index.html",
    "usage": "usage/minimal.html",
    "preparing_data": "preparing/inputs.html",
    "outputs": "outputs/layout.html",
    "qc": "usage/qc.html",
    "faq": "troubleshooting/faq.html",
    "troubleshooting": "troubleshooting/cluster.html",
}

html_theme = "sphinx_rtd_theme"
html_static_path = ["_static"]
htmlhelp_basename = "dlsurfer_doc"
html_context = {
    "display_github": True,
    "github_user": "phindagijimana",
    "github_repo": "dlsurfer",
    "github_version": "main",
    "conf_py_path": "/docs/",
}

intersphinx_mapping = {
    "python": ("https://docs.python.org/3", None),
}


def setup(app):
    app.add_css_file("theme_overrides.css")
