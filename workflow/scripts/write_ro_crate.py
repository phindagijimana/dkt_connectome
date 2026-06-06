#!/usr/bin/env python3
"""write_ro_crate.py — emit a minimal RO-Crate 1.1 for one pipeline run.

Called from the workflow's `onsuccess:` handler in the Snakefile. Produces
`<results_root>/ro-crate-metadata.json` plus a sibling `ro-crate-preview.html`
(stub) so the directory is recognised by RO-Crate-aware tools (WorkflowHub,
ROHub, ARP, Galaxy, etc.) without needing the `rocrate-py` package as a
runtime dependency.

What we record
--------------
* The workflow itself (Snakefile, every plugin's plugin.yaml + rules.smk,
  the JSON schemas).
* The resolved config snapshot.
* Container .sif paths + on-disk SHA256 digests (truncated to 16 hex chars
  in the crate; full digest stored under `dk:digest` for completeness).
* Per-rule benchmark TSVs that Snakemake wrote during the run.
* Per-subject DK connectome CSVs (and QSIPrep/QSIRecon sentinel flags).
* Run wall-clock duration (computed from .snakemake/log/<timestamp>.log if
  present; otherwise just records `dateCreated`).

Why bare JSON instead of rocrate-py
-----------------------------------
The dk_connectome runtime is pure Python stdlib + snakemake + jsonschema.
Adding rocrate-py would pull in a transitive web stack (requests, click,
jinja2, lxml) that's unnecessary for a single JSON-LD writer. The output
validates against the RO-Crate 1.1 profile (https://www.researchobject.org
/ro-crate/1.1/) with `roc-validator` / `rocrate validate`.

Invocation
----------
    python3 workflow/scripts/write_ro_crate.py \
        --results-root /path/to/results \
        --repo-root    /path/to/dk_connectome \
        --config       config/config.yaml \
        [--subjects SUB1,SUB2,...]
"""

from __future__ import annotations

import argparse
import hashlib
import json
import os
import sys
import time
from datetime import datetime, timezone
from pathlib import Path
from typing import Any


# ---------------------------------------------------------------------------
# Small helpers
# ---------------------------------------------------------------------------
def _read_yaml(path: Path) -> dict:
    """Light-weight YAML read — uses PyYAML if available, else a tiny parser."""
    try:
        import yaml  # type: ignore
        return yaml.safe_load(path.read_text()) or {}
    except ImportError:
        pass
    # very small fallback (mirrors connectome CLI's loader)
    out: dict = {}
    cur = None
    for raw in path.read_text().splitlines():
        if not raw.strip() or raw.lstrip().startswith("#"):
            continue
        if not raw[0].isspace():
            cur = None
            if ":" in raw:
                k, _, v = raw.partition(":")
                if v.strip() == "":
                    cur = k.strip()
                    out[cur] = {}
                else:
                    out[k.strip()] = v.strip().strip('"').strip("'")
        elif cur is not None:
            if ":" in raw:
                k, _, v = raw.partition(":")
                out[cur][k.strip()] = v.strip().strip('"').strip("'")
    return out


def _sha256(path: Path, chunk: int = 1 << 20) -> str:
    """Stream a sha256. Returns '' if unreadable (e.g. a directory, missing file)."""
    if not path.is_file():
        return ""
    h = hashlib.sha256()
    with path.open("rb") as fh:
        for blk in iter(lambda: fh.read(chunk), b""):
            h.update(blk)
    return h.hexdigest()


def _file_entity(repo_root: Path, abs_path: Path, *, name: str | None = None,
                 description: str | None = None, role: str | None = None,
                 with_hash: bool = True) -> dict:
    """Build a RO-Crate File entity for `abs_path`.

    `@id` is path-relative-to-the-crate-root (results_root). For files
    outside the crate root (e.g. workflow source under repo_root), we use
    an absolute file:// URI as the @id.
    """
    entity: dict[str, Any] = {
        "@type": "File",
        "name":  name or abs_path.name,
    }
    if description:
        entity["description"] = description
    if role:
        entity["dk:role"] = role
    try:
        rel = abs_path.relative_to(repo_root)
        entity["@id"] = str(rel)
    except ValueError:
        entity["@id"] = abs_path.as_uri()
    if abs_path.is_file():
        entity["contentSize"] = abs_path.stat().st_size
        if with_hash:
            digest = _sha256(abs_path)
            if digest:
                entity["sha256"] = digest
    return entity


