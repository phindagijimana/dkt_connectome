# Paper 2B — manuscript skeleton

**Framing:** imaging / methods only — **no Results on GOSE.**

**Related:** [paper2b_abstract.md](paper2b_abstract.md) · [../journal_tier.md](../journal_tier.md) §1 (NeuroImage methods)

---

## Title

**Locked:** _______________________________

---

## Abstract (~250 words)

See [paper2b_abstract.md](paper2b_abstract.md).

---

## Introduction (~1000 words)

1. Focal TBI → network dysfunction; SDC as intermediate variable (cite Griffis 2019 briefly — stroke).  
2. Normative-atlas SDC (LQT, BCB) — scalable, dominant practice.  
3. TBI breaks template assumptions (mass effect, bilateral, oedema).  
4. Patient-specific lesion-aware tractography (LeAPP, Radwan) — feasible but rarely benchmarked vs LQT **in same TBI subjects**.  
5. Functional disconnection (Arm B) as **downstream imaging validation** without clinical outcomes.  
6. **Aims:** RQ1–RQ3 from [planning.md](planning.md).

---

## Methods (~2500 words)

1. **Cohort** — inclusion: lesion ROI, ses-2WK DWI + rs-fMRI; N and exclusions.  
2. **Patient-specific SDC** — neurolit-lesion arm, Step 4.1, DKT-78, Option C policy.  
3. **LQT** — version, MNI lesion, parcellation alignment to DKT-78.  
4. **BCB (optional)** — voxel maps → parcel aggregates.  
5. **rs-fMRI** — fMRIPrep, XCP-D primary; fMRIStroke sensitivity; DKT Arm B; lesion spared FC.  
6. **Statistics** — edge-wise r, cohort summaries, SC↔FC association comparison, permutation/bootstrap (lock in analysis plan).  
7. **Reproducibility** — containers, `analysis/paper2b/`, provenance JSON.

---

## Results (~2000 words)

- **Table 1** — imaging cohort demographics (age/sex if available from BIDS/participants.tsv only — **not** GOSE).  
- **Figure 1** — pipeline schematic (patient-specific vs LQT vs Arm B).  
- **Figure 2** — representative subject: lesion, patient D, LQT D, Arm B.  
- **Figure 3** — cohort distribution of patient-specific vs LQT edge correlation.  
- **Figure 4** — lesion volume (or oedema) vs divergence.  
- **Figure 5** — SC↔FC association: patient-specific vs LQT (per subject or cohort summary).  
- **Table 2** — stratified divergence (location / bilaterality).  
- **Supplement** — fMRI stream agreement; BOLD provenance; BCB concordance if run.

---

## Discussion (~1200 words)

1. When normative SDC fails in TBI.  
2. Relation to stroke literature (Griffis — mechanism without claiming recovery).  
3. SC↔FC coupling interpretation and limitations (edge vs network level).  
4. Recommendations for connectome studies (report comparator choice).  
5. **Limitations:** N, single-site pilot, LQT parcellation mismatch risks, fMRIPrep BOLD fallback.  
6. **Future:** Paper 2 outcomes extension; cohort scale.

---

## Data and code

- BIDS derivatives path; GitHub tag; LQT version; `run_paper2b_analysis.sh`.
