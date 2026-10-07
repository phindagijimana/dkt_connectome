# Paper 2B — prior work and novelty (imaging-only)

**As-of:** 2026-10-07 · **Related:** [planning.md](planning.md) ·
[../disconnectome/prior_work_novelty.md](../disconnectome/prior_work_novelty.md) (Paper 2 full)

---

## Thesis (one sentence)

Normative-atlas SDC is widely used after focal lesions, but in **TBI** **patient-specific lesion-aware SDC** may diverge systematically and **track empirical functional disconnection** better — a **methods/mechanism** claim that does **not** require outcome prediction.

---

## Prior work map (2B-relevant rows)

| Prior work | What they did | 2B gap |
|------------|---------------|--------|
| **LQT / Griffis 2021** | Normative HCP-842 overlay | Not head-to-head vs patient DWI SDC **in TBI cohort** |
| **BCB / Foulon 2018** | Voxel normative disconnection | Same |
| **Griffis 2019** | SC↔FC (+ behavior in stroke) | **SC↔FC without behavior in TBI** |
| **LeAPP / Bey 2024** | Factorial SC preprocessing | Does not compare to LQT on same subjects |
| **Radwan 2023** | TBI VBG+ACT N≈5 | No LQT head-to-head at scale |
| **Lamouroux fMRIStroke** | Stroke FC denoising | Sensitivity stream only |

---

## Novelty claims (2B only)

| # | Claim | Evidence required |
|---|--------|-------------------|
| N1 | Quantified **LQT vs patient-specific** divergence in TBI | Cohort r distribution + lesion moderators |
| N2 | **Patient-specific SC↔FC** stronger than LQT↔FC | Prespecified comparison of association metrics |
| N3 | **Reproducible pipeline** (containers, DKT-78 alignment, dual fMRI sensitivity) | Provenance + supplement |
| N4 | **Negative result** if methods agree | Pre-registered interpretation |

**Not claimed:** GOSE prediction, domain-specific cognition, Brain-tier mechanism-of-recovery.

---

## Validation checklist

| Claim | Pass (draft) |
|-------|----------------|
| N1 | ≥25% subjects r < 0.7 vs LQT OR publish null with subset analysis |
| N2 | Patient-specific SC↔FC metric > LQT SC↔FC in ≥60% subjects or cohort mean Δ significant (bootstrap) |
| N3 | Public code path + container versions in supplement |

---

## Related work paragraph order

1. SDC after focal lesions (Griffis stroke).  
2. Dominance of normative tools (LQT, BCB).  
3. TBI anatomy breaks template assumptions.  
4. Patient-specific tractography (LeAPP, Radwan).  
5. SC↔FC mechanism (Griffis Fig 2) — **stop before behavior in TBI**.  
6. **Present study:** head-to-head + FC validation, no outcomes.
