#!/usr/bin/env python3
"""Fill release_manifest.json sha256 fields from cached Apptainer .sif files."""

from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

SCRIPT_DIR = Path(__file__).resolve().parent
sys.path.insert(0, str(SCRIPT_DIR))

import container_install  # noqa: E402

MANIFEST = container_install.RELEASE_MANIFEST
DEFAULT_CACHE = Path.home() / ".cache" / "dkt-connectome" / "containers"


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--cache",
        default=str(DEFAULT_CACHE),
        help="Apptainer cache directory (default: ~/.cache/dkt-connectome/containers)",
    )
    parser.add_argument(
        "--containers-dir",
        help="Alternate directory of .sif files (overrides --cache per key when file exists)",
    )
    parser.add_argument("--dry-run", action="store_true", help="Print updates without writing")
    args = parser.parse_args()

    cache = Path(args.cache).expanduser()
    alt = Path(args.containers_dir).expanduser() if args.containers_dir else None
    manifest = container_install.load_release_manifest()
    if manifest is None:
        print(f"ERROR: missing {MANIFEST}", file=sys.stderr)
        return 1

    cfg = container_install.apply_manifest_pins(container_install._load_merged_config())
    pins = cfg.get("container_pins") or {}
    container_paths = cfg.get("containers") or {}
    steps = manifest.setdefault("steps", {})
    updated = 0
    missing: list[str] = []

    for key in container_install.DEFAULT_KEYS:
        spec = steps.get(key)
        if not isinstance(spec, dict):
            continue
        pin = str(pins.get(key) or spec.get("uri") or "")
        configured = str(container_paths.get(key) or "").strip()
        candidates = []
        if configured:
            candidates.append(Path(configured).expanduser())
        if alt is not None:
            candidates.append(alt / container_install.sif_name(key, pin))
        candidates.append(cache / container_install.sif_name(key, pin))
        path = next((p for p in candidates if p.is_file()), None)
        if path is None:
            missing.append(key)
            continue
        digest = container_install.sha256_file(path)
        if spec.get("sha256") != digest:
            spec["sha256"] = digest
            updated += 1
            print(f"  {key}: {digest[:16]}… ({path.name}, {path.stat().st_size // (1024 * 1024)} MB)")

    orch = manifest.get("orchestrator")
    if isinstance(orch, dict):
        print("  orchestrator: skipped (OCI digest; fill from registry after docker publish)")

    if missing:
        print(f"WARNING: no cached .sif for: {', '.join(missing)}", file=sys.stderr)

    if args.dry_run:
        print(f"dry-run: would update {updated} step digest(s)")
        return 0

    MANIFEST.write_text(json.dumps(manifest, indent=2) + "\n", encoding="utf-8")
    print(f"Updated {updated} digest(s) in {MANIFEST}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
