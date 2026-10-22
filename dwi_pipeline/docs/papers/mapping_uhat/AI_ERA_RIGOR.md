---
title: AI-era rigor — working definition for methods research
date: 2026-10-21
status: PROPOSED_FRAMEWORK
applies_to: Paper 1 / Paper 2 / edgeuq / DKT-Connectome / Vecta-adjacent measurement work
not: a validated quality score; a reflection and accountability standard
---

# AI-era rigor

## Concise definition (proposed)

**AI-era rigor** is the systematic discipline of making assumptions explicit, preserving evidence provenance, testing claims against possible failure, independently verifying results, establishing limits of generalization, and accepting only conclusions proportionate to the evidence.

**Central shift:** from rigor of *production* to rigor of *justification*.

Producing an answer is no longer strong evidence of understanding. Producing a working system is no longer strong evidence that the system is correct. AI makes generation easier; rigor must concentrate on **verification, measurement, falsification, provenance, generalization, and accountability**.

This is not an established universal definition. It is a framework for scientific research, engineering, and training in this lab’s methods work.

---

## 1. How rigor is changing

| Dimension | Traditional emphasis | AI-era emphasis |
|-----------|----------------------|-----------------|
| Knowledge | What do you know? | What can you explain, verify, and challenge? |
| Research | Can you formulate and test a hypothesis? | Can you distinguish genuine discoveries from AI-generated plausible explanations? |
| Mathematics | Can you derive the solution? | Can you justify assumptions, prove properties, and detect invalid reasoning? |
| Programming | Can you implement an algorithm? | Can you specify, test, verify, and maintain a reliable system? |
| Data science | Can you train a model? | Are the data, labels, measurements, and evaluations trustworthy? |
| Scientific evidence | Are results statistically significant? | Are the estimands, assumptions, measurements, analyses, and conclusions valid? |
| Reproducibility | Can someone repeat the analysis? | Can someone independently reconstruct and challenge the entire evidence chain? |
| Expertise | Can you solve difficult problems? | Can you recognize when an apparently convincing solution is wrong? |
| Innovation | Can you generate something new? | Does it create demonstrable knowledge or value beyond existing methods? |

Old standards still matter. AI does not remove the need to understand math, write code, or run experiments. It changes **what those activities prove** about competence.

---

## 2. Seven pillars

### 1. Problem rigor — Are we asking the right question?
Define the problem, intended use, assumptions, constraints, and what counts as a meaningful answer. A sophisticated model on an irrelevant estimand is not rigorous research.

### 2. Evidence rigor — Can we trust the inputs?
Document origin, collection, missingness, measurement validity, and whether transforms preserved meaning.

### 3. Methodological rigor — Could the method be wrong?
State assumptions, use baselines, avoid leakage, quantify uncertainty, run sensitivity checks, and design tests that can **disconfirm** the hypothesis.

### 4. Verification rigor — Does the result survive independent checks?
Test code, audit calculations, compare implementations, review source evidence, verify AI outputs independently. Repeating the same AI answer is not independent verification.

### 5. Generalization rigor — Where does the result stop working?
Evaluate across sites, scanners, protocols, time, and subgroups. State the boundary of applicability.

### 6. Reproducibility and provenance rigor — Can the evidence chain be reconstructed?
Preserve permitted data references, software versions, configs, analysis decisions, model versions, transforms, and deviations from plan.

### 7. Interpretive and accountability rigor — What can we legitimately conclude?
Distinguish association vs causation, prediction vs explanation, technical success vs scientific validity, exploration vs confirmation. Assign responsibility for consequential use.

---

## 3. Evidence chain (generated output → defensible knowledge)

1. **Claim** — What exactly are we asserting?  
2. **Evidence** — What observations support it?  
3. **Method** — How was the evidence analyzed?  
4. **Verification** — What independent checks were performed?  
5. **Falsification** — What could overturn the conclusion?  
6. **Generalization** — Where does the result hold?  
7. **Interpretation** — What can we responsibly infer?

A plausible answer, a passing test, a statistically significant result, and a valid scientific conclusion are **four different things**.

---

## 4. AI-assisted research

An AI that generates many hypotheses, writes code, runs many tests, and polishes a manuscript can be highly productive and still scientifically weak (selective reporting, wrong tests, leakage, over-interpretation).

Throughput without stronger verification **increases** false-discovery risk.

Require: separation of exploration vs confirmation; auditable analysis choices; pre-specified primary outcomes when appropriate; independent validation; explicit uncertainty.

**AI should accelerate hypothesis generation and experimentation — not silently decide which results count as evidence.**

---

## 5. Application to this program (connectomes / Vecta-adjacent)

### Computational success ≠ measurement validity

Example: QSIPrep/QSIRecon finishes and writes a connectome CSV. That does **not** establish that:

