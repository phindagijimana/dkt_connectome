---
title: DL tools catalog — start inside FreeSurfer & FastSurfer
subtitle: Curate validated engines first; add external papers later
date: 23 October 2026
status: phase-1 draft
---

# DL tools catalog

**Strategy.** Phase 1 = deep-learning pieces **already shipped** in FreeSurfer and FastSurfer (validated, maintained, citeable). Phase 2 = add **external** tools only from validated papers, one at a time, behind the same FreeSurfer-shaped output contract.

We **orchestrate / expose** these; we do not reimplement them.

Related: [`README.md`](README.md) (wrapper positioning) · [`LITERATURE_MAP.md`](LITERATURE_MAP.md)

---

## Phase 1A — FastSurfer (Deep-MI)

| ID | Module | Role (≈ FreeSurfer) | Entry | Device | Cite |
|----|--------|---------------------|-------|--------|------|
| `fs.asegdkt` | FastSurferVINN | aseg + DKT-style whole-brain / cortex labels | `run_fastsurfer.sh` (default) | `--device auto\|cuda\|cpu` | Henschel 2020; Henschel 2022 VINN |
| `fs.cc` | FastSurfer-CC | corpus callosum morphometry | on by default; `--no_cc` | same | Pollak 2026 CC |
| `fs.cereb` | CerebNet | cerebellum sub-segmentation | on by default; `--no_cereb` | same | Faber 2022 |
| `fs.hypothal` | HypVINN | hypothalamus + adjacent | on by default; `--no_hypothal`; optional `--t2` | same | Estrada 2023 |
| `fs.recon_surf` | recon-surf | surfaces, thickness, FS-compatible tree | same run or `--surf_only` | mostly CPU (+ FS binaries) | Henschel 2020 |
| `fs.lit` | FastSurfer-LIT | lesion inpaint + remap into outputs | `--lesion_mask` (FS ≥ 2.6) | GPU preferred | Pollak 2025 LIT |

**Notes**

- Full default FastSurfer run ≈ major cross-sectional morphometry path.
- `--lesion_mask` is **not** compatible with `--seg_only` / `--surf_only` → for HPC GPU/CPU split, prefer **standalone neuroLIT fill** then ordinary FastSurfer (see lab EG share).
- Containers: `deepmi/fastsurfer` (CUDA / CPU); cluster helper: `srun_fastsurfer.sh`.

**Standalone LIT (same authors, outside one-shot native flag)**

| ID | Tool | Role | Entry | Device | Cite |
|----|------|------|-------|--------|------|
| `lit.inpaint` | neuroLIT | fill T1 outside recon | `lit-inpainting` | `--device auto\|cuda\|cpu` | Pollak 2025 |
| `lit.post` | neuroLIT post | package `*.lit*` / reports into FS tree | `lit-postprocessing` | CPU | Pollak 2025 |

---

## Phase 1B — FreeSurfer (MGH) DL utilities

These are **in-tree** FreeSurfer CLIs (esp. 7.3+ / 8.0). FS 8 recon-all itself uses several by default.

| ID | Tool | Role | Entry | Device | Notes |
|----|------|------|-------|--------|------|
| `fsurfer.synthseg` | SynthSeg | contrast/resolution-robust whole-brain seg (± parc) | `mri_synthseg` | GPU or `--cpu` | Also used inside FS 8 recon-all |
| `fsurfer.synthstrip` | SynthStrip | skull-strip / brain mask (any contrast) | `mri_synthstrip` | CPU fine | FS ≥ 7.3; used in FS 8 recon-all |
| `fsurfer.synthmorph` | SynthMorph | DL affine / deformable registration | `mri_synthmorph` | — | Multimodal → MNI; FS 8 related |
| `fsurfer.easyreg` | EasyReg | evolved SynthMorph-style registration | `mri_easyreg` | — | FS 7.4+ |
| `fsurfer.synthsr` | SynthSR | super-resolution / synthesis | `mri_synthsr` | — | Used in `recon-all-clinical` |
| `fsurfer.sclimbic` | ScLimbic | subcortical-limbic / hypothalamic subunits | `mri_sclimbic_seg` | — | Overlaps HypVINN niche — pick one policy later |
| `fsurfer.subregions` | segment_subregions | thalamus / hippo-amygdala / brainstem (DL; beta→stable path) | FS subregion scripts | — | Prefer over inventing HA |
| `fsurfer.recon_clinical` | recon-all-clinical | clinical / odd contrast & resolution stream | `recon-all-clinical` | — | Bundles SynthSeg / SynthSR family |
| `fsurfer.recon_all_v8` | recon-all (FS 8) | classical surfaces + **embedded** Synth* DL | `recon-all` | CPU OK (~24 GB RAM); GPU not required | ~2 h vs ~8 h; outputs differ from FS 7 |

