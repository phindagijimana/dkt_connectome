# Disconnectome paper — honest working abstract

**Purpose:** internal working abstract to share with PI and collaborators.
Written honestly — reflects what we plan to do, what's contingent on
data delivery and execution, and what we deliberately are *not* claiming.
This is not the submission-ready abstract (that comes after results are in
and the venue-framing choice is made).

**Related docs:** [index.md](index.md) · [disconnectome_missing.md](disconnectome_missing.md) ·
[outcomes_planning.md](outcomes_planning.md) · [analysis_plan.md](analysis_plan.md) ·
[../journal_tier.md](../journal_tier.md) · [../Griffis_later.md](../Griffis_later.md)

**Status:** DRAFT for PI/collaborator review, 2026-09-18.
Target: J Neurotrauma / HBM default; Brain / NeuroImage stretch (framing-dependent).

---

## Working titles (venue-dependent)

**Methods-lead (NeuroImage target):**
*Patient-specific lesion-aware disconnectomes in traumatic brain injury:
a head-to-head comparison with normative-atlas approaches and consequences
for network-level outcome prediction.*

**Biology-lead (Brain target):**
*Structural disconnection mediates functional network dysfunction and
predicts cognitive recovery after traumatic brain injury.*

**Default (HBM / J Neurotrauma):**
*Lesion-aware structural disconnection and outcome after traumatic brain
injury: a disconnectome study.*

The paper's central claim depends on which contribution turns out
quantitatively stronger; framing decision is post-analysis.

## Honest abstract (~300 words)

**Background.** Structural disconnection (SDC) — the loss of long-range
white-matter connectivity caused by focal lesions — mediates widespread
functional network dysfunction and cognitive deficits after ischemic
stroke (Griffis et al. 2019, *Cell Reports*). Whether the same mechanism
generalizes to traumatic brain injury, where lesion morphology is
heterogeneous (contusion, oedema, hemorrhage, bilateral injury), is
unknown. Current widely-used SDC pipelines (LQT: Griffis 2021;
BCBtoolkit: Foulon 2018) overlay lesion masks on normative white-matter
atlases and assume that individual patient anatomy conforms to a healthy
template — an assumption strained in TBI's more distorted anatomy.

**Question.** In TBI, does patient-specific lesion-aware structural
disconnection — computed on individual DWI with anatomically-constrained
tractography, using our containerized pipeline — differ systematically
from normative-atlas SDC? Does the difference carry clinical signal for
functional-connectivity disruption and 6-month cognitive-behavioral
outcome?

**Approach.** On a TrackTBI subset (target N ≥ 45 complete cases with
lesion masks + DWI + rs-fMRI + clinical outcomes), we compute per-subject
SDC using three approaches: patient-specific lesion-aware tractography
(this pipeline), LQT normative-atlas SDC, and BCBtoolkit voxel-level
disconnection. Resting-state functional connectivity is derived via
fMRIPrep + XCP-D, producing FC matrices in multiple atlases (DKT
subject-native, 4S 156, Schaefer 200, Gordon 333, HCP-MMP). We test
(a) canonical correlation between SDC and FC-abnormality, (b) SDC and
FC combined as predictors of 6-month Glasgow Outcome Scale-Extended
with incremental validity above lesion volume, and (c) domain-specific
network mapping to neuropsychological composites.

**Anticipated findings (results-dependent).** We expect patient-specific
SDC to diverge from normative-atlas SDC in subjects with high mass
effect, oedema, or bilateral injury, and for the divergence to carry
downstream signal. Whether the divergence is large enough to justify
methods-lead framing (NeuroImage) versus biology-lead framing (Brain)
depends on the magnitude of the head-to-head result.

**Interpretation caveats.** Results depend on TRACK-TBI clinical export
availability (external gate), complete-case N, and the strength of the
SC → FC coupling in the TBI cohort. If neuropsych battery is limited to
GOSE alone, the domain-specific mapping story shrinks and the venue
ceiling drops from Brain to HBM. If patient-specific and normative-atlas
SDC agree closely, the methods contribution shrinks and the paper leads
biology-only.

---

## What this paper *is*

- A cohort-scale test of whether Griffis 2019's SC → FC → behavior chain generalizes from stroke to TBI
- The first systematic head-to-head of patient-specific lesion-aware SDC vs normative-atlas SDC (LQT, BCBtoolkit) at cohort scale in any patient population
- A clinical-utility test: does disconnection-based imaging improve outcome prediction beyond lesion volume?
- Distributable + reproducible: containerized SC pipeline + fMRI pipeline + per-step provenance JSON

## What this paper *is not*

- Not a discovery of new brain networks or new disconnection mechanisms — the framework is Griffis 2019's, we extend it
- Not a new SDC technique — patient-specific lesion-aware ACT was established by Bey 2024 LeAPP; we adopt and evaluate
- Not a normative-atlas SDC tool — LQT and BCBtoolkit are the field standards; we use them as comparators
- Not a factorial methods paper — that's Paper 1
- Not a Nature-tier finding without the ingredients we deliberately do not chase (external replication cohort, N ≥ 500)

---

## Contingencies acknowledged for PI / collaborator review

