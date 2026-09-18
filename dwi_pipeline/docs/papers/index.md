# Papers — planning workspace

Consolidated home for paper-specific documentation: cross-paper strategy,
per-paper research questions, candidate titles, analysis registries, and
complete-case tables. Pipeline methodology docs live one level up in
`docs/` and are linked below.

**Start here:** [`publication_strategy.md`](publication_strategy.md) —
the four-paper portfolio, journal targets, cohort plans, and prior-work
analog table.

**Factorial paper cluster** — all artifacts live in [`factorial_paper/`](factorial_paper/) subfolder, each with matching `.docx`:

- [`factorial_paper/index.md`](factorial_paper/index.md) — canonical cover doc and navigation for the factorial paper; includes cross-tier paper-citation matrix
- [`factorial_paper/analysis_plan.md`](factorial_paper/analysis_plan.md) — pre-registration template with locked design choices + sign-off block (13 sections including the 6 arms, primary numeric outcome, contrast set, N thresholds, synthetic-lesion decision)
- [`factorial_paper/manuscript_skeleton.md`](factorial_paper/manuscript_skeleton.md) — section-by-section outline with word budgets, figure/table lists, and reference-list anchors
- [`factorial_paper/completion_tracker.md`](factorial_paper/completion_tracker.md) — per-subject × per-arm completion matrix with CONSORT-style assembly diagram and QC-metric dashboard
- [`factorial_paper/leapp_lineage.md`](factorial_paper/leapp_lineage.md) — deep summary of Bey 2024 (LeAPP) and lineage papers (Radwan VBG, Pollak neuroLIT, Smith ACT); establishes what we extend

**Disconnectome paper cluster** — all artifacts live in [`disconnectome/`](disconnectome/) subfolder, each with matching `.docx`:

- [`disconnectome/index.md`](disconnectome/index.md) — canonical cover doc and navigation for the disconnectome paper; includes cross-tier paper-citation matrix
- [`disconnectome/outcomes_planning.md`](disconnectome/outcomes_planning.md) — full detailed planning (RQs, data-level ceiling, Griffis-2019 contribution breakdown, design decisions)
- [`disconnectome/analysis_plan.md`](disconnectome/analysis_plan.md) — pre-registration template with locked design choices + sign-off block
- [`disconnectome/manuscript_skeleton.md`](disconnectome/manuscript_skeleton.md) — section-by-section outline with word budgets and figure/table lists
- [`disconnectome/complete_case.md`](disconnectome/complete_case.md) — subject-level tracking template with assembly diagram

**Deep dives / reference:**

- [`journal_tier.md`](journal_tier.md) / [`journal_tier.docx`](journal_tier.docx) — full ten-venue landscape for Paper 2 with per-venue framing, required analyses, and section-by-section manuscript breakdown
- [`LQT.md`](LQT.md) / [`LQT.docx`](LQT.docx) — reference summary of the Lesion Quantification Toolkit and the normative-atlas disconnection family (LQT / BCBtoolkit / NeMo). Comparator for Paper 2 methods contribution.
- [`Griffis_later.md`](Griffis_later.md) / [`Griffis_later.docx`](Griffis_later.docx) — follow-up literature on the Griffis 2019 lineage (Salvalaggio 2020, Talozzi 2023, Kuceyeski work, Boes 2015, Fox 2018). Establishes reviewer-expected practice and where Paper 2 sits.

---

## Papers at a glance

| # | Paper | Status | Target | Per-paper docs |
|---|-------|--------|--------|----------------|
| 1 | **Factorial: anatomy × lesion-aware ACT in TBI** (flagship) | Active | *Human Brain Mapping* | [`factorial_paper/`](factorial_paper/) — cluster (5 docs + .docx) |
| 2 | **Clinical disconnectome → outcomes** | Conditional (pending clinical merge confirmation) | *J Neurotrauma* → *Brain* stretch | [`disconnectome/`](disconnectome/) — cluster (5 docs + .docx) |
| 3 | **Deep Atropos vs HSVS 5TT** | Supplement to Paper 1 | Paper 1 supplement | [`paper3_deep_atropos.md`](paper3_deep_atropos.md) |
| 4 | **Longitudinal connectome resource** (~1200 sessions) | Active parallel | *Scientific Data* / *GigaScience* | [`paper4_longitudinal.md`](paper4_longitudinal.md) |

---

## Related pipeline documentation

Paper-relevant methodology and cohort docs stay under `docs/` (they serve
the pipeline itself, not any single paper):

- [Lesion-aware tractography](../lesion_aware.md) — LeAPP framework, VBT port, factorial contrasts
- [TBI experimental arms](../TBI_Experimental_Arms.md) — 3×2 factorial design + pilot tree
- [Step 4.1 disconnectome](../disconnectome.md) — spared connectome options A/B/C + integrity QC
- [Deep Atropos 5TT branch](../deep_atropos_5tt.md) — Paper 3 supplement details
- [Validation](../validation.md) — cohort validation context
- [References](../references.md) — full bibliography
- [Citation](../citation.md) — how to cite the pipeline

---

## Working conventions

- **Per-paper planning notes go in `paperN_*.md`**, not in `publication_strategy.md`.
- **Analysis registries / complete-case spreadsheets** should be added as
  `paperN_analysis_registry.md` or CSV siblings under this folder when
  they exist.
- **Draft manuscript text** (methods paragraphs, figure captions) stays here
  — not in root-level `docs/`.
- **Reusable methods prose** (e.g. the factorial description on inpainted
  arms) stays in the pipeline docs (`lesion_aware.md`) and is quoted from
  per-paper files.
