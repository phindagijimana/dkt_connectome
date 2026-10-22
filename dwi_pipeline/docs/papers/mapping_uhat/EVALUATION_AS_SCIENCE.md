---
title: Evaluation as science — definition, sources, and lab application
date: 2026-10-21
status: RESEARCH_BRIEF
companions: [AI_ERA_RIGOR.md, AI_ERA_RIGOR_LITERATURE.md]
---

# Evaluation as science

## One-line definition (lab)

**Evaluation as science** treats measurement of system or method performance as a first-class empirical discipline: define the estimand and intended use, choose metrics that can fail, report uncertainty and strata, preserve provenance, and only then interpret scores as evidence.

It is the opposite of: run a benchmark once, pick the flattering number, and ship.

This document expands the “eval as science” thread for research scientists/engineers (academia and industry), with credible citations and a mapping to Paper 1 / Paper 2 / `edgeuq`.

---

## 1. Why “eval” is not automatic science

A completed pipeline, a leaderboard rank, an AUROC, or an ECE number is **data**. It becomes scientific evidence only when:

1. the **claim** the number supports is explicit;
2. the **metric** matches that claim (construct validity);
3. the **design** can disconfirm the claim (falsification);
4. **uncertainty and scope** are reported;
5. the **evidence chain** can be reconstructed.

Without that, evaluation is theater. Credible sources make this distinction in measurement theory, open science, ML reproducibility, and frontier-lab practice.

---

## 2. Three lessons from “evaluation science” for generative AI

**Primary source:** Weidinger, Raji, Wallach, Mitchell, Wang, Salaudeen, Bommasani, Ganguli, Koyejo, Isaac (2025). *Toward an Evaluation Science for Generative AI Systems*. arXiv:2503.05336. https://arxiv.org/abs/2503.05336  

Authors span Google DeepMind, UC Berkeley, Microsoft Research, Hugging Face, Stanford, MIT, Anthropic.

They argue static benchmarks often lack **validity for real-world decisions**, and ad hoc audits do not scale. Drawing on safety evaluation in transportation, aerospace, and pharma, they emphasize three lessons:

| Lesson | Meaning | Lab translation (connectome UQ) |
|--------|---------|----------------------------------|
| **1. Metrics must apply to real-world performance** | Score must relate to the decision or use case, not only to a convenient task | Plant AUROC ↔ endpoint fragility use; leftover AUROC/ECE ↔ TRT instability use — not one blurry “UQ score” |
| **2. Metrics must be iteratively refined** | Measurement instruments improve as failure modes appear | Soft invent fail, G fail, cross-site ECE clash → refine *interpretation and protocol*, not silently retune cuts |
| **3. Institutions and norms must exist** | Shared standards, checklists, release gates, independent scrutiny | PAPER*_LOCK, anti-retune, subject-LOSO, publication split, versioned `edgeuq` |

**Industry practice in the same spirit:**

- Anthropic — *A statistical approach to model evaluations* (2025): treat eval differences as uncertain estimates, not vibes. https://www.anthropic.com/research/statistical-approach-to-model-evals  
- Anthropic engineering — agent evals: combine groundedness/coverage/source-quality checks; calibrate LLM graders against humans (eval design is research).  
- Role design at DeepMind/OpenAI/Anthropic: Research Engineers own **build + evaluate**; eval infrastructure is part of the scientific product, not an afterthought.

---

## 3. Deeper roots: measurement validity (not just ML)

Long before LLMs, measurement science insisted that **scores do not validate themselves**.

| Source | Claim | Relevance |
|--------|-------|-----------|
| **Messick (1989, 1995).** Validity as evaluative judgment of inferences from scores | What is validated is the *interpretation/use*, not the instrument alone | Do not say “U is valid”; say “U supports inference about plant fragility under frozen protocol” |
| **Kane / argument-based validity** (summarized in educational measurement) | Interpretation/use argument + validity argument; degree of support, not binary stamp | Paper 1/2 locks are interpretation/use arguments; exams are validity arguments |
| **Cronbach** (classic) | Validation = scientific inquiry into score meaning | Same as AI-era “justification over production” |

**Takeaway:** “Eval as science” is **Messick + open science + modern ML eval culture**, not a buzzword invented in 2025.

---

## 4. Documentation as evaluation infrastructure (industry + academia)

| Source | Artifact | What it forces |
|--------|----------|----------------|
| **Gebru et al. (2021).** Datasheets for Datasets. *CACM*. https://doi.org/10.1145/3458723 | Dataset provenance & recommended uses | Evidence rigor + scope |
| **Mitchell et al. (2019).** Model Cards for Model Reporting. https://arxiv.org/abs/1810.03993 | Intended use, metrics, **subgroup/stratum** performance | Generalization rigor |
| **Google Data Cards Playbook** | Operational lifecycle documentation | Provenance in product orgs |
| **Nature Portfolio ML checklist** | Code/data/split/reporting structure | Verification + reproducibility |
| **Pineau et al. / NeurIPS ML Reproducibility Checklist** | Metrics defined, runs counted, variation reported | Experimental eval hygiene |
| **Construct validity for LLM benchmarks** (NeurIPS D&B discussions / checklists, 2025) | Define phenomenon; control confounds; failure modes | Metric–claim alignment |

These artifacts treat evaluation **artifacts** (cards, checklists, strata tables) as part of the scientific deliverable.

---

## 5. Statistical / scientific model evaluation (pre-AI ML)

Eval-as-science also inherits from classical empirical modeling:

