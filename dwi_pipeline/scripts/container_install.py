#!/usr/bin/env python3
"""Pull Apptainer step images and write workflow/config/config.local.yaml."""

from __future__ import annotations

import argparse
import hashlib
import os
import re
import shutil
import subprocess
import sys
from pathlib import Path

try:
    import yaml
except ImportError:  # pragma: no cover
    yaml = None  # type: ignore

SCRIPT_DIR = Path(__file__).resolve().parent
DWI_PIPELINE_DIR = SCRIPT_DIR.parent
CONFIG = DWI_PIPELINE_DIR / "workflow" / "config" / "config.yaml"
LOCAL_CONFIG = DWI_PIPELINE_DIR / "workflow" / "config" / "config.local.yaml"
RELEASE_MANIFEST = DWI_PIPELINE_DIR / "release_manifest.json"
APP_JSON = DWI_PIPELINE_DIR / "app.json"
CONNECTOME_BUILD = DWI_PIPELINE_DIR / "containers" / "connectome" / "build_connectome.sh"
VBT_BUILD = DWI_PIPELINE_DIR / "containers" / "vbt" / "build_vbt.sh"
LESION_ACT_BUILD = DWI_PIPELINE_DIR / "containers" / "lesion_act" / "build_lesion_act.sh"
DEEP_ATROPOS_BUILD = DWI_PIPELINE_DIR / "containers" / "deep_atropos" / "build_deep_atropos.sh"
DEEP_ATROPOS_SEG_BUILD = DWI_PIPELINE_DIR / "containers" / "deep_atropos_seg" / "build_deep_atropos_seg.sh"

# Keys pulled by default for a full pipeline install (inpaint optional at runtime).
DEFAULT_KEYS = (
    "qsiprep",
    "qsirecon",
    "freesurfer",
    "fastsurfer",
    "connectome",
    "vbt",
    "lesion_act",
    "deep_atropos",
    "deep_atropos_seg",
    "lit",
    "nodestrength",
)

MODE_KEYS = {
    "all": DEFAULT_KEYS,
    "qsiprep": ("qsiprep",),
    "inpaint": ("lit", "vbt"),
    "recon": ("freesurfer", "fastsurfer"),
    "qsirecon": ("qsirecon", "freesurfer"),
    "act": ("lesion_act", "deep_atropos", "deep_atropos_seg", "qsirecon"),
    "connectome": ("connectome", "freesurfer"),
    "disconnectome": ("connectome",),
    "nodestrength": ("nodestrength",),
}

# Extra pull URIs when the primary container_pins entry is unavailable.
PULL_URI_FALLBACKS: dict[str, tuple[str, ...]] = {
    "connectome": (
        "ghcr.io/phindagijimana/dk-connectome:0.3.0",
        "ghcr.io/phindagijimana/dk-connectome:0.1.0",
        "phindagijimana321/dkt_connectome:latest",
        "phindagijimana321/dkt_connectome:2.1.0",
    ),
    "vbt": (
        "ghcr.io/phindagijimana/dkt-vbt:0.3.0",
        "phindagijimana321/dkt-vbt:0.1.0",
        "oras://index.docker.io/phindagijimana321/dkt-vbt:0.1.0",
    ),
    "lesion_act": (
        "ghcr.io/phindagijimana/dkt-lesion-act:0.3.0",
        "ghcr.io/phindagijimana/dkt-lesion-act:0.1.0",
        "phindagijimana321/dkt-lesion-act:0.1.0",
        "oras://index.docker.io/phindagijimana321/dkt-lesion-act:0.1.0",
    ),
    "deep_atropos": (
        "ghcr.io/phindagijimana/dkt-deep-atropos:0.3.0",
        "ghcr.io/phindagijimana/dkt-deep-atropos:0.1.0",
        "phindagijimana321/dkt-deep-atropos:0.1.0",
        "oras://index.docker.io/phindagijimana321/dkt-deep-atropos:0.1.0",
    ),
    "deep_atropos_seg": (
        "ghcr.io/phindagijimana/dkt-deep-atropos-seg:0.3.0",
        "ghcr.io/phindagijimana/dkt-deep-atropos-seg:0.1.0",
        "phindagijimana321/dkt-deep-atropos-seg:0.1.0",
        "oras://index.docker.io/phindagijimana321/dkt-deep-atropos-seg:0.1.0",
    ),
    "nodestrength": (
        "ghcr.io/phindagijimana/nodestrength:0.1.0",
        "phindagijimana321/nodestrength:0.1.0",
        "oras://index.docker.io/phindagijimana321/nodestrength:0.1.0",
    ),
}


def _load_json(path: Path) -> dict:
    import json

    return json.loads(path.read_text(encoding="utf-8"))


