#!/usr/bin/env python3
"""Generate docs/methods/engines.md from dlsurfer/engines.yaml (keep docs in sync)."""

from __future__ import annotations

from pathlib import Path

import yaml

ROOT = Path(__file__).resolve().parents[1]
ENGINES = ROOT / "dlsurfer" / "engines.yaml"
OUT = ROOT / "docs" / "methods" / "engines.md"


def main() -> int:
    data = yaml.safe_load(ENGINES.read_text())
    pins = data.get("pins") or {}
    engs = data.get("engines") or {}
    deferred = data.get("deferred") or []

    lines: list[str] = [
        "# Methods — resources & citations",
        "",
        "Auto-generated from `dlsurfer/engines.yaml` (`python scripts/gen_methods_docs.py`).",
        "Cite **these engines**, not DLSurfer as morphometry science.",
        "",
        "## Pinned stack",
        "",
        "| Pin | Value |",
        "|-----|-------|",
    ]
    for k, v in pins.items():
        lines.append(f"| `{k}` | `{v}` |")

    lines += [
        "",
        "## Chosen engines",
        "",
        "| Engine | CLI / resource | Paper / docs |",
        "|--------|----------------|--------------|",
    ]

    for eid, e in engs.items():
        if not e.get("chosen"):
            continue
        name = e.get("name") or eid
        cli = (e.get("cli") or "—").replace("|", "\\|")
        cites = e.get("cite") or []
        cite_s = "<br>".join(c.replace("|", "\\|") for c in cites) if cites else "—"
        ready = e.get("readiness", "")
        lines.append(f"| **{name}** (`{eid}`) · {ready} | `{cli}` | {cite_s} |")

    lines += [
        "",
        "## Per-engine detail",
        "",
    ]
    for eid, e in engs.items():
        if not e.get("chosen"):
            continue
        name = e.get("name") or eid
        lines.append(f"### {name} {{#{eid}}}")
        lines.append("")
        lines.append(f"- **Replaces (classical):** {e.get('classical_replaces', '—')}")
        lines.append(f"- **CLI / resource:** `{e.get('cli', '—')}`")
        if e.get("lab_path"):
            lines.append(f"- **Lab path:** `{e['lab_path']}`")
        why = " ".join(str(e.get("why", "")).split())
        if why:
            lines.append(f"- **Why chosen:** {why}")
        lines.append("- **Cite:**")
        for c in e.get("cite") or ["—"]:
            lines.append(f"  - {c}")
        alts = e.get("alternatives") or []
        if alts:
            alt_bits = ", ".join(
                f"`{a.get('id')}` ({a.get('readiness', '?')})" for a in alts if isinstance(a, dict)
            )
            lines.append(f"- **Alternatives:** {alt_bits}")
        lines.append("")

    if deferred:
        lines += ["## Deferred (not defaults)", ""]
        for d in deferred:
            lines.append(f"- `{d.get('id')}` — {d.get('why', '')}")
        lines.append("")

    OUT.parent.mkdir(parents=True, exist_ok=True)
    OUT.write_text("\n".join(lines) + "\n")
    print(f"wrote {OUT}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
