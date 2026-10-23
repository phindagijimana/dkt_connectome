---
title: Credible DL alternatives to classical FreeSurfer / FastSurfer stages
subtitle: Literature map for non-DL bottlenecks (esp. surfaces)
date: 23 October 2026
status: research draft
related:
  - CATALOG.md
  - CLASSICAL_TO_DL_TABLE.md
  - LITERATURE_MAP.md
  - README.md
---

# DL alternatives to classical stages

**Scope.** FreeSurfer / FastSurfer still run **classical** geometry for most surface work (`recon-surf` / recon-all surface stages). This note maps **peer-reviewed, preferably open** deep-learning alternatives by task — for Phase-2 admission into [`CATALOG.md`](CATALOG.md), not immediate replacement of FastSurfer.

**Credibility bar used here**

1. Peer-reviewed (or strong preprint + public code)  
2. Public weights / runnable code preferred  
3. Clear target of a classical FS/FastSurfer stage  
4. Independent or multi-dataset evaluation when available  
5. Honest gap vs full FreeSurfer-compatible morphometry (thickness ROI, `aparc`, fsaverage, edits)

---

## 1. What still needs an alternative (reminder)

| Classical stage | Where it lives | Why people want DL |
|-----------------|----------------|--------------------|
| White / pial mesh, topology, inflate | FastSurfer `recon-surf`; FS recon-all | 20–60+ min CPU; lesion/intensity failures |
| Spherical map + `sphere.reg` | same | Extra tens of minutes; group analysis gate |
| Cortical thickness (surface-based) | same | Tied to mesh quality |
| Volumetric atlas registration (older FS) | FS ≤7 style | Largely already replaced by Synth* / EasyReg in FS 8 |
| Skull-strip / aseg (older) | FS ≤7 | Already DL in FastSurfer / FS 8 |

**Already covered in Phase 1 (do not re-hunt):** FastSurferVINN, CerebNet, HypVINN, LIT, SynthSeg, SynthStrip, SynthMorph, EasyReg, SynthSR.

---

## 2. Cortical surface reconstruction (highest priority)

### Tier A — most credible to evaluate first

