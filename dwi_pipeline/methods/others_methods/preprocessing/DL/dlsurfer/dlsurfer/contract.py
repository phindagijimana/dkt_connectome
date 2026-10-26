"""FreeSurfer-shaped SUBJECTS_DIR contract for all DLSurfer outputs.

Canonical layout under ``$SD/$SID/`` (see ``outputs_registry.yaml``)::

    mri/ surf/ label/ stats/ scripts/ tmp/ touch/
    dwi/ pet/ fmri/ qc/          # multimodal siblings
    hippunfold/ ibeat/ dhcp/     # third-party app trees
    surf/dlsurfer/<backend>/     # non-promoted DL meshes

Does not invent empty classical files (fake aseg.stats, empty lh.thickness, …).
"""

from __future__ import annotations

from functools import lru_cache
from pathlib import Path
from typing import Any

import yaml

_PKG = Path(__file__).resolve().parent

# Morphometry defaults (also listed in outputs_registry for core*)
CORE_REQUIRED = ["mri", "surf", "scripts"]
CORE_PREFERRED = [
    "mri/aparc.DKTatlas+aseg.deep.mgz",
    "mri/aseg.auto_noCCseg.mgz",
    "surf/lh.white",
    "surf/rh.white",
    "surf/lh.pial",
    "surf/rh.pial",
    "stats",
]
ATLAS_PREFERRED = {
    "dkt": list(CORE_PREFERRED),
    "dk": [
        "mri/aseg.mgz",
        "label/lh.aparc.annot",
        "label/rh.aparc.annot",
        "surf/lh.white",
        "surf/rh.white",
    ],
    "destrieux": [
        "label/lh.aparc.a2009s.annot",
        "label/rh.aparc.a2009s.annot",
        "surf/lh.white",
        "surf/rh.white",
    ],
}


def subject_dir(sd: Path, sid: str) -> Path:
    return Path(sd) / sid


@lru_cache(maxsize=1)
def load_outputs_registry() -> dict[str, Any]:
    path = _PKG / "outputs_registry.yaml"
    with path.open() as f:
        data = yaml.safe_load(f) or {}
    return data


def layout_dirs() -> list[str]:
    lay = load_outputs_registry().get("layout") or {}
    return list(lay.get("dirs") or CORE_REQUIRED)


def ensure_fs_tree(sd: Path, sid: str) -> Path:
    """Create classical FreeSurfer-looking dirs under $SD/$SID (idempotent)."""
    root = subject_dir(sd, sid)
    for name in layout_dirs():
        (root / name).mkdir(parents=True, exist_ok=True)
    return root


def profile_contract_spec(profile: str) -> dict[str, Any] | None:
    regs = load_outputs_registry().get("profiles") or {}
    return regs.get(profile)


def _path_ok(root: Path, rel: str) -> bool:
    p = root / rel
    if p.exists():
        return True
    parent = p.parent
    if parent.exists():
        return any(parent.glob(Path(rel).name + "*"))
    return False


def _missing(root: Path, rels: list[str], *, label: str) -> list[str]:
    out: list[str] = []
    for rel in rels:
        if not _path_ok(root, rel):
            out.append(f"missing {label}: {rel}")
    return out


def check_contract(
    sd: Path,
    sid: str,
    *,
    seg_only: bool = False,
    atlas: str = "dkt",
) -> list[str]:
    """Morphometry tree check (core / core-lesion / atlas variants)."""
    root = subject_dir(sd, sid)
    problems: list[str] = []
    if not root.is_dir():
        return [f"missing subject dir: {root}"]
    for d in ("mri", "scripts") if seg_only else CORE_REQUIRED:
        if not (root / d).exists():
            problems.append(f"missing {d}/")
    if not seg_only:
        preferred = ATLAS_PREFERRED.get(atlas, CORE_PREFERRED)
        problems.extend(_missing(root, preferred, label="preferred"))
    return problems


def check_surf_dl_contract(sd: Path, sid: str, *, mode: str = "full") -> list[str]:
    """FS surf/ contract after DL surface install (TopoFit / V2C / SUGAR)."""
    from dlsurfer.adapters.surfaces_fs import check_surf_contract

    return check_surf_contract(sd, sid, mode=mode)


