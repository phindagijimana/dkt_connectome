"""
plugins/loader.smk — minimal plugin loader for the DWI -> DK connectome pipeline.

A "plugin" here is just a directory under plugins/ containing two files:

    plugins/<name>/
        plugin.yaml          # machine-readable manifest (see schema below)
        rules.smk            # Snakemake rules that produce this stage's outputs

The loader:
  1. Reads every plugin.yaml under plugins/ (in `order:` ascending order).
  2. Validates the manifest against a tiny inline schema.
  3. Validates each plugin's `requires:` against `config` (and exits early
     with a clear error if a required container or config key is missing).
  4. Honours the per-stage toggles in config (`run_recon`, `run_qsirecon`,
     `run_dk_connectome`) and skips include-ing disabled plugins.

The actual `include:` directives for plugin rule files live in the Snakefile,
not here — Snakemake requires `include:` at the top level of a Snakefile, not
inside a function. The loader's job is to populate `ENABLED_PLUGINS` and
catch misconfigurations early.

Why roll our own instead of `snakemake.module`?
  * `module:` is overkill for this scale and complicates Snakemake-Slurm
    diagnostics (rule names get prefixed).
  * A flat directory of include files keeps the DAG and CLI familiar to
    anyone who has used QSIPrep, fMRIPrep, etc.
"""

from pathlib import Path
import json
import yaml


# ---------------------------------------------------------------------------
# Manifest loading + validation
# ---------------------------------------------------------------------------
PLUGINS_DIR = Path(workflow.basedir) / "plugins"
SCHEMAS_DIR = Path(workflow.basedir) / "schemas"

_INTERNAL_NAME = "_common"

# Lazy-load + cache the plugin schema. jsonschema is a hard dep of Snakemake,
# but we degrade gracefully if it isn't importable for whatever reason
# (custom Snakemake fork, partial install, etc.) — the loader's existing
# manual checks still catch the most common mistakes.
_PLUGIN_SCHEMA = None
_SCHEMA_VALIDATOR_OK = None  # True / False / None=unattempted


def _load_plugin_schema():
    global _PLUGIN_SCHEMA, _SCHEMA_VALIDATOR_OK
    if _SCHEMA_VALIDATOR_OK is not None:
        return _PLUGIN_SCHEMA
    schema_path = SCHEMAS_DIR / "plugin.schema.json"
    if not schema_path.is_file():
        _SCHEMA_VALIDATOR_OK = False
        return None
    try:
        import jsonschema  # noqa: F401
    except ImportError:
        try:
            logger.warning(
                "jsonschema not importable; plugin.yaml schema validation skipped "
                "(loader's manual checks still apply)."
            )
        except Exception:
            pass
        _SCHEMA_VALIDATOR_OK = False
        return None
    try:
        _PLUGIN_SCHEMA = json.loads(schema_path.read_text())
    except json.JSONDecodeError as e:
        raise WorkflowError(f"schemas/plugin.schema.json is not valid JSON: {e}")
    _SCHEMA_VALIDATOR_OK = True
    return _PLUGIN_SCHEMA


def _validate_manifest_schema(data: dict, plugin_dir: Path) -> None:
    schema = _load_plugin_schema()
    if schema is None:
        return
    import jsonschema
    try:
        jsonschema.validate(instance=data, schema=schema)
    except jsonschema.ValidationError as e:
        loc = "/".join(str(p) for p in e.absolute_path) or "(root)"
        raise WorkflowError(
            f"Plugin {plugin_dir.name}: plugin.yaml schema violation at `{loc}`: "
            f"{e.message}"
        )


def _read_manifest(plugin_dir: Path) -> dict:
    """Load + sanity-check one plugin.yaml. Raises WorkflowError on problems."""
    mf = plugin_dir / "plugin.yaml"
    if not mf.is_file():
        raise WorkflowError(f"Plugin {plugin_dir.name}: missing plugin.yaml")
    try:
        data = yaml.safe_load(mf.read_text()) or {}
    except yaml.YAMLError as e:
        raise WorkflowError(f"Plugin {plugin_dir.name}: invalid YAML: {e}")

    # JSON Schema validation runs first — catches typos in field names,
    # bad enum values, wrong types, etc. with a precise pointer into the
    # YAML doc. Falls back to a no-op if jsonschema isn't available.
    _validate_manifest_schema(data, plugin_dir)

    for key in ("name", "version"):
        if key not in data:
            raise WorkflowError(f"Plugin {plugin_dir.name}: plugin.yaml missing `{key}:`")
    if data["name"] != plugin_dir.name:
        raise WorkflowError(
            f"Plugin {plugin_dir.name}: plugin.yaml name=`{data['name']}` "
            f"doesn't match directory name `{plugin_dir.name}`"
        )

    rules_file = data.get("rules", "rules.smk")
    if not (plugin_dir / rules_file).is_file():
        raise WorkflowError(
            f"Plugin {data['name']}: rules file `{rules_file}` not found "
            f"under {plugin_dir}"
        )

    data["_dir"]   = plugin_dir
    data["_rules"] = str(plugin_dir / rules_file)
    data.setdefault("order", 999)
    data.setdefault("kind",  "stage")          # "stage" or "internal"
    data.setdefault("requires", {})
    data.setdefault("optional", {})
    data.setdefault("options",  {})
    return data