def load_release_manifest() -> dict | None:
    if not RELEASE_MANIFEST.is_file():
        return None
    data = _load_json(RELEASE_MANIFEST)
    return data if isinstance(data, dict) else None


def pipeline_version_from_app() -> str:
    if APP_JSON.is_file():
        try:
            return str(_load_json(APP_JSON).get("PipelineVersion", "unknown"))
        except (OSError, ValueError, TypeError):
            pass
    return "unknown"


def apply_manifest_pins(cfg: dict) -> dict:
    """Overlay container_pins from release_manifest.json when present."""
    manifest = load_release_manifest()
    if not manifest:
        return cfg
    manifest_version = str(manifest.get("pipeline_version", ""))
    app_version = pipeline_version_from_app()
    if manifest_version and app_version != "unknown" and manifest_version != app_version:
        print(
            f"WARNING [manifest]: release_manifest pipeline_version={manifest_version} "
            f"!= app.json PipelineVersion={app_version}",
            file=sys.stderr,
        )
    steps = manifest.get("steps") or {}
    pins = dict(cfg.get("container_pins") or {})
    for key, spec in steps.items():
        if isinstance(spec, dict) and spec.get("uri"):
            pins[key] = str(spec["uri"])
    cfg = dict(cfg)
    cfg["container_pins"] = pins
    return cfg


def verify_release_manifest(
    cache: Path,
    *,
    strict: bool = False,
    keys: tuple[str, ...] | None = None,
) -> int:
    """Compare cached .sif SHA256 values to release_manifest.json when recorded."""
    manifest = load_release_manifest()
    if manifest is None:
        if strict:
            print(f"ERROR [manifest]: missing {RELEASE_MANIFEST}", file=sys.stderr)
            return 1
        print("manifest: skipped (no release_manifest.json)")
        return 0

    cfg = apply_manifest_pins(_load_merged_config())
    pins = cfg.get("container_pins") or {}
    steps = manifest.get("steps") or {}
    check_keys = keys or DEFAULT_KEYS
    errors: list[str] = []
    checked = 0
    skipped = 0

    print(f"manifest: pipeline_version={manifest.get('pipeline_version', '?')}")
    for key in check_keys:
        spec = steps.get(key) if isinstance(steps.get(key), dict) else {}
        expected = str((spec or {}).get("sha256") or "").strip().lower()
        pin = pins.get(key, "")
        path = Path(str((cfg.get("containers") or {}).get(key) or cache / sif_name(key, pin)))
        if not expected or expected in ("null", "none"):
            skipped += 1
            if path.is_file():
                print(f"  {key}: {path.name} OK (digest not pinned in manifest)")
            else:
                errors.append(f"{key}: missing cached image at {path}")
            continue
        if not path.is_file():
            errors.append(f"{key}: missing cached image at {path}")
            continue
        actual = sha256_file(path).lower()
        checked += 1
        if actual != expected:
            errors.append(
                f"{key}: digest mismatch\n"
                f"  expected: {expected}\n"
                f"  actual:   {actual}\n"
                f"  path:     {path}\n"
                f"  fix: bash scripts/install.sh --force --only {key}"
            )
        else:
            print(f"  {key}: digest OK ({path.name})")

    if skipped and strict:
        print(
            f"manifest: {skipped} key(s) have no sha256 in manifest "
            "(strict checks presence only until release build fills digests)"
        )
    if errors:
        for err in errors:
            print(f"ERROR [manifest]: {err}", file=sys.stderr)
        return 1
    print(f"manifest: OK ({checked} digests verified, {skipped} unpinned)")
    return 0


def _load_merged_config() -> dict:
    if yaml is None:
        sys.exit("ERROR: PyYAML required (pip install pyyaml)")
    cfg = yaml.safe_load(CONFIG.read_text()) or {}
    if LOCAL_CONFIG.is_file():
        local = yaml.safe_load(LOCAL_CONFIG.read_text()) or {}
        _deep_merge(cfg, local)
    return apply_manifest_pins(cfg)


def _deep_merge(base: dict, override: dict) -> None:
    for key, val in override.items():
        if isinstance(val, dict) and isinstance(base.get(key), dict):
            _deep_merge(base[key], val)
        else:
            base[key] = val


def _sanitize_tag(tag: str) -> str:
    return re.sub(r"[^A-Za-z0-9._-]+", "_", tag)


def sif_name(key: str, pin: str) -> str:
    tag = pin.split(":")[-1] if ":" in pin else pin.replace("/", "_")
    if key == "connectome":
        return "dkt_connectome.sif"
    if key == "vbt":
        return "dkt_vbt.sif"
    if key == "lesion_act":
        return "dkt_lesion_act.sif"
    if key == "deep_atropos":
        return "dkt_deep_atropos.sif"
    if key == "deep_atropos_seg":
        return "dkt_deep_atropos_seg.sif"
    if key == "freesurfer" and tag.startswith("7"):
        return f"freesurfer_{_sanitize_tag(tag)}.sif"
    if key == "fastsurfer":
        return "fastsurfer_latest.sif"
    if key == "lit":
        return f"lit_{_sanitize_tag(tag)}.sif"
    if key == "nodestrength":
        return f"nodestrength_{_sanitize_tag(tag)}.sif"
    return f"{key}_{_sanitize_tag(tag)}.sif"


