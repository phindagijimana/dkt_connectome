---
title: Credible literature on AI-era rigor, judgment, falsification, provenance
date: 2026-10-21
status: RESEARCH_BRIEF
companion: AI_ERA_RIGOR.md
scope: academia (PhD/postdoc) + industry research/engineering + funders/publishers
---

# AI-era rigor — literature brief

**Question 1:** Is redefining rigor toward verification, falsification, provenance, and justification (vs production) supported by credible sources?  
**Question 2:** How do academia and industry train judgment / falsification / provenance (PhD, postdoc, research engineer)?

**Short answer:** Yes. Your framework aligns with National Academies reproducibility guidance, NIH rigor training requirements, open-science standards (COS/TOP), classic meta-research on false discovery, publisher AI policies that keep **human accountability**, and industry ML documentation/eval practice (datasheets, model cards, eval science). Nobody uses your exact slogan; the **substance** is mainstream.

---

## 1. Authoritative framing: justification over production

| Source | What it establishes | Link to your pillars |
|--------|---------------------|----------------------|
| **NASEM (2019).** *Reproducibility and Replicability in Science* | Distinguishes reproducibility vs replicability; recommends training in stats, computation, transparent reporting; institutions (academia **and** industry/national labs) share responsibility | Provenance, verification, education |
| **NASEM (2024/25).** *On Being a Scientist* (4th ed.) — rigor module | “Method must match the question”; warn against choosing methods for trendiness; design for others to replicate; value null/uninformative results | Problem rigor, interpretive rigor, falsification |
| **NASEM (2018).** *Graduate STEM Education for the 21st Century* | PhD core = formulate problems, iterative solutions, original discovery, communicate impact — not mere output volume | Judgment as PhD identity |
| **Ioannidis (2005).** *Why Most Published Research Findings Are False* (PLOS Medicine) | More hypotheses + flexibility + bias → lower PPV; generation without controls inflates false discovery | Directly supports “AI throughput raises false-discovery risk” |
| **Ioannidis (2014).** *How to Make More Published Research True* | Remedies: replication culture, registration, sharing, better stats, **workforce training**, reward reform | Training + institutional incentives |
| **Center for Open Science — TOP Guidelines** (2015; **TOP 2025** update) | Verifiability of claims: registration, protocols, analysis plans, data/code transparency, verification studies (replication, registered reports, multiverse, many-analysts) | Provenance + falsification as policy |
| **COS Preregistration** | Separate exploration from confirmation; disclose deviations | Method + interpretive rigor |

**Publisher / AI accountability (your “capability ≠ validity”):**

| Source | Stance |
|--------|--------|
| **Nature AI policy** | AI may support; **must not replace scholarly judgement**; human accountability non-transferable; transparency required |
| **Nature (2023)** editorial on ChatGPT | No AI authorship (no accountability); document LLM use; opacity threatens trustworthiness |
| **Science** editorial policies / “Resisting AI slop” (2025–26) | Disclose AI beyond light editing; authors accountable for accuracy; more AI detection → **more human effort**, not less; resist literature degradation |

These sources do **not** say “stop using AI.” They say **production without accountable justification is not science**.

---

## 2. PhD and postdoc training (academia)

| Source | Audience | Practice relevant to judgment / falsification / provenance |
|--------|----------|--------------------------------------------------------------|
| **NIH** — RCR training (intramural + grant policy) | Trainees career-long | Misconduct vs QRPs; data management; **scientific rigor and reproducibility**; authorship; mentoring |
| **NIH** — Plan for Instruction in Methods for Enhancing Reproducibility (training grants) | T32 / fellowship programs | Required attachment: transparent reporting, rigorous design, interpretation, assessing prior-research rigor |
| **NIH / NIGMS** reproducibility training modules | PhD/postdoc labs | Transparency, blinding/randomization, sample size/exclusion, biological vs technical replicates |
| **Druilhet et al. / BMC Med Educ (2023).** PBL for doctoral critical thinking & experimental design | PhD | Explicit rigor prompts: controls, complementary methods, NIH modules in coursework |
| **Clark et al. (2024).** Philosophical inference workshop for postgrads | PhD/postdoc | Epistemology (induction/deduction/abduction); 6-month follow-up: more critical of inferences and design |
| **Ullmann et al. (2024).** PLOS Comp Biol — uncertain choices in data analysis | Grad / early PhD | Hands-on: multiplicity of analysis paths → selective reporting; teach researcher degrees of freedom |
| **Carpentries** (cited in NASEM) | Cross-career | Computational reproducibility literacy (Software/Data Carpentry) |

**Implication for training:** credible programs treat rigor as **curriculum + mentoring**, not only “learn more methods.” Your weekly claim/falsifier/provenance workout matches NIH/NASEM intent more than “generate more papers.”

---

## 3. Industry research & research engineering

