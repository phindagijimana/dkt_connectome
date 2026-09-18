# Paper 2 — Clinical disconnectome → outcomes

**Status:** Conditional — pending clinical-data confirmation from PI.
Historically paused; PI has now indicated GOSE + other outcomes are
available for TBI cohort. Un-pause once complete-case N ≥ 40 is verified.

**Target:** *Journal of Neurotrauma* (default); *Brain* / *Neurology* stretch if
neuropsych battery + rs-fMRI + multisite harmonization are all added.

**Cross-refs:** [publication_strategy.md § Paper 2](publication_strategy.md#paper-2--clinical-disconnectome-optional-paused)
· [Clinical outcomes for Paper 2](publication_strategy.md#clinical-outcomes-for-paper-2)

---

## One-paragraph summary

A biology paper asking whether structural disconnection from focal TBI
lesions predicts functional outcome and cognitive recovery beyond lesion
volume alone, using one pre-specified lesion-aware arm (e.g. `neurolit-lesion`)
applied to ~40–55 TrackTBI subjects with complete clinical outcomes. The
primary outcome is GOSE at a fixed follow-up window (typically 6 months),
with lesion volume as a mandatory covariate to demonstrate incremental
validity — modeled after Griffis et al. 2019 (*Cell Reports*) on stroke.

## Candidate titles

- *Structural disconnection predicts functional outcome after traumatic brain injury beyond lesion volume*
- *Lesion-induced network disconnection and 6-month recovery in traumatic brain injury: a TRACK-TBI disconnectome study*
- *Beyond the cavity: how focal TBI lesions disconnect brain networks and shape cognitive recovery*
- *Lesion-aware structural disconnectomes as an outcome biomarker in traumatic brain injury*
- *Mapping structural disconnection from focal TBI lesions and its relationship to functional outcome*

## Research questions

| ID | Question |
|----|----------|
| RQ1 (primary) | Does global structural disconnection at 2-week timepoint predict 6-month GOSE, after adjusting for age, sex, GCS, education, and lesion volume? |
| RQ2 (incremental validity) | Does adding disconnection to a baseline model of (lesion volume + demographics + GCS) meaningfully improve outcome prediction? |
| RQ3 (mechanism, Griffis chain) | Does structural disconnection predict a corresponding disruption in resting-state **functional connectivity**, and does the SC → FC chain predict behavior better than either alone? |
| RQ4 (domain specificity) | Do specific networks' disconnection scores map onto specific cognitive deficits (attention, memory, executive function, language)? |
| RQ5 (face validity) | Is the group-average disconnectome (MNI space) spatially coherent with lesion topology? |
| RQ6 (positioning) | Does the interpretable disconnection-based model at least approach the AUC of end-to-end CNN models (e.g. Che et al. 2026)? |

## Griffis analog and gap

Griffis 2019 (*Cell Reports*, stroke N≈114) is the closest publishable
template. Adopt: cross-validated regression, permutation testing,
incremental-validity benchmarks vs lesion volume, network-native parcellation.

**rs-fMRI is available in the TBI BIDS.** The experiment BIDS at
`/mnt/nfs/Gugger_Lab/NIR/dwi_test_TBI_experiment/bids` includes
`task-rest_bold.nii.gz` per subject/session (2WK + 6MO on the pilot); the full
~100-subject cohort is assumed to mirror this structure. This unlocks the
**full Griffis chain — SC → FC → behavior — as a primary/secondary hypothesis**,
not a future extension. Plan an fMRI preprocessing arm (fMRIPrep + XCP-D or
similar) and add functional-connectivity outputs to the Paper 2 subject subset.

**Gaps to close for HBM/Brain-tier:**

- **Multi-domain outcomes** (not just GOSE) — request neuropsych composites from clinical export
- **Multisite harmonization** (ComBat or site regressors) — TRACK-TBI is multi-site; Griffis was single-site
- **Network-native parcellation** — add Schaefer/4S atlases alongside DKT for the Paper 2 subset
- **fMRI preprocessing arm** — fMRIPrep + XCP-D (or similar) is not yet in the pipeline; needs adding

## Design decisions to lock before opening data

Per [publication_strategy.md § Clinical outcomes for Paper 2](publication_strategy.md#clinical-outcomes-for-paper-2):

- [ ] Fixed imaging arm (default `neurolit-lesion`)
- [ ] Primary outcome (default: GOSE at 6 months)
- [ ] Visit-timing rule (default: 2WK imaging → 6mo outcome)
- [ ] Mandatory covariate set (age, sex, education, GCS, lesion volume)
- [ ] Network-to-domain mapping (which parcellation, which composites)
- [ ] Complete-case N threshold (default: N ≥ 45 to proceed; N=30–44 with limitations; <30 fold into Paper 1)

## Complete-case spreadsheet template

Build BEFORE any group analysis:

```text
sub | ses | lesion_mask | neurolit-lesion_done | GOSE_6mo | RPQ_6mo | neuropsych_battery | age | sex | GCS | lesion_vol_mm3
```

## Prior-work analogs

- **Griffis et al. 2019** (Cell Reports, stroke N≈114) — closest publishable template (SC→FC→behavior chain)
- **Warren et al. 2015** (Brain, TBI graph→cognition) — TBI methods precedent
- **Palacios et al. 2022 TRACK-TBI** (J Neurotrauma, N≈391 mTBI) — multisite scale precedent
- **Che et al. 2026** (Brain Commun, TRACK-TBI Pilot, CT+GAN-MRI ResNet-18) — black-box outcome benchmark; positioning contrast (we offer interpretability)

### Comparator tools for the methods contribution

Both are normative-atlas disconnection tools; our patient-specific lesion-aware
pipeline is the alternative to compare against. Run these on the same lesion
masks (MNI-normalized) to produce head-to-head SDC/disconnection outputs.

| Tool | Reference | Output | Repo |
|------|-----------|--------|------|
| **LQT** (Lesion Quantification Toolkit) | Griffis et al. 2021, *NeuroImage: Clinical* 30:102639 | Parcel-to-parcel SDC matrix + tract-level disconnection % + parcel damage; HCP-842 normative atlas | https://github.com/JDGriffis/lesion-quantification-toolkit |
| **BCBtoolkit** (Brain Connectivity and Behaviour) | Foulon et al. 2018, *GigaScience* 7(3):giy004; Talozzi et al. 2023 | Voxel-level disconnection probability maps + Tractotron + disconnectome symptom mapping | https://toolkit.bcblab.com/ |

**Methods contribution framing:** compare patient-specific lesion-aware SDC
(this pipeline) vs normative-atlas SDC (LQT and/or BCB) on the same subjects.
Hypothesis: patient-specific SDC diverges more from normative-atlas SDC in TBI
than in stroke (because TBI has heterogeneous mass effect, edema, bilateral
injury), and the divergence has downstream consequences (better FC prediction
or better behavior prediction). If divergence is small, the methods
contribution shrinks and the paper leads with biology, with methods as
robustness supplement.

## Journal-tier landscape

**Full analysis:** [`journal_tier.md`](journal_tier.md) / [`journal_tier.docx`](journal_tier.docx) — per-venue framing, required analyses, section-by-section manuscript breakdowns, effort estimates, and failure modes.

Summary condensed below.


### Full venue table

| Venue | Realistic? | Framing that lands it | What we'd need to deliver | What we don't yet have |
|-------|-----------|----------------------|---------------------------|------------------------|
| *Nature* (main) | ❌ Not in play | Paradigm-shifting biology + broad reach beyond TBI | N > 500, multi-cohort replication, cross-disease generalizability | Everything |
| *Nature Neuroscience* | ❌ Stretch of stretch | Broad neuroscience insight beyond stroke/TBI | Very large N or exceptional mechanistic depth | Cohort scale, replication |
| *Nature Communications* | ⚠️ Stretch, conceivable | Full SC→FC→behavior + methods novelty + external replication | N ≥ 80 complete cases; independent replication cohort; crisp methods-vs-normative figure with clinical consequence | Replication cohort; N confirmation |
| *Nature Human Behaviour* | ⚠️ Stretch | Behavior-forward, domain-specific network mapping | Multi-domain neuropsych factor scores + clean domain-network mapping | Neuropsych battery confirmation |
| *Brain* | ✅ Realistic | Biology-lead: clinical-mechanistic story | N ≥ 50 complete cases + neuropsych + clean SC→FC coupling + incremental validity vs lesion volume | Clean cohort delivery |
| *NeuroImage* | ✅ Realistic | Methods-lead: patient-specific vs normative-atlas SDC head-to-head | Quantitative divergence figure vs LQT/BCB with downstream consequence (FC or behavior prediction) | The head-to-head analysis run |
| *NeuroImage: Clinical* | ✅ Very realistic | TBI-focused imaging-clinical | Standard clinical-imaging deliverables | Solid backup — no gap |
| *Medical Image Analysis* | ⚠️ Fit-dependent | Pipeline/engineering lead | Would require rewriting away from Griffis story | Different framing |
| *Human Brain Mapping* | ✅ Default landing | Either framing at lower N/novelty bar | Coherent whole; LeAPP was here | Nothing extra |
| *Cell Reports* (Griffis's venue) | ❌ Not open | — | — | They published Griffis; won't accept extension |

### Editorial identity of the 3 target venues

**NeuroImage** — neuroimaging methods + rigorous applications.

- Reader base: imaging methodologists, tool developers, imaging labs.
- Reviewers reward: methods innovation with quantitative validation, head-to-head comparisons against standard tools (LQT/BCB), sensitivity/robustness across parameters, reproducibility (containers, open code).
- Reviewers reject on: biology-only stories without methods innovation; qualitative rather than quantitative claims; missing benchmarks.
- Our fit: patient-specific lesion-aware SDC vs normative-atlas SDC in TBI is a proper head-to-head; we already have containers + provenance JSON + Snakemake DAG for reproducibility.

**Brain** — clinical neurology + translational neuroscience.

- Reader base: clinical neurologists, translational cognitive neuroscientists.
- Reviewers reward: biological/mechanistic story with clinical implications, symptom-anatomy-mechanism triads, prognostic value, cohort-level generalizability.
- Reviewers reject on: pure methods papers; no clinical interpretation; case reports; unclear biology.
- Our fit: SC → FC → behavior chain in TBI (defined patient population, ~2M/year US, real clinical decision-support relevance); Griffis 2019 stroke → TBI extension is a documented empty niche.

**Human Brain Mapping (HBM)** — neuroimaging + cognitive/clinical applications.

- Reader base: broad — imaging labs, clinical, translational, methods.
- Reviewers reward: solid neuroscience with imaging methods, especially connectivity/network analyses; N=40–100 with honest interpretation is welcome.
- Reviewers reject on: paradigm-shift novelty is not required; incoherent whole or unclear contribution will get rejected.
- Our fit: LeAPP (Bey 2024, our comparator) was HBM; they explicitly welcome our methodological family; safe fallback under either framing.

### What determines which path we actually take

Three empirical questions with unknown answers today:

| Question | If yes → | If no → |
|----------|----------|---------|
| Do patient-specific and normative-atlas SDC diverge meaningfully in TBI? | NeuroImage path viable | HBM (methods becomes supplement) |
| Is the SC→FC coupling reproducible cohort-wide? | Brain path viable | HBM |
| Do we have neuropsych battery + N ≥ 50 complete cases? | Brain path stronger | HBM |

### Strategic recommendation

1. **Design the analysis to unlock either path** — implement both LQT/BCB comparators (methods head-to-head) *and* the full SC→FC chain (biology story).
2. **Look at results** — quantitatively assess which contribution is stronger.
3. **Choose venue after results** — but lock the *analysis plan* now (contrasts, primary metrics, benchmarks) so "picking venue after results" is not "picking based on p-hacking."
4. **Do not design for *Nature Communications* from day one** — plan for HBM/Brain/NeuroImage; let quality of results decide any stretch.

### Bottom line

- **NeuroImage** if patient-specific lesion-aware SDC captures signal the normative approach misses in TBI (methods head-to-head wins).
- **Brain** if the full Griffis SC→FC→behavior chain is clean with N ≥ 50 and neuropsych domains (biology story wins).
- **HBM** as safe landing — publishable under either framing even if neither the methods head-to-head nor the biology chain is exceptional.

## Immediate operational next steps

1. Ask PI (or clinical data core) for a **data dictionary** — exact variables + visits available
2. Build complete-case spreadsheet on lesion-mask subjects
3. Count N; if N ≥ 45, un-pause and lock design; if 30–44, run with limitations; if <30 fold into Paper 1
4. Once locked, submit `neurolit-lesion` (or chosen fixed arm) on Paper 2 subject list
5. Add Schaefer/4S parcellation runs on the Paper 2 subset for network-native analysis
6. **Confirm rs-fMRI coverage** cohort-wide (pilot has it; assume full cohort mirrors — verify)
7. **Add fMRI preprocessing arm** to the pipeline (fMRIPrep + XCP-D or similar) to produce functional-connectivity outputs for the Paper 2 subset — enables Griffis SC→FC→behavior chain

## Related pipeline docs

- Step 4.1 disconnectome: [../disconnectome.md](../disconnectome.md)
- Lesion-aware methods: [../lesion_aware.md](../lesion_aware.md)
- Validation: [../validation.md](../validation.md)
- References: [../references.md](../references.md)
