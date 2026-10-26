"""Load engines.yaml and profiles.yaml."""

from __future__ import annotations

from pathlib import Path
from typing import Any

import yaml

from dlsurfer.tools import profile_is_deep_learning

_PKG = Path(__file__).resolve().parent


def _load(name: str) -> dict[str, Any]:
    path = _PKG / name
    with path.open() as f:
        return yaml.safe_load(f)


def engines() -> dict[str, Any]:
    data = _load("engines.yaml")
    return data.get("engines", {}), data.get("pins", {}), data.get("deferred", [])


def engine(engine_id: str) -> dict[str, Any]:
    engs, _, _ = engines()
    if engine_id not in engs:
        raise KeyError(f"Unknown engine: {engine_id}")
    return engs[engine_id]


def profiles() -> dict[str, Any]:
    data = _load("profiles.yaml")
    return data.get("profiles", {})


def profile(name: str) -> dict[str, Any]:
    profs = profiles()
    if name not in profs:
        known = ", ".join(sorted(profs))
        raise KeyError(f"Unknown profile '{name}'. Known: {known}")
    return profs[name]


def profiles_dl_only() -> dict[str, Any]:
    """Public DLSurfer surface: deep-learning profiles only."""
    return {
        name: meta
        for name, meta in profiles().items()
        if profile_is_deep_learning(name, meta)
    }


def ensure_dl_profile(name: str, *, allow_classical: bool = False) -> dict[str, Any]:
    """Load profile; refuse classical unless allow_classical."""
    meta = profile(name)
    if not profile_is_deep_learning(name, meta) and not allow_classical:
        raise ValueError(
            f"profile '{name}' is classical / non-DL (not part of the public "
            f"DLSurfer surface). Prefer the DL alternative, or pass "
            f"--allow-classical for lab use. See: dlsurfer tools"
        )
    return meta