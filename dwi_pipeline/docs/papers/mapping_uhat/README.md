# mapping_uhat papers (edgeuq era)

**Locked split (2026-10-21):** three outputs — see [`PUBLICATION_PLAN.md`](PUBLICATION_PLAN.md).

**Word copies:** Every top-level `.md` here has a matching `.docx` under [`docx/`](docx/), including manuscripts (`PAPER1_manuscript.docx`, `PAPER2_manuscript.docx`), locks, and [`CLAIMS_LIMITS_AND_MATH.docx`](docx/CLAIMS_LIMITS_AND_MATH.docx). Regenerate:

```bash
cd dwi_pipeline/docs/papers/mapping_uhat
for f in *.md; do pandoc "$f" -o "docx/${f%.md}.docx"; done
```
**Learning / share pack (preferred):**  
`Documents/research_learning/TrackTBI-Sub/` (hub: `learning_TrackTBI-Sub.md`)

**Also:** `Documents/researcher/` (earlier flat copy; prefer `research_learning`)

**Reviewer bar / what is closed vs blocked:** [`NEUROIMAGE_REVIEWER_RESPONSE.md`](NEUROIMAGE_REVIEWER_RESPONSE.md)

## Lab stance (AI-era methods)

| Doc | Role |
|---|---|
| [`AI_ERA_RIGOR.md`](AI_ERA_RIGOR.md) | Proposed AI-era rigor definition + mapping to P1/P2/tools |
| [`AI_ERA_RIGOR_LITERATURE.md`](AI_ERA_RIGOR_LITERATURE.md) | Annotated sources: academia, PhD/postdoc, industry, funders/publishers |
| [`EVALUATION_AS_SCIENCE.md`](EVALUATION_AS_SCIENCE.md) | Eval-as-science: validity, benchmarks vs real use, industry eval norms, P1/P2 map |
| [`BIG_MINDS_EVAL_AI_ERA_TRAINING.md`](BIG_MINDS_EVAL_AI_ERA_TRAINING.md) | What leading voices emphasize (eval / AI-era researcher / PhD–postdoc training) |
| [`TRAINING_JUDGMENT_FALSIFICATION_PROVENANCE.md`](TRAINING_JUDGMENT_FALSIFICATION_PROVENANCE.md) | Practical drills to train judgment, falsification, provenance |
| [`AI_COMMODITY_RESEARCH_ENGINEER_DIFFERENTIATORS.md`](AI_COMMODITY_RESEARCH_ENGINEER_DIFFERENTIATORS.md) | Career differentiators when AI is commodity (sourced; general) |

## Publication products

| Doc | Role |
|---|---|
| [`PUBLICATION_PLAN.md`](PUBLICATION_PLAN.md) | **P1 / P2 / DKT+edgeuq software** — do not merge |
| [`DISTRIBUTION.md`](DISTRIBUTION.md) | Tags, DOI, license while authors pending |
| [`SOFTWARE_DKT_EDGEUQ.md`](SOFTWARE_DKT_EDGEUQ.md) | Software note checklist (JOSS / NI Software) |
| [`EDGEUQ_TRUST_BANDS_HOOK.md`](EDGEUQ_TRUST_BANDS_HOOK.md) | Optional post-connectome trust bands |
| [`PREFIT_AND_SITE_MAPS.md`](PREFIT_AND_SITE_MAPS.md) | Pre-fit \(\phi\), single-subject use, site maps vs harmonization |
| [`CLAIMS_LIMITS_AND_MATH.md`](CLAIMS_LIMITS_AND_MATH.md) | **Start here (lab/PI):** plain-language story + claims + math walkthrough + critiques |
| [`PAPER2_MATH.md`](PAPER2_MATH.md) | Formal leftover math with “in words” before each formula |
| [`NEUROIMAGE_REVIEWER_RESPONSE.md`](NEUROIMAGE_REVIEWER_RESPONSE.md) | Reviewer concerns → status → fix (P1/P2) |

**Readability vs venue tone:** Lab briefs above explain theory for easy understanding. Manuscripts below stay NeuroImage / methods prose — do not dumb them down.

## Paper 1

| Doc | Role |
|---|---|
| [`PAPER1_LOCK.md`](PAPER1_LOCK.md) | Scope / frozen cuts / out-of-scope |
| [`PAPER1_manuscript.md`](PAPER1_manuscript.md) | Submission draft (pre-scale finalize) |
| [`PAPER1_tables.md`](PAPER1_tables.md) | Numbers |
| [`PAPER1_figures.md`](PAPER1_figures.md) | Figure plan |
| [`PAPER1_AWAITING_SCALE.md`](PAPER1_AWAITING_SCALE.md) | What scale adds later |

## Paper 2

| Doc | Role |
|---|---|
| [`PAPER2_LOCK.md`](PAPER2_LOCK.md) | Leftover estimand / symbols / gates |
| [`PAPER2_LITERATURE.md`](PAPER2_LITERATURE.md) | TRT + UQ + calibration lit map |
| [`PAPER2_MATH.md`](PAPER2_MATH.md) | Leftover math + held-out protocol (plain language before formulas) |
| [`PAPER2_manuscript.md`](PAPER2_manuscript.md) | Paper 2 draft (pilot demo; submit after scale) |
| [`PAPER2_PREDICTION_CALIBRATION.md`](PAPER2_PREDICTION_CALIBRATION.md) | P2 index |
| [`PREFIT_AND_SITE_MAPS.md`](PREFIT_AND_SITE_MAPS.md) | How users get \(P_L\) without local TRT; site preference |

Legacy drafts under `../mapping_u/` retain plant confirmation detail; Paper 1 manuscript cites those numbers and the 2026-10-20 retest exam.
