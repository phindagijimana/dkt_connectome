# Paper 2 (disconnectome) — prior work map and novelty claims

**Purpose:** single reference for Introduction / Related work: what exists,
what we extend, and what evidence must support each claim before submission.

**As-of:** 2026-10-07 · **Status:** living doc — imaging pilot on 7 subjects;
clinical merge and cohort N still gating inferential claims.

**Related:** [index.md](index.md) · [../paper2b_imaging/prior_work_novelty.md](../paper2b_imaging/prior_work_novelty.md) (imaging-only 2B) · [outcomes_planning.md](outcomes_planning.md) ·
[../LQT.md](../LQT.md) · [../Griffis_later.md](../Griffis_later.md) ·
[../distance_novelty.md](../distance_novelty.md) ·
[`fMRI_pipeline/FC.md`](../../../../fMRI_pipeline/FC.md) ·
[`fMRI_pipeline/docs/lesion_literature.md`](../../../../fMRI_pipeline/docs/lesion_literature.md)

---

## 1. One-sentence positioning

We test whether **patient-specific lesion-aware structural disconnection (SDC)**
in **TBI** predicts **functional disconnection and outcome** beyond lesion volume,
and whether it **outperforms normative-atlas SDC (LQT/BCB)** — extending the
**Griffis 2019 SC → FC → behavior** chain from stroke to TBI with a
**methods head-to-head** motivated by TBI anatomy.

---

## 2. Prior work map (what exists)

| Prior work | Population | SC / SDC | FC / rs-fMRI | Behavior | Gap we fill |
|------------|------------|----------|--------------|----------|-------------|
| **Griffis 2019** (*Cell Rep*) | Stroke ~114 | Normative HCP-842 / LQT-style | rs-fMRI abnormality vs HC | Multi-domain factors | **TBI**; **patient-specific** DWI SDC; factorial anatomy lock |
| **Salvalaggio 2020** (*Brain*) | Stroke | SDC + indirect FC | LNM-style indirect | Multi-domain prediction | TBI; patient-specific tractography arm |
| **Griffis 2021 LQT** (*NI:Clinical*) | Tool | Normative-atlas SDC | — | — | **Comparator**, not primary in TBI cohort |
| **Foulon 2018 BCB** | Tool | Normative SDC | — | — | Second comparator |
| **Boes 2015 / Fox 2018 LNM** | Lesion cohorts | — | Normative FC overlap | Symptoms | Parallel lineage; not DWI SDC factorial |
| **Palacios 2022** (*J Neurotrauma*) | TRACK-TBI | Standard DTI metrics | — | GOSE | No disconnectome / SC→FC chain |
| **Warren 2015** (*Brain*) | TBI | Graph metrics | rs-fMRI | Cognition | Not lesion-aware SDC on DKT |
| **Kuceyeski 2020** (*HBM*) | mTBI | Connectome | Longitudinal | Cognition | Small N; not focal lesion SDC |
| **Weiler 2022 EpiBioS4Rx** (*HBM*) | Moderate–severe TBI | — | Denoising comparison | — | Informs **FC sensitivity**, not SDC |
| **Lamouroux 2024/2025 fMRIStroke** | Stroke | — | Lesion ICA denoising | FC + behavior | **Sensitivity stream** only in our design |
| **Caeyenberghs 2024 ENIGMA** | TBI | — | rs-fMRI practices | — | Reporting framework; no gold lesion FC recipe |

Extended FC lesion methods map: [`lesion_literature.md`](../../../../fMRI_pipeline/docs/lesion_literature.md).

---

## 3. Our claimed contributions (novelty axes)

| # | Claim | Distance axis | Closest prior | Evidence required |
|---|--------|---------------|---------------|-------------------|
| C1 | **Griffis chain in TBI:** SDC ↔ empirical FC disconnection ↔ outcome | Population + biology | Griffis 2019 stroke | CCA / coupling + nested CV on GOSE; permutation p |
| C2 | **Patient-specific lesion-aware SDC** (DWI factorial arm) vs **LQT/BCB** normative SDC | Method | Griffis/LQT stroke | Edge-wise r per subject; ΔAUC/ΔR² if methods-lead |
| C3 | **Locked SC–FC parcellation** (DKT-78) + **lesion-aware FC** (spared edges, Griffis-style D) | Method | Griffis parcel exclusion; stroke FC pipelines | Arm B matrices; overlap with SC edges |
| C4 | **Factorial alignment:** neurolit-inpaint SC arm + matching fMRI variant | Method | Split SC/FC parcellation common error | Document `neurolit-lesion` on both modalities |
| C5 | **Dual fMRI stream:** XCP-D primary + fMRIStroke sensitivity (pre-specified) | Method | Lamouroux stroke-only validation | Stream agreement + primary vs sensitivity in methods |
| C6 | **Incremental validity vs lesion volume** on GOSE | Outcome | Griffis, Palacios | Ordinal nested models; locked covariates |
| C7 | **Domain-specific network → deficit** (if neuropsych available) | Outcome | Corbetta 2015, Salvalaggio | Pre-locked network–composite map ([analysis_plan.md](analysis_plan.md) §6) |

