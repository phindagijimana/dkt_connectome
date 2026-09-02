# Publication strategy — TBI lesion-aware connectomics

Living plan for manuscripts built on the **six-arm factorial** design (original /
neuroLIT / VBT × standard / lesion-aware ACT), the TrackTBI lesion cohort, and
reproducible Snakemake + container outputs. LeAPP (Bey et al. 2024) is the
primary comparator; this work extends that framework to **traumatic brain injury**
at cohort scale.

**Related docs:** [Lesion-aware tractography](lesion_aware.md) · [TBI experimental arms](TBI_Experimental_Arms.md) · [Validation](validation.md) ·
[Usage — experiment arms](usage.md) · [Step 3.1 methods](methods/step3_1_lesion_act.md) ·
[Citation](citation.md)

---

## Scientific claim (one sentence)

> In real TBI lesion MRI (~100 subjects), how much do **anatomical mitigation**
> (original vs neuroLIT vs VBT) and **lesion-aware ACT** change structural
> connectomes, and how reliably does the integrated pipeline run?

That is the **LeAPP-class** question Bey et al. answered for ischemic stroke;
TBI contusion, edema, hemorrhage, and bilateral injury are the new territory.

---

## Validation cohort

| Resource | Role in publications |
|----------|----------------------|
| **TrackTBI lesion subset** (~100 subjects with manual lesion masks) | Primary factorial sensitivity and QC cohort for paper 1 |
| **URMC / CIDUR controls** (non-lesion) | Normative connectome or **synthetic lesion injection** on healthy anatomy — not pooled with lesion factorial arms without a separate claim |
| **Pilot subject** (`sub-TBI011011`, six-arm experiment tree) | Engineering gate before full cohort; ACPC lesion warp + pathology QA |

Report **completion rates by arm** (Step 3.1 pathology QA, registration, empty nodes,
tractography hangs). At N≈100, pass/fail tables are primary results, not footnotes.

---

## Paper portfolio

### Default: one flagship + optional satellites

| Manuscript | Primary question | When it stands alone | **Status (Aug 2026)** |
|------------|------------------|----------------------|------------------------|
| **Paper 1 (flagship)** | Factorial inpainting × lesion-aware ACT in TBI | Always — default target | **Active — submit first** |
| **Paper 2 (clinical)** | Lesion topology → structural disconnection → outcomes | Only if behavioral / cognitive / recovery variables exist on the cohort | **Paused** — needs TRACK-TBI outcome merge (GOSE, etc.) |
| **Paper 3 (methods branch)** | Deep Atropos vs HSVS for pathology ACT in TBI | Only after a full head-to-head cohort run — otherwise a supplement to paper 1 | **Deprioritized** — supplement to Paper 1 only |
| **Paper 4 (longitudinal)** | Structural connectivity trajectories / resource at ~1200 sessions | Resource or trajectory paper on one standard arm | **Active — parallel batch** (does not block Paper 1) |

### Current execution priority

```text
1. Paper 1 (factorial)     — primary manuscript; imaging + pipeline only
2. Paper 4 (longitudinal)  — background batch on orig-std (or similar); no GOSE required for resource framing
3. Paper 2 (clinical)      — on hold until TRACK-TBI clinical outcomes are confirmed and merged
4. Paper 3 (Deep Atropos)  — optional sensitivity figure in Paper 1; not a standalone manuscript
```

