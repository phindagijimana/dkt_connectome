# Distance, novelty, contribution — a framework for evaluating paper ambition

**Purpose:** internal reference doc explaining how research contribution
is evaluated, what "distance from prior work" really means, how to
self-assess a proposed paper's contribution, and when to conclude a
research project is too small to pursue. Applied to Paper 1 (factorial)
and Paper 2 (disconnectome) in this planning workspace, and cross-checked
against the actual publication patterns of every paper we cite.

**As-of:** 2026-09-18. **Author:** Phind Ndagijimana (with Claude planning assist).

**Related docs:**
[publication_strategy.md](publication_strategy.md) · [journal_tier.md](journal_tier.md) ·
[factorial_paper/prior_work_novelty.md](factorial_paper/prior_work_novelty.md) ·
[disconnectome/prior_work_novelty.md](disconnectome/prior_work_novelty.md) ·
[factorial_paper/differentiation_from_leapp.md](factorial_paper/differentiation_from_leapp.md) ·
[factorial_paper/leapp_lineage.md](factorial_paper/leapp_lineage.md) ·
[Griffis_later.md](Griffis_later.md)

---

## 1. How research contribution is actually evaluated

Three evaluators, in this order:

**A. Editor (triage decision — seconds to hours).**
Reads title, abstract, cover letter. Asks: *"Is this the kind of paper this
journal publishes? Does the claim sound new enough for our tier?"* If no,
desk-reject. Editor rejection rate at top journals is 60–80%. **This is
where perceived distance from prior work matters most.**

**B. Peer reviewers (2–4 experts — weeks).**
Explicit rubric usually covers:
- *Novelty* — what is genuinely new?
- *Rigor* — are the methods sound?
- *Significance* — does anyone need to know this?
- *Clarity* — can the field understand and reproduce it?

Reviewers apply an unspoken **"so what?" test.** If the answer requires
more than one sentence, the submission is in trouble.

**C. The field, over years (citations, adoption, replication).**
The eventual test. Papers that reviewers thought were high-novelty
sometimes vanish; low-novelty-seeming careful work sometimes becomes
foundational. Reviewers optimize for *apparent* contribution; the field
rewards *actual* contribution.

---

## 2. What "distance from prior work" is really a proxy for

Distance is shorthand for a **bundle of independent axes**. A paper can be
far on some axes, close on others:

| Axis | "Far" | "Close" |
|------|-------|---------|
| **Population** | New patient group, disease, species, age band | Same population as precedent |
| **Method** | New algorithm, tool, framework, workflow | Adopts existing method |
| **Cohort scale** | Order-of-magnitude larger N | Similar or smaller N |
| **Modality** | New imaging or data type | Same modality |
| **Statistical framework** | Novel modeling approach | Standard framework |
| **Outcome** | New behavioral / clinical variable | Same outcome measures |
| **Infrastructure** | Reproducible / containerized / open code | One-off analysis |
| **Domain reach** | Cross-disease / cross-modality generalization | Single-domain application |

Total distance ≠ sum of axes; it's closer to an **L∞ norm** — reviewers
focus on the most differentiated axis and often discount the rest. LeAPP's
distance from VBG was almost entirely on the "combined into factorial +
synthetic validation" axis; the other axes were mostly close.

**Distance is measurable in principle** — you can list every axis and mark
close/far — but not measurable as a single number because reviewer
weightings differ by venue.

---

## 3. Distance is NOT the same as novelty

Related but different:

- **Distance** = how different the paper is from what came before (measurable, largely objective)
- **Novelty** = whether that distance produces new *knowledge* (partly subjective)
- **Impact** = whether that new knowledge changes what other people do (measurable but slow)

Four archetypes:

| | High novelty | Low novelty |
|---|---|---|
| **High distance** | Genuine advance (transformative) | Distant but decorative (fashionable, hollow) |
| **Low distance** | Careful replication in critical population (valuable) | Redundant (rejected) |

The "close but valuable" quadrant is important and under-appreciated. A
rigorous replication of a stroke finding in TBI at cohort scale — even
methodologically identical — is *low-distance-high-novelty* because it
validates whether the mechanism generalizes.

---

## 4. How to self-evaluate your paper's distance