---

## 4. What we do **not** claim (avoid reviewer pushback)

- **fMRIStroke validated for TBI** as primary denoising (stroke-developed; sensitivity only — [FC.md §13.1](../../../../fMRI_pipeline/FC.md)).
- **Strong SC–FC coupling** without cohort N and prespecified tests (7-subject edge r ≈ −0.13 is **pilot QC only**).
- **Superiority over end-to-end DL** (RQ6 positioning only if CNN benchmark available).
- **Standalone Paper 2** if complete-case **N < 30** ([analysis_plan.md](analysis_plan.md) §8) — fold into Paper 1 supplement.

---

## 5. Imaging implementation status vs claims (2026-10-07)

| Component | Status | Notes |
|-----------|--------|-------|
| DWI Step 4.1 disconnectome (neurolit-lesion) | ✅ Pilot 7/7 | `disconnection_matrix.csv` + QC JSON |
| fMRI fMRIPrep + XCP-D + DKT + Arm B | ✅ Pilot 7/7 | Markers `fmristroke_armB.done` |
| fMRIStroke ICLesionGS + Arm B 3b–5b | ✅ Pilot 7/7 | Parallel sensitivity |
| Exploratory coupling / stream QC | ✅ Scripts | `run_pilot_fc_analysis.sh` → `analysis/pilot_fc/` |
| Primary DKT BOLD = XCP-D T1w denoised | ⚠️ **Not on pilot** | All 7 used fMRIPrep preproc fallback; document or rerun stage 3 |
| LQT / BCB batch comparator | ❌ Not run | MATLAB / MNI lesion prep |
| Clinical GOSE + neuropsych merge | ❌ External gate | Populate [complete_case.md](complete_case.md) |
| Prespecified inferential analysis | ❌ | `analysis/paper2/` not built |

---

## 6. Validation checklist (contribution → result)

| Claim | Analysis ([analysis_plan.md](analysis_plan.md)) | Pass criterion (draft) |
|-------|-----------------------------------------------|-------------------------|
| C1 | CCA: SDC matrix ↔ FC disconnection matrix | First component r ≥ 0.4 + perm p < 0.05 (venue rule §10) |
| C2 | LQT vs patient-specific SDC edge correlation + downstream ΔAUC | r < 0.7 in ≥25% cohort OR ΔAUC ≥ 0.02 for methods-lead |
| C3 | Arm B D>0 rate, spared FC; align to SC graph | Non-degenerate D; methods paragraph on voxel-masked spared |
| C4 | Same `neurolit-lesion` FS + DWI arm documented | Provenance JSON / factorial lock |
| C5 | `compare_fc_streams.py` cohort summary | Report mean r, not as primary endpoint |
| C6 | GOSE ordinal nested models | ΔAUC vs baseline significant at locked α |
| C7 | Domain-specific regressions | ≥3/5 domains pre-specified map holds |

**Novelty for biology/methods tiers is validated only when clinical N and locked analyses complete.**

---

## 7. Venue-contingent “strongest contribution” (from locked results)

| If results show… | Lead framing | Primary anchor papers |
|------------------|--------------|------------------------|
| Large LQT divergence + ΔAUC | NeuroImage methods | LQT, BCB, Griffis 2021 |
| Strong CCA + domain mapping | Brain biology | Griffis 2019, Salvalaggio, Corbetta |
| Coherent but modest effects | HBM default | Palacios, Warren, Bey/LeAPP (methods context) |

Rule: [analysis_plan.md §10](analysis_plan.md#10-venue-decision-rule).

---

## 8. Suggested Related work paragraph order (manuscript)

1. TBI outcomes exceed lesion size — network disconnection hypothesis.  
2. Griffis 2019 stroke template (SDC → FC → behavior).  
3. Normative SDC tools (LQT, BCB, NeMo) and TBI anatomy mismatch.  
4. Patient-specific DWI / lesion-aware ACT (LeAPP, our Paper 1 arm).  
5. rs-fMRI in TBI: denoising heterogeneity (Weiler, ENIGMA).  
6. Lesion-aware FC (Griffis parcel rules; fMRIStroke as stroke sensitivity analog).  
7. **Gap:** integrated patient-specific SC + lesion-aware FC + outcomes in TBI cohort.  
8. **Present study** — pre-specified arm, dual fMRI sensitivity, head-to-head optional.

---

## 9. Key citations (minimum set)

- Griffis JC et al. 2019. *Cell Reports*. doi:10.1016/j.celrep.2019.07.100  
- Salvalaggio A et al. 2020. *Brain*. doi:10.1093/brain/awaa156  
- Griffis JC et al. 2021 LQT. *NeuroImage: Clinical*. doi:10.1016/j.nicl.2021.102639  
- Palacios EM et al. 2022. *J Neurotrauma*.  
- Lamouroux A et al. 2024 fMRIStroke. *JOSS*. doi:10.21105/joss.06636  
- Weiler M et al. 2022. *Human Brain Mapping*. doi:10.1002/hbm.25979  
- Bey T et al. 2024 LeAPP. *Human Brain Mapping*.

Full lineage: [../Griffis_later.md](../Griffis_later.md).