| Source | Point |
|--------|-------|
| **Burnham & Anderson** — information-theoretic model selection | A priori candidate models; rank by evidence; include selection uncertainty; separate planned inference from dredging |
| **Editors’ caution** (e.g. J Appl Ecol on IC misuse) | “Best” by AIC is not automatically a *good* or useful model — adequacy must be checked |

Parallel to ML: winning a benchmark ≠ justifying deployment or a scientific claim.

---

## 6. Open science: making evaluation challengeable

| Source | Mechanism |
|--------|-----------|
| **COS TOP Guidelines** (2015; TOP 2025) | Registration, protocols, analysis plans, data/code transparency; verification study types (replication, registered reports, multiverse, many-analysts) |
| **Preregistration (COS)** | Separate exploration from confirmation; disclose deviations |
| **NASEM (2019)** *Reproducibility and Replicability in Science* | Train computational/statistical practice; share enough to reconstruct |
| **NIH** rigor & reproducibility training / grant language | Design, transparency, interpretation of prior research as trained skills |

Falsification is institutionalized when negative or boundary results are **reportable** and protocols are **fixed before** peeking at flattering analyses.

---

## 7. What “eval as science” requires in practice

### A. Define the measurement claim
- Estimand (what event?)  
- Intended use (what decision?)  
- Non-claims (what must not be inferred?)

### B. Design an evaluation that can fail
- Baselines and negative controls  
- Held-out units that match the claim (e.g. **subject** LOSO for calibration)  
- Strata where theory predicts breakage (site, protocol, strong vs weak edges)

### C. Report like a measurement paper
- Point estimate **and** uncertainty / fold spread  
- Failure cases kept (not retuned away)  
- Scope of applicability  

### D. Preserve the chain
- Versions, seeds, containers, subject lists, locked cuts  
- Datasheet/model-card analogues for connectome scores (`edgeuq` protocol docs)

### E. Separate exploration from confirmation
- Pilot demo vs scaled confirmation  
- Transparent changes after locks  

---

## 8. Mapping onto this lab’s Paper 1 / Paper 2

| Eval-as-science element | Paper 1 | Paper 2 |
|-------------------------|---------|---------|
| Estimand | Planted endpoint move; jitter leakage | Leftover TRT edge move \(y\) |
| Metric–use match | AUROC \(U\)/\(F\) for fragility | AUROC \(L\); ECE of \(P_L\) for calibration |
| Can fail | Soft invent fail; G transfer fail | Cross-site ECE fail; within-site may pass |
| Strata / generalization | Retest boundary vs plant | Kirby within-site vs Kirby↔Boekel |
| Held-out design | Plant confirmation vs leftover exam | Subject-LOSO (not edge-pooled) |
| Documentation | PAPER1_LOCK, protocol, `edgeuq shift/jitter/rescan` | PAPER2_LOCK, `calibrate-leftover`, interim within-site JSON |
| Non-claims | Not leftover \(\hat{U}\) | \(P_L \neq \hat{U}\); single-subject fit ≠ valid ECE |

**Vecta / DKT parallel:** “QSIPrep finished” or “connectome CSV written” is computational success. Eval-as-science asks whether **upstream metadata/representation** and **downstream edge reliability** support the scientific use — separate empirical claims ([AI_ERA_RIGOR.md](AI_ERA_RIGOR.md) §5).

---

## 9. Training researchers/engineers in eval-as-science

Aligned with sources above and [AI_ERA_RIGOR_LITERATURE.md](AI_ERA_RIGOR_LITERATURE.md):

| Stage | Practice |
|-------|----------|
| PhD | NIH reproducibility modules; preregistration exercises; PBL on controls; “researcher degrees of freedom” seminars |
| Postdoc | Own an eval plan for each claim; write model/datasheet-style cards for methods; hostile review drills |
| Industry RE/RS | Own eval pipelines and uncertainty reporting; refuse release on single flattering benchmark; document intended use and strata |

**Weekly drill (eval-as-science version):**  
Claim → metric → falsifier → stratum where it should break → run → lock result (pass **or** fail).

---

## 10. Core reading list (eval-focused)

1. Weidinger et al. (2025). Toward an Evaluation Science for Generative AI Systems. https://arxiv.org/abs/2503.05336  
2. Messick (1995). Validity of psychological assessment. *American Psychologist*. https://doi.org/10.1037/0003-066X.50.9.741  
3. Mitchell et al. (2019). Model Cards. https://arxiv.org/abs/1810.03993  
4. Gebru et al. (2021). Datasheets for Datasets. https://doi.org/10.1145/3458723  
5. Pineau et al. NeurIPS ML Reproducibility Checklist / program reports. https://arxiv.org/abs/2003.12206  
6. COS TOP Guidelines. https://www.cos.io/initiatives/top-guidelines  
7. Anthropic (2025). Statistical approach to model evaluations. https://www.anthropic.com/research/statistical-approach-to-model-evals  
8. NASEM (2019). Reproducibility and Replicability in Science. https://nap.nationalacademies.org/catalog/25303  

---

## 11. Caveat

This brief documents **norms and primary literature**. It does not invent a new validated “eval quality score.” For external citation, prefer the primary sources in §10; use this file as the lab’s operating synthesis.

**Named-voice synthesis** (eval + AI-era researcher + PhD/postdoc training): [BIG_MINDS_EVAL_AI_ERA_TRAINING.md](BIG_MINDS_EVAL_AI_ERA_TRAINING.md).
