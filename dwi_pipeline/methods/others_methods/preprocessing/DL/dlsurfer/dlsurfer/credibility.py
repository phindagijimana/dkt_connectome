"""Credibility tiers for DLSurfer (deep-learning FreeSurfer-suite methods).

Identity: deep-learning alternatives across FreeSurfer's suite — T1 morphometry
**and** multimodal specialty (DWI bundles, PET quant, fMRI preprocess, QC).
Not TBI-only. Specialty allowed at A/B/C.

Credibility = peer-reviewed evidence + public/reproducible tooling + FS-shaped
or modality-appropriate contract + lab readiness.

Scale:
  A — production-trust defaults (core + production utils + first-class specialty)
  B — Ready literature specialty (papers + code/weights; ops may still be open)
  C — research / experimental specialty (allowed; eyes open; not default)
  D — classical non-DL (hidden; --allow-classical only)
"""

from __future__ import annotations

from typing import Any, Literal

Tier = Literal["A", "B", "C", "D"]

TIER_HELP = {
    "A": "production-trust — defaults and first-class specialty",
    "B": "Ready literature specialty — preferred when tooling is present",
    "C": "research/experimental specialty — allowed, not default",
    "D": "classical non-DL — gated behind --allow-classical",
}

# Profile id → tier. Anything omitted defaults to C if DL else D if classical.
PROFILE_TIER: dict[str, Tier] = {
    # A — core morphometry + production utils + first-class specialty
    "core": "A",
    "core-lesion": "A",
    "core-lesion-native": "A",  # alias of core-lesion (DL separable LIT only)
    "core-dk": "A",
    "core-recon-surf": "D",  # classical FastSurfer recon-surf fallback
    "seg-quick": "A",
    "seg-quick-synthseg": "A",
    "seg-synthseg-robust": "A",
    "strip": "A",
    "register-easyreg": "A",
    "register-synthmorph": "A",
    "bias-deepn4": "A",
    "preprocess-synthsr": "A",
    "structure-sclimbic": "A",
    "structure-claustrum": "A",
    "structure-hypvinn-t2": "A",
    "clinical-claustrum": "A",
    "surf-dl-topofit": "A",
    "surf-dl-topofit-only": "A",
    "thickness-fast": "A",  # biomarker-only handoff rule still applies
    # B — Ready specialty (literature-strong; deps/gates may be open)
    "seg-super-synth": "B",
    "atlas-easyatlas": "B",
    "structure-histo-atlas": "B",
    "fs8-dl-modules": "B",
    "structure-hippunfold": "B",
    "structure-hippodeep": "B",
    "structure-brainstem-mars": "B",
    "structure-ventricles-mars": "B",
    "seg-wmh-mars": "B",
    "seg-wmh-synthseg": "B",
    "nuclei-thalamic-dti-cnn": "B",
    "infant-ibeat": "B",
    "fs-clinical": "B",
    "surf-dl-v2c": "B",
    "core-dl-surf": "B",
    "surf-dl-v2c-long": "B",
    "sphere-sugar": "B",
    "sphere-s3reg": "B",
    "strip-hdbet": "B",
    "atlas-destrieux-dl": "B",
    "atlas-schaefer-dl": "B",
    # B — multimodal FS-suite DL (DWI / PET / fMRI / QC)
    "dwi-tractseg": "B",
    "pet-dl-quant": "B",
    "fmri-deepprep": "B",
    "qc-brainqcnet": "B",
    # C — experimental specialty (allowed)
    "dwi-deepwma": "C",
    "lesion-vbg": "C",
    "structure-piriform-synthseg": "C",
    "structure-piriform-nnunet": "C",
    "nuclei-thalamic-deep-thomas": "C",
    "structure-claustrum-albishri": "C",
    "structure-amygdala-go": "C",
    "infant-dhcp": "C",
    "surf-dl-cortexode": "C",
    "surf-dl-pialnn": "C",
    "surf-dl-corticalflow": "C",
    "surf-dl-surfnn": "C",
    "surf-dl-deepcsr": "C",
    "surf-dl-fastcsr": "C",
    "thickness-dl-direct": "C",
    # D — classical
    "fs8": "D",
    "fs8-lesion": "D",
    "fs-long": "D",
    "subfields-ha": "D",
    "nuclei-bs-thal": "D",
    "atlas-destrieux": "D",
    "atlas-schaefer": "D",
    "lesion-enantiomorphic": "D",
}


def tier_for_profile(name: str, meta: dict[str, Any] | None = None) -> Tier:
    if meta and meta.get("credibility") in {"A", "B", "C", "D"}:
        return meta["credibility"]  # type: ignore[return-value]
    if name in PROFILE_TIER:
        return PROFILE_TIER[name]
    if meta and meta.get("is_deep_learning") is False:
        return "D"
    if meta and meta.get("experimental"):
        return "C"
    return "C"


def format_tier_banner() -> str:
    lines = [
        "DLSurfer credibility (deep-learning FreeSurfer-suite methods; specialty allowed)",
        "  Morphometry (T1) + multimodal: TractSeg · PET-DL · DeepPrep · BrainQCNet",
        "  A = production-trust defaults + first-class specialty",
        "  B = Ready literature specialty (ops/deps may still be open)",
        "  C = research/experimental specialty (allowed; not default)",
        "  D = classical non-DL (hidden; --allow-classical)",
        "",
    ]
    return "\n".join(lines)
