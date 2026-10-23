---
title: DLSurfer — product plan
subtitle: Curated deep-learning morphometry orchestrator (FreeSurfer-shaped, not a science replacement)
date: 23 October 2026
status: plan v0.1 — implementation scaffold in ./dlsurfer/ (Phases 0–4)
codename: dlsurfer
implementation: methods/others_methods/preprocessing/DL/dlsurfer/
---

# DLSurfer plan

**One-line pitch**

> **DLSurfer** is a single-entry, device-flexible orchestrator that runs **validated** deep-learning tools from FreeSurfer and FastSurfer (later: selected external papers), keeps a **FreeSurfer-compatible subject directory**, and adds first-class **lesion** + **HPC device policy** — without claiming to replace FreeSurfer or FastSurfer science.

**Name.** `dlsurfer` (CLI) / DLSurfer (product).  
**Home (notes).** `methods/others_methods/preprocessing/DL/`  
**Related.** [`README.md`](README.md) · [`CATALOG.md`](CATALOG.md) · [`CLASSICAL_TO_DL_TABLE.md`](CLASSICAL_TO_DL_TABLE.md) · [`DL_ALTERNATIVES.md`](DL_ALTERNATIVES.md) · [`LITERATURE_MAP.md`](LITERATURE_MAP.md)

---

## 1. Claim boundary (non-negotiable)

| We claim | We do **not** claim |
|----------|---------------------|
| One subject command + one container story | Better anatomy than FastSurfer / FreeSurfer |
| FreeSurfer-shaped outputs for DWI / QSIRecon | Full FreeSurfer suite coverage |
| Device policy (GPU seg → CPU surf; auto fallback) | Reimplemented recon-surf / VINN / Synth* |
| Lesion path (standalone LIT ± post-hoc; optional native) | “AI FreeSurfer replacement” |
| Measured wall-time / queue / failure vs split jobs | Bit-identical to `recon-all` |

Science credit stays with Deep-MI, MGH FreeSurfer, and any Phase-2 paper authors. DLSurfer = **orchestration + packaging + lab ops**.

---

## 2. Problem statement

Today a lesion subject often needs:

1. GPU — VINN / neuroLIT  
2. CPU — recon-surf / FreeSurfer bits  
3. Maybe GPU — DWI DL  

Plus: native `--lesion_mask` **blocks** FastSurfer’s recommended GPU/CPU SLURM split (`--seg_only` / `--surf_only` incompatible with LIT).

DLSurfer’s job is to make the **major morphometry path** one curated entry with honest backends — starting inside FS/FastSurfer DL, then optional classical-stage DL alts from the alternatives table.

---

## 3. Architecture (logical)

```
                    ┌─────────────────────────────────────┐
                    │            dlsurfer CLI              │
                    │  profiles · device · lesion · sd/sid │
                    └─────────────────┬───────────────────┘
                                      │
              ┌───────────────────────┼───────────────────────┐
              ▼                       ▼                       ▼
        [fill / strip]          [morphometry engine]     [optional post]
         lit.inpaint              FastSurfer core          lit.post
         synthstrip               FreeSurfer 8             (Phase2: TopoFit/
         (optional)               (xor per subject)         V2C-Flow surf-dl)
                                      │
                                      ▼
                         SUBJECTS_DIR / sub-<id>/   ← FS contract
                                      │
                                      ▼
                              handoff → DKT / QSIPrep / QSIRecon
```

**Principles**

1. **Engines behind adapters** — never fork FastSurfer/FS source; call published CLIs/containers.  
2. **One engine per subject** — `fastsurfer` **xor** `freesurfer8` (document convert if ever needed).  
3. **Lesion default = standalone fill → ordinary recon** (preserves GPU/CPU split); native LIT = opt-in profile.  
4. **Outputs contract frozen early** — same tree layout DKT already expects.  
5. **Profiles over flags soup** — `core`, `core-lesion`, `seg-quick`, `fs8`, later `surf-dl`.

---

## 4. Product surface (CLI sketch)

```bash
dlsurfer run \
  --t1 /path/T1.nii.gz \
  --sid sub-EG \
  --sd /out/subjects \
  --profile core-lesion \
  --lesion-mask /path/lesion.nii.gz \
  --device auto \
  --fs-license /path/license.txt
```

### Profiles (v1)