1. **TRACK-TBI clinical export availability** — this is the external gate. Without GOSE + covariates on the lesion-mask subjects, Paper 2 cannot proceed as standalone. Fold into Paper 1 as one figure if unavailable.
2. **Neuropsych battery breadth** — GOSE alone caps ceiling at HBM / J Neurotrauma; a multi-domain battery (Trail Making, WAIS PSI, CVLT-II, BVMT-R, COWA) unlocks Brain-tier via domain-specific network mapping.
3. **rs-fMRI coverage** — verified on pilot subject; cohort-wide coverage assumed but not yet audited. If < 50% coverage, the SC → FC middle layer weakens.
4. **Complete-case N thresholds** — pre-specified:
   - N ≥ 45: proceed as standalone Paper 2
   - N = 30–44: proceed with limitations framing
   - N < 30: fold into Paper 1 as one supplementary figure
5. **Head-to-head SDC divergence magnitude** — unknown until run. Predetermines methods-lead vs biology-lead framing.
6. **LQT / BCB installation** — MATLAB dependency. May need Python ports or a MATLAB compiler runtime workaround.
7. **Cross-site harmonization** — TRACK-TBI is multisite; ComBat or site-fixed-effects likely required.

---

## Suggested citation of prior work in intro (for coauthor review)

- **Direct precedent:** Griffis et al. 2019 *Cell Reports* (SC → FC → behavior in stroke — the template we extend)
- **Multi-domain outcome extension:** Salvalaggio et al. 2020 *Brain* (established combined SC + indirect FC modeling)
- **Behavioral framework:** Corbetta et al. 2015 *Neuron* (factor-analytic multi-domain deficit scores)
- **Normative-atlas SDC comparators:** Griffis 2021 *NI:Clinical* (LQT); Foulon 2018 *GigaScience* (BCBtoolkit); Kuceyeski 2013 *Brain Connectivity* (NeMo)
- **Parallel lineage:** Boes et al. 2015 *Brain*; Fox 2018 *NEJM* (lesion network mapping)
- **Current methodological frontier:** Talozzi et al. 2023 *Brain* (latent disconnectome)
- **TBI-specific:** Warren 2015 *Brain*; Kuceyeski 2020 *HBM*; Palacios 2022 *J Neurotrauma*
- **Our methods stack:** Cieslak 2021 (QSIPrep); Esteban 2019 (fMRIPrep); Mehta 2024 (XCP-D); Bey 2024 *HBM* (LeAPP methods — cited for SC pipeline)
- **Positioning contrast (optional):** Che et al. 2026 *Brain Communications* (CT + GAN-MRI outcome prediction; we offer interpretability)

---

## What we ask coauthors to weigh in on

1. **Framing decision timing** — commit early to methods-lead OR biology-lead, or run both analyses and decide by results (recommend: latter)
2. **Target venue at submission** — J Neurotrauma safer, HBM balanced, Brain stretchy, NeuroImage methods-lead
3. **Fixed imaging arm** — `neurolit-lesion` default; consider `vbt-lesion` for stroke-analog defensibility
4. **rs-fMRI processing decisions** — 36P nuisance regression, 0.01–0.08 Hz bandpass, FD 0.5mm censoring (matches Griffis-lineage precedent) — confirm before locking analysis plan
5. **TRACK-TBI clinical export status** — who's contacting the data core, and by when?
6. **Author list + CRediT contributions**
7. **Whether to run analysis plan through OSF preregistration** (1 day; strong rigor signal)

---

## Sample-size honesty

Comparators from Griffis-lineage stroke work:

| Paper | N | Venue |
|-------|---|-------|
| Griffis 2019 (stroke, chain established) | 114 | Cell Reports |
| Salvalaggio 2020 (multi-domain extension) | ~155 | Brain |
| Talozzi 2023 (latent disconnectome, stroke) | ~500 | Brain |
| Our Paper 2 (target) | 45–55 complete cases | J Neurotrauma / HBM realistic; Brain stretch |

Our N is smaller than the direct analogs. This is defensible for:
- **Brain** if we compensate with mechanism-clarity + patient-specific-SDC differentiator + full SC → FC → behavior chain
- **HBM / J Neurotrauma** on any showing
- **NeuroImage** if methods-lead framing + head-to-head divergence delivers

Not defensible for:
- Cell Reports (N too small relative to prior)
- Nature Communications (requires replication cohort we lack)

---

## See also

- [`index.md`](index.md) — full cover doc with cross-tier paper matrix
- [`disconnectome_missing.md`](disconnectome_missing.md) — submission-readiness checklist
- [`outcomes_planning.md`](outcomes_planning.md) — full detailed planning, Griffis-2019 contribution breakdown
- [`analysis_plan.md`](analysis_plan.md) — pre-registration template
- [`manuscript_skeleton.md`](manuscript_skeleton.md) — writing template
- [`../journal_tier.md`](../journal_tier.md) — ten-venue landscape
- [`../LQT.md`](../LQT.md) — normative-atlas SDC family reference
- [`../Griffis_later.md`](../Griffis_later.md) — Salvalaggio / Talozzi / Kuceyeski lineage
- [`../distance_novelty.md`](../distance_novelty.md) — contribution framework + per-paper contribution list
