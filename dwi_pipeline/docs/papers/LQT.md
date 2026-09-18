# LQT — Lesion Quantification Toolkit + normative-atlas disconnection

**Purpose:** reference summary of the Lesion Quantification Toolkit (LQT) and
the broader **normative-atlas structural disconnection** family of methods that
LQT belongs to. Written for Paper 2 planning — the head-to-head comparator our
patient-specific lesion-aware pipeline is measured against.

**Related docs:** [paper2_disconnectome_outcomes.md](paper2_disconnectome_outcomes.md) ·
[journal_tier.md](journal_tier.md) ·
[Griffis_later.md](Griffis_later.md) ·
[../lesion_aware.md](../lesion_aware.md)

---

## What LQT is

- **Developer / lab:** Joseph Griffis, Corbetta lab (Washington University).
- **Reference:** Griffis, Metcalf, Corbetta, Shulman (2021), *Lesion Quantification Toolkit: A MATLAB software tool for estimating grey matter damage and white matter disconnections in patients with focal brain lesions.* **NeuroImage: Clinical 30:102639.** DOI: [10.1016/j.nicl.2021.102639](https://doi.org/10.1016/j.nicl.2021.102639)
- **Repo:** [https://github.com/JDGriffis/lesion-quantification-toolkit](https://github.com/JDGriffis/lesion-quantification-toolkit)
- **Language:** MATLAB (primary); third-party Python wrappers exist.
- **License:** open source (GPL).

LQT is a packaged implementation of the **normative-atlas structural
disconnection** approach that Griffis's 2019 Cell Reports paper used
informally, then hardened into a distributable tool in 2021. It became one of
the two field-standard tools for computing structural disconnection from a
lesion mask alone (the other being BCBtoolkit — see below).

---

## The normative-atlas structural disconnection approach

Conceptually, all normative-atlas SDC tools follow the same recipe:

1. **Input:** a binary lesion mask in a standard space (MNI 152).
2. **Reference:** a normative white-matter tractography atlas built from healthy participants — typically the HCP-842 tractogram (Yeh et al. 2018, N=842 HCP subjects, ~500K streamlines per subject aggregated into a canonical population atlas).
3. **Intersection:** for each streamline in the atlas, ask *does this streamline pass through the lesion mask?* Streamlines that do are considered "disconnected" by the lesion.
4. **Aggregation to parcels or tracts:**
   - **Parcel-to-parcel disconnection matrix:** for each pair of atlas-defined parcels (e.g. AAL, Yeo, Schaefer), count how many streamlines connecting them are disconnected. Normalize by total streamlines between that parcel pair. Output is a symmetric N×N matrix.
   - **Named-tract disconnection:** for each anatomically-labelled tract (corticospinal, arcuate, IFOF, etc.), compute the fraction of tract streamlines disconnected. Output is a per-tract severity vector.
5. **Grey matter damage overlay:** for atlas parcels, compute the fraction of parcel voxels intersected by the lesion — a companion "cortical damage" score.

**What LQT specifically produces per subject:**

- Parcel-to-parcel SDC matrix (AAL, Brainnetome, Schaefer, Yeo — user-selectable)
- Tract-level disconnection severity (JHU-tracts atlas + HCP-derived tract labels)
- Parcel-level cortical damage
- Ventricular / white-matter overlap flags for QC
- Output as CSV / MATLAB `.mat` per subject

**Runtime:** ~minutes per subject (dominated by mask registration + streamline intersection). Trivially parallelizable across subjects.

---

## Why normative-atlas SDC became dominant

The approach's appeal is entirely operational:

1. **No patient DWI required.** Only a lesion mask normalized to MNI. In clinical cohorts where DWI acquisition is inconsistent, incomplete, or of poor quality (motion, low SNR, few directions), the normative-atlas approach yields a SDC score anyway.
2. **Scalable.** Minutes per subject vs. hours for patient-specific tractography.
3. **Reproducible.** The same atlas + same lesion mask always gives the same SDC — no per-subject algorithmic instability from tractography.
4. **Standardized across sites.** Every group using LQT is using the same HCP-842 tract atlas, so cross-cohort meta-analyses are computationally trivial.
5. **Deterministic.** No random-seed dependence, no tractography-parameter sensitivity, no `iFOD2 vs SD_Stream` debate.

These properties made LQT-style SDC the default in stroke lesion-symptom-mapping work from ~2019 onward.

---

## The implicit assumption LQT makes

**LQT assumes that individual patient anatomy conforms to the healthy normative template used to build the tract atlas.**

Concretely:

- The lesion is registered to MNI, then overlaid on tracts that were drawn from HCP participants without lesions.
- The tract paths are the *average* paths across the HCP population — they do not represent the individual patient's actual white-matter routes.
- Any anatomical distortion in the patient (mass effect, oedema, ventricular expansion, midline shift, bilateral injury) that would displace real tracts from their template positions is invisible to LQT.

This assumption is largely defensible in ischemic stroke:

- Stroke lesions typically respect one vascular territory (MCA, PCA, etc.).
- Stroke is unilateral in >90% of cases.
- Oedema in chronic stroke has usually resolved by the 2-week imaging window.
- Tract displacement from the healthy template is modest.

The assumption is much more strained in traumatic brain injury:

- TBI lesion topology is heterogeneous — contusion, oedema, hemorrhage, diffuse axonal injury, and their combinations.
- TBI is bilateral in a substantial fraction of cases (~30–40% for moderate-severe TBI).
- Oedema and mass effect actively displace tracts from template positions.
- Ventricular expansion (both immediate from mass effect and chronic from atrophy) changes intracranial geometry.

**This is the specific gap that motivates our Paper 2 methods contribution:**
in TBI, patient-specific lesion-aware tractography should produce systematically
different SDC estimates than normative-atlas LQT — and the difference should
carry clinical signal.

---

## What LQT produces and how it maps to our outputs

| LQT output | Our equivalent |
|------------|----------------|
| Parcel-to-parcel SDC matrix (MNI atlas parcels) | `disconnection_matrix.csv` from `Step 4.1 disconnectome` (patient-DWI DKT parcels; also available in Schaefer/4S) |
| Named-tract disconnection severity | Not a first-class output of our pipeline; would need to compute from the tractogram + named-tract atlas |
| Cortical damage per parcel | `lesion_roi_metrics.csv` from `Step 4.1 disconnectome` (edge-level D per parcel) |
| Per-subject JSON QC / provenance | Not standard in LQT (LQT emits MATLAB `.mat`); ours: `disconnectome.json` + `disconnectome_qc.html` |

**Convertibility for head-to-head comparison:**

- LQT outputs parcels in atlas space (MNI); our outputs are in patient-DWI space via DKT.
- To compare edge-wise, both must be in the same parcellation. Options:
  1. Run LQT with the DKT atlas (LQT accepts custom atlases).
  2. Run our pipeline with Schaefer 200 atlas (already supported by QSIRecon) and compare against LQT+Schaefer.
- Voxel-wise comparison against BCBtoolkit's continuous disconnection maps would use MNI-normalized versions of both.

---

## Practical steps to add LQT to our workflow

For the Paper 2 head-to-head:

1. **Install LQT.** MATLAB required. Alternatives: run LQT in a MATLAB container / use MATLAB compiler runtime + compiled LQT / port key functions to Python if MATLAB access is a constraint.
2. **Normalize lesion masks to MNI.** Our pipeline already registers T1w to MNI via FreeSurfer + QSIRecon; extend to explicit lesion-mask normalization.
3. **Choose comparable atlas.** Schaefer 200 recommended for cross-comparability; or LQT with DKT.
4. **Run LQT per subject.** Batch over the Paper 2 subset.
5. **Compare against our SDC per subject.**
   - Edge-wise Pearson correlation
   - Distribution of correlations across cohort (violin plot)
   - Cases with r < 0.5 flagged for follow-up
   - Stratify by lesion features (volume, laterality, mass-effect metric if available)
6. **Downstream tests.**
   - FC-abnormality prediction: cross-validated R² per SDC method
   - GOSE prediction: cross-validated AUC per SDC method, both with lesion volume held constant
7. **Discussion.**
   - Where do the methods diverge? (probably: high-mass-effect, bilateral, high-volume)
   - Does divergence have clinical consequence? (patient-specific SDC beats LQT on downstream?)
   - Recommendation: default to patient-specific in TBI cohorts with significant lesion morphology.

---

## Strengths of LQT

- **Adoption:** widely used in stroke lesion-mapping community (>>100 published applications since 2021).
- **Standardization:** everyone using the same atlas + same tool = easy meta-analysis.
- **Speed:** minutes per subject.
- **Data-frugal:** no patient DWI needed.
- **Interpretability:** outputs map cleanly to named tracts and standard atlases.
- **Documentation:** published methods paper (Griffis 2021 NeuroImage: Clinical) with clear parameter descriptions.

## Limitations of LQT (relevant to TBI paper)

- **Anatomical-template assumption breaks in TBI.** See above.
- **MATLAB dependence.** Not trivial in Linux HPC environments without MATLAB licenses.
- **No per-subject provenance JSON.** Reproducibility is at the tool level, not the run level.
- **Single normative atlas (HCP-842).** Sensitivity to atlas choice is not exposed to the user.
- **Deterministic in a rigid way.** No mechanism to represent uncertainty about tract paths in the individual.
- **Aggregates over subjects at tract-atlas construction time.** A distortion in one subject cannot influence that subject's SDC — the atlas is fixed.

---

## Alternative normative-atlas tools (LQT is not alone)

| Tool | Lab | Reference | Distinguishing feature |
|------|-----|-----------|------------------------|
| **LQT** | Griffis / Corbetta (WashU) | Griffis 2021 NI:Clinical | Parcel-to-parcel matrix + named-tract severity |
| **BCBtoolkit** | Thiebaut de Schotten (Sorbonne / GIN Bordeaux) | Foulon 2018 GigaScience | Voxel-level disconnection probability maps; Tractotron for named tracts |
| **NeMo Tool** (Network Modification) | Kuceyeski (Weill Cornell) | Kuceyeski 2013 NeuroImage | Predecessor of LQT; uses NKI-Rockland normative connectome |
| **Disconnectome Symptom Mapping (DSM)** | Talozzi / Thiebaut de Schotten | Talozzi 2023 Brain | Latent-space disconnectome; predicts long-term symptoms |

All share the normative-atlas approach; they differ in atlas source, output format, and downstream statistical framework.

---

## Bottom line for our paper

- LQT is the **current field standard** for stroke SDC and is being applied to TBI cohorts by other groups.
- The **anatomical-template assumption is a specific weakness in TBI** — this is exactly where our patient-specific lesion-aware tractography should differ.
- **Our Paper 2 methods contribution requires an LQT + BCBtoolkit head-to-head** — this document is the reference for how to set that up and what to expect.
- **Expected outcome:** LQT and our SDC agree in low-mass-effect, unilateral, small-lesion subjects; diverge in high-mass-effect, bilateral, large-lesion subjects; divergence carries FC/behavior signal.

---

## See also

- [Griffis_later.md](Griffis_later.md) — follow-up work by Salvalaggio, Thiebaut de Schotten, Kuceyeski that established normative-atlas SDC as the field standard.
- [paper2_disconnectome_outcomes.md § Our contribution relative to Griffis 2019](paper2_disconnectome_outcomes.md#our-contribution-relative-to-griffis-2019--expanded) — how LQT slots into our contribution argument.
- [../lesion_aware.md](../lesion_aware.md) — our patient-specific alternative approach.
- [../disconnectome.md](../disconnectome.md) — Step 4.1 methods.
