# Journal-tier landscape — Paper 2 (clinical disconnectome in TBI)

**Purpose:** planning document for Paper 2 venue strategy. For each realistic
or stretch venue, spells out the framing that lands the paper, the analyses
required to defend it, and a section-by-section manuscript breakdown with
figure and table lists.

**As-of:** 2026-09-17. **Author:** Phind Ndagijimana (with Claude planning assist).
**Related docs:** [publication_strategy.md](publication_strategy.md) ·
[paper2_disconnectome_outcomes.md](disconnectome/outcomes_planning.md) ·
[../lesion_aware.md](../lesion_aware.md) · [../disconnectome.md](../disconnectome.md)

---

## TL;DR

Paper 2 has three viable target venues and one honest fallback:

- **NeuroImage** — if the head-to-head vs LQT/BCB normative-atlas SDC produces a quantitative divergence figure with clinical consequence in TBI. **Methods-lead framing.**
- **Brain** — if the full Griffis-2019 SC → FC → behavior chain lands cleanly on N ≥ 50 with a neuropsych battery. **Biology-lead framing.**
- **Human Brain Mapping** — safe landing under either framing at lower N or novelty bar. **Default.**
- **NeuroImage: Clinical** — TBI-focused imaging-clinical backup; publishable version of Paper 2 in almost any scenario short of pipeline collapse.

