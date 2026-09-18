# Griffis-lineage follow-up work — Salvalaggio, Thiebaut de Schotten, Kuceyeski, and successors

**Purpose:** summary of the influential follow-up work that built on the
Griffis 2019 SC → FC → behavior framework, extending normative-atlas
structural disconnection into new domains, statistical formalisms, and
patient populations. Written for Paper 2 planning — this is the literature
our disconnectome-outcomes paper will be judged against.

**Related docs:** [paper2_disconnectome_outcomes.md](paper2_disconnectome_outcomes.md) ·
[LQT.md](LQT.md) · [journal_tier.md](journal_tier.md)

**Caveat:** specific numerical claims (N per cohort, exact ΔAUC values, exact
methodological parameters) should be verified against source papers before
being cited in a manuscript. This document summarizes conceptual contributions
and the shape of each paper's argument.

---

## The lineage in one figure

```
Griffis 2019 Cell Reports (stroke N≈114)
   │  SDC → FC → behavior chain, HCP-normative atlas SDC
   │
   ├──────────────────────────────────────────────┐
   │                                              │
   ▼                                              ▼
Salvalaggio 2020 Brain                    Griffis 2021 NI:Clinical
(stroke N≈155,                            (LQT toolkit release)
 multi-domain outcome prediction)
   │
   ▼
Talozzi 2023 Brain                        Kuceyeski lineage:
(latent disconnectome                     NeMo (2013) — pre-Griffis
 for long-term symptoms)                  Kuceyeski 2019 Nat Comm
                                          (connectome-based prediction)
                                          Kuceyeski 2020 HBM (mTBI)
```

---

## 1. Salvalaggio et al. 2020 — extending Griffis to multi-domain outcome prediction

