# LeAPP lineage — Bey 2024 and the anatomy × ACT factorial family

**Purpose:** deep summary of the LeAPP paper (Bey et al. 2024) which is the
direct precedent our factorial paper extends, plus the lineage of methods
papers that fed into LeAPP or that we adopt alongside (Radwan's VBG,
Pollak's neuroLIT, Smith's ACT). Written for Paper 1 planning — this is the
literature the factorial paper will be judged against.

**Related:** [index.md](index.md) · [analysis_plan.md](analysis_plan.md) ·
[../../lesion_aware.md](../../lesion_aware.md)

**Caveat:** specific numerical claims (N per cohort, exact effect sizes,
methodological parameters) should be verified against source papers before
being cited in a manuscript. This document summarizes conceptual
contributions and the shape of each paper's argument.

---

## The lineage in one figure

```
Smith et al. 2012 (ACT foundation)
                       │  Anatomically-constrained tractography with MRtrix
                       ▼
Smith 2015 (SIFT2)
                       │  Streamline weighting for connectome fidelity
                       ▼
Radwan et al. 2020 (VBG)                Griffis et al. 2019 (SDC in stroke)
   │  Virtual Brain Grafting               │  Normative-atlas SDC
   ▼                                       │
Radwan et al. 2023 (TBI + VBG + ACT)      │  (methodological neighbor for Paper 2)
   │  N=5 TBI proof-of-concept             │
   │                                       │
   ▼                                       ▼
Bey et al. 2024 (LeAPP)  ─────────  our Paper 1 (this project)
   │  Full factorial: VBT + ACT              │  Extends to TBI with:
   │  in ischemic stroke                     │    - neuroLIT (Pollak 2025) as 3rd anatomy
   │  N=36 stroke + N=81 synthetic           │    - Cohort scale ~100 TBI subjects
                                             │    - Reproducible containerized pipeline
                                             │    - Provenance JSON per step
```

---

## 1. Bey et al. 2024 — the LeAPP paper (direct precedent)

