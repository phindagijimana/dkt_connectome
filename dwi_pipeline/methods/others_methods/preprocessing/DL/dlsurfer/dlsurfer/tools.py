"""FreeSurfer-shaped tool contracts — deep-learning only public surface.

Product identity: **deep-learning FreeSurfer-suite methods** — T1 morphometry
plus multimodal specialty (DWI bundles, PET quant, fMRI preprocess, QC).
Not TBI-only. Specialty allowed.

``dlsurfer recon-all`` → FastSurferVINN ``core`` (not classical FreeSurfer recon-all).
Classical Bayesian / FS-long / fs8 stay behind ``--allow-classical``.
"""

from __future__ import annotations

from typing import Any

from dlsurfer.contract import TOOL_CONTRACTS, tool_contracts
from dlsurfer.credibility import PROFILE_TIER, Tier, tier_for_profile

# Profiles that are not deep-learning (classical FS / non-DL fill).
CLASSICAL_PROFILES: frozenset[str] = frozenset(
    {
        "fs8",
        "fs8-lesion",
        "fs-long",
        "subfields-ha",
        "nuclei-bs-thal",
        "atlas-destrieux",
        "atlas-schaefer",
        "lesion-enantiomorphic",
        "core-recon-surf",
    }
)

# FS-style short names → DLSurfer profile ids (callable alone).
TOOL_ALIASES: dict[str, str] = {
    # Orchestrator
    "recon-all": "core",
    "recon-all-lesion": "core-lesion",
    # Volume / strip / salvage (Synth* + FastSurfer)
    "aseg": "seg-quick",
    "synthseg": "seg-quick-synthseg",
    "synthseg-robust": "seg-synthseg-robust",
    "wmh-synthseg": "seg-wmh-synthseg",
    "super-synth": "seg-super-synth",
    "supersynth": "seg-super-synth",
    "synthstrip": "strip",
    "hdbet": "strip-hdbet",
    "synthsr": "preprocess-synthsr",
    "deepn4": "bias-deepn4",
    # Registration / atlas DL
    "easyreg": "register-easyreg",
    "synthmorph": "register-synthmorph",
    "easyatlas": "atlas-easyatlas",
    "histo-atlas": "structure-histo-atlas",
    "hypvinn-t2": "structure-hypvinn-t2",
    "fs8-dl": "fs8-dl-modules",
    "fs8-dl-modules": "fs8-dl-modules",
    # Structure / nuclei (DL specialty — first-class)
    "hippunfold": "structure-hippunfold",
    "hippodeep": "structure-hippodeep",
    "sclimbic": "structure-sclimbic",
    "mars-brainstem": "structure-brainstem-mars",
    "mars-ventricles": "structure-ventricles-mars",
    "mars-wmh": "seg-wmh-mars",
    "claustrum": "structure-claustrum",
    "claustrum-albishri": "structure-claustrum-albishri",
    "piriform-synthseg": "structure-piriform-synthseg",
    "piriform-nnunet": "structure-piriform-nnunet",
    "amygdala-go": "structure-amygdala-go",
    "thalamic-dti-cnn": "nuclei-thalamic-dti-cnn",
    "deep-thomas": "nuclei-thalamic-deep-thomas",
    # Surfaces / sphere / thickness (DL)
    "topofit": "surf-dl-topofit",
    "v2c": "surf-dl-v2c",
    "recon-surf-dl": "core-dl-surf",
    "surfaces-dl": "core-dl-surf",
    "core-dl-surf": "core-dl-surf",
    "v2c-long": "surf-dl-v2c-long",
    "cortexode": "surf-dl-cortexode",
    "pialnn": "surf-dl-pialnn",
    "corticalflow": "surf-dl-corticalflow",
    "surfnn": "surf-dl-surfnn",
    "deepcsr": "surf-dl-deepcsr",
    "fastcsr": "surf-dl-fastcsr",
    "sugar": "sphere-sugar",
    "s3reg": "sphere-s3reg",
    "thickness": "thickness-fast",
    "dl-direct": "thickness-dl-direct",
    # Infant / clinical DL
    "ibeat": "infant-ibeat",
    "dhcp": "infant-dhcp",
    "clinical": "fs-clinical",
    # Lesion fill (optional specialty — not required for core T1 path)
    "lit": "core-lesion",
    "vbg": "lesion-vbg",
    # Atlas DL paths
    "destrieux-dl": "atlas-destrieux-dl",
    "schaefer-dl": "atlas-schaefer-dl",
    # Multimodal FS-suite DL (non-morphometry)
    "tractseg": "dwi-tractseg",
    "deepwma": "dwi-deepwma",
    "pet-dl": "pet-dl-quant",
    "deepprep": "fmri-deepprep",
    "brainqcnet": "qc-brainqcnet",
    "qc": "qc-brainqcnet",
}

def profile_is_deep_learning(name: str, meta: dict[str, Any] | None = None) -> bool:
    """True unless profile is classical or explicitly marked false."""
    if meta is not None and "is_deep_learning" in meta:
        return bool(meta["is_deep_learning"])
    return name not in CLASSICAL_PROFILES


def resolve_tool(name: str) -> str:
    """Map FS-style tool name or profile id → profile id."""
    key = name.strip().lower().replace("_", "-")
    if key in TOOL_ALIASES:
        return TOOL_ALIASES[key]
    return name


def tool_tier(alias: str) -> Tier:
    return tier_for_profile(resolve_tool(alias))


def tools_table(*, min_tier: Tier | None = None) -> list[tuple[str, str, Tier]]:
    """Sorted (alias, profile, tier) for ``dlsurfer tools``."""
    order = {"A": 0, "B": 1, "C": 2, "D": 3}
    rows: list[tuple[str, str, Tier]] = []
    for alias, prof in TOOL_ALIASES.items():
        t = tier_for_profile(prof)
        if min_tier is not None and order[t] > order[min_tier]:
            continue
        if t == "D":
            continue  # never list classical as a public tool alias
        rows.append((alias, prof, t))
    rows.sort(key=lambda r: (order[r[2]], r[0]))
    return rows


def assert_tiers_cover_profiles(profile_names: set[str]) -> list[str]:
    """Return profile names missing an explicit tier (for tests)."""
    missing = []
    for name in sorted(profile_names):
        if name not in PROFILE_TIER and name not in CLASSICAL_PROFILES:
            # experimental DL specialty may rely on default C
            continue
        if name in CLASSICAL_PROFILES and PROFILE_TIER.get(name) != "D":
            missing.append(f"{name} should be D")
    return missing