**Policy for Phase 1B**

- Prefer **one primary morphometry engine per subject**: FastSurfer **or** FreeSurfer recon-all — not both mixed mid-tree.
- Use SynthStrip / SynthSeg as **utilities** when the chosen engine needs them, or for QC / clinical oddball inputs.
- Hypothalamus: default to **HypVINN** if FastSurfer path; ScLimbic only if FreeSurfer-only path (document XOR).

---

## Suggested Phase-1 product surface

Minimal curated entry points (names illustrative):

```
core          → FastSurfer full (asegdkt + cc + cereb + hypothal + recon-surf)
core-lesion   → lit.inpaint → core   OR   native fs.lit (FS≥2.6, no seg/surf split)
fs8           → FreeSurfer 8 recon-all (Synth* inside)
strip         → mri_synthstrip
seg-quick     → mri_synthseg [--parc]   or   FastSurfer --seg_only
```

Same **SUBJECTS_DIR**-shaped contract wherever surfaces are produced.

---

## Phase 2 — external validated papers

Admission rule: peer-reviewed (or strong preprint + plan), public code/weights, FS-compatible or clear convert step, **does not duplicate** a Phase-1 tool without a measured gain (speed, lesion, modality, or TBI failure mode).

Full literature map for classical-stage replacements: [`DL_ALTERNATIVES.md`](DL_ALTERNATIVES.md).

### 2A — Lesion fill (non-FastSurfer)

| ID | Candidate | Task | Status | Why consider later |
|----|-----------|------|--------|-------------------|
| `ext.vbg` | KUL VBG | lesion fill → FS/FastSurfer | **candidate** | Large lesions; TBI evidence mixed (Deutscher 2025) |
| `ext.leapp_vbt` | LeAPP VBT | lesion-aware HCP-style | **candidate** | Stroke stack; TBI orientation crash known in-lab |
| `ext.enantiomorphic` | SPM Clinical Toolbox | unilateral mirror fill | **candidate** | Unilateral glioma/stroke only |

### 2B — Classical surface / thickness / sphere.reg (DL alternatives)

| ID | Candidate | Task | Status | Admit order |
|----|-----------|------|--------|-------------|
| `ext.topofit` | TopoFit (`mris_estimate_wm`) | WM surface (topology-correct) | **priority** | P2.1 — already in FreeSurfer |
| `ext.v2c_flow` | V2C-Flow / Vox2Cortex | WM+pial + template correspondence | **priority** | P2.2 — public pretrained |
| `ext.cortexode` | CortexODE | WM+pial Neural ODE | **candidate** | P2.3 |
| `ext.pialnn` | PialNN | WM→pial only | **candidate** | P2.3 if TopoFit WM kept |
| `ext.sugar` | SUGAR | spherical surface registration | **watch** | P2.4 if fsaverage without classical reg |
| `ext.dl_cte` | DL-CTE / CortexMorph | fast volumetric thickness | **watch** | P2.5 — not for connectome handoff |
| `ext.hippunfold` | HippUnfold | hippocampal unfolding / subfields | **watch** | Only if HA gap remains after FS subregions |

Do **not** wire Phase-2 until Phase-1 entry points and device policy are stable — except optional TopoFit pilot (already FS-native).

---

## Build order

1. **Freeze Phase-1 inventory** (this file) — done as draft.  
2. **Wire `core` + `core-lesion`** on lab container / Apptainer (reuse FastSurfer + neuroLIT).  
3. **Expose `strip` / `seg-quick`** as utilities.  
4. **Optional `fs8`** path for FreeSurfer-primary sites.  
5. **Admit Phase-2** only with a short validation note (Dice / fail rate / wall-time on lab data).

---

## Explicit non-goals (still)

- Replacing FreeSurfer or FastSurfer science credit  
- Claiming full FreeSurfer task coverage  
- Reimplementing recon-surf in DL  
- Mixing FastSurfer and FreeSurfer mid-subject without a documented convert
