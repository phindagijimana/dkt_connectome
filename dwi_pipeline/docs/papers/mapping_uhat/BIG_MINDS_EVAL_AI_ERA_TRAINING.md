---
title: What leading voices emphasize — eval as science, AI-era researchers, PhD/postdoc training
date: 2026-10-21
status: SYNTHESIS
companions: [EVALUATION_AS_SCIENCE.md, AI_ERA_RIGOR.md, AI_ERA_RIGOR_LITERATURE.md]
---

# What “big minds” talk about

Not a celebrity list — a map of **recurring themes** from high-visibility scientists, institutions, and practitioners. Details and DOIs live in companion briefs.

---

## Theme A — Evaluation as science

### Consensus message
**Scores are not science.** A benchmark, AUROC, or demo is evidence only if the claim, construct, uncertainty, and failure modes are specified. Leaderboards without validity are decision hazards.

### Who says what (representative)

| Voice / venue | Emphasis |
|---------------|----------|
| **Weidinger, Raji, Mitchell, Ganguli, et al.** (*Toward an Evaluation Science…*, 2025) | Real-world-valid metrics; iterate instruments; build **institutions/norms** — borrow from aviation/pharma safety eval |
| **Apollo Research** — “We Need a Science of Evals” | Evals must support high-stakes decisions; need coverage, robustness, replicability, statistical confidence — “ready for law” |
| **Stanford HAI / AIMS** — validating claims / AI measurement science | Separate **criterion** (directly measurable) vs **construct** (inferred); ask what the score licenses you to say |
| **Inioluwa Deborah Raji** (+ Gebru, Buolamwini) | Audits expose blind spots; benchmarks are a **low bar**, not a deployment certificate; accountability > ranking |
| **Margaret Mitchell / Timnit Gebru** | Model cards & datasheets: intended use, strata, limits — documentation is part of eval |
| **Gary Marcus / Ernie Davis** | Benchmarks are gameable; demand transparency of training data; don’t confuse polish with understanding |
| **Messick (measurement theory)** | Validate **inferences from scores**, not the test object itself |
| **Anthropic eval research** | Treat eval comparisons as statistical experiments; calibrate graders |

### One sentence they would endorse
*If you cannot say what would falsify the metric’s interpretation, you do not yet have an evaluation science — you have a scoreboard.*

---

## Theme B — The researcher in the AI era

### Consensus message
**Generation got cheap; justification got scarce.** Human accountability for claims cannot be delegated to models. Incentives that reward novelty/positive results still distort truth-seeking — AI amplifies that unless culture and gates change.

### Who says what

| Voice / venue | Emphasis |
|---------------|----------|
| **Nature / Science** editorial policy | AI may assist; **must not replace scholarly judgment**; no AI authorship (no accountability); disclose use |
| **Brian Nosek (COS)** | Culture problem: minds are biased *and* incentives reward publishable positives; fix norms + rewards (Registered Reports, TOP), not only workshops |
| **Ioannidis** | Field with many flexible analyses → high false-discovery rate; more automated probing worsens this without controls |
| **NASEM** *On Being a Scientist* | Method must match the question; resist trendy methods; value informative nulls |
| **Hinton / Bengio** (public risk discourse) | Builders carry **responsibility** for misuse and systemic risk — evaluation and governance are part of the job (LeCun more optimistic on open development; disagreement is about *policy*, not about needing better measurement) |
| **Frontier lab RE/RS roles** | Research engineers co-own **evaluation infrastructure**; papers often have engineer authors |

### One sentence they would endorse
*The AI-era researcher is judged less by how fast they produce artifacts and more by whether they can refuse unjustified ones.*

---

## Theme C — Training PhD / postdoc (and industry equivalents)

### Consensus message
**Teach design, transparency, and critique as core curriculum** — not only domain techniques. Training without incentive reform is incomplete; hiring and mentoring must reward rigor.

### Who says what / what programs do

| Voice / program | Emphasis |
|-----------------|----------|
| **NIH** | Required RCR; training-grant plans for **methods to enhance reproducibility**; modules on transparency, replicates, exclusion criteria |
| **NASEM** graduate STEM + reproducibility reports | Original research *and* computational/statistical literacy; institutions must train reproducibility |
| **Nosek / LMU-style open science hiring** | Teach preregistration/open data early; **hire** on open-science statements — change what PhDs optimize for |
| **PLOS Comp Biol teaching concepts** | Explicitly train “researcher degrees of freedom” / analysis multiplicity to fight selective reporting |
| **BMC Med Educ PBL courses** | Critical thinking + experimental design + NIH rigor modules in doctoral training |
| **Philosophy-of-inference workshops** (Clark et al.) | Epistemology for postgrads → more critical of design/inference months later |
| **Industry** | Eval ownership, model/datasheet cards, stratified reporting as professional skill (parallel to academic RCR) |

### One sentence they would endorse
*A doctorate (or research engineer role) should certify the ability to design a test that can kill your favorite result — and to document the chain so others can try.*

---

## How the three themes lock together

```text
Training (C)  →  produces researchers who
                   practice justification (B)
                   by treating measurement as science (A)
```

Big-lab / big-institution talk converges on:

1. **Validity over vibes** (eval science)  
2. **Accountability over fluency** (AI-era researcher)  
3. **Skills + incentives** (PhD/postdoc training)

Your lab docs (`AI_ERA_RIGOR.md`, `EVALUATION_AS_SCIENCE.md`) are a local operationalization of that consensus — not an outlier philosophy.

---

## Pointers

- Deep dive on eval: [EVALUATION_AS_SCIENCE.md](EVALUATION_AS_SCIENCE.md)  
- Broader source table: [AI_ERA_RIGOR_LITERATURE.md](AI_ERA_RIGOR_LITERATURE.md)  
- Lab operating definition: [AI_ERA_RIGOR.md](AI_ERA_RIGOR.md)  
