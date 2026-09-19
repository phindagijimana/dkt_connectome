# Factorial paper — contribution strategy

**Purpose:** honest analysis of how much methodological distance separates our factorial paper from LeAPP (Bey 2024) — its direct precedent — compared to how much distance separated LeAPP from *its* precedents (Radwan 2020 VBG, Smith 2012 ACT). Plus a ranked menu of enhancements we can add to widen that distance and defensibly earn a higher venue tier.

**Related:** [index.md](index.md) · [neuroimage_prerequisites.md](neuroimage_prerequisites.md) · [leapp_lineage.md](leapp_lineage.md) · [analysis_plan.md](analysis_plan.md) · [../publication_strategy.md](../publication_strategy.md)

**Status:** Framing doc — not a locked decision list. Use to prioritize which enhancements are worth the effort.

---

## Part 1 — Distance analysis: are we as far from LeAPP as LeAPP was from its precedents?

### 1.1 LeAPP's distance from its precedents

**From Radwan 2020 (VBG, *Human Brain Mapping*):**
- **Adopted:** mirror the contralesional hemisphere into the lesion cavity before recon
- **Added:** refined implementation with specific smoothing/blending parameters (VBT vs. generic VBG); integrated into a broader pipeline
- **Distance:** implementation refinement + integration

**From Smith 2012 (ACT, *NeuroImage*):**
- **Adopted:** `5ttedit -path` to mark pathology in the 5TT segmentation
- **Added:** applied this to lesioned brains at cohort scale (Smith was methods-only, no lesion cohort)
- **Distance:** cohort-scale application of an available technique

**LeAPP's synthesized contribution:**
- The **2×2 factorial** combination of VBT + ACT (neither Radwan nor Smith presented this as a factorial)
- **Synthetic-lesion validation** on N ≈ 81 healthy brains (independent rigor addition)
- Cohort application to N ≈ 36 stroke
- Branded name and containerized distribution as the "LeAPP" pipeline

### 1.2 Our distance from LeAPP