Five honest self-tests:

**Test 1 — The one-sentence claim.**
State the contribution in one sentence. If it needs more than one, distance
is low or the claim is muddled. If the sentence starts *"We show that X,
similar to prior work by Y, extends to Z"* — the paper is extending, not
creating.

**Test 2 — The counterfactual.**
*"What would the field lose if this paper didn't exist?"*
If the answer is *"we wouldn't know if X generalizes to Z, but everyone
assumed it did anyway"* — distance is real but modest. If the answer is
*"nothing, someone else was going to do it in six months"* — too small.

**Test 3 — The competitor citation test.**
Would the closest competitor lab cite this paper in their next paper on
the same topic? If yes, the paper has added something they'd have to
engage with. If no, it publishes into a void.

**Test 4 — The abstract-first test.**
If someone read only the abstract, what would they say the paper added?
Compare that to what the author *wants* them to say. Gap = clarity problem
or distance problem.

**Test 5 — The grant reviewer test.**
Imagine a grant reviewer skims 40 abstracts, including this one. Would it
stand out? If not, distance is too small or poorly communicated.

---

## 5. Optimizing distance is the wrong goal

Optimizing for distance produces predictable pathologies:

- **Novelty chasing** — pursuing the differentiator regardless of importance
- **Salami-slicing** — many small "novel" papers instead of one substantive one
- **Overclaiming** — inflating novelty via language and framing
- **Wheel reinvention** — avoiding well-established methods to appear original
- **Career-length distortion** — early-career researchers publishing distance-heavy work that doesn't hold up

Optimize instead for:

- **Contribution-to-effort ratio** — biggest advance per unit research time
- **Usefulness × correctness** — impact and rigor jointly
- **Field-appropriate ambition** — matches data, cohort, career stage, resources

Distance is a *means* to an end (usefulness). Treat it as instrumental,
not terminal.

---

## 6. When a research contribution is "too small"

**Practical signals:**

| Signal | Interpretation |
|--------|----------------|
| The one-sentence claim requires 3+ qualifications | Too small, or muddled |
| The paper needs "letter" or "short communication" format | Too small for full paper |
| A well-informed reviewer would say "should be a supplement to [existing paper]" | Definitely too small |
| The target venue is materially below the author's career-appropriate tier | Consider bundling with more work |
| A similar paper was published 2+ years ago and this doesn't materially update | Too small |
| The paper would be redundant in 5 years without a follow-up | Marginal — decide by field context |
| Reviewers ask "is this a class project or a submission?" | Definitely too small |

**Thresholds by career stage:**

- **Grad student first paper:** small is OK; being a real paper matters more than being big
- **Postdoc:** should be reaching for the top of realistic tier; small-to-medium fine for skill demonstration
- **Faculty starting a lab:** each paper should either (a) advance the major program, (b) train a student, or (c) establish a niche — if none, too small
- **Senior faculty:** small papers are opportunity cost; each one competes with bigger work

**How much distance is enough:**
For the target venue, ask: *would the venue's editors and reviewers say the
paper reaches their level?* If reading 20 recent papers from that venue,
the current draft would be at the 25th percentile or higher of contribution
size, it's in the right zone. If it would be at the 5th percentile, too
small.

---

## 7. Cross-checking against the actual publication patterns we cite

The distance / novelty / venue calculus above is not folk wisdom — it's an
observable pattern in the ecosystem. Every paper we cite in
[publication_strategy.md](publication_strategy.md) fits one of a small
number of contribution-shape templates.

### 7a. Template: framework-formation via combination

Combine 2–3 pre-existing techniques into a new named framework + apply
to a specific patient population + add methodological rigor upgrade.

| Paper | Precedents combined | New in combination | Venue |
|-------|--------------------|--------------------|-------|
| **Bey 2024 LeAPP** (*HBM*) | Radwan VBG (2020) + Smith ACT (2012) + factorial-design convention | VBT+ACT joint factorial + synthetic-lesion validation + containerized pipeline | HBM |
| **Griffis 2019** (*Cell Reports*) | HCP normative tractogram (Yeh 2018) + rs-fMRI FC (WashU pipeline) + Corbetta 2015 behavior factors | The SC→FC→behavior chain formalization; SDC-explains-FC-abnormality argument | Cell Reports |
| **Foulon 2018 BCBtoolkit** (*GigaScience*) | Existing lesion-symptom-mapping + HCP-based normative disconnection + FSL tools | Voxel-level disconnection probability maps + open toolkit + Tractotron | GigaScience |

