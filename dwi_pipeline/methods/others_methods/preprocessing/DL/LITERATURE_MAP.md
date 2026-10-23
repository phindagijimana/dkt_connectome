---
title: DL preprocessing literature map
subtitle: Is GPU↔CPU / lesion-orchestration a real limitation, and what to reuse
date: 23 October 2026
related: README.md
canvas: canvases/dl-preprocess-literature-map.canvas.tsx
---

# Literature map — DL lesion preprocessing convenience

**Question.** Is the pain in `README.md` (GPU fill → CPU recon → maybe GPU DWI; modules/containers/PATH) a **real limitation**, and are there **credible resources** to wrap rather than reinvent?

**Verdict (short).**

| Claim type | Verdict |
|------------|---------|
| **Ops / HPC hop** | **Yes — real and acknowledged upstream.** FastSurfer ships GPU/CPU partition split (`srun_fastsurfer.sh`). Lesion native path **blocks** that split. |
| **Anatomy / fill science** | **Partially.** Large tumor/cavity → LIT is SOTA. Heterogeneous **ms-TBI** fill is unsettled; VBG can **hurt** FastSurfer vs unfilled. |
| **“Replace FastSurfer”** | **No.** Do not pursue. Orchestration + FreeSurfer-shaped handoff only. |

---

## 1. Two limitation layers (keep separate)

### A. Operator / device orchestration (your README pain)

Typical lesion subject:

1. **GPU** — FastSurferVINN / neuroLIT inpaint  
2. **CPU** — recon-surf / FreeSurfer bits / MRtrix  
3. **Maybe GPU** — QSIPrep eddy / other DL  

This is **not** “missing morphometry science.” It is **queue time, partition bounce, env breakage, and failure compounding**. HPC guides routinely note: GPUs help only when the tool is GPU-enabled; FreeSurfer-style surfaces stay CPU; wait time = pending + runtime (TtS).

**Upstream already admits the hop:** FastSurfer Example 6 / `srun_fastsurfer.sh` schedules **seg on GPU partition**, **surf on CPU partition**, then cleanup — three dependent SLURM jobs. That is the field’s preferred pattern for healthy brains.

**Hard conflict with native lesion:** FastSurfer LIT docs state `--lesion_mask` is **not compatible with `--seg_only` / `--surf_only`**. So the official HPC optimizer and the official lesion path **cannot be composed**. That is a concrete, citeable gap — strongest justification for a **wrapper / standalone fill → ordinary recon** path (your DKT default).

### B. Scientific lesion mitigation (fill choice)

Separate question: *should* you fill, and with what?

| Evidence | Implication for TBI / TRACK |
|----------|-----------------------------|
| Pollak et al. 2025 *Imaging Neuroscience* (FastSurfer-LIT) | DDPM inpaint beats prior fills on simulated tumor/MS + heterogeneous clinical lesions; integrated as FS `--lesion_mask`. |
| Deutscher et al. 2025 *Frontiers Neurol* (VBG + FastSurfer, ms-TBI synthetic) | **Unexpected:** unfilled lesioned T1 often **closer** to ground-truth parcellation than VBG-filled; VBG may help only very large lesions. TBI needs TBI-aware fill policy. |
| Radwan et al. 2021 *NeuroImage* (VBG) | Strong for large heterogeneous lesions → FreeSurfer/FastSurfer after graft; open `KUL_VBG`. |
| Fekonja et al. 2022 *Comm Biol* | Enantiomorphic fill (SPM Clinical Toolbox) → FastSurfer → connectomes in **unilateral glioma** (not bilateral TBI). |
| Bey et al. 2024 *HBM* (LeAPP) | Full lesion-aware HCP-style stack (CFM + virtual brain transplant); containerized. Stroke-centric. Lab already hit **VBT orientation SIGSEGV** on radiological TBI T1s (`docs/papers/factorial_paper/vbt_orientation_finding.md`). |

**VINN clarification.** FastSurferVINN (Henschel et al. 2022) is the **resolution-independent segmentation network**, not a lesion filler. GPU step in “VINN / neuroLIT” = seg + LIT, not two fillers.

---

## 2. Credible resources (reuse map)

### Core anatomy (do not reimplement)

