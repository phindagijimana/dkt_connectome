# Paper 1 (factorial) — prior work map and novelty claims

**Purpose:** single reference for Introduction / Related work: what exists,
what we extend, and what evidence must support each claim before submission.

**As-of:** 2026-10-07 · **Status:** living doc — update when cohort analysis completes.

**Related:** [index.md](index.md) · [leapp_lineage.md](leapp_lineage.md) ·
[differentiation_from_leapp.md](differentiation_from_leapp.md) ·
[contribution_strategy.md](contribution_strategy.md) ·
[../distance_novelty.md](../distance_novelty.md)

---

## 1. One-sentence positioning

We extend **LeAPP’s stroke factorial** (anatomy mitigation × lesion-aware ACT)
to **TBI** with a **3×2 design** (original / neuroLIT / VBT × standard / lesion-aware ACT),
cohort-scale reproducible infrastructure, and TBI-specific failure modes — a
**framework-extension** paper, not a new framework-formation.

---

## 2. Prior work map (what exists)

| Prior work | Population | Core method | Primary outcome / claim | Gap for TBI factorial |
|------------|------------|-------------|-------------------------|------------------------|
| **Bey et al. 2024 LeAPP** (*HBM*) | Stroke | 2×2 VBT × ACT; synthetic-lesion validation | Connectome sensitivity by arm | Stroke-centric; 2 anatomy backends; TBI morphology not primary |
| **Radwan et al. VBG** | Stroke | Virtual brain graft | Registration / segmentation | Single anatomy trick, not factorial with ACT |
| **Pollak et al. neuroLIT** | Stroke/TBI-adjacent | DL T1 inpainting | Segmentation / downstream SC | Not cohort factorial vs VBT/orig |
| **Smith et al. ACT / lesion-aware tractography** | General | Pathology in seeding | Streamline behavior near lesion | Not crossed with anatomy mitigation at scale |
| **Smith et al. / MRtrix ACT literature** | Healthy + lesion | 5TT + ACT | Standard vs lesion ACT | LeAPP quantified; TBI 3-way anatomy not |
| **TRACK-TBI imaging** (Palacios 2022 etc.) | TBI | Standard DTI + GOSE | Outcome association | Not factorial preprocessing science |
| **ENIGMA Brain Injury** (Caeyenberghs 2024) | TBI | rs-fMRI practices review | Reproducibility guidance | No SC factorial |

Deep summaries: [leapp_lineage.md](leapp_lineage.md).

---

## 3. Our claimed contributions (novelty axes)

| # | Claim | Distance axis | Closest prior | Evidence required (not optional) |
|---|--------|---------------|---------------|----------------------------------|
| C1 | **First cohort-scale 3×2 factorial SC in TBI** (orig / neuroLIT / VBT × std / lesion ACT) | Population + method | LeAPP 2×2 stroke | N per arm ≥ prespecified threshold; QC-by-arm table |
| C2 | **neuroLIT as third anatomy backend** in factorial design | Method | Pollak inpainting; LeAPP VBT only | Arm contrast effect sizes; failure modes |
| C3 | **TBI-specific preprocessing failures documented** (e.g. VBT + negative sform) | Method + infrastructure | LeAPP stroke assumptions | [vbt_orientation_finding.md](vbt_orientation_finding.md); supplement cases |
| C4 | **Reproducible HPC stack** (Snakemake, containers, provenance JSON, BIDS arms) | Infrastructure | LeAPP public repo (less container DAG depth) | Digest table; rerun from markers |
| C5 | **Actionable guidance** (optional Tier 1: lesion-topology → recommended arm) | Interpretation | LeAPP sensitivity only | Decision tree validated on holdout subjects |
| C6 | **BIDS / fmap repair at cohort scale** (Case-2 phasediff) | Infrastructure | Ad hoc site fixes | [sidecar_repair_finding.md](sidecar_repair_finding.md) |

Ranked enhancements beyond baseline four: [differentiation_from_leapp.md](differentiation_from_leapp.md).

---

## 4. What we do **not** claim (avoid reviewer pushback)

- A **new tractography algorithm** (we compare preprocessing arms on shared QSIRecon/MRtrix stack).
- **Outcome prediction** as Paper 1 primary (belongs to Paper 2).
- **Superiority of one arm for all TBI** without lesion-stratified analysis (heterogeneity is the point).
- Equivalence to **LeAPP synthetic-lesion validation** unless Tier 0 synthetic work is executed ([neuroimage_prerequisites.md](neuroimage_prerequisites.md)).

---

## 5. Validation checklist (contribution → result)

| Claim | Analysis (see [analysis_plan.md](analysis_plan.md)) | Pass criterion (draft) |
|-------|------------------------------------------------------|-------------------------|
| C1 | Within-subject `*-std` vs `*-lesion`; 2×3 anatomy × ACT interaction | Pre-specified primary contrast significant with FDR; report effect size distribution |
| C2 | neuroLIT vs orig vs VBT holding ACT fixed | Non-trivial matrix delta vs orig; document inpaint QC |
| C3 | Case studies + cohort failure log | Publishable supplement figure |
| C4 | Completion tracker + container digests | ≥80% completion in ≥4 arms at locked N |
| C5 | Topology-stratified arm recommendation | Δconnectome or downstream metric favors pre-specified arm in ≥2 strata |

**Novelty is not validated until this table has filled “Pass criterion” cells on real cohort data.**

---

## 6. Suggested Related work paragraph order (manuscript)

1. TBI + structural connectomics burden (Palacios, Warren).  
2. Focal lesion breaks standard pipelines (registration, ACT).  
3. LeAPP factorial in stroke (Bey 2024) — direct template.  
4. Anatomy mitigations: VBG, neuroLIT.  
5. Lesion-aware ACT (Smith / LeAPP).  
6. **Gap:** no TBI cohort factorial with neuroLIT + VBT + reproducible infra.  
7. **Our study** — six arms, pre-specified contrasts, QC-first reporting.

---

## 7. Key citations (minimum set)

- Bey T et al. 2024 LeAPP. *Human Brain Mapping*. doi:10.1002/hbm.26701  
- Pollak et al. neuroLIT (see pipeline refs).  
- Radwan VBG lineage (see [leapp_lineage.md](leapp_lineage.md)).  
- Palacios EM et al. 2022 TRACK-TBI DTI. *J Neurotrauma*.  
- Caeyenberghs K et al. 2024 ENIGMA Simple Seven. *NeuroImage: Clinical*.

Full bibliography: [../../references.md](../../references.md).