| Profile | What runs | Backend |
|---------|-----------|---------|
| `core` | asegdkt + cc + cereb + hypothal + recon-surf | FastSurfer |
| `core-lesion` | lit.inpaint → `core` → optional lit.post | FastSurfer + neuroLIT |
| `core-lesion-native` | FastSurfer `--lesion_mask` (no seg/surf split) | FastSurfer ≥2.6 |
| `seg-quick` | VINN or SynthSeg only | FastSurfer `--seg_only` or `mri_synthseg` |
| `strip` | SynthStrip | FreeSurfer |
| `fs8` | FreeSurfer 8 `recon-all` | FreeSurfer |

### Profiles (v2+)

| Profile | What runs | Gate |
|---------|-----------|------|
| `surf-dl` | Phase-1 seg + TopoFit / V2C-Flow surfaces | Lab validation (EG + TBI ± LIT) |
| `thickness-fast` | DL-CTE / CortexMorph arm | Biomarker only — not connectome |

---

## 5. Phased roadmap

### Phase 0 — Spec freeze (1–2 weeks)

- [ ] Freeze claim boundary + outputs contract (this doc §1, §7)  
- [ ] Pin versions: FastSurfer (e.g. 2.6.x), FreeSurfer (8.x), neuroLIT  
- [ ] Decide container strategy: wrap `deepmi/fastsurfer` + FS license bind **vs** meta-Apptainer  
- [ ] Map DKT flags → DLSurfer profiles (`--anat-mitigation`, `--post-hoc-fs`, `--fastsurfer-lesion-mask`)  
- [ ] Repo layout proposal (see §8)

**Exit.** Written ADR: “orchestrator not fork.”

### Phase 1 — MVP `dlsurfer` (operator value)

**Ship**

- [ ] CLI: `run`, `profiles`, `doctor` (check license, GPU, containers)  
- [ ] Profiles: `core`, `core-lesion`, `seg-quick`, `strip`  
- [ ] Device policy: `auto | cuda | cpu`; GPU job for fill+seg, CPU job for recon-surf (Snakemake/SLURM or FastSurfer `srun`-style)  
- [ ] Apptainer exec wrappers; pinned tags  
- [ ] Smoke test on Gugger EG share inputs  
- [ ] Docs: cite engines; “not a replacement”

**Non-goals for MVP:** V2C-Flow, TopoFit wiring, DWI inside DLSurfer, web UI.

**Exit metrics (must measure)**

| Metric | Compare to |
|--------|------------|
| Wall-time / subject | Manual multi-job bounce |
| Queue time (TtS) | Same |
| Failure rate (env/PATH/OOM) | Same |
| Output presence | `mri/aparc.DKTatlas+aseg.mgz`, `surf/?h.white`, stats |

### Phase 2 — FreeSurfer engine + DKT handoff

- [ ] Profile `fs8`  
- [ ] Explicit handoff recipe/docs into existing DKT pipeline (or thin `dlsurfer → SUBJECTS_DIR` already enough)  
- [ ] `core-lesion-native` documented as XOR with split scheduling  
- [ ] QC hooks: reuse / call `check_inpainting`-style checks when lesion used  

**Exit.** One TRACK-TBI or EG subject through DLSurfer → existing connectome step without tree surgery.

### Phase 3 — Optional `surf-dl` backends

Admit from [`CLASSICAL_TO_DL_TABLE.md`](CLASSICAL_TO_DL_TABLE.md) only after TBI±LIT gate:

1. **TopoFit** (`mris_estimate_wm`) — lowest risk  
2. **V2C-Flow** — full WM+pial + template IDs  
3. **SUGAR** — only if `sphere.reg` is the measured bottleneck  

**Exit.** Side-by-side report: geometric error / thickness / parcel overlap vs `recon-surf`; runtime; lesion failure modes.

### Phase 4 — Harden & publish (optional paper)

- [ ] Cohort-scale timing + failure dashboard  
- [ ] Infrastructure / reproducible-workflow write-up (not methods-anatomy paper)  
- [ ] Public or lab-internal release + citation boilerplate for all engines  

---

## 6. Device & HPC policy