| Resource | Role | Device | License / access |
|----------|------|--------|------------------|
| **FastSurfer ≥ 2.6** + `--lesion_mask` | Native LIT → seg → surf → lesion remap | `--device auto\|cuda\|cpu` | Apache; Docker/Apptainer |
| **neuroLIT** (`lit-inpainting`, `lit-postprocessing`) | Standalone fill + optional post-hoc packaging | `--device auto\|cuda\|cpu` | Deep-MI; [github.com/Deep-MI/neurolit](https://github.com/Deep-MI/neurolit) |
| **FastSurfer `srun_fastsurfer.sh`** | GPU seg / CPU surf SLURM orchestration | split partitions | Ships with FastSurfer |
| **FastSurfer containers** | One env; CUDA or CPU images | `--nv` / `--gpus` | Docker Hub `deepmi/fastsurfer` |

### Alternative fills (standalone only)

| Resource | When to consider | Caveat |
|----------|------------------|--------|
| **KUL VBG** | Large / bilateral / mass-effect lesions; classic FS path | ms-TBI synthetic study: can worsen FastSurfer vs no fill |
| **LeAPP VBT** (+ CFM) | Stroke-like; want full multimodal LeAPP | TBI orientation crash risk; FreeSurfer/HCP lineage |
| **Enantiomorphic (Nachev 2001; SPM Clinical Toolbox)** | Unilateral focal (glioma/stroke) | Fails when lesion crosses midline / bilateral TBI |
| **Cost-function masking** | Registration only | Does not create healthy T1 for recon |

### Downstream DWI handoff patterns (orchestration models)

| Resource | What to copy | What not to claim |
|----------|--------------|-------------------|
| **QSIPrep** | Container + optional `--gpu` per-task; Apptainer `--nv` | Numerically different GPU vs CPU — document if used |
| **fMRIPrep / NiPreps BIDS-App** | Single-entry container CLI; docker wrapper | Mostly CPU; pattern for UX, not GPU policy |
| **Your DKT stack** | FreeSurfer-shaped dirs → QSIRecon / connectome | Already the output contract |

### Workflow glue (if measuring ops endpoints)

| Resource | Use |
|----------|-----|
| **Snakemake / Nextflow** on SLURM | Label GPU vs CPU processes; explicit `gres=gpu` |
| Lab factorial / VBT notes | TBI-specific fill reliability evidence already on disk |

---

## 3. Gap analysis → what a wrapper can honestly own

| Gap | Who owns science | What wrapper can own |
|-----|------------------|----------------------|
| LIT blocks `--seg_only`/`--surf_only` | Deep-MI | Standalone fill → then `srun`-style GPU/CPU split |
| Pluggable fill (neurolit **or** VBT) | Fill authors | One CLI / one subject command |
| FreeSurfer (not FastSurfer) + LIT products | neuroLIT postprocessing | Post-hoc packaging path |
| Older FastSurfer (&lt; 2.6) | — | Standalone only |
| End-to-end lesion → DWI | QSIPrep ≠ lesion fill | Handoff contract + device policy |
| TBI: fill vs no-fill rule | Unsettled | Expose backend choice + QC; don’t hard-wire VBG |

**Methods-paper bar (unchanged from README):** publishable as **infrastructure / reproducible workflow** if you measure **wall-time, queue time, and failure rate** vs today’s multi-job bounce — not if you claim better anatomy than FastSurfer/LIT.

---

## 4. Key citations (starter set)

1. Pollak C et al. FastSurfer-LIT. *Imaging Neuroscience* 2025. doi:10.1162/imag_a_00446  
2. Henschel L et al. FastSurferVINN. *NeuroImage* 2022. doi:10.1016/j.neuroimage.2022.118933  
3. Radwan AM et al. Virtual brain grafting. *NeuroImage* 2021. doi:10.1016/j.neuroimage.2021.117834  
4. Bey P et al. LeAPP. *Hum Brain Mapp* 2024. doi:10.1002/hbm.26701  
5. Deutscher E et al. FastSurfer after lesion filling in ms-TBI. *Front Neurol* 2025. doi:10.3389/fneur.2025.1652385  
6. Fekonja LS et al. Enantiomorphic + FastSurfer connectomes (glioma). *Commun Biol* 2022. doi:10.1038/s42003-022-03190-6  
7. Nachev P et al. Enantiomorphic normalization. *NeuroImage* 2008 (PMC2658465)  
8. FastSurfer docs: LIT module; `srun_fastsurfer.sh`; `--device auto`  
9. QSIPrep docs: `--gpu` task selection; Apptainer `--nv`

---

## 5. Kill / don’t do

- Reimplement recon-surf in DL “for GPU.”  
- Pitch as FreeSurfer/FastSurfer **replacement**.  
- Default VBG for all ms-TBI without size/location rule (Deutscher).  
- Claim native `--lesion_mask` + optimal SLURM seg/surf split (upstream incompatible).  
- Duplicate LeAPP as novelty for stroke (already published).

---

## 6. Recommended next measurements (if pursuing)

1. Time-to-science: standalone fill → `srun` GPU/CPU vs single fat GPU job vs native `--lesion_mask` (one job).  
2. Failure modes: module/PATH/container vs fill crash (VBT orientation).  
3. TBI fill policy screen: none vs neurolit vs VBG stratified by lesion volume (echo Deutscher design).