def pull_uris_for_key(key: str, pin: str) -> list[str]:
    """Ordered URIs to try for apptainer pull (primary pin first, then fallbacks)."""
    seen: set[str] = set()
    out: list[str] = []
    for raw in (pin, *PULL_URI_FALLBACKS.get(key, ())):
        uri = apptainer_uri(raw)
        if uri not in seen:
            seen.add(uri)
            out.append(uri)
    return out


def _pull_to_dest(dest: Path, uris: list[str], *, quiet: bool) -> str:
    """Try each URI until one succeeds; return the URI that worked."""
    last_err: subprocess.CalledProcessError | None = None
    tmp = dest.with_suffix(".sif.partial")
    for uri in uris:
        if tmp.exists():
            tmp.unlink()
        try:
            _run_pull(tmp, uri, quiet=quiet)
            tmp.replace(dest)
            return uri
        except subprocess.CalledProcessError as exc:
            last_err = exc
            if not quiet:
                print(f"[install] pull failed: {uri}", file=sys.stderr)
    if last_err:
        raise last_err
    raise SystemExit("ERROR: no URIs to pull")


def apptainer_uri(pin: str) -> str:
    if pin.startswith("docker://") or pin.startswith("oras://"):
        return pin
    if pin.startswith("ghcr.io/"):
        return f"docker://{pin}"
    return f"docker://{pin}"


def default_cache() -> Path:
    env = os.environ.get("DKT_CONTAINER_CACHE")
    if env:
        return Path(env).expanduser()
    return Path.home() / ".cache" / "dkt-connectome" / "containers"


def resolve_keys(mode: str | None, only: str | None) -> tuple[str, ...]:
    if only:
        return tuple(k.strip() for k in only.split(",") if k.strip())
    if mode:
        keys = MODE_KEYS.get(mode)
        if keys is None:
            sys.exit(f"ERROR: unknown mode {mode!r}")
        return keys
    return DEFAULT_KEYS


def list_plan(cache: Path, keys: tuple[str, ...]) -> list[dict]:
    cfg = _load_merged_config()
    pins = cfg.get("container_pins") or {}
    rows = []
    for key in keys:
        pin = pins.get(key)
        if not pin:
            rows.append({"key": key, "pin": None, "sif": None, "path": None, "exists": False})
            continue
        path = cache / sif_name(key, pin)
        rows.append(
            {
                "key": key,
                "pin": pin,
                "uri": apptainer_uri(pin),
                "sif": path.name,
                "path": str(path),
                "exists": path.is_file() and path.stat().st_size > 0,
            }
        )
    return rows


def _run(cmd: list[str], *, quiet: bool = False) -> None:
    if not quiet:
        print(f"+ {' '.join(cmd)}")
    subprocess.run(cmd, check=True)


def _pull_bin() -> str:
    for name in ("apptainer", "singularity"):
        if shutil.which(name):
            return name
    raise SystemExit("ERROR: apptainer or singularity required for pull")


def _run_pull(dest_partial: Path, uri: str, *, quiet: bool) -> None:
    cmd = [_pull_bin(), "pull", "--force", str(dest_partial), uri]
    _run(cmd, quiet=quiet)


def pull_one(key: str, cache: Path, *, force: bool, quiet: bool) -> Path:
    cfg = _load_merged_config()
    pin = (cfg.get("container_pins") or {}).get(key)
    if not pin:
        raise SystemExit(f"ERROR: no container_pins.{key} in {CONFIG}")
    dest = cache / sif_name(key, pin)
    cache.mkdir(parents=True, exist_ok=True)

    if dest.is_file() and dest.stat().st_size > 0 and not force:
        if not quiet:
            print(f"[install] skip {key}: {dest} exists")
        return dest

    if key == "connectome":
        return _pull_connectome(dest, pin, cache, force=force, quiet=quiet)

    if key == "vbt":
        return _pull_vbt(dest, pin, cache, force=force, quiet=quiet)

    if key == "lesion_act":
        return _pull_lesion_act(dest, pin, cache, force=force, quiet=quiet)

    if key == "deep_atropos":
        return _pull_deep_atropos(dest, pin, cache, force=force, quiet=quiet)

    if key == "deep_atropos_seg":
        return _pull_deep_atropos_seg(dest, pin, cache, force=force, quiet=quiet)

    if key == "nodestrength":
        uris = pull_uris_for_key(key, pin)
        used = _pull_to_dest(dest, uris, quiet=quiet)
        if not quiet:
            print(f"[install] OK nodestrength ({used}) -> {dest}")
        return dest

    uris = pull_uris_for_key(key, pin)
    used = _pull_to_dest(dest, uris, quiet=quiet)
    if not quiet:
        print(f"[install] OK {key} ({used}) -> {dest}")
    return dest