def check_profile_contract(
    sd: Path,
    sid: str,
    profile: str,
    *,
    atlas: str | None = None,
) -> list[str]:
    """Validate $SD/$SID against the FreeSurfer-shaped registry for ``profile``."""
    root = subject_dir(sd, sid)
    if not root.is_dir():
        return [f"missing subject dir: {root}"]

    spec = profile_contract_spec(profile)
    if spec is None:
        # Unknown profile: accept non-empty subject or mri/
        if not (root / "mri").exists() and not any(root.iterdir()):
            return [f"empty subject dir: {root}"]
        return []

    kind = str(spec.get("kind") or "")
    use_atlas = (atlas or spec.get("atlas") or "dkt").lower()

    # Morphometry full / seg_only use classical checker
    if kind == "full":
        return check_contract(sd, sid, seg_only=False, atlas=use_atlas)
    if kind == "seg_only":
        problems = check_contract(sd, sid, seg_only=True, atlas=use_atlas)
        problems.extend(_missing(root, list(spec.get("required") or []), label="required"))
        problems.extend(_missing(root, list(spec.get("preferred") or []), label="preferred"))
        # dedupe
        return list(dict.fromkeys(problems))

    if kind in {"full_dl", "white_dl", "sphere_dl"}:
        mode = {"full_dl": "full", "white_dl": "white", "sphere_dl": "sphere"}[kind]
        problems = check_surf_dl_contract(sd, sid, mode=mode)
        problems.extend(_missing(root, list(spec.get("required") or []), label="required"))
        return list(dict.fromkeys(problems))

    if kind == "seg_plus_surf_dl":
        problems = check_contract(sd, sid, seg_only=True)
        problems.extend(check_surf_dl_contract(sd, sid, mode="full"))
        problems.extend(_missing(root, list(spec.get("required") or []), label="required"))
        return list(dict.fromkeys(problems))

    problems: list[str] = []
    problems.extend(_missing(root, list(spec.get("required") or []), label="required"))
    problems.extend(_missing(root, list(spec.get("preferred") or []), label="preferred"))
    return problems


def check_tool_contract(sd: Path, sid: str, profile: str) -> list[str]:
    """Alias for profile contract (TOOL_CONTRACTS / registry)."""
    return check_profile_contract(sd, sid, profile)


def tool_contracts() -> dict[str, list[str]]:
    """Map profile → path list for TOOL_CONTRACTS consumers."""
    regs = load_outputs_registry().get("profiles") or {}
    out: dict[str, list[str]] = {}
    for name, spec in regs.items():
        paths: list[str] = []
        for key in ("required", "preferred"):
            for rel in spec.get(key) or []:
                if rel not in paths:
                    paths.append(rel)
        if paths:
            out[name] = paths
    return out


# Lazy alias used by older imports
TOOL_CONTRACTS: dict[str, list[str]] = {}


def _refresh_tool_contracts() -> dict[str, list[str]]:
    global TOOL_CONTRACTS
    TOOL_CONTRACTS = tool_contracts()
    return TOOL_CONTRACTS


_refresh_tool_contracts()


def format_layout_tree() -> str:
    """Human-readable FreeSurfer-looking layout for CLI / docs."""
    reg = load_outputs_registry()
    lay = reg.get("layout") or {}
    lines = [
        "$SD/$SID/   # FreeSurfer-shaped SUBJECTS_DIR (DLSurfer)",
        "",
        "## Classical-compatible",
    ]
    for d in lay.get("dirs") or []:
        lines.append(f"  {d}/")
    lines.append("")
    lines.append("## Multimodal (FS-suite siblings)")
    for d in lay.get("modality_dirs") or []:
        lines.append(f"  {d}/")
    lines.append("")
    lines.append("## Third-party app trees")
    for d in lay.get("app_dirs") or []:
        lines.append(f"  {d}/")
    lines.append("")
    lines.append("## By category (profile → paths)")
    by_cat: dict[str, list[str]] = {}
    for name, spec in sorted((reg.get("profiles") or {}).items()):
        cat = str(spec.get("category") or "other")
        by_cat.setdefault(cat, []).append(name)
    for cat in sorted(by_cat):
        lines.append(f"  [{cat}]")
        for name in by_cat[cat]:
            spec = (reg.get("profiles") or {})[name]
            req = ", ".join(spec.get("required") or spec.get("preferred") or ["—"])
            lines.append(f"    {name:28} {req}")
    if lay.get("policy"):
        lines.append("")
        lines.append("## Policy")
        lines.append("  " + str(lay["policy"]).strip())
    return "\n".join(lines) + "\n"


def registry_profile_names() -> set[str]:
    return set((load_outputs_registry().get("profiles") or {}).keys())
