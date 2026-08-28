# Publication strategy — TBI lesion-aware connectomics

Living plan for manuscripts built on the **six-arm factorial** design (original /
neuroLIT / VBT × standard / lesion-aware ACT), the TrackTBI lesion cohort, and
reproducible Snakemake + container outputs. LeAPP (Bey et al. 2024) is the
primary comparator; this work extends that framework to **traumatic brain injury**
at cohort scale.

**Related docs:** [Lesion-aware tractography](lesion_aware.md) · [Validation](validation.md) ·
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

| Manuscript | Primary question | When it stands alone |
|------------|------------------|----------------------|
| **Paper 1 (flagship)** | Factorial inpainting × lesion-aware ACT in TBI | Always — default target |
| **Paper 2 (clinical)** | Lesion topology → structural disconnection → outcomes | Only if behavioral / cognitive / recovery variables exist on the cohort |
| **Paper 3 (methods branch)** | Deep Atropos vs HSVS for pathology ACT in TBI | Only after a full head-to-head cohort run — otherwise a supplement to paper 1 |

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

## Paper 2 — clinical disconnectome (optional)

**Primary question:** Where and how do lesions **disconnect** brain networks, and
does that relate to **symptoms, cognition, or recovery**?

| vs paper 1 | |
|------------|--|
| Paper 1 | Methods + sensitivity (“does processing choice matter?”) |
| Paper 2 | Biology + clinical (“what does disconnection mean in TBI?”) |

**Requires:** outcome variables (GOSE, PCS, cognitive batteries, time since injury,
etc.) on a meaningful subset of the lesion cohort.

**Canonical downstream arm:** pre-specify one lesion-aware arm (e.g. `neurolit-lesion`
or `vbt-lesion`) for clinical analyses so paper 2 does not reopen the full factorial.

**Without outcomes:** fold disconnectome summaries into paper 1 as one figure — do
not spin a second manuscript.

---

## Paper 3 — Deep Atropos vs HSVS (optional)

Only if **native-T1 Deep Atropos 5TT** (`5ttgen deep_atropos`) is run as a full
alternative branch with cohort-level head-to-head metrics. Otherwise document as
future work or a supplement to paper 1.

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

### Paper 2 — disconnectome + outcomes

| Priority | Journal |
|----------|---------|
| **1** | [*Journal of Neurotrauma*](https://home.liebertpub.com/publications/journal-of-neurotrauma/1/overview) |
| **Stretch** | [*Brain*](https://academic.oup.com/brain), [*Neurology*](https://n.neurology.org/) |
| **Alternative** | *Human Brain Mapping* if disconnectome is the main figure set |

### Paper 3 — Deep Atropos comparison

*NeuroImage: Reports*, *Medical Image Analysis*, or *Frontiers in Neuroinformatics*.

### Submission order

```text
1. Human Brain Mapping  — paper 1 (TBI factorial)
2. Journal of Neurotrauma — paper 2 (if outcomes data support it)
3. NeuroImage: Reports / MedIA — paper 3 (if Deep Atropos cohort completed)
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
Phase E — Optional:      paper 2 if outcomes analyses are ready
```

Maintainer release track (software DOI, digest table):
[v1.0 science track on GitHub](https://github.com/phindagijimana/dkt_connectome/blob/main/dwi_pipeline/docs/maintainer/v1_science_track.md).

---

## See also

- [Lesion-aware tractography](lesion_aware.md) — LeAPP context, factorial design, TBI QC
- [Validation](validation.md) — cohort context, integrity checks
- [Decision tables — experiment arms](decision_tables.md#experiment-arms)
- [Maintainer — release checklist on GitHub](https://github.com/phindagijimana/dkt_connectome/blob/main/dwi_pipeline/docs/maintainer/publishing.md)
- LeAPP: Bey et al. 2024, *Human Brain Mapping* — [10.1002/hbm.26701](https://doi.org/10.1002/hbm.26701)