def _pull_connectome(dest: Path, pin: str, cache: Path, *, force: bool, quiet: bool) -> Path:
    if dest.is_file() and dest.stat().st_size > 0 and not force:
        if not quiet:
            print(f"[install] skip connectome: {dest} exists")
        return dest
    uris = pull_uris_for_key("connectome", pin)
    try:
        used = _pull_to_dest(dest, uris, quiet=quiet)
        if not quiet:
            print(f"[install] OK connectome (pull {used}) -> {dest}")
        return dest
    except subprocess.CalledProcessError:
        if not quiet:
            print("[install] connectome pull failed for all URIs; trying local build...", file=sys.stderr)
    if not CONNECTOME_BUILD.is_file():
        raise SystemExit(f"ERROR: connectome pull failed and missing {CONNECTOME_BUILD}")

    cfg = _load_merged_config()
    pins = cfg.get("container_pins") or {}
    fs_pin = pins.get("freesurfer")
    qsi_pin = pins.get("qsirecon")
    if not fs_pin or not qsi_pin:
        raise SystemExit("ERROR: connectome build needs container_pins.freesurfer and qsirecon")

    fs_sif = cache / sif_name("freesurfer", fs_pin)
    qsi_sif = cache / sif_name("qsirecon", qsi_pin)
    if not fs_sif.is_file():
        pull_one("freesurfer", cache, force=False, quiet=quiet)
        fs_sif = cache / sif_name("freesurfer", pins["freesurfer"])
    if not qsi_sif.is_file():
        pull_one("qsirecon", cache, force=False, quiet=quiet)
        qsi_sif = cache / sif_name("qsirecon", pins["qsirecon"])

    env = os.environ.copy()
    env["CONTAINER_FREESURFER"] = str(fs_sif)
    env["CONTAINER_QSIRECON"] = str(qsi_sif)
    env["OUT_SIF"] = str(dest)
    env["FORCE"] = "1" if force else "0"
    subprocess.run(["bash", str(CONNECTOME_BUILD)], check=True, env=env)
    if not quiet:
        print(f"[install] OK connectome (build) -> {dest}")
    return dest


def _pull_vbt(dest: Path, pin: str, cache: Path, *, force: bool, quiet: bool) -> Path:
    if dest.is_file() and dest.stat().st_size > 0 and not force:
        if not quiet:
            print(f"[install] skip vbt: {dest} exists")
        return dest
    uris = pull_uris_for_key("vbt", pin)
    try:
        used = _pull_to_dest(dest, uris, quiet=quiet)
        if not quiet:
            print(f"[install] OK vbt (pull {used}) -> {dest}")
        return dest
    except subprocess.CalledProcessError:
        if not quiet:
            print("[install] vbt pull failed; trying local build...", file=sys.stderr)
    if not VBT_BUILD.is_file():
        raise SystemExit(f"ERROR: vbt pull failed and missing {VBT_BUILD}")

    cfg = _load_merged_config()
    qsi_pin = (cfg.get("container_pins") or {}).get("qsiprep")
    if not qsi_pin:
        raise SystemExit("ERROR: vbt build needs container_pins.qsiprep")
    qsi_sif = cache / sif_name("qsiprep", qsi_pin)
    if not qsi_sif.is_file():
        pull_one("qsiprep", cache, force=False, quiet=quiet)
        qsi_sif = cache / sif_name("qsiprep", qsi_pin)

    env = os.environ.copy()
    env["CONTAINER_QSIPREP"] = str(qsi_sif)
    env["OUT_SIF"] = str(dest)
    env["FORCE"] = "1" if force else "0"
    subprocess.run(["bash", str(VBT_BUILD)], check=True, env=env)
    if not quiet:
        print(f"[install] OK vbt (build) -> {dest}")
    return dest


