#!/usr/bin/env python3
"""Write dataset_description.json for pipeline derivatives (RESULTS_ROOT).

Provenance is assembled from app.json (single version source), optional
release_manifest.json container pins, git HEAD, and the input BIDS
dataset_description.json. The on-disk folder layout is site-specific and not
fully BIDS Derivatives spec compliant — see docs/derivatives.md.
"""

from __future__ import annotations

import argparse
import json
import subprocess
from datetime import datetime, timezone
from pathlib import Path

SCRIPT_DIR = Path(__file__).resolve().parent
DWI_PIPELINE_DIR = SCRIPT_DIR.parent
APP_JSON = DWI_PIPELINE_DIR / "app.json"
RELEASE_MANIFEST = DWI_PIPELINE_DIR / "release_manifest.json"
REPO_ROOT = DWI_PIPELINE_DIR.parent

_FALLBACK_NAME = "DKT Connectome"
_FALLBACK_CODE_URL = "https://github.com/phindagijimana/dkt_connectome"


def load_json(path: Path) -> dict:
    if not path.is_file():
        return {}
    try:
        data = json.loads(path.read_text(encoding="utf-8"))
    except json.JSONDecodeError:
        return {}
    return data if isinstance(data, dict) else {}


def load_app_metadata(app_json: Path | None = None) -> dict:
    """Identity fields from app.json. Missing keys get stable fallbacks."""
    app = load_json(app_json or APP_JSON)
    version = str(app.get("PipelineVersion") or "unknown")
    docker_hub = str(app.get("DockerHub") or "").strip()
    return {
        "name": str(app.get("Name") or _FALLBACK_NAME),
        "version": version,
        "code_url": str(app.get("Source") or _FALLBACK_CODE_URL),
        "description": str(app.get("Description") or ""),
        "how_to_acknowledge": str(app.get("HowToAcknowledge") or ""),
        "documentation": str(app.get("Documentation") or ""),
        "license": str(app.get("License") or ""),
        "docker_hub": docker_hub,
        "container_tag": f"{docker_hub}:{version}" if docker_hub and version != "unknown" else "",
    }


def git_provenance(repo_root: Path | None = None) -> dict:
    root = repo_root or REPO_ROOT
    info: dict[str, object] = {"commit": None, "dirty": None}
    try:
        info["commit"] = subprocess.check_output(
            ["git", "-C", str(root), "rev-parse", "HEAD"],
            text=True,
            stderr=subprocess.DEVNULL,
        ).strip()
    except (subprocess.CalledProcessError, FileNotFoundError, OSError):
        return info
    try:
        status = subprocess.check_output(
            ["git", "-C", str(root), "status", "--porcelain"],
            text=True,
            stderr=subprocess.DEVNULL,
        )
        info["dirty"] = bool(status.strip())
    except (subprocess.CalledProcessError, FileNotFoundError, OSError):
        pass
    return info


def load_container_pins(manifest_path: Path | None = None) -> dict:
    """Compact step/orchestrator pins from release_manifest.json."""
    manifest = load_json(manifest_path or RELEASE_MANIFEST)
    if not manifest:
        return {}
    pins: dict[str, dict] = {}
    orchestrator = manifest.get("orchestrator")
    if isinstance(orchestrator, dict) and orchestrator.get("uri"):
        pins["orchestrator"] = {
            "uri": orchestrator.get("uri"),
            "sha256": orchestrator.get("sha256"),
        }
    steps = manifest.get("steps")
    if isinstance(steps, dict):
        for name, spec in steps.items():
            if not isinstance(spec, dict) or not spec.get("uri"):
                continue
            pins[str(name)] = {"uri": spec.get("uri"), "sha256": spec.get("sha256")}
    return {
        "pipeline_version": manifest.get("pipeline_version"),
        "pins": pins,
    }


def source_dataset_entry(bids_dir: Path) -> dict:
    """Record the input BIDS dataset; prefer DOI/version from its description."""
    desc = load_json(bids_dir / "dataset_description.json")
    version = (
        desc.get("DatasetDOI")
        or desc.get("Version")
        or desc.get("BIDSVersion")
        or "unspecified"
    )
    entry: dict[str, str] = {
        "URL": f"file://{bids_dir.resolve()}",
        "Version": str(version),
    }
    if desc.get("Name"):
        entry["Name"] = str(desc["Name"])
    return entry


def generated_by_block(app: dict | None = None) -> dict:
    meta = app or load_app_metadata()
    block: dict = {
        "Name": meta["name"],
        "Version": meta["version"],
        "CodeURL": meta["code_url"],
    }
    if meta.get("description"):
        block["Description"] = meta["description"]
    if meta.get("container_tag"):
        block["Container"] = {"Type": "docker", "Tag": meta["container_tag"]}
    return block


def build_provenance(bids_dir: Path | None, results_root: Path) -> dict:
    app = load_app_metadata()
    generated = generated_by_block(app)
    git = git_provenance()
    if git.get("commit"):
        generated["Git"] = git

    out: dict = {
        "Name": f"{app['name']} derivatives",
        "BIDSVersion": "1.9.0",
        "DatasetType": "derivative",
        "GeneratedBy": [generated],
        "PipelineResultsRoot": str(results_root.resolve()),
        "WrittenAt": datetime.now(timezone.utc).replace(microsecond=0).isoformat(),
        "LayoutNote": (
            "Internal custom layout (qsiprep_single_run_output/, connectomes/, …). "
            "BIDS Derivatives export available at derivatives/ via export_bids_derivatives.py. "
            "See dwi_pipeline/docs/derivatives.md."
        ),
    }
    if app.get("how_to_acknowledge"):
        out["HowToAcknowledge"] = app["how_to_acknowledge"]
    if app.get("documentation"):
        out["Documentation"] = app["documentation"]
    if app.get("license"):
        out["License"] = app["license"]
    pins = load_container_pins()
    if pins.get("pins"):
        out["ContainerPins"] = pins
    if bids_dir is not None:
        out["SourceDatasets"] = [source_dataset_entry(bids_dir)]
    return out


def main() -> None:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--results-root", type=Path, required=True)
    ap.add_argument("--bids-dir", type=Path, default=None)
    ap.add_argument("--dry-run", action="store_true")
    args = ap.parse_args()

    results_root = args.results_root.resolve()
    results_root.mkdir(parents=True, exist_ok=True)
    out_path = results_root / "dataset_description.json"
    payload = build_provenance(args.bids_dir.resolve() if args.bids_dir else None, results_root)

    if args.dry_run:
        print(json.dumps(payload, indent=2))
        return

    out_path.write_text(json.dumps(payload, indent=2) + "\n")
    print(f"Wrote {out_path}")


if __name__ == "__main__":
    main()