# ---------------------------------------------------------------------------
# Crate assembly
# ---------------------------------------------------------------------------
def _workflow_files(repo_root: Path) -> list[Path]:
    """Every source file that defines the workflow itself (no derivatives)."""
    files = [repo_root / "Snakefile"]
    for sub in ("plugins", "schemas"):
        d = repo_root / sub
        if d.is_dir():
            files += sorted(p for p in d.rglob("*")
                            if p.is_file() and p.suffix in (".smk", ".yaml", ".json"))
    return [f for f in files if f.is_file()]


def _container_entities(repo_root: Path, cfg: dict) -> list[dict]:
    """One File entity per .sif under config.containers, with sha256."""
    entities: list[dict] = []
    containers = (cfg.get("containers") or {})
    for key, raw in containers.items():
        sif = Path(str(raw)).expanduser()
        if not sif.is_file():
            entities.append({
                "@id":         f"#container:{key}",
                "@type":       "SoftwareApplication",
                "name":        key,
                "description": f"Apptainer image for the {key} stage (not present on disk: {sif})",
                "dk:role":     "container",
            })
            continue
        digest = _sha256(sif)
        ent = _file_entity(repo_root, sif,
                           name=f"{key}.sif",
                           description=f"Apptainer image for the {key} stage",
                           role="container",
                           with_hash=False)
        ent["@type"] = ["File", "SoftwareApplication"]
        if digest:
            ent["sha256"] = digest
            ent["dk:digest"] = f"sha256:{digest}"
        entities.append(ent)
    return entities


def _benchmark_entities(repo_root: Path, results_root: Path) -> list[dict]:
    bench_dir = results_root / "benchmarks"
    if not bench_dir.is_dir():
        return []
    return [_file_entity(repo_root, p,
                         description="Snakemake per-rule benchmark TSV "
                                     "(wall_clock, max_rss, cpu_time, io_in/out, mean_load)",
                         role="benchmark")
            for p in sorted(bench_dir.glob("*.tsv")) if p.is_file()]


def _subject_output_entities(repo_root: Path, results_root: Path,
                             subjects: list[str]) -> list[dict]:
    out: list[dict] = []
    for sid in subjects:
        candidates = [
            (results_root / "dk_connectomes" / f"sub-{sid}" / "dk_connectome.csv",
             f"DK connectome (84x84) for sub-{sid}", "dk_connectome"),
            (results_root / ".flags" / f"qsiprep.sub-{sid}.done",
             f"QSIPrep completion sentinel for sub-{sid}", "qsiprep_flag"),
            (results_root / ".flags" / f"qsirecon.sub-{sid}.done",
             f"QSIRecon completion sentinel for sub-{sid}", "qsirecon_flag"),
            (results_root / "freesurfer" / f"sub-{sid}" / "mri" / "aparc+aseg.mgz",
             f"FreeSurfer aparc+aseg.mgz for sub-{sid}", "recon"),
        ]
        for p, desc, role in candidates:
            if p.exists():
                out.append(_file_entity(repo_root, p, description=desc, role=role))
    return out


def _run_duration_seconds(repo_root: Path) -> int | None:
    """Best-effort: parse the most recent .snakemake/log/*.log for elapsed time."""
    log_dir = repo_root / ".snakemake" / "log"
    if not log_dir.is_dir():
        return None
    logs = sorted(log_dir.glob("*.log"), key=lambda p: p.stat().st_mtime)
    if not logs:
        return None
    latest = logs[-1]
    try:
        # Snakemake stamps the first line with the start time, mtime ~ end time.
        start = latest.stat().st_ctime
        end   = latest.stat().st_mtime
        return max(0, int(end - start))
    except OSError:
        return None


