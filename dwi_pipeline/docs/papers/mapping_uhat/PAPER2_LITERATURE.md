# Paper 2 — literature map

How P2 sits in prior work. Citations are anchors for the manuscript; expand bibtex at write-up.

## 1. Connectome test–retest / weak-edge reliability

| Paper | Venue | What it gives P2 |
|---|---|---|
| Buchanan et al., 2014 | NeuroImage | TRT of structural networks; pipeline factors; nodal metrics less reliable than global |
| Schumacher et al., 2018 (+ Data in Brief) | NeuroImage / DiB | Streamline-**count** reproducibility; parameter sensitivity |
| Bonilha / related edge CV–distance | (network TRT corpus) | Longer / weaker connections less stable |
| Dimitriadis et al., 2019 | NeuroImage | Graph construction ↔ reproducibility and study power |

**P2 takeaway:** Leftover churn on weak counts is **expected**. Prediction target \(y^{\mathrm{leftover}}\) should be analyzed **stratified by strength**. Plant fragility \(U\) answering a different question (Paper 1) is consistent with this literature, not a contradiction.

## 2. Assignment / construction mechanism

| Paper | Role |
|---|---|
| Yeh et al., 2019 | NeuroImage — streamline→node assignment is consequential |
| MRtrix `tck2connectome` / Smith radial search | Operational definition of `radial_4` |

**P2 takeaway:** Endpoint assignment noise is one leftover component; count magnitude / biology / RNG are others (Paper 1 reseed floor). \(L\) is deliberately count-aware.

## 3. Uncertainty products (baselines to beat or compare)

| Line | Example | Compare to |
|---|---|---|
| Tractogram bootstrap / edge classes | e.g. bootstracts-style CV, P(nonzero) | optional \(R\); is \(L\) redundant with bootstrap CV? |
| Probabilistic tractography posteriors | voxel→track uncertainty propagation | different layer (orientation vs count leftover) |
| Soft / jittered assignment | Paper 1 \(F\), \(P_{10}\) | baselines for ranking leftover \(y\) |

**P2 takeaway:** \(P_L\) must beat naive baselines and be compared honestly to resampling reliability if available.

## 4. Calibration science (design fix for Paper 1 G fail)

| Source | Lesson |
|---|---|
| Zadrozny & Elkan; Niculescu-Mizil & Caruana | Isotonic / Platt post-hoc calibration |
| Naeini ECE | Scalar calibration error |
| sklearn calibration docs | Isotonic needs enough data; can overfit small n |
| Neuroimaging UQ calibration studies | Dataset-level vs subject-level calibration can disagree |

**P2 takeaway (mandatory citation of own fail):** Fitting \(\phi\) on **plant** \(y\) and testing on **leftover** \(y\) is domain shift — Paper 1 G ECE ≈ 0.32. P2 fits \(\phi\) on leftover \(y\) from **train subjects** only and evaluates on **held-out subjects**.

## 5. What P2 is *not* claiming from lit

- Not a new TRT ICC paper (unless scale adds ICC as secondary).  
- Not \(\hat{U}\) from registration ensembles (failed path in prior locks).  
- Not invent-cap politics from Paper 1 soft rule.