def _discover_plugins() -> list[dict]:
    """Find every plugins/<name>/plugin.yaml and return manifests sorted by order."""
    if not PLUGINS_DIR.is_dir():
        raise WorkflowError(f"plugins/ directory not found at {PLUGINS_DIR}")
    manifests = []
    for d in sorted(PLUGINS_DIR.iterdir()):
        if not d.is_dir():
            continue
        if (d / "plugin.yaml").is_file():
            manifests.append(_read_manifest(d))
    if not any(m["name"] == _INTERNAL_NAME for m in manifests):
        raise WorkflowError(
            f"Required internal plugin `{_INTERNAL_NAME}` missing under plugins/."
        )
    # Sort: internal first (always loaded), then by `order`.
    manifests.sort(key=lambda m: (m["kind"] != "internal", m.get("order", 999), m["name"]))
    return manifests


# ---------------------------------------------------------------------------
# Stage gating — honour config toggles
# ---------------------------------------------------------------------------
_STAGE_TOGGLE = {
    # Plugin name -> config key. qsiprep is always on (it's stage 1).
    "qsiprep":       None,
    "recon":         "run_recon",
    "qsirecon":      "run_qsirecon",
    "dk_connectome": "run_dk_connectome",
}


def _is_enabled(manifest: dict) -> bool:
    if manifest["kind"] == "internal":
        return True
    toggle = _STAGE_TOGGLE.get(manifest["name"])
    if toggle is None:
        return True                                   # no toggle => always on
    val = config.get(toggle, True)
    if isinstance(val, str):
        return val.strip().lower() in ("1", "true", "yes", "on", "y", "t")
    return bool(val)


# ---------------------------------------------------------------------------
# Dependency validation (container paths exist, required plugins are enabled)
# ---------------------------------------------------------------------------
# Strict validation is opt-in via env var. The default (lenient) path lets
# `connectome install` succeed against a freshly-cloned repo whose
# config.yaml still has `/path/to/...` container placeholders; the rule
# itself will hard-fail at execution time if the image is genuinely missing.
import os
_STRICT = os.environ.get("DK_STRICT_VALIDATION", "").lower() in ("1", "true", "yes")


def _problem(msg: str):
    if _STRICT:
        raise WorkflowError(msg)
    # Snakemake's logger isn't always available at module import time;
    # fall back to stderr.
    try:
        logger.warning(msg)
    except Exception:
        import sys
        print(f"WARNING: {msg}", file=sys.stderr)


def _validate_requires(manifest: dict, enabled_names: set[str]):
    req = manifest.get("requires", {}) or {}

    # Required container .sif files. Lenient by default — see _STRICT note.
    for ckey in (req.get("containers") or []):
        path = (config.get("containers") or {}).get(ckey)
        if not path or str(path).startswith("/path/to") or not Path(path).is_file():
            _problem(
                f"Plugin `{manifest['name']}`: container `containers.{ckey}` = "
                f"{path!r} not found. The rule will fail at run time if the image "
                f"is actually needed. Set DK_STRICT_VALIDATION=1 to make this fatal."
            )

    # Required top-level config keys. Always strict — missing config keys
    # would cause harder-to-diagnose KeyError at rule evaluation time.
    for ck in (req.get("config") or []):
        cur = config
        for part in ck.split("."):
            if not isinstance(cur, dict) or part not in cur:
                cur = None
                break
            cur = cur[part]
        if cur in (None, ""):
            raise WorkflowError(
                f"Plugin `{manifest['name']}`: required config key `{ck}` is missing/empty."
            )

    # Required upstream plugins must also be enabled. Always strict — DAG
    # building would otherwise reach for outputs no rule will ever produce.
    for dep in (req.get("plugins") or []):
        if dep not in enabled_names:
            raise WorkflowError(
                f"Plugin `{manifest['name']}` requires plugin `{dep}` "
                f"to be enabled (check the run_<dep> toggle in config)."
            )


# ---------------------------------------------------------------------------
# Public API consumed by the Snakefile
# ---------------------------------------------------------------------------
PLUGIN_MANIFESTS = _discover_plugins()
ENABLED_PLUGINS  = [m for m in PLUGIN_MANIFESTS if _is_enabled(m)]
ENABLED_NAMES    = {m["name"] for m in ENABLED_PLUGINS}

# Validate each enabled plugin against the config + its dependencies.
for _m in ENABLED_PLUGINS:
    _validate_requires(_m, ENABLED_NAMES)


def plugin_rule_files() -> list[str]:
    """Absolute paths to every enabled plugin's rules.smk, in load order."""
    return [m["_rules"] for m in ENABLED_PLUGINS]


def print_plugin_banner():
    """One-line summary, printed from the Snakefile's onstart handler."""
    stage_names = [m["name"] for m in ENABLED_PLUGINS if m["kind"] == "stage"]
    print(f"  plugins      : {', '.join(stage_names)}")

