# Papers — planning workspace

Consolidated home for paper-specific documentation: cross-paper strategy,
per-paper research questions, candidate titles, analysis registries, and
complete-case tables. Pipeline methodology docs live one level up in
`docs/` and are linked below.

**Start here:** [`publication_strategy.md`](publication_strategy.md) —
the four-paper portfolio, journal targets, cohort plans, and prior-work
analog table.

**Deep dives:**

- [`journal_tier.md`](journal_tier.md) / [`journal_tier.docx`](journal_tier.docx) — full ten-venue landscape for Paper 2 with per-venue framing, required analyses, and section-by-section manuscript breakdown
- [`LQT.md`](LQT.md) / [`LQT.docx`](LQT.docx) — reference summary of the Lesion Quantification Toolkit and the normative-atlas disconnection family (LQT / BCBtoolkit / NeMo). Comparator for Paper 2 methods contribution.
- [`Griffis_later.md`](Griffis_later.md) / [`Griffis_later.docx`](Griffis_later.docx) — follow-up literature on the Griffis 2019 lineage (Salvalaggio 2020, Talozzi 2023, Kuceyeski work). Establishes reviewer-expected practice and where Paper 2 sits.

---

## Papers at a glance

| # | Paper | Status | Target | Per-paper doc |
|---|-------|--------|--------|---------------|
| 1 | **Factorial: anatomy × lesion-aware ACT in TBI** (flagship) | Active | *Human Brain Mapping* | [paper1_factorial.md](paper1_factorial.md) |
| 2 | **Clinical disconnectome → outcomes** | Conditional (pending clinical merge confirmation) | *J Neurotrauma* → *Brain* stretch | [paper2_disconnectome_outcomes.md](paper2_disconnectome_outcomes.md) |
| 3 | **Deep Atropos vs HSVS 5TT** | Supplement to Paper 1 | Paper 1 supplement | [paper3_deep_atropos.md](paper3_deep_atropos.md) |
| 4 | **Longitudinal connectome resource** (~1200 sessions) | Active parallel | *Scientific Data* / *GigaScience* | [paper4_longitudinal.md](paper4_longitudinal.md) |

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