**Reference:** Bey, Reineck, Villringer, Nikulin (2024). *LeAPP:
Lesion-Aware automated Processing Pipeline for structural connectome
analysis in lesioned brains.* **Human Brain Mapping** (approximate title;
verify exact wording). DOI: [10.1002/hbm.26701](https://doi.org/10.1002/hbm.26701)

**Note on citation:** verify author order and exact title against the DOI
before publishing. The BrainModes lab (Berlin / Charité) is the source, and
the pipeline is public at [https://github.com/BrainModes/LeAPP](https://github.com/BrainModes/LeAPP).

### What LeAPP is

A containerized processing pipeline for **structural connectome analysis in
brains with focal lesions**, specifically validated on ischemic stroke. Its
key innovation was making two lesion-handling decisions **independent** and
**explicit** — turning each into a knob that could be evaluated
factorially.

**The two axes of the LeAPP factorial:**

1. **Anatomical mitigation** — should the T1w be corrected before recon?
   LeAPP uses **Virtual Brain Transplant (VBT)**: mirror the contralesional
   hemisphere's anatomy into the lesion cavity before FreeSurfer /
   segmentation. This gives a plausible T1w for cortical reconstruction
   while preserving the original lesion mask for later use.
2. **Lesion-aware ACT** — should tractography treat the lesion ROI as
   pathological tissue? LeAPP uses MRtrix's `5ttedit -path` to insert the
   original (pre-mitigation) lesion mask into the five-tissue-type
   segmentation's pathology channel, so streamlines respect the injury
   during tractography.

**The factorial in LeAPP:**

- Baseline: original T1w + standard ACT
- Anatomy-mitigated only: VBT T1w + standard ACT
- ACT-only: original T1w + lesion-aware ACT (`5ttedit -path` on the
  segmentation derived from original T1w)
- Full LeAPP: VBT T1w + lesion-aware ACT

This is a 2×2 factorial. The paper reports each combination on the same
subjects and compares connectome differences.

### Cohort and validation

Two arms of validation:

- **N ≈ 36 ischemic stroke** patients with clinician-traced lesion masks;
  up to 4 longitudinal scans per subject
- **N ≈ 81 healthy controls** with **synthetic lesions** injected at
  varied locations — synthetic validation is what elevates the paper's
  methodological rigor since ground truth is known

### Key results (conceptual — verify specifics from paper)

- VBT anatomy correction meaningfully improves FreeSurfer recon success rate
  in high-mass-effect stroke cases
- Lesion-aware ACT changes streamline patterns near the lesion in expected
  ways (fewer erroneous streamlines through pathology)
- The two axes are **not additive** — some interactions between anatomy
  mitigation and ACT choice
- Synthetic-lesion validation shows that with both axes active, LeAPP
  recovers a larger fraction of expected connectivity loss than any single
  axis alone

### Venue and reception

- Published in **Human Brain Mapping** — our default target venue for Paper 1
- Reader base: imaging methodologists + clinical connectome researchers
- Sets the reviewer expectation for our submission

### Why LeAPP is *the* precedent we extend

- **Same journal** (HBM) — the venue-fit argument is straightforward
- **Same design paradigm** (factorial anatomy × ACT) — reviewers already know the shape of the argument
- **Same key techniques** (VBT, `5ttedit -path`) — we adopt them directly and cite
- **Different population** (stroke → TBI) — this is our extension's core novelty
- **Different anatomy space** (their VBT is unilateral-assumed; ours needs to handle bilateral TBI cases) — a methodological difference to acknowledge

### What our paper adds vs LeAPP

1. **Population:** TBI vs stroke (Radwan 2023 had N=5 TBI; we have ~100)
2. **Anatomy backend:** we add **neuroLIT** (Pollak 2025 DDPM inpainting) as a third arm alongside orig and VBT
3. **Bilateral-lesion handling:** VBT's mirror assumption breaks for bilateral TBI (~30–40% of moderate-severe cases); we quantify how our arms handle this
4. **Radiological-convention T1w handling:** LeAPP's VBT crashes deterministically on T1w with negative-determinant sform (radiological-convention DICOMs, common in clinical TBI cohorts); we add `fslreorient2std` preprocessing to normalize orientation before mirror-flirt-midtrans. See [`vbt_orientation_finding.md`](vbt_orientation_finding.md).
5. **Cohort scale:** LeAPP had N=36 stroke; we target ~100 TBI — 3× larger real-cohort N (LeAPP had more synthetic subjects at N=81)
6. **Reproducibility infrastructure:** we ship containerized pipeline (GHCR + DockerHub) with per-subject provenance JSON at every step + Snakemake DAG + BIDS-App wrapper. LeAPP has a public repo but less reproducibility infrastructure.

---

## 2. Radwan et al. 2020 — Virtual Brain Grafting (VBG)

**Reference:** Radwan, Emsell, Blommaert, Zhylka, Kovacs, Theys, Peeters,
Sunaert (2020). *Virtual brain grafting: enabling whole brain parcellation
in the presence of large lesions.* **NeuroImage 229:117731** (approximate;
verify DOI). Often cited as the VBG paper.

### What VBG is

An earlier and technically related approach to LeAPP's VBT. VBG uses the
contralesional hemisphere's anatomy to "graft" a plausible T1w into the
lesion cavity, then runs standard FreeSurfer / parcellation on the grafted
brain.

### Relationship to VBT (LeAPP)

- **VBG:** the general concept of using contralesional anatomy to fill the
  lesion.
- **VBT:** a specific implementation used in LeAPP with particular smoothing
  and blending parameters.

The terms are sometimes used interchangeably; in practice, VBG is the
technique family and VBT is one implementation.

### Why it matters for our paper

- **Lineage citation:** cite Radwan 2020 as the origin of the mirror-graft
  approach, then Bey 2024 as the LeAPP-specific implementation we adopted
  (via `run_vbt.py`, a port of the LeAPP BrainModes code)
- **Alternative implementation:** if VBT struggles on a subject (e.g.,
  bilateral injury), reverting to VBG-style processing may be a
  supplementary robustness analysis

---

## 3. Radwan et al. 2023 — TBI + VBG + ACT (small-N precedent)

**Reference:** Radwan et al. (2023). Related TBI application of VBG +
lesion-aware ACT. **Network Neuroscience 7(2):444–466.** DOI:
[10.1162/netn_a_00277](https://doi.org/10.1162/netn_a_00277)

### What they did

Applied the VBG + lesion-aware ACT approach to a small TBI cohort (N=5),
demonstrating feasibility of extending stroke methods to TBI. Not a full
factorial — mostly proof-of-concept.

### Why it matters for our paper

- **Establishes prior art** for VBG in TBI — so we're not the first to try
  this combination
- **N=5 is not cohort scale** — our contribution is running it at ~100
  subjects with a proper factorial design and pre-specified contrasts
- **Cite in intro** to acknowledge the precedent while positioning our
  cohort-scale evidence as new

---

## 4. Pollak et al. 2025 — neuroLIT DDPM inpainting

**Reference:** Pollak et al. (2025). *neuroLIT: Denoising Diffusion
Probabilistic Model inpainting for brain lesions.* **Imaging Neuroscience.**
DOI: [10.1162/imag_a_00446](https://doi.org/10.1162/imag_a_00446)

### What neuroLIT is

A learned (DDPM-based) approach to filling lesion cavities in T1w images
with plausible healthy-looking tissue. Alternative to the deterministic
VBT/VBG approaches — instead of copying the contralesional anatomy,
neuroLIT generates novel tissue via a diffusion generative model trained on
healthy brains.

### Advantages over VBT

- **Doesn't require contralesional intactness** — VBT breaks when the
  contralesional homolog is also damaged (common in TBI); neuroLIT can fill
  either or both sides
- **Handles arbitrary lesion topology** — no symmetry assumption
- **Learned prior** — the DDPM's learned distribution of healthy tissue may
  produce more anatomically plausible fill than deterministic mirroring

### Disadvantages / risks

- **Learned model** — behavior on out-of-distribution lesion patterns
  (unusually large, unusually shaped) is less predictable than deterministic
  VBT
- **Compute cost** — inference is slower and requires GPU
- **Model provenance** — if the DDPM was trained on adult healthy brains,
  applying it to pediatric TBI would require validation

### Why neuroLIT is in our factorial

- **Third anatomy backend** alongside orig (baseline) and VBT (LeAPP standard)
- **Test-bed for whether learned inpainting matters** — reviewers will ask
  "why not just use VBT?" and we can point to bilateral and complex-shape
  lesions where VBT's assumptions strain
- **Cite Pollak 2025 as the primary reference** for the neuroLIT technique
  in our factorial paper

---

## 5. Smith et al. 2012 — ACT (foundational technique)

**Reference:** Smith, Tournier, Calamante, Connelly (2012). *Anatomically-
constrained tractography: improved diffusion MRI streamlines tractography
through effective use of anatomical information.* **NeuroImage 62:1924–
1938.** (Foundational ACT paper.)

### What ACT is

The MRtrix3 approach to using segmentation (five-tissue-type / 5TT) to
constrain tractography, so streamlines respect anatomical boundaries. Both
"standard ACT" and "lesion-aware ACT" (via `5ttedit -path`) sit on this
foundation.

### Why it matters for our paper

- **Cite in methods** as the underlying tractography framework for all six arms
- Reference for how the pathology channel modification (`5ttedit -path`)
  interacts with the 5TT to alter streamline generation

---

## 6. Landscape synthesis — what these papers establish

Any Paper 1 submitted to HBM / NeuroImage will be judged against the
methodological standards this lineage has established:

- [ ] **Factorial (not single-arm) evaluation** — LeAPP set this bar; a
      TBI paper that runs only one arm is a downgrade
- [ ] **Explicit anatomy × ACT decomposition** — the two axes have to be
      analytically separable, not conflated
- [ ] **VBT (or equivalent) baseline** — the paper needs to include VBT for
      direct comparison to LeAPP
- [ ] **Real-cohort + optional synthetic validation** — LeAPP had both;
      the synthetic component is what elevates to NeuroImage tier
- [ ] **Container / reproducibility statement** — LeAPP had a repo; we
      should have containers + provenance JSON
- [ ] **Cohort-scale N** — LeAPP N=36 stroke; we should exceed if aiming
      to differentiate

Missing more than 1–2 of these will drop us from HBM (default) to
*NeuroImage: Reports* (backup) or downgrade Paper 1 to a sensitivity paper.

---

## 7. What our paper legitimately claims as new

### Yes claim

- **First cohort-scale (~100) 3×2 factorial in TBI** — no prior TBI paper
  has this design at this N
- **First integration of neuroLIT inpainting** into a factorial anatomy × ACT
  evaluation — Pollak 2025 published the tool but did not do the downstream
  connectome sensitivity analysis
- **Reproducible containerized pipeline** with per-step provenance JSON,
  Snakemake DAG, and BIDS-App wrapper — LeAPP has a repo but not this level
  of infrastructure
- **Deep Atropos vs HSVS 5TT sensitivity** in TBI — reported as supplement,
  not primary claim

### No claim

- The VBT / lesion-aware ACT combination — that's LeAPP's contribution; we
  cite and adopt
- The ACT framework itself — Smith 2012; we cite and use
- neuroLIT as a technique — Pollak 2025; we cite and integrate
- VBG as the mirror-graft family — Radwan 2020; we cite as lineage

---

## 8. Reviewer defense — anticipated critiques

- *"How does this differ from LeAPP?"* — TBI (not stroke), N=100 (not 36),
  neuroLIT as third arm (LeAPP had only VBT), bilateral-lesion handling,
  containerized reproducibility.
- *"Why not just use VBT everywhere?"* — VBT's mirror assumption breaks
  for bilateral TBI (~30–40% of moderate-severe cases); the factorial
  quantifies this. neuroLIT is a fallback.
- *"Is neuroLIT validated for TBI?"* — Pollak 2025 validated on healthy +
  simulated lesions; our factorial evaluates it in a real TBI cohort for
  the first time.
- *"Where's the synthetic-lesion validation?"* — either in supplement
  (default HBM version) or as main-text figure (NeuroImage stretch
  version, per analysis_plan.md § 9).
- *"Deep Atropos vs HSVS?"* — supplementary figure; not the main story
  (Paper 3 material).

---

## Bottom line for our paper

Bey 2024 (LeAPP) is the **direct methodological ancestor** of our factorial
paper. Every choice we make can be described as "same as LeAPP" (adopt) or
"extends LeAPP by X" (differentiate). Neither the biology story nor the
technique family is paradigm-shifting; the paper's contribution is
**cohort-scale TBI evaluation with an added third anatomy backend and
containerized reproducibility infrastructure** — a solid HBM submission by
default, elevated to NeuroImage-stretch if synthetic-lesion validation on
CIDUR controls also runs.

---

## See also

- [`index.md`](index.md) — factorial paper cover doc
- [`analysis_plan.md`](analysis_plan.md) — pre-registration template
- [`manuscript_skeleton.md`](manuscript_skeleton.md) — section skeleton
- [`../../lesion_aware.md`](../../lesion_aware.md) — pipeline methodology + LeAPP framework overview
- [`../../TBI_Experimental_Arms.md`](../../TBI_Experimental_Arms.md) — factorial spec
- [`../../references.md`](../../references.md) — full pipeline bibliography
