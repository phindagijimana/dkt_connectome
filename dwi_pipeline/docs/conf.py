# DKT Connectome documentation — Sphinx configuration (QSIPrep-style RTD theme).
# Build: cd dwi_pipeline/docs && make html

from __future__ import annotations

import json
from datetime import datetime
from pathlib import Path

DOCS_ROOT = Path(__file__).resolve().parent
APP_JSON = DOCS_ROOT.parent / "app.json"

if APP_JSON.is_file():
    with APP_JSON.open(encoding="utf-8") as fh:
        _app = json.load(fh)
    version = release = _app.get("PipelineVersion", "0.2.0")
else:
    version = release = "0.2.0"

project = "DKT Connectome"
author = "Inzira Labs, University of Rochester and contributors"
copyright = f"2026-{datetime.now().year}, {author}"

needs_sphinx = "4.2.0"

extensions = [
    "myst_parser",
    "sphinx.ext.intersphinx",
    "sphinx.ext.todo",
    "sphinx_reredirects",
]

templates_path = ["_templates"]
exclude_patterns = [
    "_build",
    "Thumbs.db",
    ".DS_Store",
    "maintainer",
    "maintainer/**",
    "config_catalog.md",
    "schema_reference.md",
    "presentations",
    "presentations/**",
]

source_suffix = {
    ".rst": "restructuredtext",
    ".md": "markdown",
}
master_doc = "index"
language = "en"
pygments_style = "default"
todo_include_todos = False

# MyST — keep existing Markdown admonitions and GitHub-style tables.
myst_enable_extensions = [
    "colon_fence",
    "deflist",
    "fieldlist",
    "substitution",
    "tasklist",
]
myst_heading_anchors = 3

suppress_warnings = [
    "myst.xref_missing",
    "intersphinx",
]

# Match MkDocs redirect_map (sphinx-reredirects uses .html suffixes).
redirects = {
    "quickstart": "tutorial.html",
    "preprocessing": "preparing_data.html",
    "integrity_qc": "disconnectome.html#integrity-qc",
    "getting_help": "index.html#contact",
    "advanced/theory_deep_dive": "science_overview.html",
    "BIDS_App": "contributing.html#repository-local-documentation",
    "bids_apps_registry": "contributing.html#repository-local-documentation",
    "visual_qc": "qc.html",
    "qc_dashboard": "qc.html",
    "fieldmaps_sdc": "preparing_data.html#fieldmaps-and-sdc",
    "readthedocs_setup": "contributing.html#repository-local-documentation",
    "config_catalog": "contributing.html#repository-local-documentation",
    "schema_reference": "contributing.html#repository-local-documentation",
}

html_theme = "sphinx_rtd_theme"
html_static_path = ["_static"]
htmlhelp_basename = "dkt_connectome_doc"
html_context = {
    "display_github": True,
    "github_user": "phindagijimana",
    "github_repo": "dkt_connectome",
    "github_version": "main",
    "conf_py_path": "/dwi_pipeline/docs/",
}

intersphinx_mapping = {
    "python": ("https://docs.python.org/3", None),
}


def setup(app):
    app.add_css_file("theme_overrides.css")
