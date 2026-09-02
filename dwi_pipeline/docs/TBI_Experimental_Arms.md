# TBI experimental arms

Concise reference for the **factorial experiment-arm** design used in TrackTBI lesion
connectomics: what each arm does, how the two processing axes relate, and how this
extends [LeAPP](https://doi.org/10.1002/hbm.26701) (Bey et al. 2024) from ischemic
stroke to traumatic brain injury.

**Related:** [Usage — experiment arms](usage.md#experiment-arms-experiment-arm) ·
[Lesion-aware tractography](lesion_aware.md) ·
[Publication strategy](publication_strategy.md) ·
[Decision tables](decision_tables.md#experiment-arms)

---

## What problem do the arms solve?

Focal brain lesions break the assumptions of standard connectome pipelines. A cavity
or contusion can distort registration, surface reconstruction, tissue segmentation,
tractography priors, and edge counts — yet the pipeline may still produce a plausible
matrix.

LeAPP showed that **two decisions matter independently**:

1. **Anatomical mitigation** — should the T1w be corrected before recon (inpainting /
   virtual brain transplant)?
2. **Lesion-aware ACT** — should tractography treat the injury ROI as pathological
   tissue during streamline generation?

The six core arms are a **2×3 factorial**: three anatomy backends × two ACT modes.
Each arm is a **separate pipeline run** with isolated outputs under
`RESULTS_ROOT/arms/<arm>/`.

---

## The two axes

```text
                    Step 3.1 ACT
                 Standard          Lesion-aware
              ┌─────────────────┬─────────────────┐
  Original    │   orig-std      │  orig-lesion    │
  T1w         │   (baseline)    │  (ACT only)     │
              ├─────────────────┼─────────────────┤
  neuroLIT    │ neurolit-std    │ neurolit-lesion │
  inpainting  │ (inpaint only)  │ (inpaint+ACT)   │
              ├─────────────────┼─────────────────┤
  VBT         │   vbt-std       │   vbt-lesion    │
  (LeAPP port)│ (VBT only)      │ (full LeAPP)    │
              └─────────────────┴─────────────────┘
        Step 1.1 anatomy mitigation →
```

| Axis | Pipeline step | Question it isolates |
|------|---------------|----------------------|
| **Anatomy** | Step 1.1 (`--anat-mitigation`) | Does filling / transplanting the lesion cavity change surfaces, parcellation, and connectomes? |
| **ACT** | Step 3.1 (`--act-mode`) | Does marking the **original lesion ROI** as pathology change tractography and connectomes? |

These factors are **orthogonal by design** (Bey et al. 2024). Inpainting fixes what
recon “sees”; lesion-aware ACT fixes what tractography “knows” about injured tissue.

---

## Arm reference

| Arm | Step 1.1 anatomy | Step 3.1 ACT | Role in the factorial |
|-----|------------------|--------------|------------------------|
| `orig-std` | Original T1w (`none`) | Standard | **Baseline** — no mitigation, standard ACT |
| `orig-lesion` | Original T1w | Lesion-aware | **ACT main effect** without anatomical fill |
| `neurolit-std` | neuroLIT inpainting | Standard | **Inpainting main effect** (learned DDPM fill) |
| `neurolit-lesion` | neuroLIT | Lesion-aware | Inpainting + pathology ACT (cross-source design) |
| `vbt-std` | Virtual brain transplant | Standard | Inpainting sensitivity — deterministic LeAPP-style fill |
| `vbt-lesion` | VBT | Lesion-aware | **Closest to full LeAPP factorial** on TBI data |

**Seventh arm (supplement, not core factorial):**

| Arm | Notes |
|-----|-------|
| `deep-atropos-pilot` | Native-T1 Deep Atropos 5TT + lesion-aware ACT; sensitivity branch for Paper 1 supplement, not a third anatomy backend in the main 3×2 grid |

---

## How this relates to LeAPP

### What LeAPP is

**LeAPP** (Lesion Aware automated Processing Pipeline; Bey et al. 2024,
[*Human Brain Mapping*](https://doi.org/10.1002/hbm.26701)) is a containerized
framework for **clinical stroke MRI**. It combines:

- **Virtual brain transplant (VBT)** — mirror contralesional anatomy into the lesion
  cavity before reconstruction
- **Lesion-aware ACT** — insert the clinician-traced lesion into MRtrix’s pathology
  channel (`5ttedit -path`) and rebuild tractography
- **Factorial evaluation** — compare mitigation and ACT combinations systematically
- **Synthetic lesion validation** — inject known lesions on healthy brains to quantify
  recovery of connectivity

LeAPP validated on **ischemic stroke** (N≈36 stroke + synthetic lesions on N≈81
healthy brains).

### What this pipeline adopts

| LeAPP concept | DKT Connectome implementation |
|---------------|-------------------------------|
| Factorial anatomy × ACT | `--experiment-arm` presets + isolated `arms/<arm>/` trees |
| Virtual brain transplant | `--anat-mitigation vbt` → `scripts/run_vbt.py` (port of [BrainModes/LeAPP](https://github.com/BrainModes/LeAPP)) |
| Lesion-aware ACT | `--act-mode lesion-aware` → Step 3.1 in `dkt_lesion_act.sif` |
| Original lesion ROI for pathology | On `*-lesion` inpainted arms: recon uses mitigated T1w; ACT uses **original BIDS lesion mask** |
| Disconnectome | Step 4.1 — spared connectome options A/B/C + disconnection index |
| ACPC / registration workflow | Rigid FS T1 → QSIPrep ACPC for connectome parcellation |

### What we add beyond LeAPP

| Extension | Why it matters for TBI |
|-----------|------------------------|
| **neuroLIT inpainting** (Pollak et al. 2025) | Third anatomy backend — learned fill vs deterministic VBT |
| **TrackTBI cohort scale** | Target ~100 real TBI lesions (contusion, edema, hemorrhage, bilateral injury) |
| **Deep Atropos 5TT branch** | Alternative native-T1 pathology ACT (`deep-atropos-pilot`) |
| **Snakemake + BIDS App** | Reproducible containers, provenance JSON, cohort QC dashboards |
| **Multi-measure connectomes** | Count, SIFT2, mean length, mean FA/MD from one tractogram |

### What LeAPP does *not* cover unchanged

- **TBI lesion morphology** differs from stroke (bilateral injury, midline shift, mixed
  tissue types) — cohort-specific QC is required before treating any arm as default.
- **VBT** assumes a largely unilateral lesion with an intact contralesional homolog;
  validate before applying to bilateral or diffuse injury.
- **neuroLIT** is not part of LeAPP; cite Pollak et al. 2025 when contrasting it.

---

## Intentional cross-source design (`*-lesion` inpainted arms)

On `neurolit-lesion`, `vbt-lesion`, and `deep-atropos-pilot`, different processing
layers deliberately use **different anatomical references**:

| Layer | Source | Rationale |
|-------|--------|-----------|
| Recon + HSVS 5TT | Mitigated T1w (Step 1.1) | Surfaces and parcellation should not fail on a cavity |
| ACT pathology channel | **Original BIDS lesion ROI** | Tractography priors should reflect biological injury |
| DWI / WM FOD | Unmodified QSIPrep output | Diffusion abnormality at the lesion is real, not inpainted |

This is the **LeAPP factorial contrast**, not a registration bug. Methods text should
state explicitly that anatomy was mitigated for recon while the original lesion extent
was retained for ACT (see [Step 3.1 methods](methods/step3_1_lesion_act.md)).

---

## Pre-specified contrasts (Paper 1)

Lock these **before** inspecting group results ([Publication strategy](publication_strategy.md)):

| Level | Contrast | Example |
|-------|----------|---------|
| **Primary** | std vs lesion within each anatomy | `orig-std` vs `orig-lesion` |
| **Secondary** | anatomy backends within std or lesion | `neurolit-std` vs `vbt-std` |
| **Interaction** | ACT effect after inpainting | `neurolit-lesion` vs `neurolit-std` |

**Primary numeric outcome (pick one):** global matrix correlation between paired arms,
or mean absolute edge difference on the upper triangle.

---

## Pilot: `sub-TBI011011`

The seven-arm tree on NAS is the **engineering gate** before cohort scale-up:

```text
/mnt/nfs/Gugger_Lab/NIR/dwi_test_TBI_experiment/sub-TBI011011_fastsurfer_experiment/arms/
├── orig-std/
├── orig-lesion/
├── neurolit-std/
├── neurolit-lesion/
├── vbt-std/
├── vbt-lesion/
└── deep-atropos-pilot/
```

Each arm contains the full step tree (QSIPrep → recon → QSIRecon → connectome →
disconnectome → nodestrength → QC). All seven arms verified complete (connectome,
disconnectome, QC PASS).

**Pilot analysis** (N=1, descriptive only):

```bash
bash dwi_pipeline/scripts/run_tbi011011_factorial_analysis.sh
# → writes analysis/ under the experiment root (report.md, CSVs, figures)
```

Example pilot findings (count connectome): std vs lesion Pearson r > 0.996 within
each anatomy backend; Deep Atropos arm clearly distinct (r ≈ 0.67 vs HSVS lesion
arms). These illustrate the analysis workflow — **not** cohort inference.

---

## How to run

**One arm per submission** (recommended):

```bash
export BIDS_DIR=/path/to/BIDS
export RESULTS_ROOT=/path/to/results
bash dwi_pipeline/submit.sh --experiment-arm neurolit-lesion
```

**Single subject:**

```bash
bash dwi_pipeline/workflow/run_subject.sh all TBI011011 \
  --experiment-arm vbt-lesion --disconnection
```

**Equivalent manual flags** (no arm prefix on `RESULTS_ROOT`):

```bash
bash dwi_pipeline/workflow/run_subject.sh all TBI011011 \
  --anat-mitigation vbt --act-mode lesion-aware --disconnection
```

Requires a BIDS lesion mask (`*_label-lesion_roi.nii.gz`) for any `*-lesion` arm and
for neurolit/VBT arms that run Step 1.1.

---

## Outputs per arm

Under `RESULTS_ROOT/arms/<arm>/`:

| Step | Key paths |
|------|-----------|
| 4 — Connectome | `connectomes/sub-<ID>/dkt_connectome*.csv`, `fs_to_preproc_T1w_0GenericAffine.mat` |
| 4.1 — Disconnectome | `connectomes/sub-<ID>/disconnectome/disconnection_matrix.csv` |
| 5 — Node strength | `node_strength/strength/per_subject/sub-<ID>_strength.csv` |
| QC | `qc/sub-<ID>/subject_qc.html` |

Full layout: [Outputs](outputs.md).

---

## Citations

| When you use… | Cite |
|---------------|------|
| Factorial design / lesion-aware framework | Bey et al. 2024 — [10.1002/hbm.26701](https://doi.org/10.1002/hbm.26701) |
| neuroLIT inpainting | Pollak et al. 2025 — [10.1162/imag_a_00446](https://doi.org/10.1162/imag_a_00446) |
| VBT implementation source | [BrainModes/LeAPP](https://github.com/BrainModes/LeAPP) |
| Lesion-aware ACT (MRtrix) | Smith et al. 2012 |

Full bibliography: [References — experiment arms](references.md#experiment-arms-factorial-lesion-processing).

---

## See also

- [Lesion-aware tractography](lesion_aware.md) — LeAPP summary, VBT port, TBI QC notes
- [Usage — experiment arms](usage.md#experiment-arms-experiment-arm) — CLI flags
- [Decision tables — experiment arms](decision_tables.md#experiment-arms) — when to use which arm
- [Publication strategy](publication_strategy.md) — Paper 1 cohort plan and journal targets
- [Step 1.1 — Inpainting](methods/step1_1_inpaint.md) · [Step 3.1 — Lesion-aware ACT](methods/step3_1_lesion_act.md)
- [Deep Atropos branch](deep_atropos_5tt.md) — `deep-atropos-pilot` details
- `dwi_pipeline/scripts/analyze_factorial_arms.py` — harvest script for paired Δ metrics
