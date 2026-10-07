# Paper 2B — detailed planning (imaging-only)

**Related:** [index.md](index.md) · [analysis_plan.md](analysis_plan.md) ·
[../disconnectome/outcomes_planning.md](../disconnectome/outcomes_planning.md) (full Paper 2 contrast)

---

## One-paragraph summary

Paper 2B tests whether **patient-specific lesion-aware structural disconnection**
from DWI (fixed factorial arm, default **`neurolit-lesion`**) **systematically differs**
from **normative-atlas SDC** (LQT, optionally BCBtoolkit) in TBI, whether divergence
**tracks lesion morphology** (volume, bilaterality, location), and whether
**patient-specific SDC couples more strongly to empirical functional disconnection**
(Griffis-style Arm B on DKT-78, primary XCP-D stream) than normative SDC. **No clinical
outcomes** enter primary or secondary hypotheses.

---

## Candidate titles

- *Patient-specific lesion-aware disconnectomes in traumatic brain injury: comparison with normative-atlas tools and coupling to resting-state functional disconnection*
- *Normative versus patient-specific structural disconnection in TBI: a head-to-head imaging study with functional disconnectome validation*
- *When template-based disconnectomes fail in TBI: quantitative comparison of LQT and lesion-aware tractography*

---

## Research questions

| ID | Question |
|----|----------|
| **RQ1** | How much do **patient-specific SDC** and **LQT SDC** disagree edge-wise and subject-wise in TBI? |
| **RQ2** | Which **lesion / anatomy features** predict larger disagreement (volume, labels, bilateral, session)? |
| **RQ3** | Does **patient-specific SDC** show **stronger association** with **empirical FC disconnection (Arm B)** than LQT SDC (same DKT-78 graph, same visit)? |
| **RQ4 (optional)** | Does **BCB** voxel-level disconnection **spatially concord** with patient-specific tract-level disconnection where both are defined? |
| **RQ5 (sensitivity)** | Do **XCP-D** and **fMRIStroke** Arm B streams **agree** (pre-specified sensitivity; not primary biology claim)? |

**Explicitly excluded:** GOSE prediction, neuropsych domain mapping, incremental validity vs lesion volume on **behavior**.

---

## Hypotheses

| ID | Hypothesis | Primary metric |
|----|------------|----------------|
| **H1** | Patient-specific and LQT SDC **diverge** (edge-wise r < 0.7) in **≥ 25%** of subjects with focal TBI lesions. | Per-subject upper-triangle Pearson r |
| **H2** | Divergence **increases** with **lesion volume** and **mass-effect proxies** (oedema label volume, bilateral involvement). | r or mean \|ΔD\| ~ lesion metrics |
| **H3** | **Patient-specific SDC** predicts / correlates with **Arm B FC disconnection** more strongly than LQT SDC. | CCA 1st component or CV R² (SC → FC edge vector) |
| **H4 (null)** | If H1 fails (r ≥ 0.9 cohort-wide), **normative SDC is often adequate** in TBI; report **failure subsets** (location, size). | Distribution of r |
| **H5** | Dual fMRI streams yield **high Arm B agreement** (r > 0.95 on D) despite denoising differences. | Stream comparison (pilot ~0.99) |

---

## Fixed design choices (defaults — lock in [analysis_plan.md](analysis_plan.md))

| Choice | Default |
|--------|---------|
| DWI / SDC arm | `validation_v030/arms/neurolit-lesion` |
| SDC matrix | `disconnectome/disconnection_matrix.csv` (Option C spared policy per disconnectome.json) |
| FC stream (primary) | XCP-D → DKT → Arm B (`desc-empirical_fc_disconnection.csv`) |
| FC stream (sensitivity) | fMRIStroke `ICLesionGS` |
| fMRI variant | `fmri_derivatives_inpaint`, `--inpaint` cohort only |
| Parcellation | DKT-78 (`atlas-DKT78_nodes.tsv`) |
| Visit | `ses-2WK` rs-fMRI + DWI |
| Comparators | LQT (required); BCB (optional) |

---

## Sample size (imaging-only)

| N (imaging complete) | Interpretation |
|----------------------|----------------|
| **7** (current pilot) | Methods face validity, figures for grant/supplement; **no inferential claims** |
| **≥ 25** | Preliminary group summaries; bootstrap CIs |
| **≥ 40–50** | Primary inference for H1–H3 (NeuroImage/HBM realistic) |

No complete-case **clinical** N rule — only **imaging complete-case**: lesion mask + DWI disconnectome + rs-fMRI Arm B + (for RQ1) LQT output.

---

## Relationship to Paper 2 (full)

If TRACK-TBI clinical export arrives with **N ≥ 45**, **Paper 2** adds GOSE/neuropsych and can **reuse** all 2B imaging analyses as **Results subsection + supplement**. Paper 2B can ship **first** as methods/mechanism paper, or merge into a single larger manuscript if editors prefer — pre-specify in cover letter to avoid dual submission overlap.
