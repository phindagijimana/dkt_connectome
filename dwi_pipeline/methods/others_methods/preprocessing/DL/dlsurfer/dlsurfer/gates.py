"""Production / experimental gates for DLSurfer profiles."""

from __future__ import annotations

from pathlib import Path
from typing import Any

import yaml

from dlsurfer.registry import profile as get_profile

_PKG = Path(__file__).resolve().parent


def load_gates() -> dict[str, Any]:
    with (_PKG / "gates.yaml").open() as f:
        return yaml.safe_load(f).get("gates", {})


def gates_blocking_profile(profile_name: str) -> list[dict[str, Any]]:
    """Return gate records that still block this profile (status != passed)."""
    prof = get_profile(profile_name)
    experimental = bool(prof.get("experimental"))
    out: list[dict[str, Any]] = []
    listed = False
    for gid, g in load_gates().items():
        if profile_name not in (g.get("blocks_profiles") or []):
            continue
        listed = True
        status = (g.get("status") or "open").lower()
        if status != "passed":
            out.append({"id": gid, **g, "status": status})
    # Experimental + no gate entry → still need --allow-experimental.
    # Experimental + gate listed and all passed → allow execute (out empty).
    if experimental and not listed:
        out.append(
            {
                "id": "experimental_flag",
                "title": f"Profile '{profile_name}' is experimental",
                "status": "open",
                "note": prof.get("gate") or "Pass TBI/lab gate or use --allow-experimental",
                "blocks_profiles": [profile_name],
            }
        )
    return out


def format_gates() -> str:
    lines = ["# DLSurfer production gates", ""]
    for gid, g in load_gates().items():
        status = g.get("status", "open")
        lines.append(f"## {gid}  [{status}]")
        lines.append(f"  {g.get('title')}")
        blocks = g.get("blocks_profiles") or []
        if blocks:
            lines.append(f"  blocks: {', '.join(blocks)}")
        if g.get("evidence"):
            lines.append(f"  evidence: {g['evidence']}")
        lines.append(f"  {str(g.get('note', '')).strip()}")
        lines.append("")
    lines.append("Promote: set status: passed in dlsurfer/gates.yaml + evidence path.")
    return "\n".join(lines)
