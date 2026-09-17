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
| RQ3 (domain specificity) | Do specific networks' disconnection scores map onto specific cognitive deficits (attention, memory, executive function, language)? |
| RQ4 (face validity) | Is the group-average disconnectome (MNI space) spatially coherent with lesion topology? |
| RQ5 (positioning) | Does the interpretable disconnection-based model at least approach the AUC of end-to-end CNN models (e.g. Che et al. 2026)? |

## Griffis analog and gap

Griffis 2019 (*Cell Reports*, stroke N≈114) is the closest publishable
template. Adopt: cross-validated regression, permutation testing,
incremental-validity benchmarks vs lesion volume, network-native parcellation.

**Gaps to close for HBM/Brain-tier:**

- **Multi-domain outcomes** (not just GOSE) — request neuropsych composites from clinical export
- **rs-fMRI processing** on same subjects — enables Griffis's SC → FC → behavior chain
- **Multisite harmonization** (ComBat or site regressors) — TRACK-TBI is multi-site; Griffis was single-site
- **Network-native parcellation** — add Schaefer/4S atlases alongside DKT for the Paper 2 subset

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

- **Griffis et al. 2019** (Cell Reports, stroke N≈114) — closest template
- **Warren et al. 2015** (Brain, TBI graph→cognition) — TBI methods precedent
- **Palacios et al. 2022 TRACK-TBI** (J Neurotrauma, N≈391 mTBI) — multisite scale precedent
- **Griffis LQT toolkit** — normative disconnection method (contrast: we use patient-specific lesion-aware tractography — differentiator)
- **Che et al. 2026** (Brain Commun, TRACK-TBI Pilot, CT+GAN-MRI ResNet-18) — black-box outcome benchmark; positioning contrast (we offer interpretability)

## Immediate operational next steps

1. Ask PI (or clinical data core) for a **data dictionary** — exact variables + visits available
2. Build complete-case spreadsheet on lesion-mask subjects
3. Count N; if N ≥ 45, un-pause and lock design; if 30–44, run with limitations; if <30 fold into Paper 1
4. Once locked, submit `neurolit-lesion` (or chosen fixed arm) on Paper 2 subject list
5. Add Schaefer/4S parcellation runs on the Paper 2 subset for network-native analysis

## Related pipeline docs

- Step 4.1 disconnectome: [../disconnectome.md](../disconnectome.md)
- Lesion-aware methods: [../lesion_aware.md](../lesion_aware.md)
- Validation: [../validation.md](../validation.md)
- References: [../references.md](../references.md)