- acquisition metadata and gradients were correct;
- connectome measurements are reliable;
- measurements are comparable across sites;
- downstream biological conclusions are justified.

### Mapping onto Paper 1 / Paper 2 / tools

| Pillar | Paper 1 (plant fragility + boundary) | Paper 2 (leftover \(L\) / \(P_L\)) | Software (`edgeuq`, DKT hooks) |
|--------|--------------------------------------|-----------------------------------|--------------------------------|
| Problem | Estimand = endpoint plant / jitter; **not** visit change | Estimand = leftover TRT move; **not** \(\hat{U}\) | Optional trust bands; symbols not aliased |
| Evidence | Public TRT pairs; frozen assignment | Same; within- vs cross-site y-rates | Provenance next to counts |
| Method | Frozen cuts; no invent/G retune | Subject-LOSO; leftover-only \(\phi\) | Version-pinned CLIs |
| Verification | Packs, reseed control | Independent LOSO folds; interim n=4 | Tests + release checklist |
| Falsification | Soft invent fail; G fail **kept** | Cross-site ECE fail **kept** as result | Refuse silent cross-site \(\phi\) |
| Generalization | Boundary: plant ≠ leftover | Within-site vs cross-site calibration | Document site/protocol strata |
| Provenance | Locks, `edgeuq` DOI (planned) | Same + scale tables | `CITATION.cff`, containers |
| Interpretation | Fragility / QC, not biomarker | Instability probability / ranking, not disease | Cite P1/P2; no new science claims in JOSS note |

**Ambitious program claim (separate evidence required):** upstream acquisition/metadata properties affect downstream reliability and inference. That is **not** established by inventing an integrity score and assuming it equals scientific reliability ([PUBLICATION_PLAN.md](PUBLICATION_PLAN.md)).

---

## 6. Education / training implication

If AI can emit a correct-looking solution, submitting that solution is weaker evidence of mastery than before.

Assess whether the person can:

- explain assumptions and principles;
- reconstruct essential reasoning without the tool;
- find deliberately introduced errors;
- compare alternatives and justify trade-offs;
- transfer to an unfamiliar problem;
- design a test that would reveal the solution is wrong.

Using AI while learning is fine; **mastery** still means explanation, transfer, critique, and independent problem-solving.

---

## 7. Practical checklist (reflection tool — not a validated score)

Mark only what has been **demonstrated**, not merely planned.

- [ ] **Problem** — Question and intended use precisely defined  
- [ ] **Data** — Origins, limitations, transforms documented  
- [ ] **Method** — Assumptions, baselines, uncertainty addressed  
- [ ] **Verification** — Critical outputs checked independently  
- [ ] **Falsification** — Plausible failure cases / contrary evidence tested  
- [ ] **Generalization** — Evaluated beyond the development setting  
- [ ] **Reproducibility** — Another qualified researcher can reconstruct the result  
- [ ] **Interpretation** — Conclusions stay within the evidence  

Importance of each item depends on the study.

---

## 8. Three distinctions to preserve

1. **Capability is not validity** — A system can run without being reliable in every relevant setting.  
2. **Reproducibility is not truth** — An incorrect analysis can be perfectly reproducible.  
3. **Confidence is not evidence** — Fluency and polish do not justify conclusions.

---

## 9. Professional stance (this lab)

The scarce skill is not generating more scores, pipelines, or manuscript text. It is **refusing** results that do not survive verification, site shift, and honest non-claims — and locking the ones that do.

One-line identity:

> *AI-era neuroimaging methods engineer — builds tools, but ships only claims that survive verification, site shift, and explicit non-claims.*

---

## Related docs

- [EVALUATION_AS_SCIENCE.md](EVALUATION_AS_SCIENCE.md) — **eval as science** deep dive  
- [BIG_MINDS_EVAL_AI_ERA_TRAINING.md](BIG_MINDS_EVAL_AI_ERA_TRAINING.md) — what leading voices emphasize  
- [TRAINING_JUDGMENT_FALSIFICATION_PROVENANCE.md](TRAINING_JUDGMENT_FALSIFICATION_PROVENANCE.md) — weekly drills  
- [AI_ERA_RIGOR_LITERATURE.md](AI_ERA_RIGOR_LITERATURE.md) — annotated credible sources  
- [PREFIT_AND_SITE_MAPS.md](PREFIT_AND_SITE_MAPS.md) — leftover pre-fit \(\phi\) and site maps  
- [PUBLICATION_PLAN.md](PUBLICATION_PLAN.md) — P1 / P2 / software split  
- [PAPER1_LOCK.md](PAPER1_LOCK.md) / [PAPER2_LOCK.md](PAPER2_LOCK.md) — estimands and non-claims  
- [DISTRIBUTION.md](DISTRIBUTION.md) — provenance while authors pending  
- `edgeuq` `docs/overview.md` — plant vs leftover methods  