def build_crate(*, repo_root: Path, results_root: Path, config_path: Path,
                subjects: list[str]) -> dict:
    cfg = _read_yaml(config_path)

    workflow_files = [_file_entity(repo_root, p,
                                   description=f"Workflow source — {p.relative_to(repo_root)}",
                                   role="workflow-source")
                      for p in _workflow_files(repo_root)]

    container_entities = _container_entities(repo_root, cfg)
    benchmark_entities = _benchmark_entities(repo_root, results_root)
    output_entities    = _subject_output_entities(repo_root, results_root, subjects)

    config_entity = _file_entity(repo_root, config_path,
                                 description="Resolved pipeline configuration for this run",
                                 role="config-snapshot")

    duration_s = _run_duration_seconds(repo_root)
    now = datetime.now(timezone.utc).isoformat(timespec="seconds")

    # ----- Main entity: the workflow + its run -----
    main = {
        "@id":          "./",
        "@type":        "Dataset",
        "name":         "dk_connectome pipeline run",
        "description":  ("One run of the dk_connectome Snakemake workflow "
                         "(QSIPrep -> Recon -> QSIRecon -> DK connectome). "
                         "Outputs, config snapshot, container digests, and "
                         "per-rule benchmarks are recorded in this RO-Crate."),
        "datePublished": now,
        "license":      "https://spdx.org/licenses/MIT.html",
        "creator":      {"@id": "https://github.com/phindagijimana"},
        "mainEntity":   {"@id": "Snakefile"},
        "hasPart":      ([{"@id": e["@id"]} for e in workflow_files] +
                         [{"@id": e["@id"]} for e in container_entities] +
                         [{"@id": e["@id"]} for e in benchmark_entities] +
                         [{"@id": e["@id"]} for e in output_entities] +
                         [{"@id": config_entity["@id"]}]),
    }

    snakefile_entity = next((e for e in workflow_files if e["@id"] == "Snakefile"), None)
    if snakefile_entity is not None:
        snakefile_entity["@type"] = ["File", "ComputationalWorkflow", "SoftwareSourceCode"]
        snakefile_entity["programmingLanguage"] = {"@id": "#snakemake"}

    action = {
        "@id":            "#run-1",
        "@type":          "CreateAction",
        "name":           "dk_connectome workflow run",
        "endTime":        now,
        "instrument":     {"@id": "Snakefile"},
        "object":         [{"@id": e["@id"]} for e in (container_entities + [config_entity])],
        "result":         [{"@id": e["@id"]} for e in (output_entities + benchmark_entities)],
    }
    if duration_s is not None:
        # ISO 8601 duration (e.g. PT3H42M5S)
        h, rem = divmod(duration_s, 3600)
        m, s   = divmod(rem, 60)
        action["dk:wallTimeSeconds"] = duration_s
        action["duration"] = "PT" + (f"{h}H" if h else "") + (f"{m}M" if m else "") + f"{s}S"

    snakemake_lang = {
        "@id":   "#snakemake",
        "@type": "ComputerLanguage",
        "name":  "Snakemake",
        "url":   "https://snakemake.readthedocs.io",
        "identifier": "https://snakemake.readthedocs.io",
    }

    person = {
        "@id":   "https://github.com/phindagijimana",
        "@type": "Person",
        "name":  "Phind Ndagijimana",
    }

    metadata_descriptor = {
        "@id":              "ro-crate-metadata.json",
        "@type":            "CreativeWork",
        "conformsTo":       {"@id": "https://w3id.org/ro/crate/1.1"},
        "about":            {"@id": "./"},
    }

    graph = ([metadata_descriptor, main, snakemake_lang, person, config_entity, action]
             + workflow_files
             + container_entities
             + benchmark_entities
             + output_entities)

    return {
        "@context": [
            "https://w3id.org/ro/crate/1.1/context",
            {
                "dk":  "https://github.com/phindagijimana/dk_connectome/schemas/ns#",
                "sha256": "http://www.w3.org/2001/XMLSchema#hexBinary"
            }
        ],
        "@graph": graph,
    }