**Pattern:** framework-formation papers land at venues that reward tool /
methodology packaging (HBM, GigaScience, Cell Reports if the framework
also produces mechanistic insight).

### 7b. Template: framework-extension to a new domain

Take an established framework and apply to a new population / cohort /
timepoint. Usually smaller distance than framework-formation.

| Paper | Framework extended | New domain | Venue |
|-------|--------------------|------------|-------|
| **Salvalaggio 2020** (*Brain*) | Griffis 2019 SDC + WashU stroke cohort | Multi-domain outcome prediction + indirect FC construct + expanded N=155 | Brain |
| **Radwan 2023** (*NetNeuro*) | Radwan 2020 VBG + Smith ACT | TBI cohort (N=5, proof-of-concept) | Network Neuroscience |
| **Kuceyeski 2020** (*HBM*) | Connectome + cognition modeling framework | Longitudinal mTBI (N=26) | Human Brain Mapping |
| **Talozzi 2023** (*Brain*) | BCBtoolkit disconnectome | Latent-space representations + long-term chronic outcome | Brain |

**Pattern:** framework-extensions land at the same tier as the origin OR
one tier lower, depending on execution + cohort scale. Salvalaggio at
Brain (extending Cell Reports Griffis) is at the top of what extensions
can achieve. Radwan 2023 at NetNeuro (extending HBM VBG to TBI) is at
the typical mid-tier for small-cohort proof-of-concept.

### 7c. Template: tool / methods release paper

Consolidate an approach into a distributable open tool. Distance from
prior work is mostly engineering + documentation, not new science.

| Paper | Prior scientific work | Tool release | Venue |
|-------|----------------------|--------------|-------|
| **Griffis 2021 LQT** (*NeuroImage: Clinical*) | Griffis 2019 SDC method | LQT MATLAB toolkit + documentation | NeuroImage: Clinical |
| **Kuceyeski 2013 NeMo** (*Brain Connectivity*) | Prior lesion-connectome work | NeMo Tool + normative connectome | Brain Connectivity |
| **Foulon 2018 BCBtoolkit** (*GigaScience*) | Prior disconnection-mapping work | BCBtoolkit open framework | GigaScience |

**Pattern:** tool papers land at methods-oriented venues (NI:Clinical,
GigaScience, Brain Connectivity, Frontiers in Neuroinformatics). The
contribution size is *smaller* than framework-formation papers, but the
venue expectations are also smaller — so the venue fit is appropriate.

### 7d. Template: technique-introduction

Introduce a novel algorithm / method as the primary contribution.

| Paper | Prior state | New method | Venue |
|-------|-------------|------------|-------|
| **Smith 2012 ACT** (*NeuroImage*) | Tractography with limited priors | Anatomically-constrained tractography (5TT segmentation as tractography prior) | NeuroImage |
| **Radwan 2020 VBG** (*HBM*) | Ad-hoc lesion masking | Virtual Brain Grafting mirror-and-blend | Human Brain Mapping |
| **Pollak 2025 neuroLIT** (*Imaging Neuroscience*) | Deterministic inpainting | DDPM-based learned inpainting for brain lesions | Imaging Neuroscience |
| **Boes 2015** (*Brain*) | Lesion location analyses | Lesion network mapping using normative rs-fMRI | Brain |

**Pattern:** technique introduction papers land at general-methods
neuroimaging venues (NeuroImage, HBM, Brain if there's clinical
motivation). They're framework-formation on a single axis (the technique).

### 7e. Template: cohort-scale multi-modal outcome paper

Large clinical cohort + standard methods + clinical outcome linkage.

| Paper | Cohort | Methods | Venue |
|-------|--------|---------|-------|
| **Palacios 2022** (*J Neurotrauma*) | TRACK-TBI N≈391 multisite | Standard DTI + GOSE | Journal of Neurotrauma |
| **Warren 2015** (*Brain*) | TBI cohort | Graph-theoretic connectome + cognitive testing | Brain |
| **Che 2026** (*Brain Communications*) | TRACK-TBI Pilot | CT + GAN-synthesized MRI + 3D ResNet | Brain Communications |