Paper 1 and Paper 4 do **not** require GOSE or other clinical scores. Paper 2 requires
a **separate clinical data merge** (see [Clinical outcomes for Paper 2](#clinical-outcomes-for-paper-2) below).

**Do not** split paper 1 into separate “inpainting paper” and “ACT paper” on the
same ~100 subjects unless reviewers explicitly request it (rare).

### What stays inside paper 1 (not separate manuscripts)

| Topic | Treatment |
|-------|-----------|
| ACPC-first lesion → 5TT warp (HSVS path) | Methods subsection + supplement |
| neuroLIT vs VBT only | Part of factorial — not its own paper |
| Registration / pathology QA metrics | Supplementary tables |
| Pipeline / Snakemake / containers | Methods + data availability — not a standalone software paper unless scope is deliberately narrowed |

### Avoid salami slicing

**Weak splits:** same connectome matrices with different network metrics; “Part I /
Part II” on identical subjects; pipeline note followed by “application” with no
new data.

**Strong splits:** methods factorial (paper 1) vs clinical disconnection (paper 2)
with **different primary claims**; TBI lesion cohort vs normative atlas (CIDUR)
with **different cohorts and questions**; HSVS factorial vs Deep Atropos with
**new experiments**.

---

## Paper 1 — flagship (submit first)

### Working title (shape)

*Lesion-aware structural connectomics in traumatic brain injury: a factorial
comparison of inpainting, virtual brain transplant, and pathology-informed
tractography*

### Design

Six `--experiment-arm` values (see [Lesion-aware § Experiment arms](lesion_aware.md#experiment-arms-anatomy--act)):

| Arm | Anatomy | ACT |
|-----|---------|-----|
| `orig-std` | Original T1w | Standard |
| `orig-lesion` | Original T1w | Lesion-aware |
| `neurolit-std` | neuroLIT | Standard |
| `neurolit-lesion` | neuroLIT | Lesion-aware |
| `vbt-std` | VBT (LeAPP port) | Standard |
| `vbt-lesion` | VBT | Lesion-aware |

On inpainted `*-lesion` arms, **HSVS 5TT from mitigated T1w** and **pathology
from the original BIDS lesion ROI** are intentional (LeAPP factorial); see
[Intentional cross-source design](lesion_aware.md#intentional-cross-source-design-on--lesion-inpainted-arms).

### Pre-specify contrasts (before inspecting group results)

| Level | Contrast | Question |
|-------|----------|----------|
| **Primary** | `*-std` vs `*-lesion` within each anatomy backend | Does pathology ACT change connectomes? |
| **Secondary** | `orig-*` vs `neurolit-*` vs `vbt-*` within std and lesion | How much does inpainting matter? |
| **Interaction** | Anatomy × ACT (e.g. `neurolit-lesion` vs `neurolit-std`) | Is ACT benefit larger after inpainting? |

Pick **one primary numeric outcome** (e.g. global matrix correlation between
std and lesion within `orig`, or mean absolute edge difference) so the analysis
is not purely exploratory.

### Suggested main figures

1. Pipeline schematic — six arms, ACPC lesion warp, `5ttedit -path`
2. Cohort QC — completion rate, pathology QA pass rate, streamline stats by arm
3. Factorial sensitivity — distributions of connectome change across arms
4. Representative cases — lesion, pathology channel, tractography overlays
5. Group disconnectome / network summary (spatial consistency)
6. **Optional:** synthetic lesions on healthy controls (LeAPP-style sanity check)

### Validation (TBI-appropriate)

| Type | Content |
|------|---------|
| **Technical** | Pathology channel coverage, lesion→5TT overlap, streamline counts, empty-node rate |
| **Internal consistency** | Bootstrap / split-half stability of key edges where repeat scans exist |
| **Synthetic lesions** | Inject known lesions on CIDUR or healthy subset; measure connectivity recovery |
| **Clinical face validity** | Disconnectome vs lesion location; moderation by volume and lobar site |

### Differentiation from LeAPP (required in intro / discussion)

- TBI lesion morphology vs ischemic stroke
- neuroLIT + VBT factorial vs LeAPP’s inpainting stack
- ACPC / HSVS registration workflow for Step 3.1
- TrackTBI multi-site cohort and explicit provenance per arm

### Engineering prerequisites (before cohort scale-up)

1. Rebuild `dkt_lesion_act.sif` after Step 3.1 script changes (or bind-mount the
   repo script in Snakemake) — see [Containers § Step 3.1](containers.md) and
   [lesion_act README on GitHub](https://github.com/phindagijimana/dkt_connectome/blob/main/dwi_pipeline/containers/lesion_act/README.md)
2. Clear QSIRecon internal `tckgen` hangs on `*-lesion` arms where applicable
3. Pilot on one subject until `lesion_warp_method.txt` and pathology QA pass
4. Run full factorial on ~100 subjects with isolated `RESULTS_ROOT/arms/<arm>/` trees

---

## Paper 2 — clinical disconnectome (optional, **paused**)

**Primary question:** Where and how do lesions **disconnect** brain networks, and
does that relate to **symptoms, cognition, or recovery**?

| vs paper 1 | |
|------------|--|
| Paper 1 | Methods + sensitivity (“does processing choice matter?”) |
| Paper 2 | Biology + clinical (“what does disconnection mean in TBI?”) |

**Requires:** outcome variables merged to the same subjects/sessions as the scan —
see [Clinical outcomes for Paper 2](#clinical-outcomes-for-paper-2). These are **not**
produced by the connectome pipeline and are **not** in BIDS imaging folders by default.

**Canonical downstream arm:** pre-specify one lesion-aware arm (e.g. `neurolit-lesion`
or `vbt-lesion`) for clinical analyses so paper 2 does not reopen the full factorial.

**Without outcomes:** fold disconnectome summaries into paper 1 as one figure — do
not spin a second manuscript. **Current plan:** Paper 2 is **on hold** until a
TRACK-TBI clinical export (GOSE or verified alternative) is merged; focus on Papers 1 and 4.

---

## Paper 4 — longitudinal connectomics / resource (parallel)

**Primary question:** How does structural connectivity change across time after TBI
at multisite scale (~600 subjects × 2 sessions, ~1200 total)?

| vs paper 1 | |
|------------|--|
| Paper 1 | Cross-arm processing sensitivity at one timepoint |
| Paper 4 | Time × connectivity on **one standard arm** (e.g. `orig-std`) |

**Does not require:** GOSE or clinical outcomes for a **resource / derivatives** framing
(*Scientific Data*, *GigaScience*). Optional outcome-linked trajectories if clinical
merge becomes available later.

**Run in parallel** with Paper 1 cohort jobs — lower priority than factorial completion,
but does not block Paper 1 submission. Plan **session-aware** `RESULTS_ROOT` layout and
**site/scanner harmonization** before scaling (see Palacios TRACK-TBI DTI precedent).

---

## Paper 3 — Deep Atropos vs HSVS (optional, **deprioritized**)

Only if **native-T1 Deep Atropos 5TT** (`5ttgen deep_atropos`) is run as a full
alternative branch with cohort-level head-to-head metrics. Otherwise document as
future work or a **supplement to Paper 1** (recommended: `deep-atropos-pilot` on
TBI011011 as one sensitivity figure — not a third manuscript).

---

## Journal targets

### Paper 1 — factorial methods + ~100 TBI lesion subjects

| Priority | Journal | Notes |
|----------|---------|-------|
| **1 (default)** | [*Human Brain Mapping*](https://onlinelibrary.wiley.com/journal/10659471) | LeAPP’s venue; integrated pipeline + clinical MRI connectomics |
| **Stretch** | [*NeuroImage*](https://www.sciencedirect.com/journal/neuroimage) | Higher bar — strong synthetic validation + exceptionally clean cohort stats |
| **Good fit** | [*Imaging Neuroscience*](https://direct.mit.edu/imag) | Open access; methods + reproducibility friendly |
| **Methods-heavy angle** | [*Medical Image Analysis*](https://www.sciencedirect.com/journal/medical-image-analysis) | If registration / 5TT pathology engineering is the lead story |
| **Backup / faster** | [*NeuroImage: Reports*](https://www.sciencedirect.com/journal/neuroimage-reports) | Important sensitivity work without breakthrough clinical findings |
| **Reproducibility emphasis** | [*GigaScience*](https://academic.oup.com/gigascience) | Containers, BIDS derivatives, shareable cohort resource |

**Usually not the right home for paper 1:** *Journal of Neurotrauma* (injury biology
outcomes), JOSS (software-only), *Radiology* / *AJNR* (clinical radiology practice).

### Paper 2 — disconnectome + outcomes (**paused**)

Requires TRACK-TBI clinical merge (GOSE, etc.) — see [Clinical outcomes for Paper 2](#clinical-outcomes-for-paper-2).

| Priority | Journal |
|----------|---------|
| **1** | [*Journal of Neurotrauma*](https://home.liebertpub.com/publications/journal-of-neurotrauma/1/overview) |
| **Stretch** | [*Brain*](https://academic.oup.com/brain), [*Neurology*](https://n.neurology.org/) |
| **Alternative** | *Human Brain Mapping* if disconnectome is the main figure set |

### Paper 3 — Deep Atropos comparison

*NeuroImage: Reports*, *Medical Image Analysis*, or Paper 1 **supplement** (preferred over standalone).

### Paper 4 — longitudinal resource / trajectories

| Priority | Journal | Notes |
|----------|---------|-------|
| **1 (resource)** | [*Scientific Data*](https://www.nature.com/sdata/), [*GigaScience*](https://academic.oup.com/gigascience) | ~1200-session connectome derivatives + QC + harmonization doc |
| **Stretch (science)** | [*Human Brain Mapping*](https://onlinelibrary.wiley.com/journal/10659471) | Pre-specified trajectory hypothesis + harmonization; GOSE optional |

No GOSE required for resource framing. Does not block Paper 1.

### Submission order

```text
1. Human Brain Mapping  — paper 1 (TBI factorial)
2. Scientific Data / GigaScience / HBM — paper 4 (longitudinal resource or trajectory)
3. Journal of Neurotrauma — paper 2 (only if TRACK-TBI outcome merge supports it)
4. Paper 1 supplement — paper 3 (Deep Atropos sensitivity; not standalone)
```

---

## What reviewers will expect (HBM / NeuroImage tier)

1. Cohort **completion table** by arm — not success stories only
2. **Pre-specified contrasts** (std vs lesion; orig vs neuroLIT vs VBT)
3. **Quantitative sensitivity** — matrix correlations / edge differences, not only tractography renders
4. **TBI vs stroke** discussion — why LeAPP does not suffice unchanged
5. **Reproducibility** — pipeline version, containers, BIDS, per-arm provenance (`lesion_aware_act.json`)
6. **Optional:** synthetic lesions on healthy brains (LeAPP did this)

Missing (3)–(6) often moves a *NeuroImage* submission to *HBM* or *NeuroImage: Reports* — still a strong outcome.

---

## Methods text to reuse

Factorial description for inpainted lesion arms (from [Lesion-aware](lesion_aware.md#intentional-cross-source-design-on--lesion-inpainted-arms)):

> Structural T1w was lesion-mitigated before cortical reconstruction (neuroLIT or
> virtual brain transplant). HSVS five-tissue-type images were derived from that
> mitigated anatomy. For lesion-aware ACT, the **clinician-traced lesion mask on
> the original pre-mitigation T1w** was retained, transformed to diffusion space,
> and assigned to the MRtrix pathology compartment (`5ttedit -path`). Diffusion
> MRI was not inpainted. This follows the factorial lesion-processing framework
> of Bey et al. (2024): corrected anatomy for segmentation, original lesion extent
> for tractography priors.

Cite upstream tools per [References by step](references.md). State pipeline version
(`./run --version` → `app.json`).

---

## Reporting checklist

- [ ] Pipeline version and container digests
- [ ] Six-arm provenance or explicit subset with justification
- [ ] Per-subject Step 3.1 QA (`lesion_warp_method.txt`, pathology overlap)
- [ ] Primary / secondary contrasts pre-registered or pre-specified internally
- [ ] Connectome integrity (78×78 DKT, empty nodes) — [Validation](validation.md)
- [ ] Disconnectome integrity if `--disconnection` — [Disconnectome § Integrity QC](disconnectome.md#integrity-qc)
- [ ] Data availability (BIDS derivatives policy, Zenodo software DOI when tagged)

---

## Suggested timeline

```text
Phase A — Engineering:  rebuild lesion_act SIF → pilot pass on one subject
Phase B — Cohort:        six arms × ~100 lesion subjects → QC CSV + arm summaries
Phase C — Analysis:      pre-specified contrasts → figures → internal review
Phase D — Submit:        paper 1 → HBM (or NeuroImage if validation is exceptional)
Phase E — Optional:      paper 4 longitudinal batch (parallel, orig-std)
Phase F — On hold:       paper 2 if TRACK-TBI GOSE merge confirms N≥40 complete cases
```

Maintainer release track (software DOI, digest table):
[v1.0 science track on GitHub](https://github.com/phindagijimana/dkt_connectome/blob/main/dwi_pipeline/docs/maintainer/v1_science_track.md).

---

## Manuscript planning notes

Internal planning supplement (Aug 2026). Extends the sections above with research
questions, defending outcomes, feasibility, prior-literature analogs, and data
provenance. Lock the **primary numeric metric** and **clinical merge keys** before
opening group-level results.

### Planned cohort scale (reference)

| Track | Subjects / sessions | Arms | Role |
|-------|---------------------|------|------|
| Paper 1 factorial | ~20 sensitivity → ~100 flagship | 6 | Methods sensitivity — **active** |
| Paper 2 clinical | ~55 neurolit-lesion sessions (20 overlap factorial → 35 extra) | 1 fixed | Disconnection ↔ outcomes — **paused** (no clinical merge yet) |
| Paper 3 Deep Atropos | ~30–100 paired | HSVS vs Deep Atropos | Supplement to Paper 1 only — **deprioritized** |
| Paper 4 longitudinal | ~600 × 2 sessions (~1200 total) | 1 standard (e.g. `orig-std`) | Trajectory / resource — **active (parallel)** |

**LeAPP comparator (Bey et al. 2024):** 51 participants total (36 ischemic stroke +
15 controls); stroke patients up to 4 longitudinal scans; synthetic validation
**N≈81** artificially lesioned healthy brains. Our ~100 TBI lesion target is larger
than LeAPP’s 36 stroke patients; N≈20 factorial is smaller and should be framed as
sensitivity, not flagship cohort scale.

Run on **one standard arm** in parallel with Paper 1; not a prerequisite for Paper 1.

---

### Clinical outcomes for Paper 2

Paper 2 needs **two data streams** joined on `sub-<ID>` (+ matched visit / `ses-<Y>`):

```text
Imaging (this pipeline)     →  disconnectome, lesion volume, neurolit-lesion connectome
Clinical (TRACK-TBI study)  →  GOSE, RPQ, neuropsych, GCS, demographics, visit dates
```

Clinical scores are **not** in `dkt_connectome.csv`, radiology reports, or BIDS DWI
folders. They are **study-collected follow-up data** from participating TRACK-TBI
trauma centers — not routine hospital EMR fields you pull alongside the MRI.

#### Where GOSE and related scores come from

| Measure | What it is | TRACK-TBI collection |
|---------|------------|----------------------|
| **GOSE** (Extended Glasgow Outcome Scale) | 8-point **structured interview** on overall functional recovery (work, independence, social life, symptoms) | Follow-up at ~2 weeks, 3, 6, 12 months; in-person or phone; trained assessors; [central curation](https://pmc.ncbi.nlm.nih.gov/articles/PMC8390785/) |
| **RPQ / PCS** (Rivermead Post-Concussion Questionnaire) | Patient-reported **post-concussion symptoms** | Study questionnaire at follow-up visits |
| **Neuropsych composites** | Standardized **cognitive tests** (processing speed, executive function, memory, etc.) | Research batteries at follow-up; more missing data than GOSE |
| **GCS, age, sex, education** | Acute injury severity and demographics | Study intake / chart abstraction per NINDS Common Data Elements |

**Access:** TRACK-TBI **clinical / outcomes database** via study DUA and site PI or
data core — merge export to imaging subject list. Ask: *“For lesion-mask subjects with
DWI, do we have GOSE (and visit date) at 6 months in the export we can use?”*

| Your situation | Implication |
|----------------|-------------|
| BIDS imaging + lesion masks only | **Paper 2 not ready** — imaging side can be run, but no clinical regression |
| TRACK-TBI collaborator with outcomes export | Build **complete-case table** (see below); revisit Paper 2 if N≥40 |
| GOSE missing but RPQ/neuropsych rich | RPQ or one cognitive composite as **pre-specified primary** instead |

#### Recommended outcome hierarchy (when Paper 2 resumes)

Lock **before** group-level analysis:

| Role | Default choice | Alternative |
|------|----------------|-------------|
| **Primary clinical** | **GOSE** at consistent window (e.g. 6 months) | RPQ if mild-TBI symptom cohort; one cognitive composite if cognition-first |
| **Secondary** | RPQ/PCS; one neuropsych composite | — |
| **Primary imaging** | Global mean disconnection (`disconnectome_qc.json`) | Network summaries (FDR) |
| **Mandatory covariate** | Lesion volume (mm³) | Proves “beyond lesion size” |

**Strong Paper 2** additionally requires **incremental validity** — disconnection
improves prediction vs lesion-volume-only models — on **≥45** complete cases
(GOSE + disconnectome + covariates).

#### Complete-case spreadsheet (build before committing to Paper 2)

```text
sub | ses | lesion_mask | neurolit-lesion_done | GOSE_6mo | RPQ_6mo | age | sex | GCS | lesion_vol_mm3
```

| Complete rows | Action |
|---------------|--------|
| ≥45 | Paper 2 competitive at *J Neurotrauma* |
| 30–44 | Possible with limitations |
| <30 | Fold disconnectome figure into Paper 1; keep Paper 2 on hold |

**Reuse without Paper 2:** group disconnectome map + spatial face validity (lesion
topology) as **one figure in Paper 1** — no GOSE required.

---

### Research questions per paper

#### Paper 1 — factorial methods (flagship)

**Overarching:** In real TBI with focal lesions, how much do anatomy mitigation
(orig / neuroLIT / VBT) and lesion-aware ACT change structural connectomes, and
how reliably does the integrated pipeline run at cohort scale?

| ID | Question |
|----|----------|
| RQ1 (primary) | Does **lesion-aware ACT** produce systematically different connectomes than **standard ACT** within each anatomy backend? |
| RQ2 (secondary) | How much does **anatomy mitigation** (orig vs neuroLIT vs VBT) change connectomes, holding ACT fixed? |
| RQ3 (interaction) | Is ACT benefit **larger after inpainting** (anatomy × ACT interaction)? |
| RQ4 (operations) | What are **completion rates, QC pass rates, and failure modes** across six arms? |
| RQ5 (optional) | On **synthetic lesions** in healthy controls, does the pipeline recover expected connectivity loss (LeAPP-style)? |

**Not asking:** which arm is ground truth; whether disconnection predicts clinical recovery.

#### Paper 2 — clinical disconnectome (optional, **paused**)

**Status:** On hold — pipeline can produce disconnectomes, but **TRACK-TBI clinical
outcome merge (GOSE, etc.) is not in hand**. Do not plan cohort `neurolit-lesion`
runs for Paper 2 until complete-case N is confirmed.

**Overarching:** Where do TBI lesions structurally disconnect brain networks, and
does that disconnection relate to symptoms, cognition, or recovery beyond lesion
size alone?

| ID | Question |
|----|----------|
| RQ1 | Do focal lesions produce **spatially coherent** structural disconnection (lesion topology → network disconnection)? |
| RQ2 | Is **greater disconnection** associated with **worse outcomes** (GOSE, PCS, cognition) after covariate adjustment? |
| RQ3 | Does disconnection explain outcomes **better than lesion volume or location alone**? |
| RQ4 | Are effects **network- or site-specific** (which disconnected networks map to which deficits)? |
| RQ5 (optional) | Do lesion size, lobe, or bilaterality **moderate** disconnection–outcome links? |

**Gate:** merged TrackTBI clinical table on the lesion cohort. **Fixed arm** (e.g.
`neurolit-lesion`) — do not reopen the factorial.

#### Paper 3 — Deep Atropos vs HSVS (**deprioritized — supplement only**)

**Overarching:** For pathology-informed ACT in TBI, does native Deep Atropos 5TT
materially change tissue priors, tractography, and connectomes vs HSVS/ACPC on the
same subjects and masks?

| ID | Question |
|----|----------|
| RQ1 | Do Deep Atropos and HSVS differ in **5TT / tissue classification** at the lesion and rim? |
| RQ2 | Do 5TT differences translate into **systematic paired connectome differences**? |
| RQ3 | Which source is **more operationally viable** (QA, empty nodes, failures, runtime)? |

**Gate:** cohort Deep Atropos branch — single-subject pilot is supplement only.

#### Paper 4 — longitudinal resource (~600 × 2 sessions, **active parallel**)

**Overarching:** How does structural connectivity change across time after TBI at
multisite scale?

| ID | Question |
|----|----------|
| RQ1 | Do connectome metrics **change systematically** from timepoint 1 to 2? |
| RQ2 | Are trajectories associated with **injury severity or recovery** (if outcomes linked)? |
| RQ3 | How much variance is **site/scanner** vs biology (harmonization)? |

Run on **one standard arm** in parallel with Paper 1; not a prerequisite for Paper 1.

**One-line summary**

```text
Paper 1        → Does processing choice (anatomy × ACT) change TBI connectomes reliably?
Paper 2        → Does lesion-induced disconnection explain clinical outcomes? (paused)
Paper 3        → Deep Atropos vs HSVS — supplement to Paper 1 only
Paper 4        → How does structural connectivity evolve over time at scale?
```

---

### Key ideas per paper

#### Paper 1

- Factorial 2×3 design: six `--experiment-arm` presets, isolated `RESULTS_ROOT/arms/<arm>/` trees.
- Primary contrast: `*-std` vs `*-lesion` within each anatomy backend.
- Secondary: orig vs neuroLIT vs VBT; interaction anatomy × ACT.
- Outcomes: QC-by-arm tables, quantitative matrix/edge sensitivity, representative cases.
- Validation: synthetic lesions on CIDUR controls (LeAPP-style); TBI011011 = engineering pilot.
- Comparator: Bey et al. 2024 LeAPP; emphasize TBI vs stroke and ACPC/HSVS workflow.
- Default venue: *Human Brain Mapping*.

#### Paper 2 (**paused**)

- Single arm: neurolit-lesion (~55 subject-sessions) — **do not scale until clinical merge confirmed**.
- Needs **TRACK-TBI study export** (GOSE primary if available; RPQ/neuropsych secondary) — **not pipeline outputs**.
- See [Clinical outcomes for Paper 2](#clinical-outcomes-for-paper-2).
- Without outcomes: one disconnectome figure in Paper 1 only.

#### Paper 3 (**deprioritized**)

- Head-to-head 5TT on same subjects — **supplement to Paper 1**, not standalone.
- TBI011011 `deep-atropos-pilot` → one sensitivity figure only unless cohort N≥30 shows large effects.

#### Paper 4 (**active parallel**)

- Single standard arm on ~1200 sessions; session-aware results layout.
- No GOSE required for resource paper; harmonization plan required before scale-up.
- Parallel to Paper 1 — does not block factorial submission.

---

### Outcomes that defend each paper

| Paper | Tier A (must have) | Tier B (strengthens) | Success threshold (honest) |
|-------|-------------------|----------------------|----------------------------|
| **1** | Arm completion; pre-specified std vs lesion contrast; quantitative matrix metric | Anatomy contrast; interaction; synthetic lesions; QC tables | **Min:** N≈20, primary contrast significant, QC table. **Strong:** N≈80–100 + synthetic panel. |
| **2** | Spatial disconnectome coherence; global/network disconnection; **clinical association** | Incremental validity vs volume; network-specific effects; moderation | N≈40–55 + one primary outcome (e.g. GOSE); disconnection survives volume adjustment. |
| **3** | Paired 5TT differences at lesion rim; paired connectome delta | QA tradeoff; disconnectome delta between sources | N≈30–50 paired; systematic non-noise effects. |
| **4** | Session-paired Δ connectome; harmonization plan | ICC / test–retest; GOSE-linked trajectories (optional) | Resource: *Scientific Data* / *GigaScience*; no clinical gate |

#### How outcomes differ

| | Paper 1 | Paper 2 | Paper 3 | Paper 4 |
|---|---------|---------|---------|---------|
| **Claim type** | Processing sensitivity | Biology + clinical | 5TT engineering | Time × connectivity |
| **Comparison** | Within-subject, cross-arm | Disconnection vs clinical score | HSVS vs Deep Atropos paired | Session 1 vs 2 |
| **Primary CSV** | `dkt_connectome.csv` × 6 | `disconnection_matrix.csv` + clinical merge | Connectomes from two 5TT branches | `dkt_connectome.csv` × time |
| **Needs external clinical data?** | No | **Yes (gate — not in repo today)** | No | No (optional for science paper) |
| **Status** | **Active** | **Paused** | **Supplement only** | **Active (parallel)** |

#### Obtaining outcomes from current data

**Already in pipeline outputs (per subject / arm under `RESULTS_ROOT`):**

| Outcome | Path / tool |
|---------|-------------|
| Connectome matrices | `arms/<arm>/connectomes/sub-<ID>/dkt_connectome.csv` |
| Empty nodes | `connectomes/sub-<ID>/parcellation.json` |
| Inpaint QC | `inpainted/.../inpainting_qc.json` |
| ACT provenance | `lesion_aware_act/sub-<ID>/lesion_aware_act.json` |
| Subject QC rollup | `scripts/collect_subject_qc.py` → `qc/sub-<ID>/subject_qc.json` |
| Disconnection matrix | `connectomes/sub-<ID>/disconnectome/disconnection_matrix.csv` |
| Disconnection summary | `disconnectome/disconnectome_qc.json`, `lesion_roi_metrics.csv` |
| Node strength | `node_strength/strength/per_subject/sub-<ID>_strength.csv` |
| Deep Atropos 5TT | `deep_atropos/sub-<ID>/base_5tt_native.mif` |

**Still to build:** factorial harvest script (walk six arms → paired Δ metrics CSV);
synthetic lesion injection on CIDUR (~26 connectomes on NAS, ~61 DWI locally).

**External (Paper 2 gate):** TRACK-TBI **study** clinical export — GOSE, RPQ, neuropsych,
GCS, age, sex — merged on `sub-<ID>` + visit window. **Not** from hospital EMR or
radiology; **not** in this repository today. See [Clinical outcomes for Paper 2](#clinical-outcomes-for-paper-2).

**Current execution focus:** Paper 1 (factorial cohort + analysis registry) and
Paper 4 (longitudinal `orig-std` batch). Paper 2 paused; Paper 3 → Paper 1 supplement.

**Current engineering status (pilot):** `sub-TBI011011` six-arm tree on NAS; CIDUR
Group 1 = 26/27 controls with connectomes (no lesion/disconnectome); full TrackTBI
factorial cohort not yet run at scale.

---

### Honest feasibility review

| Paper | Stand-alone strength | Biggest gap | Fixable? | Go / no-go |
|-------|---------------------|-------------|----------|------------|
| **1** | High (design + LeAPP lineage) | Cohort factorial N + analysis script | Yes | **Active** — N≥20 sensitivity; N≈80–100 flagship |
| **2** | Medium (outcomes-dependent) | TRACK-TBI clinical merge (GOSE) | Maybe (DUA) | **Paused** — revisit if complete-case N≥40 |
| **3** | Low today | Cohort Deep Atropos branch | Yes (compute) | **Supplement only** — not standalone |
| **4** | Medium (resource) | 1200 sessions + harmonization | Yes (parallel) | **Active (background)** — resource framing first |

**Paper 1 failure modes:** tractography figures only; N=1 pilot as cohort; post-hoc
edge fishing; hiding failed arms.

**Paper 2 failure modes:** disconnectome maps without outcome link; arm switching
post-hoc; many outcomes without pre-specified primary.

**Fundamental limitation (all papers):** no in vivo gold-standard structural connectome —
frame as sensitivity / robustness, not “which pipeline is truth.”

**Highest-leverage next steps:**

1. **Paper 1:** analysis registry (primary metric, contrasts) → factorial cohort runs → QC CSV.
2. **Paper 4:** session-aware layout + harmonization plan → `orig-std` batch when capacity allows.
3. **Paper 2 (optional):** one email to TRACK-TBI data contact re GOSE availability; build complete-case spreadsheet before any neurolit-lesion scale-up for clinical aims.

---

### Prior literature analogs

| Your paper | Best existing analog | Similarity | Your addition |
|------------|---------------------|------------|---------------|
| **1** | [Bey et al. 2024 LeAPP](https://doi.org/10.1002/hbm.26701) | ★★★★★ Methods + synthetic validation; stroke | TBI; neuroLIT + VBT factorial; ACPC/HSVS |
| **1** | [Radwan et al. 2023](https://doi.org/10.1162/netn_a_00277) | ★★★ TBI + VBG + ACT; N=5 | Cohort factorial |
| **1** | [Pollak et al. 2025 neuroLIT](https://doi.org/10.1162/imag_a_00446) | ★★ Inpainting QA only | Downstream connectome sensitivity |
| **2** | [Griffis et al. 2019](https://doi.org/10.1016/j.celrep.2019.07.100) | ★★★★★ Disconnection → behavior; stroke N≈114 | TBI + explicit disconnectome matrix + TRACK-TBI outcomes |
| **2** | [Warren et al. 2015](https://doi.org/10.1093/brain/awv075) | ★★★★ TBI graph metrics → cognition | Lesion-aware tractography + disconnection index |
| **2** | [Palacios et al. 2022 TRACK-TBI](https://doi.org/10.1089/neu.2022.0070) | ★★★★ Multisite GOSE; N≈391 mTBI | Disconnectome not tract DTI |
| **2** | [Osmanlıoğlu et al. 2022](https://doi.org/10.1002/hbm.25894) | ★★★ TBI longitudinal + cognition | Normative score vs lesion disconnectome |
| **3** | [Smith et al. 2020 HSVS](https://doi.org/10.1016/j.neuroimage.2020.117345) | ★★ One side of comparison | Cohort Deep Atropos vs HSVS under pathology ACT |
| **Longitudinal** | [Kuceyeski et al. 2020 HBM](https://doi.org/10.1002/hbm.24713) | ★★★ Longitudinal connectome + cognition; mTBI N=26 | Multisite ~1200-session structural resource |
| **Paper 4** | [Palacios et al. 2022 TRACK-TBI](https://doi.org/10.1089/neu.2022.0070) | ★★★★ Multisite longitudinal DTI + GOSE | Structural **connectome** resource / trajectories |

**Novelty gaps (defensible claims):**

- **Paper 1:** No published **orig × neuroLIT × VBT × std/lesion ACT** factorial at TBI cohort scale.
- **Paper 2:** No standard paper combining **TBI focal masks + lesion-aware disconnectome + TRACK-TBI-scale outcomes** in one cohort.
- **Paper 3:** No close peer-reviewed **Deep Atropos vs HSVS pathology ACT** cohort comparison in TBI.
- **Longitudinal / Paper 4:** TRACK-TBI DTI/outcome papers exist at scale; formal **multisite structural connectome resource** at ~1200 sessions remains a gap.

**Republication note:** Prior work (LeAPP, Griffis, Palacios) covers **pieces**, not this
full combination. Paper 1 and Paper 4 are **extensions**, not duplicates — provided
cohort N, pre-specified metrics, and honest QC are delivered. Paper 2 remains valid
only with a confirmed TRACK-TBI clinical merge.

---

## See also

- [Lesion-aware tractography](lesion_aware.md) — LeAPP context, factorial design, TBI QC
- [Validation](validation.md) — cohort context, integrity checks
- [Decision tables — experiment arms](decision_tables.md#experiment-arms)
- [Maintainer — release checklist on GitHub](https://github.com/phindagijimana/dkt_connectome/blob/main/dwi_pipeline/docs/maintainer/publishing.md)
- LeAPP: Bey et al. 2024, *Human Brain Mapping* — [10.1002/hbm.26701](https://doi.org/10.1002/hbm.26701)