def write_preview_html(out_dir: Path, crate_json_name: str) -> Path:
    """Tiny human-readable index — RO-Crate spec recommends ro-crate-preview.html."""
    p = out_dir / "ro-crate-preview.html"
    p.write_text(
        "<!doctype html>\n"
        "<html lang='en'><head><meta charset='utf-8'>"
        "<title>dk_connectome RO-Crate</title>"
        "<style>body{font-family:system-ui,sans-serif;max-width:48rem;margin:2rem auto;padding:0 1rem;line-height:1.5}"
        "code{background:#f4f4f4;padding:0.1rem 0.3rem;border-radius:3px}</style>"
        "</head><body>"
        "<h1>dk_connectome — Research Object</h1>"
        "<p>This directory is a <a href='https://www.researchobject.org/ro-crate/1.1/'>"
        "RO-Crate 1.1</a> describing one run of the dk_connectome Snakemake workflow.</p>"
        f"<p>Machine-readable manifest: <code>{crate_json_name}</code></p>"
        "<p>Inspect with any RO-Crate tool, e.g. "
        "<a href='https://pypi.org/project/rocrate/'>rocrate-py</a>: "
        "<code>rocrate-cli describe .</code></p>"
        "</body></html>\n"
    )
    return p


def main(argv: list[str] | None = None) -> int:
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    ap.add_argument("--results-root", required=True, type=Path)
    ap.add_argument("--repo-root",    required=True, type=Path)
    ap.add_argument("--config",       required=True, type=Path)
    ap.add_argument("--subjects",     default="",
                    help="comma-separated subject IDs (without sub- prefix). "
                         "Empty = read from <repo-root>/config/subjects.tsv "
                         "or the config's `subjects:` list.")
    ap.add_argument("--out",          default=None,
                    help="output path (default <results-root>/ro-crate-metadata.json)")
    args = ap.parse_args(argv)

    repo_root    = args.repo_root.resolve()
    results_root = args.results_root.resolve()
    cfg_path     = args.config.resolve()

    if args.subjects:
        subjects = [s.strip().removeprefix("sub-")
                    for s in args.subjects.split(",") if s.strip()]
    else:
        cfg = _read_yaml(cfg_path)
        tsv = cfg.get("subjects_tsv")
        subjects = []
        if tsv:
            tp = Path(str(tsv))
            if not tp.is_absolute():
                tp = (repo_root / tp).resolve()
            if tp.exists():
                for ln in tp.read_text().splitlines():
                    s = ln.strip()
                    if s and not s.startswith("#"):
                        subjects.append(s.removeprefix("sub-"))
        if not subjects:
            for s in (cfg.get("subjects") or []):
                subjects.append(str(s).removeprefix("sub-"))
        subjects = sorted(set(subjects))

    crate = build_crate(repo_root=repo_root,
                        results_root=results_root,
                        config_path=cfg_path,
                        subjects=subjects)

    out_path = Path(args.out) if args.out else (results_root / "ro-crate-metadata.json")
    out_path.parent.mkdir(parents=True, exist_ok=True)
    out_path.write_text(json.dumps(crate, indent=2, sort_keys=False))
    preview = write_preview_html(out_path.parent, out_path.name)

    n_workflow_files = sum(1 for e in crate["@graph"]
                           if isinstance(e.get("@type"), list)
                           and "ComputationalWorkflow" in e["@type"]) \
                       + sum(1 for e in crate["@graph"]
                             if e.get("dk:role") == "workflow-source")
    n_outputs = sum(1 for e in crate["@graph"] if e.get("dk:role") == "dk_connectome")

    print(f"[ro-crate] wrote {out_path}")
    print(f"[ro-crate]   subjects with outputs: {n_outputs}")
    print(f"[ro-crate]   workflow source files: {n_workflow_files}")
    print(f"[ro-crate]   preview:               {preview}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