**Adopted:** everything LeAPP established — VBT, `5ttedit -path`, factorial framework, synthetic-validation approach (if Tier B runs per [neuroimage_prerequisites.md § Item 1](neuroimage_prerequisites.md#item-1--synthetic-lesion-validation-on-cidur)).

**Added:**
- **neuroLIT** (Pollak 2025) as a third anatomy backend → 2×2 becomes 3×2
- **TBI cohort** (not stroke) at target N ≈ 100
- **Bilateral-lesion handling** — LeAPP's mirror assumption strains at ~30–40 % of moderate-severe TBI cases (per [leapp_lineage.md § 1](leapp_lineage.md#what-our-paper-adds-vs-leapp))
- **Per-step provenance JSON + Snakemake DAG + containerized distribution** (LeAPP has a repo but less infrastructure)
- **TBI-specific failure-mode characterization** (VBT-on-bilateral, midtrans transient failures observed in pilot, neuroLIT OOD lesion patterns)

### 1.3 Side-by-side comparison

| Comparison axis | LeAPP → its precedents | Us → LeAPP |
|---|---|---|
| Population extension | Stroke (novel cohort for the technique) | Stroke → TBI (novel cohort + different pathology class) |
| Number of new "arms" | Combined VBT + ACT into a joint factorial | Added neuroLIT (3rd arm) beyond LeAPP's 2 |
| Cohort scale (real) | N = 36 stroke | N ~ 100 TBI (target) |
| Cohort scale (synthetic) | N = 81 healthy w/ injected lesions | N ~ 26 CIDUR (target, per [../publication_strategy.md](../publication_strategy.md) line 615) |
| Framework naming | Named "LeAPP" — makes a framework claim | Not named — pipeline is `dkt_connectome`, technical not brand-forward |
| New technique invented | VBT (a specific implementation of Radwan's VBG concept) | None invented — VBT ported, neuroLIT external, ACT external |
| Genuinely new methodological move | Synthetic-lesion validation methodology | Bilateral-lesion subgroup handling + reproducibility infrastructure |
| Cross-lab distance | Bey/Charité ≠ Radwan/Sunaert | URMC ≠ Bey/BrainModes |
| Framework-formation vs -extension | **Framework-formation** — created LeAPP by combining pre-existing pieces | **Framework-extension** — extends LeAPP to new population + adds arm |

### 1.4 Where we're arguably *closer* to LeAPP than LeAPP was to its precedents

1. **We don't create a new named framework.** LeAPP branded itself — introduced a name that other papers now cite. Not naming signals extension humility rather than framework-formation.
2. **We didn't invent an implementation.** LeAPP invented VBT (its specific implementation of VBG's conceptual idea). Everything algorithmic in our pipeline is someone else's — VBT from LeAPP, neuroLIT from Pollak, ACT from Smith.
3. **Our new "arm" is external.** LeAPP's new arms (VBT-specific implementation + lesion-aware ACT combined) were their own work; our third arm is Pollak 2025's tool that we integrate.
4. **Our factorial is a scale extension of LeAPP's.** 2×2 → 3×2 is one new row of arms; LeAPP's factorial was genuinely new to their subfield.

### 1.5 Where we're arguably *further* from LeAPP than LeAPP was from its precedents

1. **Population change is more consequential.** LeAPP applied VBG/ACT (already applicable to lesioned brains) to a specific stroke cohort. We apply LeAPP (validated in stroke's constrained morphology) to TBI's heterogeneous morphology — where the framework's implicit assumptions (unilateral, low mass effect) genuinely strain. This is a stronger empirical test of the framework's generalizability than LeAPP's cohort application was of VBG's.
2. **neuroLIT is a different class of technique from VBT** (learned DDPM vs. deterministic mirror). LeAPP's move from VBG → VBT was refinement within the same conceptual class (both mirror-graft). Our third arm is a genuinely different conceptual approach to anatomy mitigation.
3. **Cohort scale is larger on real subjects** (N ~ 100 vs. N = 36), though LeAPP's synthetic component (N = 81) partially compensates.
4. **Reproducibility infrastructure is meaningfully deeper** — per-step provenance JSON at every stage + containerized distribution (GHCR + DockerHub) + BIDS-App wrapper + Snakemake DAG. LeAPP has a repo but not this stack.
5. **Bilateral-lesion handling is a specific stress test** of an implicit LeAPP assumption. LeAPP didn't stress-test VBG's assumptions in the same way.

### 1.6 Honest verdict

**Roughly comparable magnitude, but with two important differences:**

1. **Character of contribution differs.** LeAPP was a **framework-formation** paper: it combined pre-existing pieces into a new named methodological package. Ours is a **framework-extension** paper: it takes LeAPP's package and extends it in three specific directions (new population, new arm, new infrastructure).
2. **Reviewer scrutiny differs by contribution class.** Framework-formations get credit for the combination (whole > sum of parts). Framework-extensions have to earn credit by demonstrating each extension is non-trivial. LeAPP-vs-VBG was accepted as framework-formation; we have to defend each of our extensions individually.

**Implication for venue acceptance:**
- **HBM (default target):** comparable acceptance risk — LeAPP was published there, extension papers of similar magnitude also publish there.
- **NeuroImage (stretch):** potentially harder than LeAPP-tier because framework-formations tend to fare slightly better than same-magnitude framework-extensions at methods-lead venues. Item 1 (Tier B synthetic validation, per [neuroimage_prerequisites.md](neuroimage_prerequisites.md)) is the specific move that closes this gap.

### 1.7 The specific asymmetry to be aware of

LeAPP had a hidden advantage over its precedents that we don't have vs. LeAPP: **it named itself and became the reference point.** Future papers now cite "LeAPP" as a thing, not "the framework of Bey 2024." This gives LeAPP a self-reinforcing brand.

If we name our pipeline something analogous ("`dkt_lesion_connectomics`" or similar) and publish under that name, we get some of that brand advantage. If we just position as "extension of LeAPP to TBI," we're implicitly agreeing to live under LeAPP's brand — which caps our long-term citation trajectory.

---

## Part 2 — Four baseline improvements to close the perceived gap

These are the four highest-leverage additions to shrink the "framework-extension" perception. Each is doc-referenced in [neuroimage_prerequisites.md](neuroimage_prerequisites.md) or [index.md](index.md).

| # | Enhancement | Cost | Payoff | Doc reference |
|---|---|---|---|---|
| **A** | Run Tier B synthetic-lesion validation on CIDUR | ~4 wks compute+analysis | Matches LeAPP's methodological completeness signal | [neuroimage_prerequisites.md § Item 1](neuroimage_prerequisites.md#item-1--synthetic-lesion-validation-on-cidur) |
| **B** | Name the pipeline as a citable framework | ~1 day | Brand advantage for citation trajectory | Not yet documented — decision item |
| **C** | Foreground neuroLIT integration as a genuinely new anatomy-mitigation option (not "third arm we added") | Analysis-only (framing) | Reviewers see novel technique class, not incremental arm | Manuscript framing decision |
| **D** | Make bilateral-lesion handling a first-class result, not a supplement | Analysis-only (elevate) | Genuine scientific bite LeAPP didn't cover | [neuroimage_prerequisites.md § 3a](neuroimage_prerequisites.md#3a-bilateral-tbi-subgroup-characterized) — currently marked "supplement figure" |

Do these four and our distance-from-precedent looks similar to LeAPP's. Skip them and we look meaningfully more derivative than LeAPP was.

---

## Part 3 — Additional enhancement menu (ranked by novelty × cost)

Beyond the four above, these are additional differentiators. Note: several overlap other papers in the portfolio — flagged as "portfolio conflict" where they'd cannibalize Paper 4 novelty.

### Tier 1 — high leverage, likely worth adding

| # | Enhancement | What it delivers | Cost | Portfolio note |
|---|---|---|---|---|
| **5** | **Edge-uncertainty quantification** via bootstrap resampling of tractography seeds or subject-level bootstrap of streamline weights | Turns "the connectome is X" into "the connectome is X ± Y." LeAPP reported point estimates only. Already flagged as candidate in [../publication_strategy.md](../publication_strategy.md) line 148 ("bootstrap / split-half stability of key edges") | ~2 wks compute + analysis code | Clear Paper 1 territory |
| **6** | **Cross-parcellation robustness suite** — DKT (primary) + Schaefer 200 (already in [analysis_plan.md § 3](analysis_plan.md#3-primary-parcellation)) + 4S156 (per [../outputs.md](../outputs.md), supported by QSIRecon when `QSIRECON_ATLASES` enabled) | If factorial effect sizes are consistent across parcellations → robustness win. If they diverge → per-parcellation sensitivity result. Either way publishable | ~1 wk (rerun connectome step only) | Clear Paper 1 territory |
| **8** | **Lesion-topology → arm-recommendation decision tree** | Turns the factorial results into an actionable output: "given lesion location + volume + bilaterality, use arm X." Shifts contribution from "sensitivity science" to "actionable methods guidance." LeAPP didn't do this | 1–2 wks post-hoc analysis | Clear Paper 1 territory — **highest marginal value beyond the baseline four** |

### Tier 2 — medium leverage, worth if timeline permits

| # | Enhancement | What it delivers | Cost | Portfolio note |
|---|---|---|---|---|
| **9** | **Automated lesion segmentation comparison** — clinician-traced vs. nnU-Net / MELD masks per arm | Demonstrates sensitivity to mask source; enables fully-automated cohort processing without expert tracers. LeAPP used clinician-traced masks only | 2× compute for a subset | Clear Paper 1 territory |
| **10** | **Multi-measure connectome consistency** — report factorial effects across streamline count / SIFT2 / mean length / mean FA / mean MD (already produced from one tractogram) | Robustness if consistent, insight if not. Uses underused pipeline capability | Analysis-only, no additional compute | Clear Paper 1 territory |
| **12** | **Prospective preregistration** — post [analysis_plan.md](analysis_plan.md) to OSF or AsPredicted before opening group results | Reviewer trust in the primary contrasts. LeAPP wasn't prospectively registered | ~1 day | Clear Paper 1 territory |

### Tier 3 — portfolio conflicts (avoid — belongs to Paper 4)

| # | Enhancement | Why it's a conflict |
|---|---|---|
| **7** | Test-retest reliability / ICC on repeat scans | Explicitly assigned to Paper 4 per [../paper4_longitudinal.md](../paper4_longitudinal.md) line 20 ("session-paired Δ, ICC / test–retest as secondary content") — pulling this into Paper 1 cannibalizes Paper 4 novelty |
| **11** | Cross-site harmonization (ComBat / site-fixed effects) | Explicitly assigned to Paper 4 per [../paper4_longitudinal.md](../paper4_longitudinal.md) line 42 ("harmonization method: ComBat default") and [../publication_strategy.md § Paper 4](../publication_strategy.md) — cross-site harmonization is Paper 4's core resource contribution |

**Rule:** if it belongs to Paper 4, don't pull it into Paper 1 — that hurts both papers. Paper 1 stays methods-sensitivity focused; Paper 4 stays multisite-resource focused.

### Tier 4 — scope-expanding, requires re-planning

| # | Enhancement | Why not now |
|---|---|---|
| **13** | Deep Atropos as full third arm dimension (3 anatomy × 2 ACT × 2 5TT source = 12 arms) | Currently supplement-only per [analysis_plan.md § 10](analysis_plan.md#10-deep-atropos-sensitivity-figure-in-supplement) and [../publication_strategy.md](../publication_strategy.md). Promoting to full arm doubles cohort compute cost and reframes the paper. Legitimate but scope-expanding — requires publication-strategy amendment before adding |

### Tier 5 — nice-to-have, mostly skip

- **14** Multi-shell DWI robustness — depends on cohort having multi-shell subjects; probably too niche
- **15** Publish BIDS-Derivatives on Zenodo with DOI — standard practice, not a novelty differentiator
- **16** LQT/BCB SDC cross-check — Paper 2 territory, leave there
- **17** Full FC integration as robustness — Paper 2's Griffis chain, leave there
- **18** Effect of MRI acquisition parameters — requires acquisition-heterogeneity data
- **19** Data-augmented training/validation — ML-adjacent, scope creep
- **20** Lesion age (acute / subacute / chronic) stratification — depends on TRACK-TBI visit-timing spread

---

## Part 4 — Recommended combined package

If we add the four baseline improvements (A/B/C/D) plus items **5, 6, 8, 10, 12** from Tier 1/2:

1. **A.** Tier B synthetic validation
2. **B.** Framework naming
3. **C.** Foreground neuroLIT
4. **D.** First-class bilateral handling
5. **5.** Edge-uncertainty quantification
6. **6.** Cross-parcellation robustness
7. **8.** Decision-tree recommendation
8. **10.** Multi-measure consistency
9. **12.** Preregistration

...the paper's distance from LeAPP looks **substantially larger than LeAPP-vs-VBG**. That combination would make a legitimate *NeuroImage* main submission (not just stretch) and may earn a *Human Brain Mapping* editorial preview.

**The paper would move from** "TBI extension of LeAPP" **to** "a methodologically-comprehensive framework for lesion-aware structural connectomics validated in TBI, with actionable per-lesion arm-selection guidance."

### If you can only add three enhancements beyond the baseline four

**Priority order:**

1. **#8 — decision-tree recommendation** (highest marginal value; functionally shifts paper from "which knobs matter" to "here's what you should do")
2. **#6 — cross-parcellation robustness** (heads off the top reviewer question)
3. **#5 — edge-uncertainty quantification** (rewrites the story from "we ran LeAPP on TBI" to "we made LeAPP's outputs quantitatively defensible in TBI")

---

## Part 5 — Open decisions this doc surfaces

Not locked — flagged for future decision.

- [ ] **Framework name commitment** — do we brand the pipeline (e.g., `dkt_lesion_connectomics`) or accept living under LeAPP's brand? Not yet a locked decision anywhere.
- [ ] **Elevate bilateral handling to main result?** — currently marked "supplement figure" in [manuscript_skeleton.md § Supplement](manuscript_skeleton.md#supplement) S5.
- [ ] **Include edge-uncertainty (#5)?** — analysis-plan decision, not yet in [analysis_plan.md](analysis_plan.md).
- [ ] **Include cross-parcellation suite (#6)?** — [analysis_plan.md § 3](analysis_plan.md#3-primary-parcellation) mentions Schaefer 200 as sensitivity but doesn't lock 4S156 as third parcellation.
- [ ] **Preregistration commitment (#12)?** — is the analysis plan going to OSF before group results open?
- [ ] **Decision-tree deliverable (#8)?** — commit to producing it as a supplementary artifact + integrating into pipeline output?

Each of these belongs in [analysis_plan.md](analysis_plan.md) as a locked decision when committed.

---

## Decision log

| Date | Item | Decision | Rationale |
|------|------|----------|-----------|
| 2026-09-17 | Doc created | Contribution-strategy analysis captured from distance-from-LeAPP discussion | Baseline four + enhancement menu documented; portfolio conflicts with Paper 4 flagged (items 7, 11); scope-expanding items (13) flagged |
| | | | |

---

## See also

- [index.md](index.md) — factorial paper cover doc + cross-tier citation matrix
- [neuroimage_prerequisites.md](neuroimage_prerequisites.md) — three open items gating NeuroImage tier
- [leapp_lineage.md](leapp_lineage.md) — LeAPP + lineage papers (Radwan / Pollak / Smith)
- [analysis_plan.md](analysis_plan.md) — pre-registration template with locked decisions
- [../publication_strategy.md](../publication_strategy.md) — cross-paper strategy for all four papers
- [../paper4_longitudinal.md](../paper4_longitudinal.md) — Paper 4 territory (harmonization, ICC/test-retest)