| Source | Setting | What “good” looks like |
|--------|---------|-------------------------|
| **Gebru et al. (2018/2021).** Datasheets for Datasets (CACM) | Academia + piloted at Microsoft/Google/IBM | Structured provenance: motivation, composition, collection, recommended uses, maintenance |
| **Mitchell et al. (2019).** Model Cards for Model Reporting (Google et al.) | Industry ML release | Intended use, metrics across relevant strata, evaluation context — **limits of generalization** as first-class |
| **Google Data Cards Playbook** | Industry | Operational datasheet practice across lifecycle |
| **Weidinger, Raji, Wallach, Mitchell, Ganguli, et al. (2025).** *Toward an evaluation science for generative AI* | DeepMind / academia / Anthropic authors | Eval must map to real-world validity; iterative metrics; institutions/norms — benchmarks alone insufficient |
| **Anthropic** — statistical approach to model evals; agent evals engineering | Industry frontier labs | Eval as science: uncertainty, design, human calibration of graders — not one lucky benchmark |
| **DeepMind / OpenAI / Anthropic role design** (career pages; role continuum lit.) | Industry RS/RE | Research Engineers own **build + evaluate**; Anthropic often engineers as paper authors — engineering *is* research contribution when it enables valid claims |

**Implication:** In serious industry AI research, the scarce product is often **defensible evaluation and documentation**, not another unvalidated demo — the same shift you describe for neuroimaging methods engineers.

---

## 4. Mapping literature → your two questions

### Q1 — Is the redefined rigor credible?
**Yes, as a synthesis of existing standards**, not as a brand-new doctrine:

- NASEM + NIH already elevate design, transparency, reproducibility training.  
- Ioannidis + COS explain why **cheap hypothesis/analysis generation** (now amplified by AI) threatens truth.  
- Nature/Science insist **judgment and accountability stay human**.  
- Datasheets/model cards/eval science operationalize **provenance + generalization limits** in industry.

Your concise definition is a useful **umbrella**; cite the table above when talking to coauthors or PIs.

### Q2 — How to train judgment, falsification, provenance?
Credible systems already use:

| Skill | Established training mechanisms |
|-------|----------------------------------|
| **Judgment** | Match method to question (NASEM scientist guide); assess rigor of prior research (NIH); intended-use docs (model cards) |
| **Falsification / disconfirmation** | Preregistration + registered reports; replication/verification studies (TOP 2025); negative results valued; hostile evals in industry |
| **Provenance** | Data/code sharing; datasheets; versioned protocols; computational reproducibility education (NASEM Rec 6-6; Carpentries) |

**PhD/postdoc:** NIH RCR + reproducibility plans; PBL design courses; philosophy-of-inference workshops; “researcher degrees of freedom” seminars.  
**Industry RE/RS:** eval ownership, stratified reporting, documentation at release, statistical eval design.

---

## 4b. Evaluation as science (expanded)

See dedicated brief: [EVALUATION_AS_SCIENCE.md](EVALUATION_AS_SCIENCE.md).

Headline sources: Weidinger et al. (2025) arXiv:2503.05336; Messick validity; Model Cards / Datasheets; NeurIPS reproducibility checklist; Anthropic statistical evals; COS TOP verification practices.

## 5. Reading list (start here)

**Core (academia / funders)**  
1. NASEM (2019). *Reproducibility and Replicability in Science*. https://nap.nationalacademies.org/catalog/25303  
2. NIH rigor & reproducibility training hub. https://grants.nih.gov/policy-and-compliance/policy-topics/reproducibility/training  
3. Ioannidis JPA (2005). PLOS Medicine. https://doi.org/10.1371/journal.pmed.0020124  
4. Nosek / COS — TOP Guidelines. https://www.cos.io/initiatives/top-guidelines  
5. Nature AI editorial policies. https://www.nature.com/nature/editorial-policies/ai  

**Industry / ML documentation & eval**  
6. Gebru et al. Datasheets for Datasets. https://doi.org/10.1145/3458723  
7. Mitchell et al. Model Cards. https://arxiv.org/abs/1810.03993  
8. Weidinger et al. Toward an evaluation science for generative AI (2025). https://arxiv.org/abs/2503.05336  

**Training practice**  
9. Ullmann et al. (2024). Uncertain choices in empirical data analysis. PLOS Comp Biol. https://doi.org/10.1371/journal.pcbi.1011936  
10. Doctoral PBL + rigor (BMC Med Educ 2023). https://doi.org/10.1186/s12909-023-04569-7  

---

## 6. Caveat (rigor about the framework itself)

This brief supports **alignment with credible norms**. It does **not** claim your checklist is a validated psychometric instrument (same caveat as in `AI_ERA_RIGOR.md`). Use it as a lab standard and coauthor communication tool; when citing externally, prefer NASEM/NIH/COS/Nature primary sources.