**Pattern:** these papers rely on cohort scale + clinical relevance rather
than methodological novelty. Distance is on the population/scale axis;
methods can be standard.

### 7f. Template: paradigm review / high-visibility overview

Rare but occasionally hit by lead authors of established paradigms.

| Paper | Paradigm | Venue |
|-------|----------|-------|
| **Fox 2018** (*NEJM*) | Lesion network mapping paradigm | New England Journal of Medicine |

**Pattern:** the author establishes or synthesizes a paradigm; the venue
rewards the review-level scholarship.

---

## 8. Where our two papers sit in this ecosystem

### Paper 1 (Factorial)

**Template match:** framework-extension (§ 7b), with elements of
technique-integration on the neuroLIT axis (§ 7d).

**Direct analogs by pattern:**

- Salvalaggio 2020 (Brain) — same template: extend an existing framework (Griffis 2019) to a related but different scope (multi-domain outcomes). Landed at Brain, one tier below Cell Reports (Griffis's venue).
- Radwan 2023 (NetNeuro) — same template: extend an established methodological framework (VBG) to a new population (TBI, N=5). Landed at NetNeuro, appropriate to small cohort.
- Bey 2024 LeAPP (HBM) — inverse position for us: they were the framework-formation paper we're extending. Landed at HBM.

**Our position:** framework-extension at HBM tier, exactly matching the
LeAPP tier. Not stretching upward from where LeAPP was published, because
framework-extensions rarely exceed their origin venue. NeuroImage stretch
is achievable if we add synthetic-lesion validation (matching LeAPP's
methodological completeness).

**Distance/novelty verdict:** normal and appropriately sized for HBM. Below
the ceiling of the target tier — room for the Tier B (synthetic validation)
addition to push into NeuroImage territory.

### Paper 2 (Disconnectome)

**Template match:** framework-extension (§ 7b) with methods-differentiation
on the SDC-computation axis (patient-specific vs normative-atlas).

**Direct analogs by pattern:**

- Salvalaggio 2020 (Brain) — extended Griffis 2019 SDC to multi-domain outcomes. Same lab. Landed at Brain, one tier below Cell Reports.
- Talozzi 2023 (Brain) — extended Thiebaut de Schotten disconnectome framework with latent-space representations. Different lab, different institution. Also landed at Brain.
- Warren 2015 (Brain) — TBI-specific graph-connectome + cognition. Landed at Brain because clinical population + mechanistic story.

**Our position:** if execution is clean, this is the same template as
Salvalaggio 2020 or Talozzi 2023 — framework-extension of a Cell-Reports
framework to a new population + new methods variant → Brain-tier realistic.

**Key differentiator vs Salvalaggio:** they extended within same lab / same
cohort (safer, easier). We extend cross-lab / cross-institution / new
patient population. This is *larger* distance than Salvalaggio's, but
Brain-tier venue is achievable.

**Distance/novelty verdict:** appropriately sized for J Neurotrauma / HBM
by default, Brain by stretch. Cohort N is the risk factor — if N < 40,
falls into "too small for Brain" territory (Salvalaggio had N=155;
Talozzi had large stroke cohort).

---

## 9. Is our contribution common or normal for the field?

**Yes — both papers fit patterns that are pervasive in the neuroimaging
literature.** Framework-extension papers are the majority of publications
in this space (small volume of framework-formation, larger volume of
extensions, larger still of tool papers and cohort applications).

**What our papers share with typical field publications:**

| Aspect | Our papers | Field norm |
|--------|-----------|------------|
| Adopt established techniques | Yes (ACT, `5ttedit -path`, VBT, LQT/BCB as comparators) | Extremely common (~85% of published neuroimaging papers) |
| Introduce one new axis of differentiation | Yes (Paper 1: TBI + neuroLIT; Paper 2: patient-specific SDC + TBI) | Standard framework-extension move |
| Extend prior published framework | Yes (LeAPP for Paper 1; Griffis for Paper 2) | Standard |
| Modest technical novelty | Yes | Standard for HBM / Brain tier |
| Reproducibility infrastructure | Yes (containers + provenance JSON) | Increasingly standard (post-2020 expectation) |
| Cross-lab replication | Yes (both papers) | Valued but not unusual |

**Where our papers slightly differ from field norm (positive differentiators):**

- **Depth of reproducibility infrastructure** — most framework-extension papers ship code but not containerized + provenance-tracked pipelines. Ours does. This is a small but consistent differentiator.
- **Explicit pre-registration** (planned) — most extension papers don't preregister. If we do, it's a modest rigor upgrade.
- **Cross-tier documentation** — our per-paper folders + planning docs are unusually mature for pre-submission state. This helps internal execution, not external perception.

**Where our papers are typical (not differentiators):**

- Sample sizes for both papers (N~50–100) are within the typical range for HBM/Brain-tier papers
- Statistical frameworks (CCA, ridge regression, factorial ANOVA) are standard
- Methods stack (fMRIPrep, MRtrix, FreeSurfer, XCP-D) is consensus-standard

**Where our papers face field-typical risks:**

- Reviewer perception of "just another cohort extension" — a real risk that all framework-extension papers face
- Cohort delivery uncertainty — very common risk in TBI cohort work
- Cross-site heterogeneity — common risk for TRACK-TBI–derived cohorts

---

## 10. Rules of thumb for our two papers

**Do:**
- Execute what we already have cleanly (each of Paper 1's five contributions clearly delivered; each of Paper 2's three claims empirically supported)
- Add the highest-leverage single novelty per paper (Paper 1: synthetic validation; Paper 2: LQT/BCB head-to-head)
- Match venue ambition to actual results (submit to Brain only if the biology story is clean; NeuroImage only if the methods head-to-head shows meaningful divergence)
- Own the lineage explicitly — cite Bey 2024 / Griffis 2019 in the intro and discussion as extension targets
- Ship reproducibility infrastructure as a first-class feature, not a supplement

**Don't:**
- Chase more novelty axes to inflate distance (adds effort without proportional payoff)
- Claim framework-formation when we're doing framework-extension (reviewers see through it)
- Try to salami-slice — one substantive paper > two small ones
- Submit above tier without matching evidence (rejection wastes months; downgrading is expected)
- Ignore the "so what?" test until reviewers apply it

---

## 11. Applied conclusion

Both papers are **normal-to-slightly-above-normal contribution-shape**
publications for their target tiers. Neither is uniquely ambitious;
neither is too small. Both fit patterns that publish successfully in this
field ecosystem.

**Paper 1** most resembles Radwan 2023 (framework-extension to TBI) but at
larger cohort scale — placing it at HBM tier rather than NetNeuro tier.
Bey 2024 sits above as the framework-formation ancestor.

**Paper 2** most resembles Salvalaggio 2020 (framework-extension of
Griffis 2019 with added methods variant) but cross-lab and to TBI —
placing it at Brain-tier realistic, J Neurotrauma solid, HBM safe.

The main risk isn't distance being too small — it's execution not
matching the distance we already have. The scripts, containers, and
provenance are in place; what's left is disciplined analysis + honest
writing + venue-appropriate submission.

---

## 12. Executive summary — templates in this literature (compressed)

*Short-form recap of §§ 7–11, kept together for quick reference.*

### Short answer

**Yes — both papers match well-established templates that regularly publish
successfully in this ecosystem.**

### Every paper we cite fits one of ~6 templates

| Template | Examples we cite | Typical venue |
|----------|------------------|---------------|
| **Framework-formation via combination** — combine 2–3 pre-existing techniques into a named framework + apply to specific population | Bey 2024 LeAPP; Griffis 2019; Foulon 2018 BCBtoolkit | HBM, Cell Reports, GigaScience |
| **Framework-extension to new domain** — take established framework, apply to new population/cohort | Salvalaggio 2020, Radwan 2023, Kuceyeski 2020, Talozzi 2023 | Same tier as origin or one lower |
| **Tool / methods release** — consolidate an approach into distributable open tool | Griffis 2021 LQT; Kuceyeski 2013 NeMo; Foulon 2018 BCBtoolkit | NI:Clinical, GigaScience, Brain Connectivity |
| **Technique introduction** — introduce a novel algorithm as primary contribution | Smith 2012 ACT; Radwan 2020 VBG; Pollak 2025 neuroLIT; Boes 2015 LNM | NeuroImage, HBM, Brain |
| **Cohort-scale multi-modal outcome** — large clinical cohort + standard methods + outcome linkage | Palacios 2022; Warren 2015; Che 2026 | J Neurotrauma, Brain, Brain Communications |
| **Paradigm review** — synthesize an established paradigm | Fox 2018 | NEJM, Nature Reviews |

### Where our two papers fit

**Paper 1 (Factorial)** matches the framework-extension template, closest to:

- Radwan 2023 (VBG framework → TBI, but N=5 → NetNeuro tier)
- Salvalaggio 2020 (Griffis framework → new outcomes, N=155 → Brain tier)

We're between them — ~100 TBI subjects, so **HBM tier** (matches LeAPP
itself, which is the natural place for framework-extensions of HBM origin
papers).