def _pull_lesion_act(dest: Path, pin: str, cache: Path, *, force: bool, quiet: bool) -> Path:
    if dest.is_file() and dest.stat().st_size > 0 and not force:
        if not quiet:
            print(f"[install] skip lesion_act: {dest} exists")
        return dest
    uris = pull_uris_for_key("lesion_act", pin)
    try:
        used = _pull_to_dest(dest, uris, quiet=quiet)
        if not quiet:
            print(f"[install] OK lesion_act (pull {used}) -> {dest}")
        return dest
    except subprocess.CalledProcessError:
        if not quiet:
            print("[install] lesion_act pull failed; trying local build...", file=sys.stderr)
    if not LESION_ACT_BUILD.is_file():
        raise SystemExit(f"ERROR: lesion_act pull failed and missing {LESION_ACT_BUILD}")

    cfg = _load_merged_config()
    qsi_pin = (cfg.get("container_pins") or {}).get("qsirecon")
    if not qsi_pin:
        raise SystemExit("ERROR: lesion_act build needs container_pins.qsirecon")
    qsi_sif = cache / sif_name("qsirecon", qsi_pin)
    if not qsi_sif.is_file():
        pull_one("qsirecon", cache, force=False, quiet=quiet)
        qsi_sif = cache / sif_name("qsirecon", qsi_pin)

    env = os.environ.copy()
    env["CONTAINER_QSIRECON"] = str(qsi_sif)
    env["OUT_SIF"] = str(dest)
    env["FORCE"] = "1" if force else "0"
    subprocess.run(["bash", str(LESION_ACT_BUILD)], check=True, env=env)
    if not quiet:
        print(f"[install] OK lesion_act (build) -> {dest}")
    return dest


def _pull_deep_atropos(dest: Path, pin: str, cache: Path, *, force: bool, quiet: bool) -> Path:
    if dest.is_file() and dest.stat().st_size > 0 and not force:
        if not quiet:
            print(f"[install] skip deep_atropos: {dest} exists")
        return dest
    uris = pull_uris_for_key("deep_atropos", pin)
    try:
        used = _pull_to_dest(dest, uris, quiet=quiet)
        if not quiet:
            print(f"[install] OK deep_atropos (pull {used}) -> {dest}")
        return dest
    except subprocess.CalledProcessError:
        if not quiet:
            print("[install] deep_atropos pull failed; trying local build...", file=sys.stderr)
    if not DEEP_ATROPOS_BUILD.is_file():
        raise SystemExit(f"ERROR: deep_atropos pull failed and missing {DEEP_ATROPOS_BUILD}")

    cfg = _load_merged_config()
    qsi_pin = (cfg.get("container_pins") or {}).get("qsirecon")
    if not qsi_pin:
        raise SystemExit("ERROR: deep_atropos build needs container_pins.qsirecon")
    qsi_sif = cache / sif_name("qsirecon", qsi_pin)
    if not qsi_sif.is_file():
        pull_one("qsirecon", cache, force=False, quiet=quiet)
        qsi_sif = cache / sif_name("qsirecon", qsi_pin)

    env = os.environ.copy()
    env["CONTAINER_QSIRECON"] = str(qsi_sif)
    env["OUT_SIF"] = str(dest)
    env["FORCE"] = "1" if force else "0"
    subprocess.run(["bash", str(DEEP_ATROPOS_BUILD)], check=True, env=env)
    if not quiet:
        print(f"[install] OK deep_atropos (build) -> {dest}")
    return dest


def _pull_deep_atropos_seg(dest: Path, pin: str, cache: Path, *, force: bool, quiet: bool) -> Path:
    if dest.is_file() and dest.stat().st_size > 0 and not force:
        if not quiet:
            print(f"[install] skip deep_atropos_seg: {dest} exists")
        return dest
    uris = pull_uris_for_key("deep_atropos_seg", pin)
    try:
        used = _pull_to_dest(dest, uris, quiet=quiet)
        if not quiet:
            print(f"[install] OK deep_atropos_seg (pull {used}) -> {dest}")
        return dest
    except subprocess.CalledProcessError:
        if not quiet:
            print("[install] deep_atropos_seg pull failed; trying local build...", file=sys.stderr)
    if not DEEP_ATROPOS_SEG_BUILD.is_file():
        raise SystemExit(f"ERROR: deep_atropos_seg pull failed and missing {DEEP_ATROPOS_SEG_BUILD}")

    env = os.environ.copy()
    env["OUT_SIF"] = str(dest)
    env["FORCE"] = "1" if force else "0"
    subprocess.run(["bash", str(DEEP_ATROPOS_SEG_BUILD)], check=True, env=env)
    if not quiet:
        print(f"[install] OK deep_atropos_seg (build) -> {dest}")
    return dest


def pull_all(
    cache: Path,
    keys: tuple[str, ...],
    *,
    missing_only: bool,
    force: bool,
    quiet: bool,
) -> None:
    _pull_bin()  # raises if missing
    os.environ.setdefault(
        "APPTAINER_TMPDIR",
        str(Path(os.environ.get("APPTAINER_TMPDIR", cache.parent / "apptainer_tmp"))),
    )
    Path(os.environ["APPTAINER_TMPDIR"]).mkdir(parents=True, exist_ok=True)

    for key in keys:
        pin_rows = list_plan(cache, (key,))
        if pin_rows and pin_rows[0].get("exists") and missing_only and not force:
            if not quiet:
                print(f"[install] skip {key}: already present")
            continue
        pull_one(key, cache, force=force, quiet=quiet)