| Method | Replaces | Claim | Code / shipping | Caveats for TBI / lab |
|--------|----------|-------|-----------------|------------------------|
| **TopoFit** (Hoopes et al., MIDL 2022) | WM surface fit / topology-heavy white placement | Topologically correct WM; ~1 s GPU / ~17 s CPU; in **FreeSurfer** as `mris_estimate_wm` | [github.com/ahoopes/topofit](https://github.com/ahoopes/topofit); FS package | White only; still need pial + thickness + parc pipeline |
| **V2C-Flow** (Bongratz et al., 2024; extends Vox2Cortex CVPR 2022) | WM + pial (4 surfaces); optional **fsaverage correspondence** | <2 s; joint WM/pial; template vertex IDs → skip inflate/sphere.reg for some analyses | [github.com/ai-med/Vox2Cortex](https://github.com/ai-med/Vox2Cortex) | Coord convention (scanner RAS); not a drop-in SUBJECTS_DIR; TBI/lesion not primary eval |
| **CortexODE** (Ma et al., TMI 2022) | WM + pial via Neural ODE flows | <5 s pipeline; <0.2 mm mean geometric error vs classical on multi-age sets | Public (paper + code ecosystem) | Needs initial seg + topology correction step |
| **recon-all-clinical** + SynthDist (Iglesias / FS) | Clinical / odd contrast surfaces | Any contrast/resolution path inside FreeSurfer | FreeSurfer wiki `recon-all-clinical` | Still uses classical FS geometry after DL distance maps; not “pure DL mesh” |

### Tier B — strong papers; more assembly required

| Method | Role | Notes |
|--------|------|-------|
| **Vox2Cortex** (Bongratz et al., CVPR 2022) | Explicit WM+pial GNN deformation | Predecessor of V2C-Flow; public code |
| **PialNN** (Ma et al., 2021) | WM → pial only | Needs a good WM mesh first (pairs with TopoFit conceptually) |
| **CorticalFlow** (Lebrat et al., 2022) | Diffeomorphic template → cortex | Topology-preserving flows; ~1 s |
| **SurfNN** (Zheng et al., ISBI 2023) | Joint midthickness → WM+pial | ADNI eval; competitive with CortexODE |
| **SurfNet** (coupled diffeomorphic) | Joint CSR | Newer; check code maturity before wiring |
| **DeepCSR** (Santa Cruz et al., WACV 2021) | Implicit SDF → mesh | Needs topology correction; slower than explicit SOTA |

### Independent benchmarking signal

- Mello et al. 2025/2026 (*Sci Rep* / medRxiv): DL **seg** (DeepSCAN / FastSurferCNN / QuickNAT) + **short classical surface** (~11 min) — DeepSCAN+surfaces most robust vs FreeSurfer / synthetic GT.  
  **Implication:** hybrid (DL vol + classical surf) remains a credible default; pure DL mesh is not yet the consensus clinical morphometry stack.

---

## 3. Thickness without (or with less) classical mesh

| Method | Idea | Credibility | Gap |
|--------|------|-------------|-----|
| **DL+DiReCT** (Rebsamen et al., 2020) | DL anatomy seg → DiReCT thickness | Good correlation with FreeSurfer; faster | Volumetric thickness ≠ full surface morphometry |
| **CortexMorph** (2023) | VoxelMorph speeds DiReCT registration | Seconds-scale thickness | Same DiReCT family limits |
| **DL-CTE** (Wu et al., 2025; github.com/wujiong-hub/DL-CTE) | CNN seg + unsupervised diffeomorphic reg → thickness | Public code; claims better FS consistency than DiReCT | Still not `aparc` surface stats |
| Direct CNN thickness/curvature maps | End-to-end voxel → maps | Exploratory | Weak FS replacement for ROI surface workflows |

**Use if:** you need fast thickness biomarkers and can drop FreeSurfer surface products.  
**Do not use if:** QSIRecon / connectome / `aparc` surface labels are required.

---

## 4. Spherical / surface registration

| Method | Replaces | Code | Notes |
|--------|----------|------|-------|
| **SUGAR** (Ren et al., 2023) | Classical `sphere.reg`-class alignment | [github.com/pBFSLab/SUGAR](https://github.com/pBFSLab/SUGAR) | Sub-second; large multi-dataset eval; still expects FS-preprocessed surfaces |
| **S3Reg** (Zhao et al., TMI 2021) | Spherical deformable reg | [github.com/BRAIN-Lab-UNC/S3Reg](https://github.com/BRAIN-Lab-UNC/S3Reg) | ~10 s; multimodal features |
| **V2C-Flow template IDs** | Often **avoids** separate spherical reg | Vox2Cortex repo | Correspondence baked into reconstruction |
| Emerging uncertainty-aware CSR+sphere (2026 arXiv) | Surfaces + fsaverage + clinical contrast | Watch | Synth-trained; promising for clinical TBI-like inputs |

Volumetric registration alternatives (**SynthMorph**, **EasyReg**) are already Phase 1B — not repeated here.

---

## 5. What is *not* a credible “replace recon-surf” shortcut

| Idea | Why not (yet) |
|------|----------------|
| Marching cubes on FastSurferVINN alone | Staircasing, topology defects, no FS thickness pipeline |
| Claiming any CVPR CSR paper = FreeSurfer replacement | Missing edits, longitudinal, stats contract, lesion robustness |
| Training a lab-specific surface net without FS silver standard | Validation cost dominates |
| Skipping surfaces entirely for DKT connectomes | Your stack’s surface/5TT path may still need meshes |

---

## 6. Recommended admission order (Phase 2)

| Priority | Candidate | Why first | Validation plan (lab) |
|----------|-----------|-----------|------------------------|
| **P2.1** | **TopoFit** (`mris_estimate_wm`) | Already in FreeSurfer; lowest integration risk | White surface vs FastSurfer `recon-surf` on EG + TBI subset (ASSD / HD) |
| **P2.2** | **V2C-Flow** | Full WM+pial + template correspondence; public pretrained | Runtime + thickness vs FastSurfer; lesion subjects with/without LIT |
| **P2.3** | **CortexODE** or **PialNN** (if TopoFit WM kept) | Modular WM→pial | Same metrics; topology / intersection rate |
| **P2.4** | **SUGAR** or V2C correspondence | Only if group `fsaverage` analyses needed without classical sphere.reg | Parcel overlap vs FS `sphere.reg` |
| **P2.5** | **DL-CTE / CortexMorph** | Optional fast thickness arm | Correlation with FS thickness; not for connectome handoff |
| **Defer** | DeepCSR, SurfNet-until-code-stable, custom nets | Higher ops cost / weaker shipping | — |

**TBI gate for any surface DL:** run on lesioned T1 **with** and **without** neuroLIT fill; reject methods that fail visibly at cavity / contusion boundaries without a documented mitigation.

---

## 7. Strategic conclusion

| Question | Answer |
|----------|--------|
| Do credible DL alternatives to classical surfaces exist? | **Yes** — TopoFit, V2C-Flow, CortexODE, PialNN/CorticalFlow/SurfNN family. |
| Can they fully replace FastSurfer `recon-surf` for your DKT/DWI stack today? | **Not as a drop-in.** Closest shipping path: TopoFit (FS) or V2C-Flow (research) + careful output adaptation. |
| Best near-term research bet? | Keep Phase-1 FastSurfer/FS8; **pilot P2.1–P2.2** as optional `surf-dl` backend; measure wall-time, failure rate, thickness/parcel agreement on TRACK-TBI / EG. |
| Best ops bet without new science risk? | Stay on FastSurfer `recon-surf` + GPU/CPU split; use DL alts only where they remove a hop you measure. |

---

## 8. Key citations

1. Hoopes A et al. TopoFit. MIDL 2022. (FS: `mris_estimate_wm`)  
2. Bongratz F et al. Vox2Cortex. CVPR 2022; V2C-Flow arXiv:2401.12938 (2024).  
3. Ma Q et al. CortexODE. IEEE TMI 2022.  
4. Ma Q et al. PialNN. 2021.  
5. Lebrat L et al. CorticalFlow. 2022.  
6. Zheng H et al. SurfNN. ISBI 2023.  
7. Santa Cruz R et al. DeepCSR. WACV 2021.  
8. Rebsamen M et al. DL+DiReCT. Hum Brain Mapp 2020.  
9. Ren J et al. SUGAR. arXiv:2307.00511 (2023).  
10. Zhao F et al. S3Reg. IEEE TMI 2021.  
11. Mello VBB et al. Fast surface reconstruction benchmarking. Sci Rep 2026 (medRxiv 2025).  
12. FreeSurfer: SynthMorph, EasyReg, recon-all-clinical, TopoFit integration notes.