**Paper 2 (Disconnectome)** matches the framework-extension + methods
differentiation template, closest to:

- Salvalaggio 2020 — extended Griffis 2019 SDC → multi-domain outcomes → Brain (one tier below Cell Reports)
- Talozzi 2023 — extended BCB framework → latent-space + long-term outcomes → Brain

We're extending Griffis 2019 cross-lab, cross-institution, to TBI, with a
genuine methods differentiator (patient-specific vs normative-atlas SDC).
That's a *larger* distance than Salvalaggio's, but **Brain-tier is the
natural target** — matching both direct analogs.

### Key finding: our papers are not unusually ambitious OR unusually derivative

Looking at framework-extension papers in this literature:

- **Sample size (N ~50–100)** — within normal range for HBM/Brain tier
- **Cross-lab extension of a framework** — common (about half of framework-extensions in this space are cross-lab)
- **Reproducibility infrastructure depth** — slightly above normal (a positive differentiator, not the norm)
- **Statistical framework** — standard (CCA, ridge regression, factorial ANOVA all boilerplate)
- **Adopted techniques** — using off-the-shelf ACT, `5ttedit -path`, VBT, XCP-D → **matches ~85% of published neuroimaging papers**

### Our modest differentiators from the field norm

**Positive:**

- **Containerized + provenance-tracked pipeline** — most framework-extension papers ship code but not this level of infrastructure
- **Cross-tier planning documentation** — unusually mature pre-submission state (helps execution, not perception)
- **Explicit anti-p-hacking pre-registration** (planned) — modest rigor upgrade