def write_config(cache: Path, out: Path, *, quiet: bool) -> None:
    cfg = _load_merged_config()
    pins = cfg.get("container_pins") or {}
    containers: dict[str, str] = {}
    for key in DEFAULT_KEYS:
        pin = pins.get(key)
        if pin:
            containers[key] = str((cache / sif_name(key, pin)).resolve())

    block = {
        "container_pins": dict(cfg.get("container_pins") or {}),
        "containers": containers,
    }
    if yaml is None:
        raise SystemExit("PyYAML required")
    header = (
        "# Auto-generated by DKT Connectome install (scripts/container_install.py).\n"
        "# Regenerate: bash scripts/install.sh\n"
    )
    out.parent.mkdir(parents=True, exist_ok=True)
    out.write_text(header + yaml.safe_dump(block, sort_keys=False))
    if not quiet:
        print(f"[install] wrote {out}")


def doctor(cache: Path | None, *, mode: str, with_dry_run: bool = False) -> int:
    errors: list[str] = []
    warnings: list[str] = []
    ci = os.environ.get("BIDS_APP_CI") == "1"

    for tool in ("python3", "snakemake"):
        if shutil.which(tool) is None:
            errors.append(f"{tool} not found on PATH")
    if not ci and shutil.which("apptainer") is None:
        errors.append("apptainer not found on PATH")

    fs_license = os.environ.get("FS_LICENSE")
    if not fs_license and LOCAL_CONFIG.is_file() and yaml:
        merged = _load_merged_config()
        fs_license = merged.get("fs_license")
    if not ci:
        if not fs_license or not Path(fs_license).expanduser().is_file():
            errors.append(
                "FreeSurfer license missing — export FS_LICENSE=/path/to/license.txt "
                "(https://surfer.nmr.mgh.harvard.edu/registration.html)"
            )

    cfg = _load_merged_config() if yaml else {}
    containers = cfg.get("containers") or {}
    if cache is None:
        cache = default_cache()

    keys = resolve_keys(mode, None)
    for key in keys:
        path = containers.get(key) or str(cache / sif_name(key, (cfg.get("container_pins") or {}).get(key, "unknown")))
        if ci:
            continue
        p = Path(path)
        if not p.is_file() or p.stat().st_size == 0:
            errors.append(
                f"missing container ({key}): {path}\n"
                f"  fix: bash scripts/install.sh --cache {cache}"
            )

    if with_dry_run and not ci:
        fixture = DWI_PIPELINE_DIR / "tests" / "fixtures" / "bids_minimal"
        lic = os.environ.get("FS_LICENSE", "/tmp/license.txt")
        if fixture.is_dir() and shutil.which("bash"):
            proc = subprocess.run(
                [
                    "bash",
                    str(DWI_PIPELINE_DIR / "workflow" / "run_subject.sh"),
                    "qsiprep",
                    "EXAMPLE",
                    "--session-filter",
                    "baseline",
                    "--dry-run",
                    "--no-sdc",
                    "--no-dwi-filter",
                ],
                cwd=DWI_PIPELINE_DIR,
                env={
                    **os.environ,
                    "BIDS_APP_CI": "1",
                    "BIDS_DIR": str(fixture),
                    "RESULTS_ROOT": "/tmp/dkt_doctor_dryrun",
                },
                capture_output=True,
                text=True,
                timeout=180,
            )
            if proc.returncode != 0:
                errors.append(
                    "Snakemake dry-run check failed — run workflow/run_subject.sh qsiprep EXAMPLE --dry-run"
                )
                if proc.stderr:
                    warnings.append(proc.stderr[:300])

    for w in warnings:
        print(f"WARNING [doctor]: {w}")
    if errors:
        for e in errors:
            print(f"ERROR [doctor]: {e}", file=sys.stderr)
        print("\nRun: bash scripts/install.sh", file=sys.stderr)
        return 1
    print("doctor: OK")
    for row in list_plan(cache, keys):
        if row.get("path"):
            status = "OK" if row.get("exists") or ci else "missing"
            print(f"  {row['key']}: {row['path']} [{status}]")
    return 0