**Reference:** Salvalaggio, De Filippo De Grazia, Zorzi, Thiebaut de Schotten,
Corbetta (2020). *Post-stroke deficit prediction from lesion and indirect
structural and functional disconnection.* **Brain 143(7):2173–2188.** DOI:
[10.1093/brain/awaa156](https://doi.org/10.1093/brain/awaa156)

### What they did

Building directly on Griffis 2019, Salvalaggio et al. tested whether
structural disconnection (computed via LQT-style normative-atlas overlay) and
functional disconnection (a novel construct) could predict multi-domain
behavioral outcomes in the same WashU stroke cohort. Key features:

- Same cohort infrastructure as Griffis 2019 (WashU / Corbetta / Shulman stroke cohort).
- Extended sample (~155 stroke patients).
- Used **both** structural disconnection (SDC) and a construct they called
  **indirect functional disconnection** (predicted FC changes from lesion
  location using a mapping learned on healthy controls).
- Multi-domain behavioral battery from Corbetta 2015 factor scores (motor,
  language, attention, memory, visual).
- Trained multivariate ridge regression models to predict each behavioral
  domain from (a) lesion size, (b) SDC, (c) indirect FC, and (d) combinations.
- Cross-validated with permutation testing.

### What they found (conceptual)

- SDC and indirect FC predicted behavior with cross-validated correlations
  that clearly exceeded lesion-size-only baselines across most domains.
- SDC was most informative for motor and language domains.
- Indirect FC added incremental value on top of SDC for attention and memory
  domains — suggesting that structural disconnection alone doesn't capture
  everything about functional network disruption relevant to cognition.
- The best-performing models combined SDC + indirect FC — establishing the
  practical value of combining structural and functional views.

### Why it matters for our paper

- **Establishes the multi-domain outcome format as standard practice** — a
  paper about disconnection-and-outcome without domain-specific analyses will
  be judged against this precedent.
- **Combined SDC + FC modeling is now expected** — our Paper 2 needs to include
  both, not just SDC → outcome. Our RQ2 (incremental validity vs lesion volume)
  needs a further RQ3 (incremental validity of adding FC on top of SDC).
- **Cross-validated ridge regression is the reviewer-expected framework** —
  we should adopt this exact framework rather than inventing our own.
- **They used LQT-style normative-atlas SDC on stroke, where the anatomy-
  template assumption is valid.** Our TBI extension needs to demonstrate that
  the same framework holds when the assumption is strained — or that
  patient-specific SDC is required.

### What our paper adds vs Salvalaggio

- **Population:** TBI vs stroke.
- **SDC method:** patient-specific lesion-aware tractography vs LQT normative-atlas.
- **FC method:** empirical rs-fMRI FC-abnormality vs their "indirect FC" (predicted from lesion location).
- **Testable hypothesis:** in TBI, the extra machinery (patient DWI + lesion-aware ACT + empirical FC) captures signal that normative-atlas + indirect FC cannot.

---

## 2. Thiebaut de Schotten lab lineage — BCBtoolkit → latent disconnectome

The Michel Thiebaut de Schotten group (Sorbonne / GIN Bordeaux) built a
parallel line of normative-atlas disconnection tools and applications that
now define an alternative pole of the field.

### 2a. Foulon et al. 2018 — BCBtoolkit

**Reference:** Foulon, Cerliani, Kinkingnéhun, Levy, Rosso, Urbanski, Volle,
Thiebaut de Schotten (2018). *Advanced lesion symptom mapping analyses and
implementation as BCBtoolkit.* **GigaScience 7(3):giy004.** DOI:
[10.1093/gigascience/giy004](https://doi.org/10.1093/gigascience/giy004)

Introduced BCBtoolkit — the alternative to LQT — with voxel-level continuous
disconnection probability maps (not just parcel-to-parcel matrices). See
[LQT.md](LQT.md) for the comparison table.

Key methodological innovations relevant to Paper 2:

- **Continuous disconnection probability per voxel** — richer output than
  binary edge disconnection, better suited to voxel-wise lesion-symptom mapping.
- **Tractotron** — a companion tool that maps lesion onto major named tracts
  with a per-tract disconnection probability.
- **Statistical framework for lesion-symptom mapping** that integrates
  disconnection maps as predictors.

### 2b. Talozzi et al. 2023 — Latent disconnectome

**Reference:** Talozzi, Forkel, Pacella, Nozais, Allart, Piscicelli, Pérennou,
Tournier, Zaidat, Corcoran, ..., Thiebaut de Schotten (2023). *Latent
disconnectome prediction of long-term cognitive-behavioral symptoms in
stroke.* **Brain 146:1963–1978.** DOI:
[10.1093/brain/awad013](https://doi.org/10.1093/brain/awad013)

### What they did

- Constructed a **latent-space representation of disconnectome maps** across
  a large stroke cohort using unsupervised dimensionality reduction (variational
  autoencoder / matrix factorization approaches).
- Showed that a small number of **latent disconnectome components** capture
  the majority of anatomical variability in stroke disconnection patterns.
- These latent components predicted long-term (chronic, > 3 months post-stroke)
  cognitive-behavioral symptoms across multiple domains.
- Argued that latent representations offer better generalizability than raw
  parcel-to-parcel matrices (which have many correlated dimensions and are
  hard to interpret in high-dimensional regression).

### Why it matters for our paper

- **Latent representations are becoming the standard for disconnectome →
  outcome models** at large cohort scales. Raw N-choose-2 edge features may
  now be seen as an older approach.
- Cross-validation frameworks in this space have matured — CCA (Griffis 2019),
  ridge regression (Salvalaggio 2020), and now latent/deep-learning (Talozzi
  2023) form a spectrum of options.
- For our N ~50–100 TBI cohort, latent methods may be unnecessary (few
  latent components would be estimable), but citing this work anchors us in
  the current methodological frontier.
- **Chronic-phase outcome (Talozzi 2023) vs acute-imaging → medium-term-outcome
  (our design)** — worth distinguishing in the discussion.

### What our paper adds vs Talozzi

- **Population:** TBI vs stroke.
- **SDC method:** patient-specific vs normative-atlas.
- **Cohort scale:** likely smaller, so latent-space methods are less applicable.
- **Contribution level:** methodological (novel SDC computation) rather than
  statistical (novel dimensionality reduction).

---

## 3. Kuceyeski lineage — NeMo Tool and connectome-based prediction

Amy Kuceyeski's group (Weill Cornell) has a long-standing programme on
network-modification prediction of behavior across neurological populations
including stroke, TBI, and neurodegenerative disease.

### 3a. Kuceyeski et al. 2013 — NeMo Tool

**Reference:** Kuceyeski, Maruta, Relkin, Raj (2013). *The Network Modification
(NeMo) Tool: elucidating the effect of white matter integrity changes on
cortical and subcortical structural connectivity.* **Brain Connectivity 3(5):451–463.**
DOI: [10.1089/brain.2013.0147](https://doi.org/10.1089/brain.2013.0147)

The NeMo Tool predates and philosophically prefigures LQT:

- Takes a lesion or ROI mask in MNI space.
- Overlays on a **normative connectome** built from an independent healthy
  reference cohort (originally NKI-Rockland).
- Estimates which cortical and subcortical connections are affected.
- Outputs "Change in Connectivity" (ChaCo) scores per region.

**Relationship to LQT:** NeMo was the first widely-used tool of the normative-
atlas SDC family. LQT (2021) has become more widely adopted in recent stroke
work, but NeMo remains a valid alternative and is periodically referenced.
Some groups still cite NeMo scores in comparison papers.

### 3b. Kuceyeski et al. 2019 — Connectome-based cognitive prediction

**Reference:** Kuceyeski et al. (2019). *The functional and structural connections
best predicting individual cognitive performance.* **Nature Communications**
(exact citation to verify; ~2019–2020 timeframe).

Key contribution:

- Compared structural and functional connectivity's predictive value for cognition.
- Established methodological priors that carried into the stroke/TBI literature:
  which connectivity features carry cognitive signal, and how to model them.

### 3c. Kuceyeski et al. 2020 — mTBI longitudinal connectome

**Reference:** Kuceyeski et al. (2020). *Longitudinal connectome findings in
mild traumatic brain injury.* **Human Brain Mapping** (exact citation to verify).
Already referenced in [publication_strategy.md](publication_strategy.md) as an
analog for Paper 4 (longitudinal resource).

- Longitudinal connectome + cognitive-outcome study in a modest mild TBI cohort
  (N=26).
- Established the feasibility of connectome-cognition modeling in TBI at
  small-to-moderate scale.
- Relevant to Paper 2 as a TBI-specific precedent for connectome-outcome links
  (though at a smaller scale and without lesion-mask-driven disconnection).

### Why the Kuceyeski lineage matters for our paper

- **NeMo is a normative-atlas SDC tool we should be aware of** — if reviewers
  ask "why LQT and BCBtoolkit but not NeMo?", we should have a considered
  answer (LQT and BCBtoolkit are more widely cited in current stroke work;
  NeMo could be added as a sensitivity comparator if reviewers request).
- **Kuceyeski's TBI connectome work sits at HBM tier with N=26** — this
  informs our tier expectations: at N=50–100 with a stronger disconnection
  framework and clinical outcomes, we should be able to hit at least HBM,
  potentially Brain.
- **Connectome-cognition modeling frameworks (Kuceyeski) inform our RQ3
  (domain-specific network → deficit mapping)** — the Kuceyeski papers have
  worked out much of the statistical machinery we'd adopt.

---

## 4. Parallel lineage — Boes / Fox / Kletenik lesion-network mapping

An adjacent but distinct methodological family developed in parallel to the
Griffis SDC lineage. Where Griffis-style SDC uses **structural** (white-matter
tract) disconnection, Boes/Fox-style **lesion network mapping (LNM)** uses
**functional** connectivity from a normative rs-fMRI atlas to identify
brain networks affected by the lesion. Both lineages sit under the umbrella
of "lesion → network dysfunction → symptom" work but arrive at it from
different modalities.

### 4a. Boes et al. 2015 — Lesion network mapping

**Reference:** Boes, Prasad, Liu, Liu, Pascual-Leone, Caviness, Fox (2015).
*Network localization of neurological symptoms from focal brain lesions.*
**Brain 138(10):3061–3075.** DOI:
[10.1093/brain/awv228](https://doi.org/10.1093/brain/awv228)

**What they did:**
- Instead of asking *which tracts does the lesion damage?*, asked *which
  functional networks does the lesion location connect to in a healthy brain?*
- Overlaid patient lesion masks (MNI) on a **normative rs-fMRI connectivity
  atlas** built from healthy participants.
- For each voxel in the lesion, extracted the healthy-brain functional
  connectivity map — i.e. which distant voxels are functionally connected to
  the lesioned area in healthy people.
- Aggregated across all voxels of the lesion to produce a per-patient
  "lesion network map."
- Showed that specific neurological symptoms map to specific lesion networks
  across heterogeneous lesion locations.

**Why it matters for our paper:**
- Established the lesion-network-mapping paradigm — a **parallel** approach
  to Griffis-style SDC that is now widely used.
- Foundational reference in the broader "lesion → network" literature that
  reviewers expect to see cited.
- **Contrast to our approach:** we use *patient-specific* SDC from *individual
  DWI*; Boes uses *normative* FC from *lesion location alone*. Both use
  normative reference data, but Boes doesn't need patient imaging beyond the
  lesion mask.

### 4b. Fox 2018 — Lesion network mapping paradigm (editorial synthesis)

**Reference:** Fox (2018). *Mapping symptoms to brain networks with the human
connectome.* **New England Journal of Medicine 379(23):2237–2245.** DOI:
[10.1056/NEJMra1706158](https://doi.org/10.1056/NEJMra1706158)

**What it did:**
- Editorial-style review in *NEJM* synthesizing the lesion-network-mapping
  paradigm for a clinical audience.
- Established the terminology, method framework, and clinical potential of
  mapping lesion locations to human-connectome-atlas-defined networks.
- High-visibility reference — the *NEJM* citation lends legitimacy to the
  broader network-mapping approach.

**Why it matters for our paper:**
- Not a direct methodological precedent (it's a review, not a primary study)
  but the highest-visibility overview of the parallel lineage.
- Cite in Paper 2 introduction alongside Griffis 2019 to position our work in
  the broader "lesion → network → symptom" landscape.
- If reviewers ask why we don't use lesion network mapping directly, this is
  the paper that describes what they'd be asking us to do — and we can
  distinguish our SDC-based approach as complementary.

### 4c. Kletenik and follow-up applications

Multiple papers from Fox's lab (2020–2023) applied lesion network mapping to
diverse symptom domains — depression, memory, addiction, movement disorders,
etc. Not directly comparable to our disconnection-outcomes paper, but the
broader field is aware of them.

The Griffis 2019 → Salvalaggio 2020 → Talozzi 2023 line is the **direct
lineage** we're extending. The Boes 2015 → Fox 2018 → Kletenik lineage is a
**parallel lineage** on rs-fMRI-based lesion network mapping that we cite for
completeness in the intro but do not directly extend.

## 4d. Additional lineage references worth knowing

Beyond the parallel LNM lineage, the following are frequently cited:

| Paper | Contribution | Relevance to Paper 2 |
|-------|--------------|----------------------|
| **Yeh et al. 2018 NeuroImage** — HCP-842 tractography atlas | The normative tractogram everyone uses | Underpins LQT + NeMo; cite in methods |
| **Griffis et al. 2020 Brain** — network dysfunction in stroke followup | Extended 2019 framework longitudinally | Cite in intro |
| **Corbetta et al. 2015 Neuron** — WashU stroke behavior battery | Multi-domain factor analysis of behavior | Motivates neuropsych domain-specificity we adopt |

---

## 5. What these papers establish as expected practice

Any Paper 2 submitted to HBM / Brain / NeuroImage will be judged against the
methodological standards these papers have established:

- [ ] **Normative-atlas SDC as a baseline comparator** — LQT or BCBtoolkit; we do this.
- [ ] **Multi-domain behavioral outcomes** — Corbetta-style factor scores or equivalent domain composites.
- [ ] **Cross-validated regression with permutation testing** — ridge / linear / logistic + null shuffling.
- [ ] **Incremental validity vs lesion volume** — Griffis 2019's foundational move.
- [ ] **Incremental validity of FC on top of SDC** — Salvalaggio's extension.
- [ ] **Face-validity group-average disconnectome figure** — spatial coherence with lesion topology before jumping to outcomes.
- [ ] **Combined structural + functional model** — expected, not just structural.
- [ ] **Discussion positioning against Griffis / Salvalaggio / Talozzi** — reviewers will expect explicit comparison.
- [ ] **Reproducibility statement** — Griffis has released LQT open-source; our containers + provenance JSON must be at parity.

Missing more than 1–2 of these will get us bumped from Brain to HBM or from
HBM to a lower-tier venue.

---

## 6. Implications for our Paper 2 positioning

### Where we sit in the lineage

- **Direct extension of Griffis 2019** to TBI, adopting the chain and the
  statistical framework.
- **Direct extension of Salvalaggio 2020** to include patient-specific SDC.
- **Adjacent to Talozzi 2023** — same era, different methodological direction
  (they went latent; we go patient-specific).
- **Complementary to Kuceyeski TBI work** — same population, different framing
  (they emphasize network trajectories; we emphasize disconnection mechanism).

### What's still open in the literature (and defensible for us to claim)

1. **Patient-specific vs normative-atlas SDC has not been systematically
   compared at cohort scale in TBI.** This is our primary methodological
   contribution.
2. **The Griffis chain (SC → FC → behavior) has not been formally tested in
   TBI at cohort scale.** Salvalaggio and Talozzi did it in stroke; the TBI
   extension is empty.
3. **Multi-domain outcome prediction from lesion-aware disconnection has not
   been done in TBI with rs-fMRI + neuropsych + lesion masks together.**
4. **Recommendation frameworks for when to use patient-specific vs
   normative-atlas SDC in different patient populations** — nobody has
   published guidance; we could propose one.

### What is *not* open (do not claim)

- The general chain SDC → FC → behavior is established (Griffis / Salvalaggio /
  Talozzi). We do not claim its discovery.
- Normative-atlas SDC as a tool is established (LQT / BCBtoolkit / NeMo). We
  do not claim its innovation.
- Lesion-network mapping as a paradigm is established (Boes / Fox line). We do
  not claim to have invented it.
- Multi-domain factor-score behavioral analysis is established (Corbetta 2015).
  We adopt but do not claim.

### Reviewer defense — anticipated critiques

- *"How does this differ from Salvalaggio 2020?"* — TBI vs stroke, patient-specific SDC vs LQT, empirical FC vs indirect FC.
- *"Why not use LQT / BCBtoolkit if it's the field standard?"* — We use it as our comparator, not our primary method, because we hypothesize (and test) that its anatomy assumption breaks in TBI.
- *"Have you looked at Talozzi 2023 latent methods?"* — Yes; at our N these are not applicable, but latent representations are noted as future work at larger cohorts.
- *"What about NeMo?"* — Sensitivity comparator if reviewers require; not primary because LQT and BCBtoolkit are more widely applied in recent stroke work.

---

## Bottom line for our paper

The Griffis 2019 → Salvalaggio 2020 → Talozzi 2023 lineage establishes a
mature methodological framework for **stroke** disconnection-outcome
research. Our Paper 2 extends this framework in two directions:

1. **Population extension:** stroke → TBI, where the anatomy-template
   assumption is strained.
2. **Method extension:** normative-atlas SDC → patient-specific lesion-aware
   SDC, with an empirical demonstration that the extra machinery matters
   more in TBI than in stroke.

Neither extension alone is paradigm-shifting; together, and executed cleanly,
they justify a strong-tier venue (NeuroImage or Brain). Failure to execute
either well drops us to HBM.

---

## See also

- [LQT.md](LQT.md) — tool-level reference for LQT and normative-atlas SDC.
- [paper2_disconnectome_outcomes.md § Our contribution relative to Griffis 2019](paper2_disconnectome_outcomes.md#our-contribution-relative-to-griffis-2019--expanded) — full contribution breakdown.
- [journal_tier.md](journal_tier.md) — venue selection given this lineage.
- [../references.md](../references.md) — full bibliography.