**Neutral:**

- Sample sizes, statistical methods, imaging modalities — all field-standard

### Verdict

**Both our papers publish successfully in this ecosystem's normal pattern.**
Neither is uniquely ambitious (would risk desk-reject at higher venues)
nor uniquely small (would risk "supplement to X" review comment). The
main risk isn't distance being too small — it's *execution not matching
the distance we already have*.

Direct predecessors in the same template landed at:

- **Paper 1's template:** HBM (Radwan 2020 VBG, Bey 2024 LeAPP, Kuceyeski 2020) — matches our HBM target
- **Paper 2's template:** Brain (Salvalaggio 2020, Talozzi 2023, Warren 2015) — matches our Brain stretch target

Not pushing beyond these tiers would be **under-selling**; pushing beyond
them (Nature main / Cell Reports) would be **over-selling**.

Full case-by-case comparison and rules of thumb are in §§ 7–11 above.

---

## 13. Contributions per paper (consolidated list)

Consolidates the contribution inventories scattered across
[factorial_paper/differentiation_from_leapp.md](factorial_paper/differentiation_from_leapp.md),
[disconnectome/outcomes_planning.md](disconnectome/outcomes_planning.md#our-contribution-relative-to-griffis-2019--expanded),
[factorial_paper/index.md](factorial_paper/index.md#contribution-summary), and
[disconnectome/index.md](disconnectome/index.md#contribution-summary) into a
single per-paper checklist.

Each contribution is labelled by tier:

- **Core** = in the manuscript's abstract-level claim; required for submission
- **Additional** = post-hoc / stretch additions that raise novelty magnitude or venue tier

### 13a. Paper 1 — Factorial (Anatomy × ACT in TBI)

**Core contributions (in the abstract-level claim):**

| # | Contribution | Vs precedent |
|---|--------------|-------------|
| 1 | **Population extension** to TBI (heterogeneous morphology: contusion + oedema + hemorrhage + bilateral) | LeAPP validated on ischemic stroke only |
| 2 | **Third anatomy backend (neuroLIT)** — Pollak 2025 DDPM-based learned inpainting integrated as first-class arm | LeAPP had 2 anatomy backends (orig + VBT) |
| 3 | **Cohort-scale evaluation in TBI** — ~100 real TBI subjects across all 6 factorial arms | LeAPP: 36 stroke + 81 synthetic; ~3× larger real cohort |
| 4 | **Bilateral-lesion handling** — explicit subgroup analysis where VBT's mirror assumption strains | Not addressed in LeAPP (stroke lesions typically unilateral) |
| 5 | **Containerized reproducibility infrastructure** — Snakemake DAG + per-step provenance JSON + Apptainer SIFs on GHCR/DockerHub + BIDS-App wrapper | LeAPP has a repo; not this depth of infra |
| 6 | **Cohort-scale QC-by-arm reporting** as first-class result (RQ4) — completion / failure-mode / pathology-QA table | Not standard in LeAPP-family papers |
| 7 | **Deep Atropos vs HSVS 5TT sensitivity supplement** — folds Paper 3 material into Paper 1 methods space | Not in LeAPP |
| 8 | **Explicit factorial contrast pre-specification** — anatomy × ACT interaction as testable hypothesis | Aligns with LeAPP; strengthened by locked analysis plan |

**Additional contributions (Tier 1–2 from `differentiation_from_leapp.md`; optional but each raises HBM → NeuroImage odds):**

| # | Contribution | Effort | Novelty payoff |
|---|--------------|:------:|:--------------:|
| 9 | **Synthetic-lesion validation on CIDUR controls** (Tier B) — LeAPP-parity move | 4 wks | ★★★★ |
| 10 | **Edge-level uncertainty quantification** via bootstrap tractography seeds | 2 wks | ★★★ |
| 11 | **Cross-parcellation robustness suite** (DKT + Schaefer 200 + 4S 156) | 1 wk | ★★★ |
| 12 | **Test-retest reliability** on repeat-scan subjects if available | Free if data | ★★★ |
| 13 | **Lesion-topology → arm-recommendation decision tree** | 1-2 wks | ★★★★ (highest marginal value) |
| 14 | **Multi-measure connectome consistency** (count + SIFT2 + length + FA + MD) | Analysis-only | ★★ |
| 15 | **Cross-site harmonization** (ComBat or site regressors) | Analysis-only | ★★★ |
| 16 | **Prospective preregistration** on OSF or AsPredicted | 1 day | ★★ (highest per-day) |
| 17 | **Deep Atropos as full third factorial axis** (3×2×2 = 12 arms) | 2× compute | ★★★★ (scope-expanding) |

### 13b. Paper 2 — Disconnectome (SC → FC → behavior in TBI)

**Core contributions:**

| # | Contribution | Vs precedent |
|---|--------------|-------------|
| 1 | **Population extension** to TBI | Griffis 2019 validated on ischemic stroke only |
| 2 | **Patient-specific lesion-aware SDC** via `5ttedit -path` + iFOD2 tractography on individual DWI | Griffis / LQT / BCB use normative-atlas overlay only |
| 3 | **Head-to-head patient-specific vs normative-atlas SDC in TBI** — first systematic comparison at cohort scale | No prior head-to-head at cohort scale in any pathology |
| 4 | **Full three-part chain in TBI** — SC disconnection → rs-fMRI FC disruption → behavior | Griffis's chain in stroke; no TBI test at cohort scale |
| 5 | **Multi-atlas FC output** from single XCP-D run (4S156, 4S256/Schaefer 200, Gordon, Glasser, HCP) + post-hoc DKT | Griffis used one atlas (Gordon 333) |
| 6 | **Incremental validity vs lesion volume** — cross-validated ΔAUC/ΔR² above age+sex+edu+GCS+lesion-vol baseline | Griffis-style rigor bar; adopted directly |
| 7 | **Domain-specific network → cognitive deficit mapping** — attention→DAN, memory→medial-temporal, executive→fronto-parietal, language→left fronto-temporal, motor→sensorimotor | Contingent on TRACK-TBI neuropsych battery availability |
| 8 | **Combined SC + FC predictive model** — Salvalaggio 2020-style, using empirical rs-fMRI (not indirect FC construct) | Salvalaggio's indirect-FC was predicted-from-lesion; we use actual FC |
| 9 | **Reproducibility infrastructure** — same containerized + provenance-tracked stack as Paper 1, extended to fMRI arm | Griffis/Salvalaggio used WashU custom pipeline (4dfp) |
| 10 | **Face-validity group disconnectome atlas** in MNI space | Griffis 2019 Figure 2 replicated in TBI |

**Additional contributions (contingent on data / effort):**

| # | Contribution | Depends on |
|---|--------------|------------|
| 11 | **Cross-site harmonization** — ComBat / site-fixed-effects | TRACK-TBI multisite structure (Griffis was single-site) |
| 12 | **Prospective analysis-plan pre-registration** — locked design in `disconnectome/analysis_plan.md` | Discipline (free — 1 day) |
| 13 | **Automated vs clinician-traced lesion mask sensitivity** — supplement enabling cohort scaling without expert tracers | nnU-Net / MELD auto-seg availability |
| 14 | **Latent-space disconnectome** (Talozzi 2023-style dimensionality reduction) | N ≥ 60 |
| 15 | **CT-only subjects extension** (Che 2026 synthetic-MRI + disconnectome) | Future-directions discussion; no execution required |

### 13c. Cross-paper contribution overlap

Some infrastructure contributions serve both papers (build once, deploy twice):

| Shared infrastructure | Serves Paper 1 | Serves Paper 2 |
|-----------------------|:--------------:|:--------------:|
| Containerized dwi_pipeline (structural connectomes) | ✅ Primary | ✅ Provides SC matrices |
| Containerized fMRI_pipeline (fMRIPrep + XCP-D + DKT post-hoc) | — | ✅ Primary |
| Per-step provenance JSON schema | ✅ | ✅ |
| Snakemake DAG + BIDS-App wrapper | ✅ | ✅ |
| Preregistration convention | ✅ | ✅ |
| Cross-site harmonization tooling | ✅ (Tier 2) | ✅ (Core) |

Building this infrastructure once (already largely done) amortizes across
both papers — a small hidden efficiency that most framework-extension
papers don't have.

### 13d. What is deliberately NOT a contribution

Being explicit about what we do not claim, to avoid overclaiming:

- Not new tractography technique — Smith 2012 (ACT) + Tournier 2019 (MRtrix3 iFOD2)
- Not new inpainting technique — Pollak 2025 (neuroLIT); Bey 2024 (VBT, itself refinement of Radwan 2020 VBG)
- Not new lesion-aware ACT logic — Bey 2024 established `5ttedit -path` for lesioned brains
- Not new normative-atlas SDC tool — Griffis 2021 (LQT); Foulon 2018 (BCBtoolkit) — we use as comparators
- Not new fMRI preprocessing framework — Esteban 2019 (fMRIPrep); Mehta 2024 (XCP-D)
- Not new statistical framework — CCA, ridge regression, factorial ANOVA are standard
- Not new cognitive-behavioral framework — Corbetta 2015 factor-analytic approach

Owning the boundary between adopted-from-prior-work and new-in-this-paper
is what keeps the contribution list defensible.

---

## See also

- [publication_strategy.md](publication_strategy.md) — cross-paper strategy and prior-work analog table
- [journal_tier.md](journal_tier.md) — full venue landscape for Paper 2
- [factorial_paper/differentiation_from_leapp.md](factorial_paper/differentiation_from_leapp.md) — ranked menu of Paper 1 additions
- [factorial_paper/leapp_lineage.md](factorial_paper/leapp_lineage.md) — Bey 2024 deep summary
- [Griffis_later.md](Griffis_later.md) — Salvalaggio 2020, Talozzi 2023, Kuceyeski lineage
- [LQT.md](LQT.md) — LQT + normative-atlas SDC reference