def verify_pins(*, require_network: bool = True, mode: str | None = None) -> int:
    """HTTP-check registry references (no pull).

    For each key, at least one URI (primary or fallback) must be reachable.
    """
    cfg = _load_merged_config()
    pins = cfg.get("container_pins") or {}
    keys = resolve_keys(mode, None) if mode else DEFAULT_KEYS
    errors: list[str] = []
    warnings: list[str] = []
    checked = 0
    for key in keys:
        pin = pins.get(key)
        if not pin:
            continue
        uris = pull_uris_for_key(key, pin)
        key_ok = False
        for i, uri in enumerate(uris):
            checked += 1
            ok, detail = _registry_reachable(uri)
            status = "OK" if ok else "FAIL"
            label = "primary" if i == 0 else "fallback"
            print(f"verify\t{key}\t{status}\t{label}\t{uri}\t{detail}")
            if ok:
                key_ok = True
            elif i > 0:
                warnings.append(f"{key} fallback unreachable: {uri} ({detail})")
        if not key_ok and require_network:
            errors.append(f"{key}: no reachable URI among {len(uris)} candidates")
    for w in warnings:
        print(f"WARNING [verify]: {w}")
    if errors:
        print(f"\nverify: {len(errors)} keys with no reachable URI ({checked} checks)", file=sys.stderr)
        return 1
    print(f"verify: OK ({checked} checks, {len(keys)} keys)")
    return 0


def sha256_file(path: Path) -> str:
    h = hashlib.sha256()
    with path.open("rb") as fh:
        for chunk in iter(lambda: fh.read(1024 * 1024), b""):
            h.update(chunk)
    return h.hexdigest()


def digest_rows(cache: Path, keys: tuple[str, ...]) -> list[dict]:
    rows: list[dict] = []
    for row in list_plan(cache, keys):
        path = row.get("path")
        digest = ""
        size_mb = ""
        if path and Path(path).is_file():
            p = Path(path)
            digest = sha256_file(p)
            size_mb = f"{p.stat().st_size / (1024 * 1024):.1f}"
        rows.append(
            {
                "key": row["key"],
                "pin": row.get("pin") or "",
                "sif": row.get("sif") or "",
                "path": path or "",
                "sha256": digest or "(not cached)",
                "size_mb": size_mb or "-",
            }
        )
    return rows


def format_digests_markdown(rows: list[dict], *, version: str) -> str:
    lines = [
        "# Container digest table",
        "",
        f"**Pipeline version:** {version}  ",
        "**Regenerate:** `python3 dwi_pipeline/scripts/generate_container_digests_md.py` after `bash dwi_pipeline/scripts/install.sh --mode all`.",
        "",
        "| Step | Pin | SIF file | Size (MB) | SHA256 |",
        "|------|-----|----------|-----------|--------|",
    ]
    for r in rows:
        sha = r["sha256"]
        if len(sha) > 16 and sha != "(not cached)":
            sha = f"`{sha[:16]}…`"
        else:
            sha = f"`{sha}`"
        lines.append(
            f"| {r['key']} | `{r['pin']}` | `{r['sif']}` | {r['size_mb']} | {sha} |"
        )
    lines.extend(
        [
            "",
            "Primary pins live in [`workflow/config/config.yaml`](https://github.com/phindagijimana/dkt_connectome/blob/main/dwi_pipeline/workflow/config/config.yaml).",
            "Paper supplement: copy this table to Supplementary Table S4 when cutting v1.0.",
            "",
        ]
    )
    return "\n".join(lines)


def cmd_digests(args: argparse.Namespace) -> None:
    cache = Path(args.cache).expanduser()
    keys = resolve_keys(args.mode, args.only)
    rows = digest_rows(cache, keys)
    if args.format == "markdown":
        print(format_digests_markdown(rows, version=args.version))
        return
    for r in rows:
        print(
            f"{r['key']}\t{r['pin']}\t{r['sha256']}\t{r['size_mb']}\t{r['path']}"
        )


def _registry_reachable(uri: str) -> tuple[bool, str]:
    """Best-effort registry probe (Docker Hub tags API or HEAD)."""
    import urllib.error
    import urllib.request

    if uri.startswith("oras://"):
        # ORAS/docker index — treat docker hub path as tags API
        uri = uri.replace("oras://index.docker.io/", "docker://")
    if uri.startswith("docker://"):
        ref = uri[len("docker://") :]
        if ref.startswith("ghcr.io/"):
            url = f"https://{ref.rsplit(':', 1)[0]}"
            try:
                req = urllib.request.Request(url, method="HEAD")
                with urllib.request.urlopen(req, timeout=15) as resp:
                    return True, f"HTTP {resp.status}"
            except urllib.error.HTTPError as exc:
                return exc.code in (200, 401, 405), f"HTTP {exc.code}"
            except OSError as exc:
                return False, str(exc)
        # docker hub namespace/repo:tag
        if "/" in ref and ":" in ref:
            repo, tag = ref.rsplit(":", 1)
            user, name = repo.split("/", 1)
            url = f"https://hub.docker.com/v2/repositories/{user}/{name}/tags/{tag}"
            try:
                with urllib.request.urlopen(url, timeout=15) as resp:
                    return resp.status == 200, f"HTTP {resp.status}"
            except urllib.error.HTTPError as exc:
                return False, f"HTTP {exc.code}"
            except OSError as exc:
                return False, str(exc)
    return True, "skipped"