*Nature* main is not in play. *Nature Communications* is a stretch requiring an
external replication cohort (which we don't have). Design the analysis to
unlock either the methods-lead or biology-lead path, run both, then choose
venue by which contribution is quantitatively stronger — but lock the
analysis plan (contrasts, primary metrics, benchmarks) *before* opening
group results.

---

## Full venue landscape

| Venue | Realistic? | Framing that lands it | What we'd need to deliver | What we don't yet have |
|-------|-----------|----------------------|---------------------------|------------------------|
| *Nature* (main) | ❌ Not in play | Paradigm-shifting biology + broad reach beyond TBI | N > 500, multi-cohort replication, cross-disease generalizability | Everything |
| *Nature Neuroscience* | ❌ Stretch of stretch | Broad neuroscience insight beyond stroke/TBI | Very large N or exceptional mechanistic depth | Cohort scale, replication |
| *Nature Communications* | ⚠️ Stretch, conceivable | Full SC→FC→behavior + methods novelty + external replication | N ≥ 80 complete; independent replication cohort; crisp methods-vs-normative figure with clinical consequence | Replication cohort; N confirmation |
| *Nature Human Behaviour* | ⚠️ Stretch | Behavior-forward, domain-specific network mapping | Multi-domain neuropsych factor scores + clean domain-network mapping | Neuropsych battery confirmation |
| *Brain* | ✅ Realistic | Biology-lead: clinical-mechanistic story | N ≥ 50 complete cases + neuropsych + clean SC→FC coupling + incremental validity vs lesion volume | Clean cohort delivery |
| *NeuroImage* | ✅ Realistic | Methods-lead: patient-specific vs normative-atlas SDC head-to-head | Quantitative divergence figure vs LQT/BCB with downstream consequence (FC or behavior prediction) | The head-to-head analysis run |
| *NeuroImage: Clinical* | ✅ Very realistic | TBI-focused imaging-clinical | Standard clinical-imaging deliverables | Solid backup — no gap |
| *Medical Image Analysis* | ⚠️ Fit-dependent | Pipeline/engineering lead | Would require rewriting away from Griffis story | Different framing |
| *Human Brain Mapping* | ✅ Default landing | Either framing at lower N/novelty bar | Coherent whole; LeAPP was here | Nothing extra |
| *Journal of Neurotrauma* | ✅ Realistic backup | Clinical outcomes in TBI | GOSE + covariates on N ≥ 40; less demand on methods novelty | Nothing extra beyond baseline analysis |
| *Cell Reports* (Griffis's venue) | ❌ Not open | — | — | They published Griffis; won't accept extension |

**How to read the table:** ✅ means we can plausibly get there with the data we
have or expect to have. ⚠️ means the venue is conceivable but only if
specific additional deliverables land. ❌ means the venue is either editorially
closed to us or requires resources (cohort scale, replication) we do not have.

---

## Path-determination logic

Three empirical questions with unknown answers today determine which venue is
open:

| Question | If yes → | If no → |
|----------|----------|---------|
| Do patient-specific and normative-atlas SDC diverge meaningfully in TBI? | NeuroImage path viable | HBM (methods becomes supplement) |
| Is the SC→FC coupling reproducible cohort-wide? | Brain path viable | HBM |
| Do we have neuropsych battery + N ≥ 50 complete cases? | Brain path stronger | HBM |

**Strategic rule:** design the analysis to unlock either path; run both; then
choose venue by which contribution is quantitatively stronger. Do **not**
commit to a venue before results — but do lock the analysis plan (contrasts,
primary metrics, benchmarks) before opening group results.

---

# Venue deep dives

## 1. NeuroImage — methods-lead (realistic primary target)

### Editorial identity

- **Reader base:** neuroimaging methodologists, tool developers, computational imaging labs.
- **Reviewers reward:** methods innovation with quantitative validation, head-to-head comparisons against standard tools (LQT, BCBtoolkit), sensitivity/robustness across parameters, reproducibility (containers, open code, provenance).
- **Reviewers reject on:** biology-only stories without a methods contribution; qualitative rather than quantitative claims; missing benchmarks; single-atlas or single-method analyses; unclear why anyone should adopt the method.
- **Our fit:** patient-specific lesion-aware SDC (from our lesion-aware ACT pipeline) vs normative-atlas SDC (LQT / BCBtoolkit) in TBI is a proper head-to-head. Our provenance JSON + Snakemake DAG + container distribution + open-code repo directly satisfy reproducibility expectations.

**For the full contribution breakdown** (what of Griffis 2019 we adopt, where we differentiate, and the specific methods advance that unlocks NeuroImage), see [`paper2_disconnectome_outcomes.md § Our contribution relative to Griffis 2019 — expanded`](disconnectome/outcomes_planning.md#our-contribution-relative-to-griffis-2019--expanded).

### Framing

**Working title:** *Patient-specific lesion-aware disconnectomes in traumatic brain injury: a head-to-head comparison with normative-atlas approaches and consequences for network-level outcome prediction.*

**One-sentence claim:** In TBI, patient-specific lesion-aware structural disconnection matrices diverge systematically from normative-atlas disconnection maps, and the divergence carries clinical signal that improves prediction of functional-connectivity disruption and behavior beyond normative-atlas SDC alone.

**Abstract shape (~250 words):**

> *Background.* Structural disconnection (SDC) has emerged as a key mediator between focal brain lesions and network-level dysfunction. Existing SDC pipelines (LQT, BCBtoolkit) overlay lesion masks on normative white-matter atlases (HCP-842), avoiding patient-specific tractography but assuming that individual anatomy conforms to a healthy template.
>
> *Question.* In traumatic brain injury — where mass effect, oedema, and bilateral injury deform individual anatomy — does patient-specific lesion-aware tractography produce different SDC estimates than normative-atlas overlay, and does the difference matter for downstream network and behavioral prediction?
>
> *Methods.* On N=[cohort] TrackTBI subjects with clinician-traced lesion masks, we computed SDC using (1) our patient-specific lesion-aware pipeline (MRtrix `5ttedit -path`, iFOD2 + SIFT2, DKT parcellation) and (2) two normative-atlas tools (LQT, BCBtoolkit). We compared SDC maps voxel- and edge-wise, and evaluated each SDC representation's ability to predict resting-state functional connectivity disruption and 6-month GOSE.
>
> *Results.* Patient-specific SDC diverged from normative-atlas SDC in [X]% of subjects at edge magnitudes exceeding [Y]. Divergence was largest in subjects with [feature]. Patient-specific SDC predicted FC disruption with cross-validated R² of [Z], vs LQT [Z1]; and GOSE with AUC [W], vs LQT [W1]. Divergence and improvement in prediction were correlated at [ρ].
>
> *Interpretation.* Normative-atlas SDC underestimates or misroutes disconnection in TBI. Patient-specific lesion-aware tractography, previously considered too fragile in lesioned brains, is now feasible and produces clinically meaningful improvements.

### Analysis required

1. Complete our factorial pipeline on the Paper 2 subset with the fixed arm (`neurolit-lesion` default; consider `vbt-lesion` as sensitivity).
2. Run LQT on the same subjects — install the MATLAB toolkit, normalize lesion masks to MNI (already done by pipeline for other purposes), export parcel-to-parcel SDC matrices.
3. Run BCBtoolkit on the same subjects — install, produce voxel-level disconnection probability maps and (optionally) Tractotron tract-level output.
4. Edge-wise comparison: correlate patient-specific SDC and LQT SDC matrices per subject. Report distribution of correlations, cases with r < 0.5, and identify subject-level features (lesion volume, lesion location, mass-effect severity) predicting divergence.
5. Voxel-wise comparison: overlay BCB disconnection probability maps with our patient-specific tract-level disconnection scores, report spatial concordance.
6. Downstream test 1: predict resting-state FC abnormality from each SDC representation using CCA or ridge regression, cross-validated across subjects, permutation-tested for significance.
7. Downstream test 2: predict 6-month GOSE from each SDC representation, controlling for lesion volume + age + sex + GCS.
8. Robustness: reproduce with alternative parcellation (Schaefer 200) and alternative fixed arm (`vbt-lesion`).
9. Reproducibility supplement: container digests, provenance JSON schema, code repo tag.

### Manuscript breakdown

**Title.** As above.

**Abstract.** ~250 words as sketched.

**Introduction (~1000 words).**
- Widespread network dysfunction after focal lesions — Griffis et al. 2019 for stroke.
- SDC as a mediator between lesion and network dysfunction.
- Normative-atlas approaches (LQT, BCBtoolkit) are the current standard — reasons they became dominant (scalable, no patient DWI needed).
- Limits in TBI specifically: heterogeneous mass effect, oedema, bilateral injury, midline shift; individual anatomy departs from normative template.
- Our contribution: patient-specific lesion-aware tractography via `5ttedit -path`, feasibility in TBI, head-to-head with normative-atlas tools, clinical downstream test.
- Predictions: SDC divergence larger in high-mass-effect / bilateral subjects; patient-specific SDC improves FC and behavior prediction.

**Methods (~2500 words).**
- Cohort: TrackTBI subject subset (N, inclusion criteria, lesion mask provenance).
- Imaging: acquisition parameters (T1w, DWI shell b=[value], rs-fMRI TR/TE, sessions).
- Preprocessing: QSIPrep pipeline, session/fmap handling, lesion mask registration.
- Patient-specific SDC: FastSurfer recon, `5ttedit -path` with lesion mask, iFOD2 tractography, SIFT2 weighting, DKT parcellation, disconnection matrix construction (spared-connectome options A/B/C).
- Normative SDC: LQT (Griffis 2021), BCBtoolkit (Foulon 2018) — versions, parameter choices, MNI normalization procedure.
- FC processing: fMRIPrep + XCP-D or equivalent, atlas-parcel time series, connectivity matrix.
- Clinical outcomes: GOSE at 6 months, covariates (age, sex, education, GCS, lesion volume).
- Statistical models: edge-wise correlation, CCA for SDC↔FC, ridge regression with cross-validation, permutation testing.
- Software / reproducibility: containers, DAG, provenance JSON, code and container URLs.

**Results (~2000 words).**
- Cohort characteristics table.
- Figure 1: pipeline schematic (patient-specific vs normative).
- Figure 2: representative subject — lesion + patient-specific SDC + LQT SDC + BCB disconnection map side by side.
- Figure 3: cohort-wide SDC concordance distribution (violin plot per method-pair); scatter of concordance vs lesion volume / mass-effect metric.
- Figure 4: FC prediction — cross-validated R² per SDC representation, per network.
- Figure 5: GOSE prediction — ROC / AUC per SDC representation, with lesion-volume-only baseline.
- Table 1: SDC divergence stratified by lesion location (frontal / temporal / parietal / occipital / bilateral).
- Table 2: incremental-validity model comparison (nested model AIC/BIC).

**Discussion (~1500 words).**
- Interpretation of divergence: where and why patient-specific SDC differs.
- Clinical implications: which patient subgroups benefit most from patient-specific processing.
- Comparison to Griffis 2019 (stroke): expect smaller divergence there — testable prediction.
- Limitations: single-cohort, single-site, N constrained by lesion-mask + rs-fMRI + GOSE overlap.
- Future directions: replication cohort, expansion to Deep Atropos 5TT, synthetic-MRI extension for CT-only subjects.

**Data and code availability.** BIDS derivatives on [repo], containers on GHCR + DockerHub, code on GitHub at tagged release.

**Supplement (~2000 words).**
- S1: fMRI preprocessing details (fMRIPrep version, XCP-D pipeline, motion QC).
- S2: LQT and BCBtoolkit parameter tables.
- S3: Alternative-parcellation robustness (Schaefer 200).
- S4: Alternative fixed-arm robustness (`vbt-lesion`).
- S5: Provenance JSON schema example.
- S6: Container digest table + reproducibility instructions.

**Figures: 5 main + 6 supplement.**
**Tables: 2 main + 3 supplement.**

### Effort estimate

| Item | Effort |
|------|--------|
| Complete cohort processing (fixed arm) | 2 weeks compute + 1 week QC |
| LQT install + run on all subjects | 2 weeks |
| BCBtoolkit install + run on all subjects | 2 weeks |
| fMRI preprocessing arm (fMRIPrep + XCP-D) | 3 weeks build + 2 weeks compute |
| SDC divergence analysis | 2 weeks |
| CCA / ridge regression modeling | 3 weeks |
| Manuscript drafting | 4 weeks |
| Supplement + code release | 2 weeks |
| **Total (calendar time with overlap)** | **~4 months** |

### Risk / failure modes

- **Divergence is small** — patient-specific and normative SDC agree within noise → methods contribution collapses; fall back to biology-lead (Brain / HBM) or supplement.
- **LQT MATLAB dependency** — MATLAB-only install may be a barrier; may need to port to Python or use a container.
- **BCBtoolkit installation friction** — historically MATLAB + FSL wrapper; Python components newer.
- **fMRI arm not yet in pipeline** — real engineering to build.
- **Reviewer demand for replication cohort** — NeuroImage may accept without one; expect at least a request for stronger justification if we don't have it.

---

## 2. Brain — biology-lead (realistic primary target)

### Editorial identity

- **Reader base:** clinical neurologists, translational cognitive neuroscientists in clinical departments.
- **Reviewers reward:** biological/mechanistic story with clinical implications, symptom-anatomy-mechanism triads, prognostic value, cohort-level generalizability, novel clinical insights.
- **Reviewers reject on:** pure methods papers, no clinical interpretation, case reports, unclear biology, weak clinical justification.
- **Our fit:** SC → FC → behavior chain in TBI (defined patient population, ~2M/year US, real clinical decision-support relevance); the Griffis 2019 stroke → TBI extension is a documented empty niche.

### Framing

**Working title:** *Structural disconnection mediates functional network dysfunction and predicts cognitive recovery after traumatic brain injury.*

**One-sentence claim:** Lesion-aware structural disconnection in TBI mechanistically explains resting-state functional connectivity disruption and predicts domain-specific cognitive outcome at 6 months, beyond what lesion volume or location alone can explain.

**Abstract shape (~250 words):**

> *Background.* Focal traumatic brain injury (TBI) produces cognitive and functional deficits that often exceed what would be expected from local damage alone. In stroke, structural disconnection of white-matter tracts has been shown to mechanistically explain widespread functional network dysfunction (Griffis et al. 2019). Whether the same mechanism generalizes to TBI — where lesions are morphologically more heterogeneous — is unknown.
>
> *Methods.* We processed N=[cohort] TrackTBI subjects with clinician-traced lesion masks through a lesion-aware structural connectome pipeline that inserts individual lesion masks into MRtrix's pathology channel during tractography. We computed patient-specific structural disconnection matrices, resting-state functional connectivity, and correlated both with 6-month Glasgow Outcome Scale-Extended (GOSE) and multi-domain neuropsychological composites (processing speed, executive function, memory, language).
>
> *Results.* Structural disconnection was spatially concordant with functional connectivity disruption (canonical correlation r = [X], p < 0.001) across all subjects. Disconnection scores in domain-specific networks predicted domain-specific cognitive deficits (attention → dorsal attention network SDC; memory → medial temporal SDC; executive → fronto-parietal SDC). Structural disconnection improved 6-month GOSE prediction over a lesion-volume + demographics baseline (ΔAUC = [Y], cross-validated).
>
> *Interpretation.* In TBI, focal lesions produce widespread network dysfunction via structural disconnection of long-range tracts. Disconnection-based biomarkers offer clinically actionable prognostic value that lesion volume alone does not capture. These findings extend the Griffis 2019 disconnection framework from stroke to TBI and support incorporating tract-level disconnection into TBI recovery models.

### Analysis required

1. Complete cohort processing on fixed arm (`neurolit-lesion` default).
2. rs-fMRI processing (fMRIPrep + XCP-D) → FC matrices.
3. FC abnormality per subject vs a healthy-control normative distribution (borrow CIDUR controls, ~26 with rs-fMRI if available; else public HCP normative distribution).
4. CCA analysis: SDC ↔ FC-abnormality — replicate Griffis 2019 method.
5. Domain-specific network → cognitive-composite regressions (Schaefer/Yeo parcellation + neuropsych factor scores).
6. GOSE ordinal regression with lesion-volume baseline vs SDC-augmented model; cross-validated ΔAUC + permutation testing.
7. Face-validity figure: group-average disconnectome in MNI, lesion topology overlay.
8. Subgroup analysis: does the mechanism generalize across lesion locations / severities / mechanisms of injury?

### Manuscript breakdown

**Title.** As above.

**Abstract.** ~250 words as sketched.

**Introduction (~1200 words).**
- Widespread post-TBI network dysfunction — brief clinical framing (2M/year, chronic sequelae).
- Griffis 2019 stroke framework — SC → FC → behavior — and why TBI is a natural next test case.
- Existing TBI network work (Palacios, Kuceyeski, Warren) and its limits.
- Our contribution: first cohort-scale disconnection-based mechanism paper in TBI with prospective SC → FC → behavior model.
- Predictions.

**Methods (~2500 words).**
- Cohort: TrackTBI subject subset — inclusion / exclusion / demographics / clinical severity distribution.
- Imaging: T1w, DWI, rs-fMRI acquisition + preprocessing (references cite Palacios 2022 for TRACK-TBI protocol).
- Structural disconnection: lesion-aware pipeline (brief; cite our methods paper for full).
- Functional connectivity: fMRIPrep + XCP-D + parcellation + connectivity matrix construction.
- Clinical outcomes: GOSE assessment (window, assessor training), neuropsych battery.
- Statistical models: CCA (SDC ↔ FC), ridge regression, ordinal regression for GOSE.
- Missing data handling.

**Results (~2000 words).**
- Cohort characteristics table.
- Figure 1: group-average disconnectome in MNI space (face validity).
- Figure 2: CCA — first component's SDC loadings + FC loadings + scatter of subject scores.
- Figure 3: domain-specific network → cognitive-composite scatter plots (5 panels: attention, memory, executive, language, motor).
- Figure 4: GOSE prediction — ROC curves for lesion-volume baseline vs SDC-augmented vs SDC+FC-augmented models.
- Figure 5: representative-subject case series (3 subjects: mild, moderate, severe) — lesion + SDC + FC-abnormality + outcome.
- Table 1: cohort demographics and clinical severity.
- Table 2: incremental-validity model comparison (nested models, cross-validated AUC, permutation p).
- Table 3: domain-network mapping (which network's SDC predicts which composite).

**Discussion (~1800 words).**
- Mechanism: SDC → FC → behavior generalizes from stroke to TBI.
- Domain-specific network mapping strengthens biological interpretability.
- Clinical implications: disconnection-based biomarker for prognosis; potential for targeted rehab.
- Comparison to Griffis 2019: similarities and differences in stroke vs TBI (magnitude of effect, network specificity).
- Limitations: single-cohort, single-site, N constrained, no independent replication, self-report symptom vs objective outcome.
- Future directions: longitudinal recovery trajectories, intervention targets.

**Data and code availability.**

**Supplement (~2000 words).**
- S1: rs-fMRI preprocessing details and motion QC.
- S2: Neuropsych battery details, factor analysis, missing-data handling.
- S3: Alternative parcellation / atlas robustness.
- S4: Alternative fixed arm robustness (`vbt-lesion`).
- S5: SDC method-choice sensitivity (patient-specific vs LQT — this is where the "methods-lead" would live if we split it out; if kept as biology paper, this is a brief robustness check).
- S6: Subgroup analyses by injury mechanism, lesion location.

**Figures: 5 main + 5 supplement.**
**Tables: 3 main + 2 supplement.**

### Effort estimate

| Item | Effort |
|------|--------|
| Complete cohort processing (fixed arm) | 2 weeks compute + 1 week QC |
| fMRI preprocessing arm (fMRIPrep + XCP-D) | 3 weeks build + 2 weeks compute |
| Neuropsych factor analysis / composite construction | 2 weeks (assumes data available) |
| CCA + regression modeling | 3 weeks |
| Manuscript drafting | 4 weeks |
| Clinical reviewer / neurologist coauthor rounds | 2 weeks |
| **Total (calendar time with overlap)** | **~4 months** |

### Risk / failure modes

- **SC → FC coupling is noisy or weak** — CCA doesn't yield a coherent first component → biology story collapses; fall back to HBM or methods-lead.
- **Neuropsych battery is thin** — reviewers demand multi-domain factor scores; if we only have GOSE + RPQ the paper's domain-specificity story shrinks and Brain becomes harder.
- **Single-site / single-cohort** — Brain reviewers may ask for external replication; likely a resubmission gate.
- **GOSE prediction incremental effect is small** — if ΔAUC is < 0.05 above lesion volume, incremental-validity claim is unpersuasive.

---

## 3. Human Brain Mapping (HBM) — default landing

### Editorial identity

- **Reader base:** broad — imaging labs, clinical, translational, methods researchers. LeAPP (Bey et al. 2024) was here, so our methodological family is welcome.
- **Reviewers reward:** solid neuroscience with imaging methods; connectivity/network analyses; N = 40–100 with honest interpretation; well-executed studies at moderate scale.
- **Reviewers reject on:** incoherent whole; unclear contribution; missing basic reproducibility; unjustified methodological choices.
- **Our fit:** either the methods-lead or biology-lead framing works at HBM under lower bar. If neither the head-to-head divergence figure nor the SC→FC coupling is exceptional, HBM is the honest home.

### Framing

**Working title (methods-lead flavor):** *Lesion-aware structural disconnectomes in traumatic brain injury: methods and clinical correlates.*
**Working title (biology-lead flavor):** *Structural disconnection and outcome after traumatic brain injury: a lesion-aware disconnectome study.*

Both frames use the same data and analyses; HBM welcomes either as long as the story is coherent and well-defended.

### Analysis required

Same as NeuroImage or Brain versions, with these relaxations acceptable at HBM:

- N < 50 acceptable if biology is coherent
- Single-atlas SDC analysis acceptable (no LQT/BCB head-to-head required if we frame it as biology-lead)
- Single-outcome (GOSE) acceptable if we frame the paper honestly as prognostic rather than domain-specific
- Cohort-only (no external replication) is fine

### Manuscript breakdown

Follows either NeuroImage or Brain outline depending on which frame we lead with, but:

- **Introduction** shorter (~800 words) — HBM permits less exhaustive positioning
- **Methods** the same rigor
- **Results** — 4 main figures instead of 5, 2 main tables instead of 3
- **Discussion** shorter (~1200 words), fewer speculation paragraphs
- **Supplement** less exhaustive

### Effort estimate

Approximately 80% of the NeuroImage or Brain effort — the analytic backbone is the same, but writing and supplement effort is lighter.

### Risk / failure modes

- **Truly weak results everywhere** — even HBM will reject an incoherent submission. HBM's rejection risk is not "your ceiling is too low" but "the story doesn't hang together."

---

## 4. NeuroImage: Clinical — solid backup

### Editorial identity

- **Reader base:** clinical neuroimaging researchers, translational imaging labs.
- **Reviewers reward:** clinically-relevant imaging findings with methodological transparency, TBI-focused work, prognostic biomarkers.
- **Reviewers reject on:** methodological weaknesses, unclear clinical relevance, non-clinical framing.
- **Our fit:** natural home for a Paper 2 that emphasizes clinical/prognostic relevance without needing the full Brain-tier biological mechanism story.

### Framing

**Working title:** *Lesion-aware structural disconnectomes as a prognostic biomarker in traumatic brain injury.*

Framing is prognostic-clinical: does SDC predict outcome? Do specific disconnection patterns map to specific deficits? Less demand on mechanism than Brain.

### Analysis required

- Cohort processing (fixed arm)
- GOSE prediction with SDC + lesion volume baseline
- Optional: domain-specific mapping if neuropsych available
- Simpler statistical framework acceptable (logistic regression + AUC)

### Manuscript breakdown

- Shorter than Brain/NI (typical NI:Clinical papers are ~4000 words main text)
- 4 main figures, 2 tables
- Focused supplement

### Effort estimate

Roughly 70% of Brain effort.

### Risk / failure modes

- **Unclear clinical relevance** — if the outcome prediction improvement is small in absolute terms, reviewers may question clinical utility.

---

## 5. Nature Communications — stretch, conceivable

### Editorial identity

- **Reader base:** broad multidisciplinary — neuroscientists, imaging, clinical, computational biology.
- **Reviewers reward:** paradigm-advancing findings, methodological novelty PLUS strong biology, cross-cohort or cross-domain validation, broad reach.
- **Reviewers reject on:** single-cohort findings, narrow methodological contributions, results that fit better at a specialty venue.
- **Our fit:** *only* if we can deliver both the methods head-to-head AND the full biology chain AND some form of external validation.

### Framing

**Working title:** *Patient-specific lesion-aware disconnectomes reveal mechanism and prognosis of network dysfunction after traumatic brain injury.*

Combined framing: methods + biology + clinical prognostic value + (ideally) replication.

### Analysis required (in addition to NeuroImage + Brain analyses)

- External replication cohort — a second TBI cohort with lesion masks + DWI + rs-fMRI + outcomes. **We don't have this.** Would require establishing a collaboration.
- OR: LQT/BCB benchmarking on synthetic lesions in healthy controls (CIDUR N=26) as a form of methodological replication.
- OR: cross-domain validation showing our patient-specific SDC generalizes to another disease population (stroke) where Griffis is the gold standard.
- Larger cohort (N ≥ 80 complete cases) — depends on TrackTBI cohort availability.

### Manuscript breakdown

- Fusion of NeuroImage and Brain outlines
- 6 main figures, 3 tables
- Substantial supplement

### Effort estimate

Roughly 2× NeuroImage or Brain effort due to replication cohort establishment.

### Risk / failure modes

- **Cannot get replication cohort** — reviewers will likely reject or bounce to specialty venue.
- **Result complexity outstrips a Nature Comm-length manuscript** — trying to fit both methods and biology into 4000 words is hard.

---

## 6. Nature Human Behaviour — stretch

### Editorial identity

- **Reader base:** cognitive neuroscientists, behavioral scientists.
- **Reviewers reward:** behavior-forward findings, domain-specific network-behavior mapping, novel behavioral biomarkers.
- **Reviewers reject on:** methods-forward papers, weak behavioral characterization.
- **Our fit:** only if TRACK-TBI neuropsych battery is comprehensive (multiple domains) AND network-domain mapping is exceptionally clean.

### Framing

**Working title:** *Domain-specific network disconnection predicts cognitive recovery after traumatic brain injury.*

### Analysis required

- Multi-domain neuropsych factor scores (Corbetta-style battery, requires TRACK-TBI export to be rich)
- Network-native parcellation (Schaefer / Yeo mapped onto neuropsych domains)
- Clean domain-network mapping with hold-out validation
- Domain-specific incremental validity

### Manuscript breakdown

Similar to Brain but with behavior-heavy framing and less imaging methodology.

### Effort estimate

Similar to Brain if neuropsych battery is available; substantially more if we need to construct composite scores.

### Risk / failure modes

- **Neuropsych battery not sufficiently multi-domain** — story collapses.
- **Domain-specific mapping is noisy** — the paper's central claim fails.

---

## 7. Medical Image Analysis — fit-dependent

### Editorial identity

- **Reader base:** medical imaging engineers, computational imaging researchers.
- **Reviewers reward:** engineering/pipeline innovation, quantitative methods contributions, benchmarking.
- **Reviewers reject on:** clinical-narrative framing, weak engineering novelty.
- **Our fit:** would require completely rewriting away from the biology story, leading instead with the lesion-aware ACT pipeline as an engineering contribution.

### Framing

**Working title:** *A reproducible pipeline for patient-specific lesion-aware structural connectomics in focal brain lesions.*

### Analysis required

- Pipeline benchmarking (runtime, reproducibility, failure modes, resource requirements)
- Methods head-to-head vs LQT/BCB with engineering-flavored metrics
- Container / provenance / DAG documentation as a first-class contribution

### Manuscript breakdown

Engineering-heavy. Main figures show pipeline DAG, benchmark tables, container digests.

### Effort estimate

Would compete with Paper 1 (factorial paper) for the engineering framing. Probably not worth pursuing as a separate paper unless Paper 1 pivots.

### Risk / failure modes

- **Overlaps with Paper 1** — probably better to fold engineering framing into Paper 1 supplement.

---

## 8. Journal of Neurotrauma — realistic clinical backup

### Editorial identity

- **Reader base:** TBI-focused clinical and translational researchers.
- **Reviewers reward:** TBI-specific findings, prognostic biomarkers, clinical relevance.
- **Reviewers reject on:** non-TBI content, weak clinical rationale.
- **Our fit:** natural home if we want to lead purely with clinical prognostic value.

### Framing

**Working title:** *Structural disconnectome as an outcome biomarker after traumatic brain injury.*

### Analysis required

Basic: cohort processing, GOSE prediction, lesion volume baseline. Neuropsych optional, rs-fMRI optional.

### Manuscript breakdown

Shorter than Brain; focus on clinical relevance.

### Effort estimate

Roughly 60% of Brain effort.

### Risk / failure modes

- **Clinical utility unclear at cohort N** — reviewers ask for larger validation.

---

# Strategic path selection

## Same data, three different papers

Given the realistic-case data scenario of **GOSE + neuropsych battery + N ≥ 50**
(the second-highest ceiling in the data-tier table), the same underlying data
supports three fundamentally different manuscripts — one per candidate venue.
The papers differ in their *core claim*, not their evidence base.

### Comparison at the same data level

| Aspect | NeuroImage version | Brain version | HBM version |
|--------|--------------------|---------------|-------------|
| Core claim | Patient-specific SDC captures signal that normative-atlas SDC misses in TBI (methods advance) | SDC mechanistically explains domain-specific cognitive deficits in TBI (biology extension of Griffis 2019) | Same as Brain, framed more descriptively |
| Primary contribution | Methods (SDC computation improvement) | Biology (mechanism generalization) | Either — coherent whole |
| Main use of neuropsych | Validation of methods divergence via downstream ΔAUC per domain | The central story: SDC → domain-specific deficit mapping | The central story (Brain equivalent) |
| Requires LQT/BCB head-to-head | **Yes** (or paper collapses to Brain/HBM) | Supplement only (robustness check) | Supplement only |
| Requires rs-fMRI | Optional (helps but not central) | Preferable — pushes closer to Brain-tier | Not required |
| Central figure | Patient-specific vs LQT vs BCB divergence + downstream ΔAUC/ΔR² | Grid of scatter plots (each domain vs its network's SDC) + face-validity group disconnectome | Same as Brain, fewer panels |
| Face-validity group disconnectome | Supplement | Main Fig 1 | Main Fig 1 |
| Expected outcome bar | Must beat LQT downstream | Must beat lesion volume alone | Must beat lesion volume alone |
| Intro word budget | ~1000 (methods-forward) | ~1200 (clinical-mechanistic) | ~800 (concise) |
| Discussion word budget | ~1500 | ~1800 | ~1200 |
| Main figures / tables | 5 / 2 | 5 / 3 | 4 / 2 |
| Reader base | Imaging methodologists | Clinical neurologists | Broad imaging + clinical |
| Expected reviewer question | *"Does patient-specific actually help vs LQT standard?"* | *"Does mechanism generalize from stroke to TBI, and survive incremental validity?"* | *"Is the whole coherent, honest, and reproducible?"* |
| Additional effort | +LQT+BCB install + head-to-head analysis (~4 wk) | +neuropsych factor analysis + domain-network mapping (~3 wk) | Baseline |

### When to write which version

The strategic point is that **the underlying data supports all three**; the
write-up should follow whichever contribution turns out quantitatively
stronger.

- **Write NeuroImage version if:** the patient-specific vs normative-atlas
  SDC divergence figure shows meaningful separation, and that separation
  translates into ΔAUC/ΔR² improvements on FC or behavior prediction. The
  methods contribution is the paper.
- **Write Brain version if:** the domain-specific network → cognitive-deficit
  mapping is clean (each domain has an identifiable network signal), the
  incremental validity vs lesion volume is meaningful (ΔAUC ≥ 0.05), and the
  cohort N ≥ 50 with rich neuropsych. The biology is the paper.
- **Write HBM version if:** neither the head-to-head nor the mechanism story
  is exceptional but the whole is coherent. Same data, more modest framing.

### Do not shop venues after seeing results

The choice among the three is by *contribution strength*, not by ambition.
This is why the analysis plan (contrasts, primary metrics, benchmarks) is
locked *before* group-level results are opened — otherwise the venue choice
becomes p-hacking dressed up as strategy.

---

## Design the analysis to unlock either path

Regardless of which venue is the eventual target, the following analyses are
required and should be built in parallel:

1. **Complete cohort processing** with fixed lesion-aware arm — required for any Paper 2 version
2. **fMRI preprocessing arm** in the pipeline — required for biology-lead (Brain / HBM biology)
3. **LQT + BCB installation and cohort run** — required for methods-lead (NeuroImage)
4. **Complete-case clinical spreadsheet** — required for any Paper 2 version
5. **Schaefer / 4S parcellation** — required for network-native analyses (Brain domain-specific)
6. **Neuropsych factor analysis** (if battery available) — required for Brain domain-specific + Nature Human Behaviour

## When to commit to a venue

- **After analyses 1–5 are complete and quality-assessed** — not before.
- **Lock analysis plan before opening group-level results** — pre-register internally.
- **Choose venue based on which contribution is quantitatively stronger** — head-to-head divergence vs SC→FC coupling.

## Pre-registration principles

Before opening group results:

- [ ] Primary imaging arm fixed (default `neurolit-lesion`)
- [ ] Primary clinical outcome fixed (default 6-month GOSE)
- [ ] Primary imaging outcome fixed (default global disconnection score)
- [ ] Visit-timing rule fixed (default 2wk imaging → 6mo outcome)
- [ ] Covariate set fixed (age, sex, education, GCS, lesion volume)
- [ ] Network-to-domain mapping fixed (which atlas → which composite)
- [ ] Incremental-validity benchmark models specified
- [ ] Complete-case N threshold specified (proceed at N ≥ 45, limitations at 30–44, fold into Paper 1 at < 30)

---

# Master timeline

Assuming clinical export arrives within 2 months and cohort processing runs in
parallel:

| Month | Milestone |
|-------|-----------|
| Month 1 | Clinical data-dictionary request; cohort processing (fixed arm) start; fMRI arm engineering start |
| Month 2 | Complete-case spreadsheet built; N confirmed; analysis plan locked; LQT/BCB install |
| Month 3 | Cohort processing complete; fMRI arm complete on cohort; SDC head-to-head figures drafted |
| Month 4 | SC→FC coupling analysis complete; GOSE / neuropsych regression complete |
| Month 5 | Venue decision (NeuroImage vs Brain vs HBM); manuscript drafting begins |
| Month 6 | First draft complete; internal coauthor review |
| Month 7 | Coauthor revisions; final polish |
| Month 8 | Submission |

Realistic revision + resubmission adds 2–4 additional months to publication.

---

# Appendix A — Analysis inventory (what needs building)

- [ ] fMRI preprocessing arm (fMRIPrep + XCP-D or equivalent) — new pipeline component
- [ ] LQT installation + wrapper (MATLAB or Python port) — new tool
- [ ] BCBtoolkit installation + wrapper — new tool
- [ ] Schaefer 200 / 4S parcellation runs on the Paper 2 subset — existing pipeline supports, just add config
- [ ] SDC divergence analysis script (edge-wise, subject-level, subgroup) — new analysis code
- [ ] CCA implementation for SDC↔FC — new analysis code
- [ ] Incremental-validity nested regression suite — new analysis code
- [ ] MNI group-average disconnectome — new analysis code
- [ ] Complete-case spreadsheet builder — new analysis code
- [ ] Face-validity figure generator — new analysis code

# Appendix B — Reproducibility inventory (what's already built)

- [x] Containerized pipeline (dkt_connectome, dkt_lesion_act, dkt_vbt SIFs on GHCR + DockerHub)
- [x] Snakemake DAG with per-step marker files
- [x] Provenance JSON at each step (`lesion_aware_act.json`, `disconnectome.json`, etc.)
- [x] Per-arm output isolation (`RESULTS_ROOT/arms/<arm>/`)
- [x] BIDS App interface
- [x] QC dashboards (subject-level HTML)
- [x] Disconnectome integrity QC (Options A/B/C sensitivity)
- [x] Six-arm factorial experiment tree on pilot subject

# Appendix C — Manuscript checklists

## NeuroImage checklist

- [ ] Methods innovation stated crisply in abstract
- [ ] Head-to-head figure (patient-specific vs LQT vs BCB) as Figure 1 or 2
- [ ] Quantitative divergence metrics reported
- [ ] Clinical downstream validation as Results, not Discussion
- [ ] Reproducibility statement + container digests
- [ ] Code and container URLs in data availability
- [ ] Robustness analyses in supplement

## Brain checklist

- [ ] Clinical relevance stated in first paragraph
- [ ] Griffis 2019 explicitly cited and positioned
- [ ] SC → FC → behavior chain figure as Figure 2 or 3
- [ ] Domain-specific mapping figure
- [ ] Incremental validity vs lesion volume table
- [ ] Group-average disconnectome face-validity figure
- [ ] Cohort demographics table
- [ ] Clinical implications discussion

## HBM checklist

- [ ] Either NeuroImage or Brain checklist, minus 1–2 items
- [ ] Honest limitations section
- [ ] Coherent whole (methods + biology + clinical)

## Appendix D — What TRACK-TBI clinical export should include

Request from PI / data core:

| Variable | Rationale |
|----------|-----------|
| GOSE at each visit (2wk, 3mo, 6mo, 12mo) + visit date | Primary outcome |
| RPQ or PCL-5 at each visit | Secondary symptom outcome |
| Neuropsych battery (Trail Making A/B, WAIS Processing Speed, CVLT-II, BVMT-R, COWA, SDMT) with visit dates | Domain-specific outcomes (unlocks Brain + NHB) |
| GCS (field + admission) | Injury severity covariate |
| PTA, LOC duration | Injury severity covariate |
| Age at injury, sex, education years, race, prior TBI history | Mandatory covariates |
| Mechanism of injury (MVA / fall / assault / sports / other) | Descriptive + subgroup stratification |
| Lesion characteristics (volume mm³, lobar location) — if not already in BIDS derivatives | Mandatory covariate |
| Site / scanner | Harmonization covariate |
| Enrollment date + inclusion/exclusion metadata | Cohort construction |

**Ask specifically:** *"For subjects with lesion masks + DWI + rs-fMRI in the TrackTBI-Sub subset, what fraction have (a) 6-month GOSE, (b) a neuropsych composite at 6 months, and (c) all covariates listed above?"*

---

## See also

- [publication_strategy.md](publication_strategy.md) — cross-paper strategy
- [paper2_disconnectome_outcomes.md](disconnectome/outcomes_planning.md) — Paper 2 planning stub (analysis registry, complete-case template)
- [../lesion_aware.md](../lesion_aware.md) — lesion-aware ACT methodology
- [../disconnectome.md](../disconnectome.md) — Step 4.1 methods
- [../validation.md](../validation.md) — validation cohort context
- [../references.md](../references.md) — full bibliography