| Stage | Default partition | Notes |
|-------|-------------------|-------|
| lit.inpaint / VINN / SynthSeg | GPU | `--device auto` fallback CPU |
| recon-surf / FS surfaces | CPU | Never hold a GPU idle for surfaces |
| lit.post | CPU | Fast |
| Native `--lesion_mask` | Single job (GPU-capable node) | **Cannot** use seg/surf split — warn in CLI |

Implement as: local serial · SLURM two-step · or call `srun_fastsurfer.sh` after standalone fill.

---

## 7. Outputs contract (freeze early)

Minimum tree DLSurfer guarantees for `core` / `core-lesion`:

```
$SD/$SID/
  mri/   # orig, aseg/DKT products, mask, …
  surf/  # ?h.white, ?h.pial, thickness, sphere.reg (if profile includes surf)
  label/ stats/ scripts/
```

Lesion profiles additionally expect neurolit products when `--post-lit` / lit.post enabled (`mask.lit*`, lesion reports) — align with EG `posthoc/` expectations.

Downstream must not require DLSurfer-specific paths.

---

## 8. Proposed repo layout (when implementing)

```
dlsurfer/
  README.md
  pyproject.toml          # or packaging of choice
  dlsurfer/
    cli.py
    profiles.yaml
    adapters/
      fastsurfer.py
      neurolit.py
      freesurfer.py
      synthstrip.py
    device.py
    hpc/                  # slurm templates
    contract.py           # output checks
  containers/             # def files or pin list
  tests/
    test_profiles_dryrun.py
    test_contract_eg.py
  docs/
    claims.md
    citations.md
```

Notes stay in `methods/others_methods/preprocessing/DL/` until code repo exists; then link both ways.

---

## 9. Mapping to current DKT flags

| DKT today | DLSurfer profile / flag |
|-----------|-------------------------|
| `--fastsurfer` + no lesion | `core` |
| `--anat-mitigation neurolit` | fill step of `core-lesion` |
| `--post-hoc-fs` | `--post-lit` / lit.post |
| `--fastsurfer-lesion-mask` | `core-lesion-native` |
| `--anat-mitigation vbt` | Phase 2+ fill backend (not MVP) |
| `--freesurfer` | `fs8` |

Long-term: DKT can call `dlsurfer` as Step 1.1+2 instead of bespoke scripting — **optional**; DLSurfer should stand alone first.

---

## 10. Risks & mitigations

| Risk | Mitigation |
|------|------------|
| Scope creep (“cover all FreeSurfer”) | Profiles + catalog admission bar |
| Native LIT vs HPC split confusion | CLI fail-fast + docs (already known) |
| Version drift of FastSurfer/FS | Pin tags; `dlsurfer doctor` |
| TBI surface DL fails on lesions | TBI±LIT gate before `surf-dl` |
| “Replacement” messaging | Fixed boilerplate in `--help` and README |
| Duplicate DKT logic | Thin adapters; DKT remains source of connectome truth |

---

## 11. Success criteria

**MVP success.** Lab member runs EG T1+mask with one command; gets FS-shaped tree; GPU/CPU scheduling works without module roulette; docs cite FastSurfer/LIT.

**Product success.** TRACK-TBI subset shows ↓ failure rate and ↓ TtS vs current split; DKT handoff unchanged; no anatomy-superiority claims.

**Paper success (optional).** Infrastructure metrics paper; methods credit to engine authors.

---

## 12. Immediate next actions

1. Approve claim boundary + MVP profile list (§1, §4).  
2. Choose container strategy (wrap upstream vs meta-image).  
3. Scaffold `dlsurfer` repo / package under lab path (when ready to code).  
4. Implement `doctor` + `core` dry-run against EG.  
5. Add `core-lesion` using existing neuroLIT + FastSurfer paths from Gugger EG demo.

---

## 13. Open decisions (resolve in Phase 0)

| Decision | Options | Recommendation |
|----------|---------|----------------|
| Language | Python CLI vs Bash+YAML | **Python** CLI + YAML profiles |
| HPC | Shell out to `srun_fastsurfer` vs native SLURM templates | Start with **srun_fastsurfer after fill**; native templates later |
| Default engine | FastSurfer vs FS8 | **FastSurfer** (`core`); FS8 as explicit profile |
| VBT in MVP | yes / no | **No** — neurolit only until VBT TBI orientation story is productized |
| Relation to DKT | sibling tool vs merge | **Sibling** first; optional DKT adapter later |