def cmd_list(args: argparse.Namespace) -> None:
    cache = Path(args.cache).expanduser()
    keys = resolve_keys(args.mode, args.only)
    for row in list_plan(cache, keys):
        mark = "present" if row.get("exists") else "missing"
        print(f"{row['key']}\t{mark}\t{row.get('pin') or '-'}\t{row.get('path') or '-'}")


def cmd_pull(args: argparse.Namespace) -> None:
    cache = Path(args.cache).expanduser()
    keys = resolve_keys(args.mode, args.only)
    pull_all(cache, keys, missing_only=args.missing_only, force=args.force, quiet=args.quiet)
    if args.write_config:
        write_config(cache, Path(args.config).expanduser(), quiet=args.quiet)


def cmd_write_config(args: argparse.Namespace) -> None:
    write_config(Path(args.cache).expanduser(), Path(args.config).expanduser(), quiet=args.quiet)


def cmd_doctor(args: argparse.Namespace) -> None:
    cache = Path(args.cache).expanduser() if args.cache else None
    raise SystemExit(doctor(cache, mode=args.mode, with_dry_run=args.with_dry_run))


def cmd_verify_manifest(args: argparse.Namespace) -> None:
    cache = Path(args.cache).expanduser()
    keys = resolve_keys(args.mode, args.only)
    raise SystemExit(
        verify_release_manifest(cache, strict=args.strict, keys=keys)
    )


def cmd_verify(args: argparse.Namespace) -> None:
    raise SystemExit(
        verify_pins(require_network=not args.offline, mode=args.mode)
    )


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    sub = parser.add_subparsers(dest="command", required=True)

    p_list = sub.add_parser("list", help="Show pinned images and cache paths")
    p_list.add_argument("--cache", default=str(default_cache()))
    p_list.add_argument("--mode", default=None)
    p_list.add_argument("--only", default=None, help="Comma-separated keys")
    p_list.set_defaults(func=cmd_list)

    p_pull = sub.add_parser("pull", help="apptainer pull step images into cache")
    p_pull.add_argument("--cache", default=str(default_cache()))
    p_pull.add_argument("--mode", default=None)
    p_pull.add_argument("--only", default=None)
    p_pull.add_argument("--missing-only", action="store_true")
    p_pull.add_argument("--force", action="store_true")
    p_pull.add_argument("--quiet", action="store_true")
    p_pull.add_argument("--write-config", action="store_true")
    p_pull.add_argument(
        "--config",
        default=str(LOCAL_CONFIG),
        help="Output path for config.local.yaml when --write-config",
    )
    p_pull.set_defaults(func=cmd_pull)

    p_cfg = sub.add_parser("write-config", help="Write workflow/config/config.local.yaml")
    p_cfg.add_argument("--cache", default=str(default_cache()))
    p_cfg.add_argument("--config", default=str(LOCAL_CONFIG))
    p_cfg.add_argument("--quiet", action="store_true")
    p_cfg.set_defaults(func=cmd_write_config)

    p_doc = sub.add_parser("doctor", help="Verify tools, license, and containers")
    p_doc.add_argument("--cache", default=None)
    p_doc.add_argument("--mode", default="all")
    p_doc.add_argument(
        "--with-dry-run",
        action="store_true",
        help="Also run Snakemake dry-run on bids_minimal (slower)",
    )
    p_doc.set_defaults(func=cmd_doctor)

    p_verify = sub.add_parser("verify", help="HTTP-check container_pins registries (no pull)")
    p_verify.add_argument("--mode", default=None, help="Check keys for pipeline mode (qsiprep, all, ...)")
    p_verify.add_argument(
        "--offline",
        action="store_true",
        help="Do not fail when registries are unreachable",
    )
    p_verify.set_defaults(func=cmd_verify)

    p_manifest = sub.add_parser(
        "verify-manifest",
        help="Verify cached .sif digests against release_manifest.json",
    )
    p_manifest.add_argument("--cache", default=str(default_cache()))
    p_manifest.add_argument("--mode", default="all")
    p_manifest.add_argument("--only", default=None)
    p_manifest.add_argument(
        "--strict",
        action="store_true",
        help="Fail if manifest file missing (still skips null sha256 pins)",
    )
    p_manifest.set_defaults(func=cmd_verify_manifest)

    p_dig = sub.add_parser("digests", help="SHA256 digests of cached .sif files")
    p_dig.add_argument("--cache", default=str(default_cache()))
    p_dig.add_argument("--mode", default="all")
    p_dig.add_argument("--only", default=None)
    p_dig.add_argument("--format", choices=("tsv", "markdown"), default="tsv")
    p_dig.add_argument(
        "--version",
        default=pipeline_version_from_app(),
        help="Pipeline version for markdown header",
    )
    p_dig.set_defaults(func=cmd_digests)

    args = parser.parse_args()
    args.func(args)


if __name__ == "__main__":
    main()
